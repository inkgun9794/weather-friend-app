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
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshCity());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshCity();
    }
  }

  Future<void> _refreshCity() async {
    if (_refreshing || !mounted) return;
    if (!ref.read(onboardingCompleteProvider)) return;

    _refreshing = true;
    try {
      final perm = await Geolocator.checkPermission();
      if (perm != LocationPermission.always &&
          perm != LocationPermission.whileInUse) {
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 8),
        ),
      );

      final city = await _resolveCity(pos);
      await ref.read(selectedCityProvider.notifier).set(city);
      debugPrint('[location] weather city=${city.label} (${city.cityId})');
    } catch (e) {
      debugPrint('[location] city refresh skipped: $e');
    } finally {
      _refreshing = false;
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
      if (prev != true && next == true) _refreshCity();
    });
    return widget.child;
  }
}
