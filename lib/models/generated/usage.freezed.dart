// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of '../usage.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$UsageCollectionParams {

 bool get enabled; int? get profileId; String get profileLabel; int get revision;
/// Create a copy of UsageCollectionParams
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UsageCollectionParamsCopyWith<UsageCollectionParams> get copyWith => _$UsageCollectionParamsCopyWithImpl<UsageCollectionParams>(this as UsageCollectionParams, _$identity);

  /// Serializes this UsageCollectionParams to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UsageCollectionParams&&(identical(other.enabled, enabled) || other.enabled == enabled)&&(identical(other.profileId, profileId) || other.profileId == profileId)&&(identical(other.profileLabel, profileLabel) || other.profileLabel == profileLabel)&&(identical(other.revision, revision) || other.revision == revision));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,enabled,profileId,profileLabel,revision);

@override
String toString() {
  return 'UsageCollectionParams(enabled: $enabled, profileId: $profileId, profileLabel: $profileLabel, revision: $revision)';
}


}

/// @nodoc
abstract mixin class $UsageCollectionParamsCopyWith<$Res>  {
  factory $UsageCollectionParamsCopyWith(UsageCollectionParams value, $Res Function(UsageCollectionParams) _then) = _$UsageCollectionParamsCopyWithImpl;
@useResult
$Res call({
 bool enabled, int? profileId, String profileLabel, int revision
});




}
/// @nodoc
class _$UsageCollectionParamsCopyWithImpl<$Res>
    implements $UsageCollectionParamsCopyWith<$Res> {
  _$UsageCollectionParamsCopyWithImpl(this._self, this._then);

  final UsageCollectionParams _self;
  final $Res Function(UsageCollectionParams) _then;

/// Create a copy of UsageCollectionParams
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? enabled = null,Object? profileId = freezed,Object? profileLabel = null,Object? revision = null,}) {
  return _then(_self.copyWith(
enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,profileId: freezed == profileId ? _self.profileId : profileId // ignore: cast_nullable_to_non_nullable
as int?,profileLabel: null == profileLabel ? _self.profileLabel : profileLabel // ignore: cast_nullable_to_non_nullable
as String,revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [UsageCollectionParams].
extension UsageCollectionParamsPatterns on UsageCollectionParams {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UsageCollectionParams value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UsageCollectionParams() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UsageCollectionParams value)  $default,){
final _that = this;
switch (_that) {
case _UsageCollectionParams():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UsageCollectionParams value)?  $default,){
final _that = this;
switch (_that) {
case _UsageCollectionParams() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool enabled,  int? profileId,  String profileLabel,  int revision)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UsageCollectionParams() when $default != null:
return $default(_that.enabled,_that.profileId,_that.profileLabel,_that.revision);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool enabled,  int? profileId,  String profileLabel,  int revision)  $default,) {final _that = this;
switch (_that) {
case _UsageCollectionParams():
return $default(_that.enabled,_that.profileId,_that.profileLabel,_that.revision);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool enabled,  int? profileId,  String profileLabel,  int revision)?  $default,) {final _that = this;
switch (_that) {
case _UsageCollectionParams() when $default != null:
return $default(_that.enabled,_that.profileId,_that.profileLabel,_that.revision);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _UsageCollectionParams implements UsageCollectionParams {
  const _UsageCollectionParams({required this.enabled, this.profileId, required this.profileLabel, this.revision = 0});
  factory _UsageCollectionParams.fromJson(Map<String, dynamic> json) => _$UsageCollectionParamsFromJson(json);

@override final  bool enabled;
@override final  int? profileId;
@override final  String profileLabel;
@override@JsonKey() final  int revision;

/// Create a copy of UsageCollectionParams
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UsageCollectionParamsCopyWith<_UsageCollectionParams> get copyWith => __$UsageCollectionParamsCopyWithImpl<_UsageCollectionParams>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UsageCollectionParamsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UsageCollectionParams&&(identical(other.enabled, enabled) || other.enabled == enabled)&&(identical(other.profileId, profileId) || other.profileId == profileId)&&(identical(other.profileLabel, profileLabel) || other.profileLabel == profileLabel)&&(identical(other.revision, revision) || other.revision == revision));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,enabled,profileId,profileLabel,revision);

@override
String toString() {
  return 'UsageCollectionParams(enabled: $enabled, profileId: $profileId, profileLabel: $profileLabel, revision: $revision)';
}


}

/// @nodoc
abstract mixin class _$UsageCollectionParamsCopyWith<$Res> implements $UsageCollectionParamsCopyWith<$Res> {
  factory _$UsageCollectionParamsCopyWith(_UsageCollectionParams value, $Res Function(_UsageCollectionParams) _then) = __$UsageCollectionParamsCopyWithImpl;
@override @useResult
$Res call({
 bool enabled, int? profileId, String profileLabel, int revision
});




}
/// @nodoc
class __$UsageCollectionParamsCopyWithImpl<$Res>
    implements _$UsageCollectionParamsCopyWith<$Res> {
  __$UsageCollectionParamsCopyWithImpl(this._self, this._then);

  final _UsageCollectionParams _self;
  final $Res Function(_UsageCollectionParams) _then;

/// Create a copy of UsageCollectionParams
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? enabled = null,Object? profileId = freezed,Object? profileLabel = null,Object? revision = null,}) {
  return _then(_UsageCollectionParams(
enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,profileId: freezed == profileId ? _self.profileId : profileId // ignore: cast_nullable_to_non_nullable
as int?,profileLabel: null == profileLabel ? _self.profileLabel : profileLabel // ignore: cast_nullable_to_non_nullable
as String,revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$UsageBatchAck {

 String get sessionId; int get sequence;
/// Create a copy of UsageBatchAck
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UsageBatchAckCopyWith<UsageBatchAck> get copyWith => _$UsageBatchAckCopyWithImpl<UsageBatchAck>(this as UsageBatchAck, _$identity);

  /// Serializes this UsageBatchAck to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UsageBatchAck&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.sequence, sequence) || other.sequence == sequence));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionId,sequence);

@override
String toString() {
  return 'UsageBatchAck(sessionId: $sessionId, sequence: $sequence)';
}


}

/// @nodoc
abstract mixin class $UsageBatchAckCopyWith<$Res>  {
  factory $UsageBatchAckCopyWith(UsageBatchAck value, $Res Function(UsageBatchAck) _then) = _$UsageBatchAckCopyWithImpl;
@useResult
$Res call({
 String sessionId, int sequence
});




}
/// @nodoc
class _$UsageBatchAckCopyWithImpl<$Res>
    implements $UsageBatchAckCopyWith<$Res> {
  _$UsageBatchAckCopyWithImpl(this._self, this._then);

  final UsageBatchAck _self;
  final $Res Function(UsageBatchAck) _then;

/// Create a copy of UsageBatchAck
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sessionId = null,Object? sequence = null,}) {
  return _then(_self.copyWith(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,sequence: null == sequence ? _self.sequence : sequence // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [UsageBatchAck].
extension UsageBatchAckPatterns on UsageBatchAck {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UsageBatchAck value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UsageBatchAck() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UsageBatchAck value)  $default,){
final _that = this;
switch (_that) {
case _UsageBatchAck():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UsageBatchAck value)?  $default,){
final _that = this;
switch (_that) {
case _UsageBatchAck() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String sessionId,  int sequence)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UsageBatchAck() when $default != null:
return $default(_that.sessionId,_that.sequence);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String sessionId,  int sequence)  $default,) {final _that = this;
switch (_that) {
case _UsageBatchAck():
return $default(_that.sessionId,_that.sequence);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String sessionId,  int sequence)?  $default,) {final _that = this;
switch (_that) {
case _UsageBatchAck() when $default != null:
return $default(_that.sessionId,_that.sequence);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _UsageBatchAck implements UsageBatchAck {
  const _UsageBatchAck({required this.sessionId, required this.sequence});
  factory _UsageBatchAck.fromJson(Map<String, dynamic> json) => _$UsageBatchAckFromJson(json);

@override final  String sessionId;
@override final  int sequence;

/// Create a copy of UsageBatchAck
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UsageBatchAckCopyWith<_UsageBatchAck> get copyWith => __$UsageBatchAckCopyWithImpl<_UsageBatchAck>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UsageBatchAckToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UsageBatchAck&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.sequence, sequence) || other.sequence == sequence));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionId,sequence);

@override
String toString() {
  return 'UsageBatchAck(sessionId: $sessionId, sequence: $sequence)';
}


}

/// @nodoc
abstract mixin class _$UsageBatchAckCopyWith<$Res> implements $UsageBatchAckCopyWith<$Res> {
  factory _$UsageBatchAckCopyWith(_UsageBatchAck value, $Res Function(_UsageBatchAck) _then) = __$UsageBatchAckCopyWithImpl;
@override @useResult
$Res call({
 String sessionId, int sequence
});




}
/// @nodoc
class __$UsageBatchAckCopyWithImpl<$Res>
    implements _$UsageBatchAckCopyWith<$Res> {
  __$UsageBatchAckCopyWithImpl(this._self, this._then);

  final _UsageBatchAck _self;
  final $Res Function(_UsageBatchAck) _then;

/// Create a copy of UsageBatchAck
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sessionId = null,Object? sequence = null,}) {
  return _then(_UsageBatchAck(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,sequence: null == sequence ? _self.sequence : sequence // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$UsageBucketData {

 int get minute; int? get profileId; String get profileLabel; UsageRoute get route; String get node; String get process; String get processPath; String get domain; String get host; String get destinationIP; int get upload; int get download; int get connections;
/// Create a copy of UsageBucketData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UsageBucketDataCopyWith<UsageBucketData> get copyWith => _$UsageBucketDataCopyWithImpl<UsageBucketData>(this as UsageBucketData, _$identity);

  /// Serializes this UsageBucketData to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UsageBucketData&&(identical(other.minute, minute) || other.minute == minute)&&(identical(other.profileId, profileId) || other.profileId == profileId)&&(identical(other.profileLabel, profileLabel) || other.profileLabel == profileLabel)&&(identical(other.route, route) || other.route == route)&&(identical(other.node, node) || other.node == node)&&(identical(other.process, process) || other.process == process)&&(identical(other.processPath, processPath) || other.processPath == processPath)&&(identical(other.domain, domain) || other.domain == domain)&&(identical(other.host, host) || other.host == host)&&(identical(other.destinationIP, destinationIP) || other.destinationIP == destinationIP)&&(identical(other.upload, upload) || other.upload == upload)&&(identical(other.download, download) || other.download == download)&&(identical(other.connections, connections) || other.connections == connections));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,minute,profileId,profileLabel,route,node,process,processPath,domain,host,destinationIP,upload,download,connections);

@override
String toString() {
  return 'UsageBucketData(minute: $minute, profileId: $profileId, profileLabel: $profileLabel, route: $route, node: $node, process: $process, processPath: $processPath, domain: $domain, host: $host, destinationIP: $destinationIP, upload: $upload, download: $download, connections: $connections)';
}


}

/// @nodoc
abstract mixin class $UsageBucketDataCopyWith<$Res>  {
  factory $UsageBucketDataCopyWith(UsageBucketData value, $Res Function(UsageBucketData) _then) = _$UsageBucketDataCopyWithImpl;
@useResult
$Res call({
 int minute, int? profileId, String profileLabel, UsageRoute route, String node, String process, String processPath, String domain, String host, String destinationIP, int upload, int download, int connections
});




}
/// @nodoc
class _$UsageBucketDataCopyWithImpl<$Res>
    implements $UsageBucketDataCopyWith<$Res> {
  _$UsageBucketDataCopyWithImpl(this._self, this._then);

  final UsageBucketData _self;
  final $Res Function(UsageBucketData) _then;

/// Create a copy of UsageBucketData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? minute = null,Object? profileId = freezed,Object? profileLabel = null,Object? route = null,Object? node = null,Object? process = null,Object? processPath = null,Object? domain = null,Object? host = null,Object? destinationIP = null,Object? upload = null,Object? download = null,Object? connections = null,}) {
  return _then(_self.copyWith(
minute: null == minute ? _self.minute : minute // ignore: cast_nullable_to_non_nullable
as int,profileId: freezed == profileId ? _self.profileId : profileId // ignore: cast_nullable_to_non_nullable
as int?,profileLabel: null == profileLabel ? _self.profileLabel : profileLabel // ignore: cast_nullable_to_non_nullable
as String,route: null == route ? _self.route : route // ignore: cast_nullable_to_non_nullable
as UsageRoute,node: null == node ? _self.node : node // ignore: cast_nullable_to_non_nullable
as String,process: null == process ? _self.process : process // ignore: cast_nullable_to_non_nullable
as String,processPath: null == processPath ? _self.processPath : processPath // ignore: cast_nullable_to_non_nullable
as String,domain: null == domain ? _self.domain : domain // ignore: cast_nullable_to_non_nullable
as String,host: null == host ? _self.host : host // ignore: cast_nullable_to_non_nullable
as String,destinationIP: null == destinationIP ? _self.destinationIP : destinationIP // ignore: cast_nullable_to_non_nullable
as String,upload: null == upload ? _self.upload : upload // ignore: cast_nullable_to_non_nullable
as int,download: null == download ? _self.download : download // ignore: cast_nullable_to_non_nullable
as int,connections: null == connections ? _self.connections : connections // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [UsageBucketData].
extension UsageBucketDataPatterns on UsageBucketData {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UsageBucketData value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UsageBucketData() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UsageBucketData value)  $default,){
final _that = this;
switch (_that) {
case _UsageBucketData():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UsageBucketData value)?  $default,){
final _that = this;
switch (_that) {
case _UsageBucketData() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int minute,  int? profileId,  String profileLabel,  UsageRoute route,  String node,  String process,  String processPath,  String domain,  String host,  String destinationIP,  int upload,  int download,  int connections)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UsageBucketData() when $default != null:
return $default(_that.minute,_that.profileId,_that.profileLabel,_that.route,_that.node,_that.process,_that.processPath,_that.domain,_that.host,_that.destinationIP,_that.upload,_that.download,_that.connections);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int minute,  int? profileId,  String profileLabel,  UsageRoute route,  String node,  String process,  String processPath,  String domain,  String host,  String destinationIP,  int upload,  int download,  int connections)  $default,) {final _that = this;
switch (_that) {
case _UsageBucketData():
return $default(_that.minute,_that.profileId,_that.profileLabel,_that.route,_that.node,_that.process,_that.processPath,_that.domain,_that.host,_that.destinationIP,_that.upload,_that.download,_that.connections);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int minute,  int? profileId,  String profileLabel,  UsageRoute route,  String node,  String process,  String processPath,  String domain,  String host,  String destinationIP,  int upload,  int download,  int connections)?  $default,) {final _that = this;
switch (_that) {
case _UsageBucketData() when $default != null:
return $default(_that.minute,_that.profileId,_that.profileLabel,_that.route,_that.node,_that.process,_that.processPath,_that.domain,_that.host,_that.destinationIP,_that.upload,_that.download,_that.connections);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _UsageBucketData implements UsageBucketData {
  const _UsageBucketData({required this.minute, this.profileId, this.profileLabel = '', this.route = UsageRoute.unknown, this.node = '', this.process = '', this.processPath = '', this.domain = '', this.host = '', this.destinationIP = '', this.upload = 0, this.download = 0, this.connections = 0});
  factory _UsageBucketData.fromJson(Map<String, dynamic> json) => _$UsageBucketDataFromJson(json);

@override final  int minute;
@override final  int? profileId;
@override@JsonKey() final  String profileLabel;
@override@JsonKey() final  UsageRoute route;
@override@JsonKey() final  String node;
@override@JsonKey() final  String process;
@override@JsonKey() final  String processPath;
@override@JsonKey() final  String domain;
@override@JsonKey() final  String host;
@override@JsonKey() final  String destinationIP;
@override@JsonKey() final  int upload;
@override@JsonKey() final  int download;
@override@JsonKey() final  int connections;

/// Create a copy of UsageBucketData
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UsageBucketDataCopyWith<_UsageBucketData> get copyWith => __$UsageBucketDataCopyWithImpl<_UsageBucketData>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UsageBucketDataToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UsageBucketData&&(identical(other.minute, minute) || other.minute == minute)&&(identical(other.profileId, profileId) || other.profileId == profileId)&&(identical(other.profileLabel, profileLabel) || other.profileLabel == profileLabel)&&(identical(other.route, route) || other.route == route)&&(identical(other.node, node) || other.node == node)&&(identical(other.process, process) || other.process == process)&&(identical(other.processPath, processPath) || other.processPath == processPath)&&(identical(other.domain, domain) || other.domain == domain)&&(identical(other.host, host) || other.host == host)&&(identical(other.destinationIP, destinationIP) || other.destinationIP == destinationIP)&&(identical(other.upload, upload) || other.upload == upload)&&(identical(other.download, download) || other.download == download)&&(identical(other.connections, connections) || other.connections == connections));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,minute,profileId,profileLabel,route,node,process,processPath,domain,host,destinationIP,upload,download,connections);

@override
String toString() {
  return 'UsageBucketData(minute: $minute, profileId: $profileId, profileLabel: $profileLabel, route: $route, node: $node, process: $process, processPath: $processPath, domain: $domain, host: $host, destinationIP: $destinationIP, upload: $upload, download: $download, connections: $connections)';
}


}

/// @nodoc
abstract mixin class _$UsageBucketDataCopyWith<$Res> implements $UsageBucketDataCopyWith<$Res> {
  factory _$UsageBucketDataCopyWith(_UsageBucketData value, $Res Function(_UsageBucketData) _then) = __$UsageBucketDataCopyWithImpl;
@override @useResult
$Res call({
 int minute, int? profileId, String profileLabel, UsageRoute route, String node, String process, String processPath, String domain, String host, String destinationIP, int upload, int download, int connections
});




}
/// @nodoc
class __$UsageBucketDataCopyWithImpl<$Res>
    implements _$UsageBucketDataCopyWith<$Res> {
  __$UsageBucketDataCopyWithImpl(this._self, this._then);

  final _UsageBucketData _self;
  final $Res Function(_UsageBucketData) _then;

/// Create a copy of UsageBucketData
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? minute = null,Object? profileId = freezed,Object? profileLabel = null,Object? route = null,Object? node = null,Object? process = null,Object? processPath = null,Object? domain = null,Object? host = null,Object? destinationIP = null,Object? upload = null,Object? download = null,Object? connections = null,}) {
  return _then(_UsageBucketData(
minute: null == minute ? _self.minute : minute // ignore: cast_nullable_to_non_nullable
as int,profileId: freezed == profileId ? _self.profileId : profileId // ignore: cast_nullable_to_non_nullable
as int?,profileLabel: null == profileLabel ? _self.profileLabel : profileLabel // ignore: cast_nullable_to_non_nullable
as String,route: null == route ? _self.route : route // ignore: cast_nullable_to_non_nullable
as UsageRoute,node: null == node ? _self.node : node // ignore: cast_nullable_to_non_nullable
as String,process: null == process ? _self.process : process // ignore: cast_nullable_to_non_nullable
as String,processPath: null == processPath ? _self.processPath : processPath // ignore: cast_nullable_to_non_nullable
as String,domain: null == domain ? _self.domain : domain // ignore: cast_nullable_to_non_nullable
as String,host: null == host ? _self.host : host // ignore: cast_nullable_to_non_nullable
as String,destinationIP: null == destinationIP ? _self.destinationIP : destinationIP // ignore: cast_nullable_to_non_nullable
as String,upload: null == upload ? _self.upload : upload // ignore: cast_nullable_to_non_nullable
as int,download: null == download ? _self.download : download // ignore: cast_nullable_to_non_nullable
as int,connections: null == connections ? _self.connections : connections // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$UsageBatch {

 String get sessionId; int get sequence; List<UsageBucketData> get buckets; bool get degraded; int get degradedStartMinute; int get degradedEndMinute;
/// Create a copy of UsageBatch
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UsageBatchCopyWith<UsageBatch> get copyWith => _$UsageBatchCopyWithImpl<UsageBatch>(this as UsageBatch, _$identity);

  /// Serializes this UsageBatch to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UsageBatch&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.sequence, sequence) || other.sequence == sequence)&&const DeepCollectionEquality().equals(other.buckets, buckets)&&(identical(other.degraded, degraded) || other.degraded == degraded)&&(identical(other.degradedStartMinute, degradedStartMinute) || other.degradedStartMinute == degradedStartMinute)&&(identical(other.degradedEndMinute, degradedEndMinute) || other.degradedEndMinute == degradedEndMinute));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionId,sequence,const DeepCollectionEquality().hash(buckets),degraded,degradedStartMinute,degradedEndMinute);

@override
String toString() {
  return 'UsageBatch(sessionId: $sessionId, sequence: $sequence, buckets: $buckets, degraded: $degraded, degradedStartMinute: $degradedStartMinute, degradedEndMinute: $degradedEndMinute)';
}


}

/// @nodoc
abstract mixin class $UsageBatchCopyWith<$Res>  {
  factory $UsageBatchCopyWith(UsageBatch value, $Res Function(UsageBatch) _then) = _$UsageBatchCopyWithImpl;
@useResult
$Res call({
 String sessionId, int sequence, List<UsageBucketData> buckets, bool degraded, int degradedStartMinute, int degradedEndMinute
});




}
/// @nodoc
class _$UsageBatchCopyWithImpl<$Res>
    implements $UsageBatchCopyWith<$Res> {
  _$UsageBatchCopyWithImpl(this._self, this._then);

  final UsageBatch _self;
  final $Res Function(UsageBatch) _then;

/// Create a copy of UsageBatch
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sessionId = null,Object? sequence = null,Object? buckets = null,Object? degraded = null,Object? degradedStartMinute = null,Object? degradedEndMinute = null,}) {
  return _then(_self.copyWith(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,sequence: null == sequence ? _self.sequence : sequence // ignore: cast_nullable_to_non_nullable
as int,buckets: null == buckets ? _self.buckets : buckets // ignore: cast_nullable_to_non_nullable
as List<UsageBucketData>,degraded: null == degraded ? _self.degraded : degraded // ignore: cast_nullable_to_non_nullable
as bool,degradedStartMinute: null == degradedStartMinute ? _self.degradedStartMinute : degradedStartMinute // ignore: cast_nullable_to_non_nullable
as int,degradedEndMinute: null == degradedEndMinute ? _self.degradedEndMinute : degradedEndMinute // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [UsageBatch].
extension UsageBatchPatterns on UsageBatch {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UsageBatch value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UsageBatch() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UsageBatch value)  $default,){
final _that = this;
switch (_that) {
case _UsageBatch():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UsageBatch value)?  $default,){
final _that = this;
switch (_that) {
case _UsageBatch() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String sessionId,  int sequence,  List<UsageBucketData> buckets,  bool degraded,  int degradedStartMinute,  int degradedEndMinute)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UsageBatch() when $default != null:
return $default(_that.sessionId,_that.sequence,_that.buckets,_that.degraded,_that.degradedStartMinute,_that.degradedEndMinute);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String sessionId,  int sequence,  List<UsageBucketData> buckets,  bool degraded,  int degradedStartMinute,  int degradedEndMinute)  $default,) {final _that = this;
switch (_that) {
case _UsageBatch():
return $default(_that.sessionId,_that.sequence,_that.buckets,_that.degraded,_that.degradedStartMinute,_that.degradedEndMinute);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String sessionId,  int sequence,  List<UsageBucketData> buckets,  bool degraded,  int degradedStartMinute,  int degradedEndMinute)?  $default,) {final _that = this;
switch (_that) {
case _UsageBatch() when $default != null:
return $default(_that.sessionId,_that.sequence,_that.buckets,_that.degraded,_that.degradedStartMinute,_that.degradedEndMinute);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _UsageBatch implements UsageBatch {
  const _UsageBatch({required this.sessionId, required this.sequence, final  List<UsageBucketData> buckets = const [], this.degraded = false, this.degradedStartMinute = 0, this.degradedEndMinute = 0}): _buckets = buckets;
  factory _UsageBatch.fromJson(Map<String, dynamic> json) => _$UsageBatchFromJson(json);

@override final  String sessionId;
@override final  int sequence;
 final  List<UsageBucketData> _buckets;
@override@JsonKey() List<UsageBucketData> get buckets {
  if (_buckets is EqualUnmodifiableListView) return _buckets;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_buckets);
}

@override@JsonKey() final  bool degraded;
@override@JsonKey() final  int degradedStartMinute;
@override@JsonKey() final  int degradedEndMinute;

/// Create a copy of UsageBatch
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UsageBatchCopyWith<_UsageBatch> get copyWith => __$UsageBatchCopyWithImpl<_UsageBatch>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UsageBatchToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UsageBatch&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.sequence, sequence) || other.sequence == sequence)&&const DeepCollectionEquality().equals(other._buckets, _buckets)&&(identical(other.degraded, degraded) || other.degraded == degraded)&&(identical(other.degradedStartMinute, degradedStartMinute) || other.degradedStartMinute == degradedStartMinute)&&(identical(other.degradedEndMinute, degradedEndMinute) || other.degradedEndMinute == degradedEndMinute));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionId,sequence,const DeepCollectionEquality().hash(_buckets),degraded,degradedStartMinute,degradedEndMinute);

@override
String toString() {
  return 'UsageBatch(sessionId: $sessionId, sequence: $sequence, buckets: $buckets, degraded: $degraded, degradedStartMinute: $degradedStartMinute, degradedEndMinute: $degradedEndMinute)';
}


}

/// @nodoc
abstract mixin class _$UsageBatchCopyWith<$Res> implements $UsageBatchCopyWith<$Res> {
  factory _$UsageBatchCopyWith(_UsageBatch value, $Res Function(_UsageBatch) _then) = __$UsageBatchCopyWithImpl;
@override @useResult
$Res call({
 String sessionId, int sequence, List<UsageBucketData> buckets, bool degraded, int degradedStartMinute, int degradedEndMinute
});




}
/// @nodoc
class __$UsageBatchCopyWithImpl<$Res>
    implements _$UsageBatchCopyWith<$Res> {
  __$UsageBatchCopyWithImpl(this._self, this._then);

  final _UsageBatch _self;
  final $Res Function(_UsageBatch) _then;

/// Create a copy of UsageBatch
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sessionId = null,Object? sequence = null,Object? buckets = null,Object? degraded = null,Object? degradedStartMinute = null,Object? degradedEndMinute = null,}) {
  return _then(_UsageBatch(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,sequence: null == sequence ? _self.sequence : sequence // ignore: cast_nullable_to_non_nullable
as int,buckets: null == buckets ? _self._buckets : buckets // ignore: cast_nullable_to_non_nullable
as List<UsageBucketData>,degraded: null == degraded ? _self.degraded : degraded // ignore: cast_nullable_to_non_nullable
as bool,degradedStartMinute: null == degradedStartMinute ? _self.degradedStartMinute : degradedStartMinute // ignore: cast_nullable_to_non_nullable
as int,degradedEndMinute: null == degradedEndMinute ? _self.degradedEndMinute : degradedEndMinute // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$UsageFilter {

 DateTime get start; DateTime get end; UsageTrafficScope get scope; int? get profileId; String? get profileLabel; String? get node; String? get processPath; String? get processLabel; String? get domain; bool get liveEnd; bool get calendarToday; Duration? get rollingWindow;
/// Create a copy of UsageFilter
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UsageFilterCopyWith<UsageFilter> get copyWith => _$UsageFilterCopyWithImpl<UsageFilter>(this as UsageFilter, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UsageFilter&&(identical(other.start, start) || other.start == start)&&(identical(other.end, end) || other.end == end)&&(identical(other.scope, scope) || other.scope == scope)&&(identical(other.profileId, profileId) || other.profileId == profileId)&&(identical(other.profileLabel, profileLabel) || other.profileLabel == profileLabel)&&(identical(other.node, node) || other.node == node)&&(identical(other.processPath, processPath) || other.processPath == processPath)&&(identical(other.processLabel, processLabel) || other.processLabel == processLabel)&&(identical(other.domain, domain) || other.domain == domain)&&(identical(other.liveEnd, liveEnd) || other.liveEnd == liveEnd)&&(identical(other.calendarToday, calendarToday) || other.calendarToday == calendarToday)&&(identical(other.rollingWindow, rollingWindow) || other.rollingWindow == rollingWindow));
}


@override
int get hashCode => Object.hash(runtimeType,start,end,scope,profileId,profileLabel,node,processPath,processLabel,domain,liveEnd,calendarToday,rollingWindow);

@override
String toString() {
  return 'UsageFilter(start: $start, end: $end, scope: $scope, profileId: $profileId, profileLabel: $profileLabel, node: $node, processPath: $processPath, processLabel: $processLabel, domain: $domain, liveEnd: $liveEnd, calendarToday: $calendarToday, rollingWindow: $rollingWindow)';
}


}

/// @nodoc
abstract mixin class $UsageFilterCopyWith<$Res>  {
  factory $UsageFilterCopyWith(UsageFilter value, $Res Function(UsageFilter) _then) = _$UsageFilterCopyWithImpl;
@useResult
$Res call({
 DateTime start, DateTime end, UsageTrafficScope scope, int? profileId, String? profileLabel, String? node, String? processPath, String? processLabel, String? domain, bool liveEnd, bool calendarToday, Duration? rollingWindow
});




}
/// @nodoc
class _$UsageFilterCopyWithImpl<$Res>
    implements $UsageFilterCopyWith<$Res> {
  _$UsageFilterCopyWithImpl(this._self, this._then);

  final UsageFilter _self;
  final $Res Function(UsageFilter) _then;

/// Create a copy of UsageFilter
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? start = null,Object? end = null,Object? scope = null,Object? profileId = freezed,Object? profileLabel = freezed,Object? node = freezed,Object? processPath = freezed,Object? processLabel = freezed,Object? domain = freezed,Object? liveEnd = null,Object? calendarToday = null,Object? rollingWindow = freezed,}) {
  return _then(_self.copyWith(
start: null == start ? _self.start : start // ignore: cast_nullable_to_non_nullable
as DateTime,end: null == end ? _self.end : end // ignore: cast_nullable_to_non_nullable
as DateTime,scope: null == scope ? _self.scope : scope // ignore: cast_nullable_to_non_nullable
as UsageTrafficScope,profileId: freezed == profileId ? _self.profileId : profileId // ignore: cast_nullable_to_non_nullable
as int?,profileLabel: freezed == profileLabel ? _self.profileLabel : profileLabel // ignore: cast_nullable_to_non_nullable
as String?,node: freezed == node ? _self.node : node // ignore: cast_nullable_to_non_nullable
as String?,processPath: freezed == processPath ? _self.processPath : processPath // ignore: cast_nullable_to_non_nullable
as String?,processLabel: freezed == processLabel ? _self.processLabel : processLabel // ignore: cast_nullable_to_non_nullable
as String?,domain: freezed == domain ? _self.domain : domain // ignore: cast_nullable_to_non_nullable
as String?,liveEnd: null == liveEnd ? _self.liveEnd : liveEnd // ignore: cast_nullable_to_non_nullable
as bool,calendarToday: null == calendarToday ? _self.calendarToday : calendarToday // ignore: cast_nullable_to_non_nullable
as bool,rollingWindow: freezed == rollingWindow ? _self.rollingWindow : rollingWindow // ignore: cast_nullable_to_non_nullable
as Duration?,
  ));
}

}


