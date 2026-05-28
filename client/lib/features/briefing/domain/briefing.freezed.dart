// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'briefing.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$WeatherSnapshot {

@JsonKey(name: 'temperature_c') double get temperatureC;@JsonKey(name: 'feels_like_c') double get feelsLikeC; String get condition;@JsonKey(name: 'precipitation_prob') int get precipitationProb;@JsonKey(name: 'wind_speed_kmh') double get windSpeedKmh; int get humidity; int? get pm10;
/// Create a copy of WeatherSnapshot
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WeatherSnapshotCopyWith<WeatherSnapshot> get copyWith => _$WeatherSnapshotCopyWithImpl<WeatherSnapshot>(this as WeatherSnapshot, _$identity);

  /// Serializes this WeatherSnapshot to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WeatherSnapshot&&(identical(other.temperatureC, temperatureC) || other.temperatureC == temperatureC)&&(identical(other.feelsLikeC, feelsLikeC) || other.feelsLikeC == feelsLikeC)&&(identical(other.condition, condition) || other.condition == condition)&&(identical(other.precipitationProb, precipitationProb) || other.precipitationProb == precipitationProb)&&(identical(other.windSpeedKmh, windSpeedKmh) || other.windSpeedKmh == windSpeedKmh)&&(identical(other.humidity, humidity) || other.humidity == humidity)&&(identical(other.pm10, pm10) || other.pm10 == pm10));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,temperatureC,feelsLikeC,condition,precipitationProb,windSpeedKmh,humidity,pm10);

@override
String toString() {
  return 'WeatherSnapshot(temperatureC: $temperatureC, feelsLikeC: $feelsLikeC, condition: $condition, precipitationProb: $precipitationProb, windSpeedKmh: $windSpeedKmh, humidity: $humidity, pm10: $pm10)';
}


}

