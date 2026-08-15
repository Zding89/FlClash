// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../usage.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_UsageCollectionParams _$UsageCollectionParamsFromJson(
  Map<String, dynamic> json,
) => _UsageCollectionParams(
  enabled: json['enabled'] as bool,
  profileId: (json['profileId'] as num?)?.toInt(),
  profileLabel: json['profileLabel'] as String,
  revision: (json['revision'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$UsageCollectionParamsToJson(
  _UsageCollectionParams instance,
) => <String, dynamic>{
  'enabled': instance.enabled,
  'profileId': instance.profileId,
  'profileLabel': instance.profileLabel,
  'revision': instance.revision,
};

_UsageBatchAck _$UsageBatchAckFromJson(Map<String, dynamic> json) =>
    _UsageBatchAck(
      sessionId: json['sessionId'] as String,
      sequence: (json['sequence'] as num).toInt(),
    );

Map<String, dynamic> _$UsageBatchAckToJson(_UsageBatchAck instance) =>
    <String, dynamic>{
      'sessionId': instance.sessionId,
      'sequence': instance.sequence,
    };

_UsageBucketData _$UsageBucketDataFromJson(Map<String, dynamic> json) =>
    _UsageBucketData(
      minute: (json['minute'] as num).toInt(),
      profileId: (json['profileId'] as num?)?.toInt(),
      profileLabel: json['profileLabel'] as String? ?? '',
      route:
          $enumDecodeNullable(_$UsageRouteEnumMap, json['route']) ??
          UsageRoute.unknown,
      node: json['node'] as String? ?? '',
      process: json['process'] as String? ?? '',
      processPath: json['processPath'] as String? ?? '',
      domain: json['domain'] as String? ?? '',
      host: json['host'] as String? ?? '',
      destinationIP: json['destinationIP'] as String? ?? '',
      upload: (json['upload'] as num?)?.toInt() ?? 0,
      download: (json['download'] as num?)?.toInt() ?? 0,
      connections: (json['connections'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$UsageBucketDataToJson(_UsageBucketData instance) =>
    <String, dynamic>{
      'minute': instance.minute,
      'profileId': instance.profileId,
      'profileLabel': instance.profileLabel,
      'route': _$UsageRouteEnumMap[instance.route]!,
      'node': instance.node,
      'process': instance.process,
      'processPath': instance.processPath,
      'domain': instance.domain,
      'host': instance.host,
      'destinationIP': instance.destinationIP,
      'upload': instance.upload,
      'download': instance.download,
      'connections': instance.connections,
    };

const _$UsageRouteEnumMap = {
  UsageRoute.proxy: 'proxy',
  UsageRoute.direct: 'direct',
  UsageRoute.unknown: 'unknown',
};

_UsageBatch _$UsageBatchFromJson(Map<String, dynamic> json) => _UsageBatch(
  sessionId: json['sessionId'] as String,
  sequence: (json['sequence'] as num).toInt(),
  buckets:
      (json['buckets'] as List<dynamic>?)
          ?.map((e) => UsageBucketData.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  degraded: json['degraded'] as bool? ?? false,
  degradedStartMinute: (json['degradedStartMinute'] as num?)?.toInt() ?? 0,
  degradedEndMinute: (json['degradedEndMinute'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$UsageBatchToJson(_UsageBatch instance) =>
    <String, dynamic>{
      'sessionId': instance.sessionId,
      'sequence': instance.sequence,
      'buckets': instance.buckets,
      'degraded': instance.degraded,
      'degradedStartMinute': instance.degradedStartMinute,
      'degradedEndMinute': instance.degradedEndMinute,
    };