/// Adds pattern-matching-related methods to [UsageFilter].
extension UsageFilterPatterns on UsageFilter {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UsageFilter value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UsageFilter() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UsageFilter value)  $default,){
final _that = this;
switch (_that) {
case _UsageFilter():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UsageFilter value)?  $default,){
final _that = this;
switch (_that) {
case _UsageFilter() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( DateTime start,  DateTime end,  UsageTrafficScope scope,  int? profileId,  String? profileLabel,  String? node,  String? processPath,  String? processLabel,  String? domain,  bool liveEnd,  bool calendarToday,  Duration? rollingWindow)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UsageFilter() when $default != null:
return $default(_that.start,_that.end,_that.scope,_that.profileId,_that.profileLabel,_that.node,_that.processPath,_that.processLabel,_that.domain,_that.liveEnd,_that.calendarToday,_that.rollingWindow);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( DateTime start,  DateTime end,  UsageTrafficScope scope,  int? profileId,  String? profileLabel,  String? node,  String? processPath,  String? processLabel,  String? domain,  bool liveEnd,  bool calendarToday,  Duration? rollingWindow)  $default,) {final _that = this;
switch (_that) {
case _UsageFilter():
return $default(_that.start,_that.end,_that.scope,_that.profileId,_that.profileLabel,_that.node,_that.processPath,_that.processLabel,_that.domain,_that.liveEnd,_that.calendarToday,_that.rollingWindow);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( DateTime start,  DateTime end,  UsageTrafficScope scope,  int? profileId,  String? profileLabel,  String? node,  String? processPath,  String? processLabel,  String? domain,  bool liveEnd,  bool calendarToday,  Duration? rollingWindow)?  $default,) {final _that = this;
switch (_that) {
case _UsageFilter() when $default != null:
return $default(_that.start,_that.end,_that.scope,_that.profileId,_that.profileLabel,_that.node,_that.processPath,_that.processLabel,_that.domain,_that.liveEnd,_that.calendarToday,_that.rollingWindow);case _:
  return null;

}
}

}

/// @nodoc


class _UsageFilter implements UsageFilter {
  const _UsageFilter({required this.start, required this.end, this.scope = UsageTrafficScope.proxy, this.profileId, this.profileLabel, this.node, this.processPath, this.processLabel, this.domain, this.liveEnd = false, this.calendarToday = false, this.rollingWindow});
  

@override final  DateTime start;
@override final  DateTime end;
@override@JsonKey() final  UsageTrafficScope scope;
@override final  int? profileId;
@override final  String? profileLabel;
@override final  String? node;
@override final  String? processPath;
@override final  String? processLabel;
@override final  String? domain;
@override@JsonKey() final  bool liveEnd;
@override@JsonKey() final  bool calendarToday;
@override final  Duration? rollingWindow;

/// Create a copy of UsageFilter
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UsageFilterCopyWith<_UsageFilter> get copyWith => __$UsageFilterCopyWithImpl<_UsageFilter>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UsageFilter&&(identical(other.start, start) || other.start == start)&&(identical(other.end, end) || other.end == end)&&(identical(other.scope, scope) || other.scope == scope)&&(identical(other.profileId, profileId) || other.profileId == profileId)&&(identical(other.profileLabel, profileLabel) || other.profileLabel == profileLabel)&&(identical(other.node, node) || other.node == node)&&(identical(other.processPath, processPath) || other.processPath == processPath)&&(identical(other.processLabel, processLabel) || other.processLabel == processLabel)&&(identical(other.domain, domain) || other.domain == domain)&&(identical(other.liveEnd, liveEnd) || other.liveEnd == liveEnd)&&(identical(other.calendarToday, calendarToday) || other.calendarToday == calendarToday)&&(identical(other.rollingWindow, rollingWindow) || other.rollingWindow == rollingWindow));
}