/// @nodoc
abstract mixin class $WeatherSnapshotCopyWith<$Res>  {
  factory $WeatherSnapshotCopyWith(WeatherSnapshot value, $Res Function(WeatherSnapshot) _then) = _$WeatherSnapshotCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'temperature_c') double temperatureC,@JsonKey(name: 'feels_like_c') double feelsLikeC, String condition,@JsonKey(name: 'precipitation_prob') int precipitationProb,@JsonKey(name: 'wind_speed_kmh') double windSpeedKmh, int humidity, int? pm10
});




}
/// @nodoc
class _$WeatherSnapshotCopyWithImpl<$Res>
    implements $WeatherSnapshotCopyWith<$Res> {
  _$WeatherSnapshotCopyWithImpl(this._self, this._then);

  final WeatherSnapshot _self;
  final $Res Function(WeatherSnapshot) _then;

/// Create a copy of WeatherSnapshot
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? temperatureC = null,Object? feelsLikeC = null,Object? condition = null,Object? precipitationProb = null,Object? windSpeedKmh = null,Object? humidity = null,Object? pm10 = freezed,}) {
  return _then(_self.copyWith(
temperatureC: null == temperatureC ? _self.temperatureC : temperatureC // ignore: cast_nullable_to_non_nullable
as double,feelsLikeC: null == feelsLikeC ? _self.feelsLikeC : feelsLikeC // ignore: cast_nullable_to_non_nullable
as double,condition: null == condition ? _self.condition : condition // ignore: cast_nullable_to_non_nullable
as String,precipitationProb: null == precipitationProb ? _self.precipitationProb : precipitationProb // ignore: cast_nullable_to_non_nullable
as int,windSpeedKmh: null == windSpeedKmh ? _self.windSpeedKmh : windSpeedKmh // ignore: cast_nullable_to_non_nullable
as double,humidity: null == humidity ? _self.humidity : humidity // ignore: cast_nullable_to_non_nullable
as int,pm10: freezed == pm10 ? _self.pm10 : pm10 // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [WeatherSnapshot].
extension WeatherSnapshotPatterns on WeatherSnapshot {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WeatherSnapshot value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WeatherSnapshot() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WeatherSnapshot value)  $default,){
final _that = this;
switch (_that) {
case _WeatherSnapshot():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WeatherSnapshot value)?  $default,){
final _that = this;
switch (_that) {
case _WeatherSnapshot() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'temperature_c')  double temperatureC, @JsonKey(name: 'feels_like_c')  double feelsLikeC,  String condition, @JsonKey(name: 'precipitation_prob')  int precipitationProb, @JsonKey(name: 'wind_speed_kmh')  double windSpeedKmh,  int humidity,  int? pm10)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WeatherSnapshot() when $default != null:
return $default(_that.temperatureC,_that.feelsLikeC,_that.condition,_that.precipitationProb,_that.windSpeedKmh,_that.humidity,_that.pm10);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'temperature_c')  double temperatureC, @JsonKey(name: 'feels_like_c')  double feelsLikeC,  String condition, @JsonKey(name: 'precipitation_prob')  int precipitationProb, @JsonKey(name: 'wind_speed_kmh')  double windSpeedKmh,  int humidity,  int? pm10)  $default,) {final _that = this;
switch (_that) {
case _WeatherSnapshot():
return $default(_that.temperatureC,_that.feelsLikeC,_that.condition,_that.precipitationProb,_that.windSpeedKmh,_that.humidity,_that.pm10);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'temperature_c')  double temperatureC, @JsonKey(name: 'feels_like_c')  double feelsLikeC,  String condition, @JsonKey(name: 'precipitation_prob')  int precipitationProb, @JsonKey(name: 'wind_speed_kmh')  double windSpeedKmh,  int humidity,  int? pm10)?  $default,) {final _that = this;
switch (_that) {
case _WeatherSnapshot() when $default != null:
return $default(_that.temperatureC,_that.feelsLikeC,_that.condition,_that.precipitationProb,_that.windSpeedKmh,_that.humidity,_that.pm10);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WeatherSnapshot implements WeatherSnapshot {
  const _WeatherSnapshot({@JsonKey(name: 'temperature_c') required this.temperatureC, @JsonKey(name: 'feels_like_c') required this.feelsLikeC, required this.condition, @JsonKey(name: 'precipitation_prob') required this.precipitationProb, @JsonKey(name: 'wind_speed_kmh') required this.windSpeedKmh, required this.humidity, this.pm10});
  factory _WeatherSnapshot.fromJson(Map<String, dynamic> json) => _$WeatherSnapshotFromJson(json);

@override@JsonKey(name: 'temperature_c') final  double temperatureC;
@override@JsonKey(name: 'feels_like_c') final  double feelsLikeC;
@override final  String condition;
@override@JsonKey(name: 'precipitation_prob') final  int precipitationProb;
@override@JsonKey(name: 'wind_speed_kmh') final  double windSpeedKmh;
@override final  int humidity;
@override final  int? pm10;

/// Create a copy of WeatherSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WeatherSnapshotCopyWith<_WeatherSnapshot> get copyWith => __$WeatherSnapshotCopyWithImpl<_WeatherSnapshot>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WeatherSnapshotToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WeatherSnapshot&&(identical(other.temperatureC, temperatureC) || other.temperatureC == temperatureC)&&(identical(other.feelsLikeC, feelsLikeC) || other.feelsLikeC == feelsLikeC)&&(identical(other.condition, condition) || other.condition == condition)&&(identical(other.precipitationProb, precipitationProb) || other.precipitationProb == precipitationProb)&&(identical(other.windSpeedKmh, windSpeedKmh) || other.windSpeedKmh == windSpeedKmh)&&(identical(other.humidity, humidity) || other.humidity == humidity)&&(identical(other.pm10, pm10) || other.pm10 == pm10));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,temperatureC,feelsLikeC,condition,precipitationProb,windSpeedKmh,humidity,pm10);

@override
String toString() {
  return 'WeatherSnapshot(temperatureC: $temperatureC, feelsLikeC: $feelsLikeC, condition: $condition, precipitationProb: $precipitationProb, windSpeedKmh: $windSpeedKmh, humidity: $humidity, pm10: $pm10)';
}


}

/// @nodoc
abstract mixin class _$WeatherSnapshotCopyWith<$Res> implements $WeatherSnapshotCopyWith<$Res> {
  factory _$WeatherSnapshotCopyWith(_WeatherSnapshot value, $Res Function(_WeatherSnapshot) _then) = __$WeatherSnapshotCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'temperature_c') double temperatureC,@JsonKey(name: 'feels_like_c') double feelsLikeC, String condition,@JsonKey(name: 'precipitation_prob') int precipitationProb,@JsonKey(name: 'wind_speed_kmh') double windSpeedKmh, int humidity, int? pm10
});




}
/// @nodoc
class __$WeatherSnapshotCopyWithImpl<$Res>
    implements _$WeatherSnapshotCopyWith<$Res> {
  __$WeatherSnapshotCopyWithImpl(this._self, this._then);

  final _WeatherSnapshot _self;
  final $Res Function(_WeatherSnapshot) _then;

/// Create a copy of WeatherSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? temperatureC = null,Object? feelsLikeC = null,Object? condition = null,Object? precipitationProb = null,Object? windSpeedKmh = null,Object? humidity = null,Object? pm10 = freezed,}) {
  return _then(_WeatherSnapshot(
temperatureC: null == temperatureC ? _self.temperatureC : temperatureC // ignore: cast_nullable_to_non_nullable
as double,feelsLikeC: null == feelsLikeC ? _self.feelsLikeC : feelsLikeC // ignore: cast_nullable_to_non_nullable
as double,condition: null == condition ? _self.condition : condition // ignore: cast_nullable_to_non_nullable
as String,precipitationProb: null == precipitationProb ? _self.precipitationProb : precipitationProb // ignore: cast_nullable_to_non_nullable
as int,windSpeedKmh: null == windSpeedKmh ? _self.windSpeedKmh : windSpeedKmh // ignore: cast_nullable_to_non_nullable
as double,humidity: null == humidity ? _self.humidity : humidity // ignore: cast_nullable_to_non_nullable
as int,pm10: freezed == pm10 ? _self.pm10 : pm10 // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}


/// @nodoc
mixin _$Briefing {

 String get city; String get date; int get hour;@JsonKey(name: 'character_id') String get characterId; BriefingType get type; String get transcript;@JsonKey(name: 'voice_script') String? get voiceScript;@JsonKey(name: 'audio_url') String? get audioUrl;@JsonKey(name: 'weather_snapshot') WeatherSnapshot? get weatherSnapshot;
/// Create a copy of Briefing
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BriefingCopyWith<Briefing> get copyWith => _$BriefingCopyWithImpl<Briefing>(this as Briefing, _$identity);

  /// Serializes this Briefing to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Briefing&&(identical(other.city, city) || other.city == city)&&(identical(other.date, date) || other.date == date)&&(identical(other.hour, hour) || other.hour == hour)&&(identical(other.characterId, characterId) || other.characterId == characterId)&&(identical(other.type, type) || other.type == type)&&(identical(other.transcript, transcript) || other.transcript == transcript)&&(identical(other.voiceScript, voiceScript) || other.voiceScript == voiceScript)&&(identical(other.audioUrl, audioUrl) || other.audioUrl == audioUrl)&&(identical(other.weatherSnapshot, weatherSnapshot) || other.weatherSnapshot == weatherSnapshot));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,city,date,hour,characterId,type,transcript,voiceScript,audioUrl,weatherSnapshot);

@override
String toString() {
  return 'Briefing(city: $city, date: $date, hour: $hour, characterId: $characterId, type: $type, transcript: $transcript, voiceScript: $voiceScript, audioUrl: $audioUrl, weatherSnapshot: $weatherSnapshot)';
}


}

/// @nodoc
abstract mixin class $BriefingCopyWith<$Res>  {
  factory $BriefingCopyWith(Briefing value, $Res Function(Briefing) _then) = _$BriefingCopyWithImpl;
@useResult
$Res call({
 String city, String date, int hour,@JsonKey(name: 'character_id') String characterId, BriefingType type, String transcript,@JsonKey(name: 'voice_script') String? voiceScript,@JsonKey(name: 'audio_url') String? audioUrl,@JsonKey(name: 'weather_snapshot') WeatherSnapshot? weatherSnapshot
});


$WeatherSnapshotCopyWith<$Res>? get weatherSnapshot;

}
/// @nodoc
class _$BriefingCopyWithImpl<$Res>
    implements $BriefingCopyWith<$Res> {
  _$BriefingCopyWithImpl(this._self, this._then);

  final Briefing _self;
  final $Res Function(Briefing) _then;

/// Create a copy of Briefing
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? city = null,Object? date = null,Object? hour = null,Object? characterId = null,Object? type = null,Object? transcript = null,Object? voiceScript = freezed,Object? audioUrl = freezed,Object? weatherSnapshot = freezed,}) {
  return _then(_self.copyWith(
city: null == city ? _self.city : city // ignore: cast_nullable_to_non_nullable
as String,date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as String,hour: null == hour ? _self.hour : hour // ignore: cast_nullable_to_non_nullable
as int,characterId: null == characterId ? _self.characterId : characterId // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as BriefingType,transcript: null == transcript ? _self.transcript : transcript // ignore: cast_nullable_to_non_nullable
as String,voiceScript: freezed == voiceScript ? _self.voiceScript : voiceScript // ignore: cast_nullable_to_non_nullable
as String?,audioUrl: freezed == audioUrl ? _self.audioUrl : audioUrl // ignore: cast_nullable_to_non_nullable
as String?,weatherSnapshot: freezed == weatherSnapshot ? _self.weatherSnapshot : weatherSnapshot // ignore: cast_nullable_to_non_nullable
as WeatherSnapshot?,
  ));
}
/// Create a copy of Briefing
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WeatherSnapshotCopyWith<$Res>? get weatherSnapshot {
    if (_self.weatherSnapshot == null) {
    return null;
  }

  return $WeatherSnapshotCopyWith<$Res>(_self.weatherSnapshot!, (value) {
    return _then(_self.copyWith(weatherSnapshot: value));
  });
}
}


/// Adds pattern-matching-related methods to [Briefing].
extension BriefingPatterns on Briefing {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Briefing value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Briefing() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Briefing value)  $default,){
final _that = this;
switch (_that) {
case _Briefing():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Briefing value)?  $default,){
final _that = this;
switch (_that) {
case _Briefing() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String city,  String date,  int hour, @JsonKey(name: 'character_id')  String characterId,  BriefingType type,  String transcript, @JsonKey(name: 'voice_script')  String? voiceScript, @JsonKey(name: 'audio_url')  String? audioUrl, @JsonKey(name: 'weather_snapshot')  WeatherSnapshot? weatherSnapshot)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Briefing() when $default != null:
return $default(_that.city,_that.date,_that.hour,_that.characterId,_that.type,_that.transcript,_that.voiceScript,_that.audioUrl,_that.weatherSnapshot);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String city,  String date,  int hour, @JsonKey(name: 'character_id')  String characterId,  BriefingType type,  String transcript, @JsonKey(name: 'voice_script')  String? voiceScript, @JsonKey(name: 'audio_url')  String? audioUrl, @JsonKey(name: 'weather_snapshot')  WeatherSnapshot? weatherSnapshot)  $default,) {final _that = this;
switch (_that) {
case _Briefing():
return $default(_that.city,_that.date,_that.hour,_that.characterId,_that.type,_that.transcript,_that.voiceScript,_that.audioUrl,_that.weatherSnapshot);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String city,  String date,  int hour, @JsonKey(name: 'character_id')  String characterId,  BriefingType type,  String transcript, @JsonKey(name: 'voice_script')  String? voiceScript, @JsonKey(name: 'audio_url')  String? audioUrl, @JsonKey(name: 'weather_snapshot')  WeatherSnapshot? weatherSnapshot)?  $default,) {final _that = this;
switch (_that) {
case _Briefing() when $default != null:
return $default(_that.city,_that.date,_that.hour,_that.characterId,_that.type,_that.transcript,_that.voiceScript,_that.audioUrl,_that.weatherSnapshot);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Briefing implements Briefing {
  const _Briefing({required this.city, required this.date, required this.hour, @JsonKey(name: 'character_id') required this.characterId, required this.type, required this.transcript, @JsonKey(name: 'voice_script') this.voiceScript, @JsonKey(name: 'audio_url') this.audioUrl, @JsonKey(name: 'weather_snapshot') this.weatherSnapshot});
  factory _Briefing.fromJson(Map<String, dynamic> json) => _$BriefingFromJson(json);

@override final  String city;
@override final  String date;
@override final  int hour;
@override@JsonKey(name: 'character_id') final  String characterId;
@override final  BriefingType type;
@override final  String transcript;
@override@JsonKey(name: 'voice_script') final  String? voiceScript;
@override@JsonKey(name: 'audio_url') final  String? audioUrl;
@override@JsonKey(name: 'weather_snapshot') final  WeatherSnapshot? weatherSnapshot;

/// Create a copy of Briefing
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BriefingCopyWith<_Briefing> get copyWith => __$BriefingCopyWithImpl<_Briefing>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BriefingToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Briefing&&(identical(other.city, city) || other.city == city)&&(identical(other.date, date) || other.date == date)&&(identical(other.hour, hour) || other.hour == hour)&&(identical(other.characterId, characterId) || other.characterId == characterId)&&(identical(other.type, type) || other.type == type)&&(identical(other.transcript, transcript) || other.transcript == transcript)&&(identical(other.voiceScript, voiceScript) || other.voiceScript == voiceScript)&&(identical(other.audioUrl, audioUrl) || other.audioUrl == audioUrl)&&(identical(other.weatherSnapshot, weatherSnapshot) || other.weatherSnapshot == weatherSnapshot));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,city,date,hour,characterId,type,transcript,voiceScript,audioUrl,weatherSnapshot);

@override
String toString() {
  return 'Briefing(city: $city, date: $date, hour: $hour, characterId: $characterId, type: $type, transcript: $transcript, voiceScript: $voiceScript, audioUrl: $audioUrl, weatherSnapshot: $weatherSnapshot)';
}


}

