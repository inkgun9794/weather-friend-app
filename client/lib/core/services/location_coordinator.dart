import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:geolocator/geolocator.dart';
import 'package:weather_friend/features/location/data/city_catalog.dart';
import 'package:weather_friend/features/location/data/onboarding_provider.dart';
import 'package:weather_friend/features/location/data/selected_city_provider.dart';

/// Keeps weather city aligned with the device's current location.
///
/// This never asks for permission on its own. It only refreshes location when
/// permission is already granted, so users do not see surprise permission
/// prompts outside onboarding/settings flows.
class LocationCoordinator extends ConsumerStatefulWidget {
  const LocationCoordinator({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<LocationCoordinator> createState() =>
      _LocationCoordinatorState();
}

class _LocationCoordinatorState extends ConsumerState<LocationCoordinator>
    with WidgetsBindingObserver {
  static const _distanceFilterMeters = 2000;

  StreamSubscription<Position>? _positionSubscription;
  bool _startingUpdates = false;
  bool _resolvingCity = false;
  bool _isForeground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _startLocationUpdates(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_stopLocationUpdates());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _isForeground = true;
      _startLocationUpdates();
    } else {
      _isForeground = false;
      unawaited(_stopLocationUpdates());
    }
  }

  Future<void> _startLocationUpdates() async {
    if (_startingUpdates ||
        _positionSubscription != null ||
        !_isForeground ||
        !mounted) {
      return;
    }
    if (!ref.read(onboardingCompleteProvider)) return;

    _startingUpdates = true;
    try {
      final perm = await Geolocator.checkPermission();
      if (perm != LocationPermission.always &&
          perm != LocationPermission.whileInUse) {
        return;
      }

      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            timeLimit: Duration(seconds: 8),
          ),
        );
        await _applyPosition(pos);
      } catch (e) {
        debugPrint('[location] current position refresh skipped: $e');
      }

      if (!_isForeground || !mounted || !ref.read(onboardingCompleteProvider)) {
        return;
      }

      _positionSubscription =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.low,
              distanceFilter: _distanceFilterMeters,
            ),
          ).listen(
            (position) => unawaited(_applyPosition(position)),
            onError: (Object error) {
              debugPrint('[location] position stream stopped: $error');
              unawaited(_stopLocationUpdates());
            },
          );
    } catch (e) {
      debugPrint('[location] location updates unavailable: $e');
    } finally {
      _startingUpdates = false;
    }
  }

  Future<void> _stopLocationUpdates() async {
    final subscription = _positionSubscription;
    _positionSubscription = null;
    await subscription?.cancel();
  }

  Future<void> _applyPosition(Position pos) async {
    if (_resolvingCity || !mounted) return;

    _resolvingCity = true;
    try {
      final city = await _resolveCity(pos);
      final current = ref.read(selectedCityProvider);
      if (current.cityId == city.cityId) return;

      await ref.read(selectedCityProvider.notifier).set(city);
      debugPrint(
        '[location] weather city changed: '
        '${current.label} -> ${city.label} (${city.cityId})',
      );
    } catch (e) {
      debugPrint('[location] city refresh skipped: $e');
    } finally {
      _resolvingCity = false;
    }
  }

  Future<WeatherCity> _resolveCity(Position pos) async {
    try {
      final marks = await geocoding.placemarkFromCoordinates(
        pos.latitude,
        pos.longitude,
      );
      if (marks.isNotEmpty) {
        final mark = marks.first;
        final matched = await CityCatalog.matchAddress(
          administrativeArea: mark.administrativeArea,
          locality: mark.locality,
          subAdministrativeArea: mark.subAdministrativeArea,
          subLocality: mark.subLocality,
        );
        if (matched != null) return matched;
      }
    } catch (_) {
      /* fall through to nearest city */
    }
    return CityCatalog.nearest(lat: pos.latitude, lon: pos.longitude);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(onboardingCompleteProvider, (prev, next) {
      if (prev != true && next == true) {
        _startLocationUpdates();
      } else if (prev == true && next != true) {
        unawaited(_stopLocationUpdates());
      }
    });
    return widget.child;
  }
}