@override
int get hashCode => Object.hash(runtimeType,start,end,scope,profileId,profileLabel,node,processPath,processLabel,domain,liveEnd,calendarToday,rollingWindow);

@override
String toString() {
  return 'UsageFilter(start: $start, end: $end, scope: $scope, profileId: $profileId, profileLabel: $profileLabel, node: $node, processPath: $processPath, processLabel: $processLabel, domain: $domain, liveEnd: $liveEnd, calendarToday: $calendarToday, rollingWindow: $rollingWindow)';
}


}

/// @nodoc
abstract mixin class _$UsageFilterCopyWith<$Res> implements $UsageFilterCopyWith<$Res> {
  factory _$UsageFilterCopyWith(_UsageFilter value, $Res Function(_UsageFilter) _then) = __$UsageFilterCopyWithImpl;
@override @useResult
$Res call({
 DateTime start, DateTime end, UsageTrafficScope scope, int? profileId, String? profileLabel, String? node, String? processPath, String? processLabel, String? domain, bool liveEnd, bool calendarToday, Duration? rollingWindow
});




}
/// @nodoc
class __$UsageFilterCopyWithImpl<$Res>
    implements _$UsageFilterCopyWith<$Res> {
  __$UsageFilterCopyWithImpl(this._self, this._then);

  final _UsageFilter _self;
  final $Res Function(_UsageFilter) _then;

/// Create a copy of UsageFilter
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? start = null,Object? end = null,Object? scope = null,Object? profileId = freezed,Object? profileLabel = freezed,Object? node = freezed,Object? processPath = freezed,Object? processLabel = freezed,Object? domain = freezed,Object? liveEnd = null,Object? calendarToday = null,Object? rollingWindow = freezed,}) {
  return _then(_UsageFilter(
start: null == start ? _self.start : start // ignore: cast_nullable_to_non_nullable
as DateTime,end: null == end ? _self.end : end // ignore: cast_nullable_to_non_nullable
as DateTime,scope: null == scope ? _self.scope : scope // ignore: cast_nullable_to_non_nullable
as UsageTrafficScope,profileId: freezed == profileId ? _self.profileId : profileId // ignore: cast_nullable_to_non_nullable
as int?,profileLabel: freezed == profileLabel ? _self.profileLabel : profileLabel // ignore: cast_nullable_to_non_nullable
as String?,node: freezed == node ? _self.node : node // ignore: cast_nullable_to_non_nullable
as String?,processPath: freezed == processPath ? _self.processPath : processPath // ignore: cast_nullable_to_non_nullable
as String?,processLabel: freezed == processLabel ? _self.processLabel : processLabel // ignore: cast_nullable_to_non_nullable
as String?,domain: freezed == domain ? _self.domain : domain // ignore: cast_nullable_to_non_nullable
as String?,liveEnd: null == liveEnd ? _self.liveEnd : liveEnd // ignore: cast_nullable_to_non_nullable
as bool,calendarToday: null == calendarToday ? _self.calendarToday : calendarToday // ignore: cast_nullable_to_non_nullable
as bool,rollingWindow: freezed == rollingWindow ? _self.rollingWindow : rollingWindow // ignore: cast_nullable_to_non_nullable
as Duration?,
  ));
}


}