/// @nodoc
abstract mixin class _$BriefingCopyWith<$Res> implements $BriefingCopyWith<$Res> {
  factory _$BriefingCopyWith(_Briefing value, $Res Function(_Briefing) _then) = __$BriefingCopyWithImpl;
@override @useResult
$Res call({
 String city, String date, int hour,@JsonKey(name: 'character_id') String characterId, BriefingType type, String transcript,@JsonKey(name: 'voice_script') String? voiceScript,@JsonKey(name: 'audio_url') String? audioUrl,@JsonKey(name: 'weather_snapshot') WeatherSnapshot? weatherSnapshot
});


@override $WeatherSnapshotCopyWith<$Res>? get weatherSnapshot;

}
/// @nodoc
class __$BriefingCopyWithImpl<$Res>
    implements _$BriefingCopyWith<$Res> {
  __$BriefingCopyWithImpl(this._self, this._then);

  final _Briefing _self;
  final $Res Function(_Briefing) _then;

/// Create a copy of Briefing
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? city = null,Object? date = null,Object? hour = null,Object? characterId = null,Object? type = null,Object? transcript = null,Object? voiceScript = freezed,Object? audioUrl = freezed,Object? weatherSnapshot = freezed,}) {
  return _then(_Briefing(
city: null == city ? _self.city : city // ignore: cast_nullable_to_non_nullable
as String,date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as String,hour: null == hour ? _self.hour : hour // ignore: cast_nullable_to_non_nullable
as int,characterId: null == characterId ? _self.characterId : characterId // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as BriefingType,transcript: null == transcript ? _self.transcript : transcript // ignore: cast_nullable_to_non_nullable
as String,voiceScript: freezed == voiceScript ? _self.voiceScript : voiceScript // ignore: cast_nullable_to_non_nullable
as String?,audioUrl: freezed == audioUrl ? _self.audioUrl : audioUrl // ignore: cast_nullable_to_non_nullable
as String?,weatherSnapshot: freezed == weatherSnapshot ? _self.weatherSnapshot : weatherSnapshot // ignore: cast_nullable_to_non_nullable
as WeatherSnapshot?,
  ));
}

/// Create a copy of Briefing
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WeatherSnapshotCopyWith<$Res>? get weatherSnapshot {
    if (_self.weatherSnapshot == null) {
    return null;
  }

  return $WeatherSnapshotCopyWith<$Res>(_self.weatherSnapshot!, (value) {
    return _then(_self.copyWith(weatherSnapshot: value));
  });
}
}

// dart format on