/// @nodoc
mixin _$UsageSummary {

 int get upload; int get download; int get connections;
/// Create a copy of UsageSummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UsageSummaryCopyWith<UsageSummary> get copyWith => _$UsageSummaryCopyWithImpl<UsageSummary>(this as UsageSummary, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UsageSummary&&(identical(other.upload, upload) || other.upload == upload)&&(identical(other.download, download) || other.download == download)&&(identical(other.connections, connections) || other.connections == connections));
}


@override
int get hashCode => Object.hash(runtimeType,upload,download,connections);

@override
String toString() {
  return 'UsageSummary(upload: $upload, download: $download, connections: $connections)';
}


}

/// @nodoc
abstract mixin class $UsageSummaryCopyWith<$Res>  {
  factory $UsageSummaryCopyWith(UsageSummary value, $Res Function(UsageSummary) _then) = _$UsageSummaryCopyWithImpl;
@useResult
$Res call({
 int upload, int download, int connections
});




}
/// @nodoc
class _$UsageSummaryCopyWithImpl<$Res>
    implements $UsageSummaryCopyWith<$Res> {
  _$UsageSummaryCopyWithImpl(this._self, this._then);

  final UsageSummary _self;
  final $Res Function(UsageSummary) _then;

/// Create a copy of UsageSummary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? upload = null,Object? download = null,Object? connections = null,}) {
  return _then(_self.copyWith(
upload: null == upload ? _self.upload : upload // ignore: cast_nullable_to_non_nullable
as int,download: null == download ? _self.download : download // ignore: cast_nullable_to_non_nullable
as int,connections: null == connections ? _self.connections : connections // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [UsageSummary].
extension UsageSummaryPatterns on UsageSummary {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UsageSummary value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UsageSummary() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UsageSummary value)  $default,){
final _that = this;
switch (_that) {
case _UsageSummary():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UsageSummary value)?  $default,){
final _that = this;
switch (_that) {
case _UsageSummary() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int upload,  int download,  int connections)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UsageSummary() when $default != null:
return $default(_that.upload,_that.download,_that.connections);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int upload,  int download,  int connections)  $default,) {final _that = this;
switch (_that) {
case _UsageSummary():
return $default(_that.upload,_that.download,_that.connections);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int upload,  int download,  int connections)?  $default,) {final _that = this;
switch (_that) {
case _UsageSummary() when $default != null:
return $default(_that.upload,_that.download,_that.connections);case _:
  return null;

}
}

}

/// @nodoc


class _UsageSummary extends UsageSummary {
  const _UsageSummary({this.upload = 0, this.download = 0, this.connections = 0}): super._();
  

@override@JsonKey() final  int upload;
@override@JsonKey() final  int download;
@override@JsonKey() final  int connections;

/// Create a copy of UsageSummary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UsageSummaryCopyWith<_UsageSummary> get copyWith => __$UsageSummaryCopyWithImpl<_UsageSummary>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UsageSummary&&(identical(other.upload, upload) || other.upload == upload)&&(identical(other.download, download) || other.download == download)&&(identical(other.connections, connections) || other.connections == connections));
}


@override
int get hashCode => Object.hash(runtimeType,upload,download,connections);

@override
String toString() {
  return 'UsageSummary(upload: $upload, download: $download, connections: $connections)';
}


}

/// @nodoc
abstract mixin class _$UsageSummaryCopyWith<$Res> implements $UsageSummaryCopyWith<$Res> {
  factory _$UsageSummaryCopyWith(_UsageSummary value, $Res Function(_UsageSummary) _then) = __$UsageSummaryCopyWithImpl;
@override @useResult
$Res call({
 int upload, int download, int connections
});




}
/// @nodoc
class __$UsageSummaryCopyWithImpl<$Res>
    implements _$UsageSummaryCopyWith<$Res> {
  __$UsageSummaryCopyWithImpl(this._self, this._then);

  final _UsageSummary _self;
  final $Res Function(_UsageSummary) _then;

/// Create a copy of UsageSummary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? upload = null,Object? download = null,Object? connections = null,}) {
  return _then(_UsageSummary(
upload: null == upload ? _self.upload : upload // ignore: cast_nullable_to_non_nullable
as int,download: null == download ? _self.download : download // ignore: cast_nullable_to_non_nullable
as int,connections: null == connections ? _self.connections : connections // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$UsageTrendPoint {

 DateTime get time; int get upload; int get download; int get connections;
/// Create a copy of UsageTrendPoint
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UsageTrendPointCopyWith<UsageTrendPoint> get copyWith => _$UsageTrendPointCopyWithImpl<UsageTrendPoint>(this as UsageTrendPoint, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UsageTrendPoint&&(identical(other.time, time) || other.time == time)&&(identical(other.upload, upload) || other.upload == upload)&&(identical(other.download, download) || other.download == download)&&(identical(other.connections, connections) || other.connections == connections));
}


@override
int get hashCode => Object.hash(runtimeType,time,upload,download,connections);

@override
String toString() {
  return 'UsageTrendPoint(time: $time, upload: $upload, download: $download, connections: $connections)';
}


}

/// @nodoc
abstract mixin class $UsageTrendPointCopyWith<$Res>  {
  factory $UsageTrendPointCopyWith(UsageTrendPoint value, $Res Function(UsageTrendPoint) _then) = _$UsageTrendPointCopyWithImpl;
@useResult
$Res call({
 DateTime time, int upload, int download, int connections
});




}
/// @nodoc
class _$UsageTrendPointCopyWithImpl<$Res>
    implements $UsageTrendPointCopyWith<$Res> {
  _$UsageTrendPointCopyWithImpl(this._self, this._then);

  final UsageTrendPoint _self;
  final $Res Function(UsageTrendPoint) _then;

/// Create a copy of UsageTrendPoint
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? time = null,Object? upload = null,Object? download = null,Object? connections = null,}) {
  return _then(_self.copyWith(
time: null == time ? _self.time : time // ignore: cast_nullable_to_non_nullable
as DateTime,upload: null == upload ? _self.upload : upload // ignore: cast_nullable_to_non_nullable
as int,download: null == download ? _self.download : download // ignore: cast_nullable_to_non_nullable
as int,connections: null == connections ? _self.connections : connections // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [UsageTrendPoint].
extension UsageTrendPointPatterns on UsageTrendPoint {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UsageTrendPoint value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UsageTrendPoint() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UsageTrendPoint value)  $default,){
final _that = this;
switch (_that) {
case _UsageTrendPoint():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UsageTrendPoint value)?  $default,){
final _that = this;
switch (_that) {
case _UsageTrendPoint() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( DateTime time,  int upload,  int download,  int connections)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UsageTrendPoint() when $default != null:
return $default(_that.time,_that.upload,_that.download,_that.connections);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( DateTime time,  int upload,  int download,  int connections)  $default,) {final _that = this;
switch (_that) {
case _UsageTrendPoint():
return $default(_that.time,_that.upload,_that.download,_that.connections);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( DateTime time,  int upload,  int download,  int connections)?  $default,) {final _that = this;
switch (_that) {
case _UsageTrendPoint() when $default != null:
return $default(_that.time,_that.upload,_that.download,_that.connections);case _:
  return null;

}
}

}

/// @nodoc


class _UsageTrendPoint extends UsageTrendPoint {
  const _UsageTrendPoint({required this.time, this.upload = 0, this.download = 0, this.connections = 0}): super._();
  

@override final  DateTime time;
@override@JsonKey() final  int upload;
@override@JsonKey() final  int download;
@override@JsonKey() final  int connections;

/// Create a copy of UsageTrendPoint
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UsageTrendPointCopyWith<_UsageTrendPoint> get copyWith => __$UsageTrendPointCopyWithImpl<_UsageTrendPoint>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UsageTrendPoint&&(identical(other.time, time) || other.time == time)&&(identical(other.upload, upload) || other.upload == upload)&&(identical(other.download, download) || other.download == download)&&(identical(other.connections, connections) || other.connections == connections));
}


@override
int get hashCode => Object.hash(runtimeType,time,upload,download,connections);

@override
String toString() {
  return 'UsageTrendPoint(time: $time, upload: $upload, download: $download, connections: $connections)';
}


}

/// @nodoc
abstract mixin class _$UsageTrendPointCopyWith<$Res> implements $UsageTrendPointCopyWith<$Res> {
  factory _$UsageTrendPointCopyWith(_UsageTrendPoint value, $Res Function(_UsageTrendPoint) _then) = __$UsageTrendPointCopyWithImpl;
@override @useResult
$Res call({
 DateTime time, int upload, int download, int connections
});




}
/// @nodoc
class __$UsageTrendPointCopyWithImpl<$Res>
    implements _$UsageTrendPointCopyWith<$Res> {
  __$UsageTrendPointCopyWithImpl(this._self, this._then);

  final _UsageTrendPoint _self;
  final $Res Function(_UsageTrendPoint) _then;

/// Create a copy of UsageTrendPoint
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? time = null,Object? upload = null,Object? download = null,Object? connections = null,}) {
  return _then(_UsageTrendPoint(
time: null == time ? _self.time : time // ignore: cast_nullable_to_non_nullable
as DateTime,upload: null == upload ? _self.upload : upload // ignore: cast_nullable_to_non_nullable
as int,download: null == download ? _self.download : download // ignore: cast_nullable_to_non_nullable
as int,connections: null == connections ? _self.connections : connections // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$UsageRankingItem {

 String get key; String get label; int get upload; int get download; int get connections;
/// Create a copy of UsageRankingItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UsageRankingItemCopyWith<UsageRankingItem> get copyWith => _$UsageRankingItemCopyWithImpl<UsageRankingItem>(this as UsageRankingItem, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UsageRankingItem&&(identical(other.key, key) || other.key == key)&&(identical(other.label, label) || other.label == label)&&(identical(other.upload, upload) || other.upload == upload)&&(identical(other.download, download) || other.download == download)&&(identical(other.connections, connections) || other.connections == connections));
}


@override
int get hashCode => Object.hash(runtimeType,key,label,upload,download,connections);

@override
String toString() {
  return 'UsageRankingItem(key: $key, label: $label, upload: $upload, download: $download, connections: $connections)';
}


}

/// @nodoc
abstract mixin class $UsageRankingItemCopyWith<$Res>  {
  factory $UsageRankingItemCopyWith(UsageRankingItem value, $Res Function(UsageRankingItem) _then) = _$UsageRankingItemCopyWithImpl;
@useResult
$Res call({
 String key, String label, int upload, int download, int connections
});




}
/// @nodoc
class _$UsageRankingItemCopyWithImpl<$Res>
    implements $UsageRankingItemCopyWith<$Res> {
  _$UsageRankingItemCopyWithImpl(this._self, this._then);

  final UsageRankingItem _self;
  final $Res Function(UsageRankingItem) _then;

/// Create a copy of UsageRankingItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? key = null,Object? label = null,Object? upload = null,Object? download = null,Object? connections = null,}) {
  return _then(_self.copyWith(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,upload: null == upload ? _self.upload : upload // ignore: cast_nullable_to_non_nullable
as int,download: null == download ? _self.download : download // ignore: cast_nullable_to_non_nullable
as int,connections: null == connections ? _self.connections : connections // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [UsageRankingItem].
extension UsageRankingItemPatterns on UsageRankingItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UsageRankingItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UsageRankingItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UsageRankingItem value)  $default,){
final _that = this;
switch (_that) {
case _UsageRankingItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UsageRankingItem value)?  $default,){
final _that = this;
switch (_that) {
case _UsageRankingItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String key,  String label,  int upload,  int download,  int connections)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UsageRankingItem() when $default != null:
return $default(_that.key,_that.label,_that.upload,_that.download,_that.connections);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String key,  String label,  int upload,  int download,  int connections)  $default,) {final _that = this;
switch (_that) {
case _UsageRankingItem():
return $default(_that.key,_that.label,_that.upload,_that.download,_that.connections);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String key,  String label,  int upload,  int download,  int connections)?  $default,) {final _that = this;
switch (_that) {
case _UsageRankingItem() when $default != null:
return $default(_that.key,_that.label,_that.upload,_that.download,_that.connections);case _:
  return null;

}
}

}

/// @nodoc


class _UsageRankingItem extends UsageRankingItem {
  const _UsageRankingItem({required this.key, required this.label, this.upload = 0, this.download = 0, this.connections = 0}): super._();
  

@override final  String key;
@override final  String label;
@override@JsonKey() final  int upload;
@override@JsonKey() final  int download;
@override@JsonKey() final  int connections;

/// Create a copy of UsageRankingItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UsageRankingItemCopyWith<_UsageRankingItem> get copyWith => __$UsageRankingItemCopyWithImpl<_UsageRankingItem>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UsageRankingItem&&(identical(other.key, key) || other.key == key)&&(identical(other.label, label) || other.label == label)&&(identical(other.upload, upload) || other.upload == upload)&&(identical(other.download, download) || other.download == download)&&(identical(other.connections, connections) || other.connections == connections));
}


@override
int get hashCode => Object.hash(runtimeType,key,label,upload,download,connections);

@override
String toString() {
  return 'UsageRankingItem(key: $key, label: $label, upload: $upload, download: $download, connections: $connections)';
}


}

/// @nodoc
abstract mixin class _$UsageRankingItemCopyWith<$Res> implements $UsageRankingItemCopyWith<$Res> {
  factory _$UsageRankingItemCopyWith(_UsageRankingItem value, $Res Function(_UsageRankingItem) _then) = __$UsageRankingItemCopyWithImpl;
@override @useResult
$Res call({
 String key, String label, int upload, int download, int connections
});




}
/// @nodoc
class __$UsageRankingItemCopyWithImpl<$Res>
    implements _$UsageRankingItemCopyWith<$Res> {
  __$UsageRankingItemCopyWithImpl(this._self, this._then);

  final _UsageRankingItem _self;
  final $Res Function(_UsageRankingItem) _then;

/// Create a copy of UsageRankingItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? key = null,Object? label = null,Object? upload = null,Object? download = null,Object? connections = null,}) {
  return _then(_UsageRankingItem(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,upload: null == upload ? _self.upload : upload // ignore: cast_nullable_to_non_nullable
as int,download: null == download ? _self.download : download // ignore: cast_nullable_to_non_nullable
as int,connections: null == connections ? _self.connections : connections // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$UsageOverview {

 UsageSummary get summary; List<UsageTrendPoint> get trend; List<UsageTrendPoint> get hourlyDistribution; Map<UsageDimension, List<UsageRankingItem>> get rankings;
/// Create a copy of UsageOverview
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UsageOverviewCopyWith<UsageOverview> get copyWith => _$UsageOverviewCopyWithImpl<UsageOverview>(this as UsageOverview, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UsageOverview&&(identical(other.summary, summary) || other.summary == summary)&&const DeepCollectionEquality().equals(other.trend, trend)&&const DeepCollectionEquality().equals(other.hourlyDistribution, hourlyDistribution)&&const DeepCollectionEquality().equals(other.rankings, rankings));
}


@override
int get hashCode => Object.hash(runtimeType,summary,const DeepCollectionEquality().hash(trend),const DeepCollectionEquality().hash(hourlyDistribution),const DeepCollectionEquality().hash(rankings));

@override
String toString() {
  return 'UsageOverview(summary: $summary, trend: $trend, hourlyDistribution: $hourlyDistribution, rankings: $rankings)';
}


}

/// @nodoc
abstract mixin class $UsageOverviewCopyWith<$Res>  {
  factory $UsageOverviewCopyWith(UsageOverview value, $Res Function(UsageOverview) _then) = _$UsageOverviewCopyWithImpl;
@useResult
$Res call({
 UsageSummary summary, List<UsageTrendPoint> trend, List<UsageTrendPoint> hourlyDistribution, Map<UsageDimension, List<UsageRankingItem>> rankings
});


$UsageSummaryCopyWith<$Res> get summary;

}
/// @nodoc
class _$UsageOverviewCopyWithImpl<$Res>
    implements $UsageOverviewCopyWith<$Res> {
  _$UsageOverviewCopyWithImpl(this._self, this._then);

  final UsageOverview _self;
  final $Res Function(UsageOverview) _then;

/// Create a copy of UsageOverview
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? summary = null,Object? trend = null,Object? hourlyDistribution = null,Object? rankings = null,}) {
  return _then(_self.copyWith(
summary: null == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as UsageSummary,trend: null == trend ? _self.trend : trend // ignore: cast_nullable_to_non_nullable
as List<UsageTrendPoint>,hourlyDistribution: null == hourlyDistribution ? _self.hourlyDistribution : hourlyDistribution // ignore: cast_nullable_to_non_nullable
as List<UsageTrendPoint>,rankings: null == rankings ? _self.rankings : rankings // ignore: cast_nullable_to_non_nullable
as Map<UsageDimension, List<UsageRankingItem>>,
  ));
}
/// Create a copy of UsageOverview
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UsageSummaryCopyWith<$Res> get summary {
  
  return $UsageSummaryCopyWith<$Res>(_self.summary, (value) {
    return _then(_self.copyWith(summary: value));
  });
}
}


/// Adds pattern-matching-related methods to [UsageOverview].
extension UsageOverviewPatterns on UsageOverview {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UsageOverview value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UsageOverview() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UsageOverview value)  $default,){
final _that = this;
switch (_that) {
case _UsageOverview():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UsageOverview value)?  $default,){
final _that = this;
switch (_that) {
case _UsageOverview() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( UsageSummary summary,  List<UsageTrendPoint> trend,  List<UsageTrendPoint> hourlyDistribution,  Map<UsageDimension, List<UsageRankingItem>> rankings)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UsageOverview() when $default != null:
return $default(_that.summary,_that.trend,_that.hourlyDistribution,_that.rankings);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( UsageSummary summary,  List<UsageTrendPoint> trend,  List<UsageTrendPoint> hourlyDistribution,  Map<UsageDimension, List<UsageRankingItem>> rankings)  $default,) {final _that = this;
switch (_that) {
case _UsageOverview():
return $default(_that.summary,_that.trend,_that.hourlyDistribution,_that.rankings);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( UsageSummary summary,  List<UsageTrendPoint> trend,  List<UsageTrendPoint> hourlyDistribution,  Map<UsageDimension, List<UsageRankingItem>> rankings)?  $default,) {final _that = this;
switch (_that) {
case _UsageOverview() when $default != null:
return $default(_that.summary,_that.trend,_that.hourlyDistribution,_that.rankings);case _:
  return null;

}
}

}

/// @nodoc


class _UsageOverview implements UsageOverview {
  const _UsageOverview({required this.summary, final  List<UsageTrendPoint> trend = const [], final  List<UsageTrendPoint> hourlyDistribution = const [], final  Map<UsageDimension, List<UsageRankingItem>> rankings = const {}}): _trend = trend,_hourlyDistribution = hourlyDistribution,_rankings = rankings;
  

@override final  UsageSummary summary;
 final  List<UsageTrendPoint> _trend;
@override@JsonKey() List<UsageTrendPoint> get trend {
  if (_trend is EqualUnmodifiableListView) return _trend;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_trend);
}

 final  List<UsageTrendPoint> _hourlyDistribution;
@override@JsonKey() List<UsageTrendPoint> get hourlyDistribution {
  if (_hourlyDistribution is EqualUnmodifiableListView) return _hourlyDistribution;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_hourlyDistribution);
}

 final  Map<UsageDimension, List<UsageRankingItem>> _rankings;
@override@JsonKey() Map<UsageDimension, List<UsageRankingItem>> get rankings {
  if (_rankings is EqualUnmodifiableMapView) return _rankings;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_rankings);
}


/// Create a copy of UsageOverview
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UsageOverviewCopyWith<_UsageOverview> get copyWith => __$UsageOverviewCopyWithImpl<_UsageOverview>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UsageOverview&&(identical(other.summary, summary) || other.summary == summary)&&const DeepCollectionEquality().equals(other._trend, _trend)&&const DeepCollectionEquality().equals(other._hourlyDistribution, _hourlyDistribution)&&const DeepCollectionEquality().equals(other._rankings, _rankings));
}


@override
int get hashCode => Object.hash(runtimeType,summary,const DeepCollectionEquality().hash(_trend),const DeepCollectionEquality().hash(_hourlyDistribution),const DeepCollectionEquality().hash(_rankings));

@override
String toString() {
  return 'UsageOverview(summary: $summary, trend: $trend, hourlyDistribution: $hourlyDistribution, rankings: $rankings)';
}


}

/// @nodoc
abstract mixin class _$UsageOverviewCopyWith<$Res> implements $UsageOverviewCopyWith<$Res> {
  factory _$UsageOverviewCopyWith(_UsageOverview value, $Res Function(_UsageOverview) _then) = __$UsageOverviewCopyWithImpl;
@override @useResult
$Res call({
 UsageSummary summary, List<UsageTrendPoint> trend, List<UsageTrendPoint> hourlyDistribution, Map<UsageDimension, List<UsageRankingItem>> rankings
});


@override $UsageSummaryCopyWith<$Res> get summary;

}
/// @nodoc
class __$UsageOverviewCopyWithImpl<$Res>
    implements _$UsageOverviewCopyWith<$Res> {
  __$UsageOverviewCopyWithImpl(this._self, this._then);

  final _UsageOverview _self;
  final $Res Function(_UsageOverview) _then;

/// Create a copy of UsageOverview
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? summary = null,Object? trend = null,Object? hourlyDistribution = null,Object? rankings = null,}) {
  return _then(_UsageOverview(
summary: null == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as UsageSummary,trend: null == trend ? _self._trend : trend // ignore: cast_nullable_to_non_nullable
as List<UsageTrendPoint>,hourlyDistribution: null == hourlyDistribution ? _self._hourlyDistribution : hourlyDistribution // ignore: cast_nullable_to_non_nullable
as List<UsageTrendPoint>,rankings: null == rankings ? _self._rankings : rankings // ignore: cast_nullable_to_non_nullable
as Map<UsageDimension, List<UsageRankingItem>>,
  ));
}

/// Create a copy of UsageOverview
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UsageSummaryCopyWith<$Res> get summary {
  
  return $UsageSummaryCopyWith<$Res>(_self.summary, (value) {
    return _then(_self.copyWith(summary: value));
  });
}
}

// dart format on
