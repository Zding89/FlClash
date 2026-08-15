// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../usage_database.dart';

// ignore_for_file: type=lint
class $UsageBucketsTable extends UsageBuckets
    with TableInfo<$UsageBucketsTable, UsageBucket> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UsageBucketsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _minuteMeta = const VerificationMeta('minute');
  @override
  late final GeneratedColumn<int> minute = GeneratedColumn<int>(
    'minute',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localDayMeta = const VerificationMeta(
    'localDay',
  );
  @override
  late final GeneratedColumn<String> localDay = GeneratedColumn<String>(
    'local_day',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _localHourMeta = const VerificationMeta(
    'localHour',
  );
  @override
  late final GeneratedColumn<int> localHour = GeneratedColumn<int>(
    'local_hour',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _localDayStartMeta = const VerificationMeta(
    'localDayStart',
  );
  @override
  late final GeneratedColumn<int> localDayStart = GeneratedColumn<int>(
    'local_day_start',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _bucketKeyMeta = const VerificationMeta(
    'bucketKey',
  );
  @override
  late final GeneratedColumn<String> bucketKey = GeneratedColumn<String>(
    'bucket_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<int> profileId = GeneratedColumn<int>(
    'profile_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _profileLabelMeta = const VerificationMeta(
    'profileLabel',
  );
  @override
  late final GeneratedColumn<String> profileLabel = GeneratedColumn<String>(
    'profile_label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _routeMeta = const VerificationMeta('route');
  @override
  late final GeneratedColumn<String> route = GeneratedColumn<String>(
    'route',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nodeMeta = const VerificationMeta('node');
  @override
  late final GeneratedColumn<String> node = GeneratedColumn<String>(
    'node',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _processMeta = const VerificationMeta(
    'process',
  );
  @override
  late final GeneratedColumn<String> process = GeneratedColumn<String>(
    'process',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _processPathMeta = const VerificationMeta(
    'processPath',
  );
  @override
  late final GeneratedColumn<String> processPath = GeneratedColumn<String>(
    'process_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _domainMeta = const VerificationMeta('domain');
  @override
  late final GeneratedColumn<String> domain = GeneratedColumn<String>(
    'domain',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _hostMeta = const VerificationMeta('host');
  @override
  late final GeneratedColumn<String> host = GeneratedColumn<String>(
    'host',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _destinationIpMeta = const VerificationMeta(
    'destinationIp',
  );
  @override
  late final GeneratedColumn<String> destinationIp = GeneratedColumn<String>(
    'destination_ip',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _domainKeyMeta = const VerificationMeta(
    'domainKey',
  );
  @override
  late final GeneratedColumn<String> domainKey = GeneratedColumn<String>(
    'domain_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _uploadMeta = const VerificationMeta('upload');
  @override
  late final GeneratedColumn<int> upload = GeneratedColumn<int>(
    'upload',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _downloadMeta = const VerificationMeta(
    'download',
  );
  @override
  late final GeneratedColumn<int> download = GeneratedColumn<int>(
    'download',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _connectionsMeta = const VerificationMeta(
    'connections',
  );
  @override
  late final GeneratedColumn<int> connections = GeneratedColumn<int>(
    'connections',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    minute,
    localDay,
    localHour,
    localDayStart,
    bucketKey,
    profileId,
    profileLabel,
    route,
    node,
    process,
    processPath,
    domain,
    host,
    destinationIp,
    domainKey,
    upload,
    download,
    connections,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'usage_buckets';
  @override
  VerificationContext validateIntegrity(
    Insertable<UsageBucket> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('minute')) {
      context.handle(
        _minuteMeta,
        minute.isAcceptableOrUnknown(data['minute']!, _minuteMeta),
      );
    } else if (isInserting) {
      context.missing(_minuteMeta);
    }
    if (data.containsKey('local_day')) {
      context.handle(
        _localDayMeta,
        localDay.isAcceptableOrUnknown(data['local_day']!, _localDayMeta),
      );
    }
    if (data.containsKey('local_hour')) {
      context.handle(
        _localHourMeta,
        localHour.isAcceptableOrUnknown(data['local_hour']!, _localHourMeta),
      );
    }
    if (data.containsKey('local_day_start')) {
      context.handle(
        _localDayStartMeta,
        localDayStart.isAcceptableOrUnknown(
          data['local_day_start']!,
          _localDayStartMeta,
        ),
      );
    }
    if (data.containsKey('bucket_key')) {
      context.handle(
        _bucketKeyMeta,
        bucketKey.isAcceptableOrUnknown(data['bucket_key']!, _bucketKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_bucketKeyMeta);
    }
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    }
    if (data.containsKey('profile_label')) {
      context.handle(
        _profileLabelMeta,
        profileLabel.isAcceptableOrUnknown(
          data['profile_label']!,
          _profileLabelMeta,
        ),
      );
    }
    if (data.containsKey('route')) {
      context.handle(
        _routeMeta,
        route.isAcceptableOrUnknown(data['route']!, _routeMeta),
      );
    } else if (isInserting) {
      context.missing(_routeMeta);
    }
    if (data.containsKey('node')) {
      context.handle(
        _nodeMeta,
        node.isAcceptableOrUnknown(data['node']!, _nodeMeta),
      );
    }
    if (data.containsKey('process')) {
      context.handle(
        _processMeta,
        process.isAcceptableOrUnknown(data['process']!, _processMeta),
      );
    }
    if (data.containsKey('process_path')) {
      context.handle(
        _processPathMeta,
        processPath.isAcceptableOrUnknown(
          data['process_path']!,
          _processPathMeta,
        ),
      );
    }
    if (data.containsKey('domain')) {
      context.handle(
        _domainMeta,
        domain.isAcceptableOrUnknown(data['domain']!, _domainMeta),
      );
    }
    if (data.containsKey('host')) {
      context.handle(
        _hostMeta,
        host.isAcceptableOrUnknown(data['host']!, _hostMeta),
      );
    }
    if (data.containsKey('destination_ip')) {
      context.handle(
        _destinationIpMeta,
        destinationIp.isAcceptableOrUnknown(
          data['destination_ip']!,
          _destinationIpMeta,
        ),
      );
    }
    if (data.containsKey('domain_key')) {
      context.handle(
        _domainKeyMeta,
        domainKey.isAcceptableOrUnknown(data['domain_key']!, _domainKeyMeta),
      );
    }
    if (data.containsKey('upload')) {
      context.handle(
        _uploadMeta,
        upload.isAcceptableOrUnknown(data['upload']!, _uploadMeta),
      );
    }
    if (data.containsKey('download')) {
      context.handle(
        _downloadMeta,
        download.isAcceptableOrUnknown(data['download']!, _downloadMeta),
      );
    }
    if (data.containsKey('connections')) {
      context.handle(
        _connectionsMeta,
        connections.isAcceptableOrUnknown(
          data['connections']!,
          _connectionsMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {minute, bucketKey};
  @override
  UsageBucket map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UsageBucket(
      minute: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}minute'],
      )!,
      localDay: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_day'],
      )!,
      localHour: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}local_hour'],
      )!,
      localDayStart: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}local_day_start'],
      )!,
      bucketKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bucket_key'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}profile_id'],
      ),
      profileLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_label'],
      )!,
      route: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}route'],
      )!,
      node: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}node'],
      )!,
      process: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}process'],
      )!,
      processPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}process_path'],
      )!,
      domain: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}domain'],
      )!,
      host: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}host'],
      )!,
      destinationIp: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}destination_ip'],
      )!,
      domainKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}domain_key'],
      )!,
      upload: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}upload'],
      )!,
      download: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}download'],
      )!,
      connections: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}connections'],
      )!,
    );
  }

  @override
  $UsageBucketsTable createAlias(String alias) {
    return $UsageBucketsTable(attachedDatabase, alias);
  }
}

class UsageBucket extends DataClass implements Insertable<UsageBucket> {
  final int minute;
  final String localDay;
  final int localHour;
  final int localDayStart;
  final String bucketKey;
  final int? profileId;
  final String profileLabel;
  final String route;
  final String node;
  final String process;
  final String processPath;
  final String domain;
  final String host;
  final String destinationIp;
  final String domainKey;
  final int upload;
  final int download;
  final int connections;
  const UsageBucket({
    required this.minute,
    required this.localDay,
    required this.localHour,
    required this.localDayStart,
    required this.bucketKey,
    this.profileId,
    required this.profileLabel,
    required this.route,
    required this.node,
    required this.process,
    required this.processPath,
    required this.domain,
    required this.host,
    required this.destinationIp,
    required this.domainKey,
    required this.upload,
    required this.download,
    required this.connections,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['minute'] = Variable<int>(minute);
    map['local_day'] = Variable<String>(localDay);
    map['local_hour'] = Variable<int>(localHour);
    map['local_day_start'] = Variable<int>(localDayStart);
    map['bucket_key'] = Variable<String>(bucketKey);
    if (!nullToAbsent || profileId != null) {
      map['profile_id'] = Variable<int>(profileId);
    }
    map['profile_label'] = Variable<String>(profileLabel);
    map['route'] = Variable<String>(route);
    map['node'] = Variable<String>(node);
    map['process'] = Variable<String>(process);
    map['process_path'] = Variable<String>(processPath);
    map['domain'] = Variable<String>(domain);
    map['host'] = Variable<String>(host);
    map['destination_ip'] = Variable<String>(destinationIp);
    map['domain_key'] = Variable<String>(domainKey);
    map['upload'] = Variable<int>(upload);
    map['download'] = Variable<int>(download);
    map['connections'] = Variable<int>(connections);
    return map;
  }

  UsageBucketsCompanion toCompanion(bool nullToAbsent) {
    return UsageBucketsCompanion(
      minute: Value(minute),
      localDay: Value(localDay),
      localHour: Value(localHour),
      localDayStart: Value(localDayStart),
      bucketKey: Value(bucketKey),
      profileId: profileId == null && nullToAbsent
          ? const Value.absent()
          : Value(profileId),
      profileLabel: Value(profileLabel),
      route: Value(route),
      node: Value(node),
      process: Value(process),
      processPath: Value(processPath),
      domain: Value(domain),
      host: Value(host),
      destinationIp: Value(destinationIp),
      domainKey: Value(domainKey),
      upload: Value(upload),
      download: Value(download),
      connections: Value(connections),
    );
  }

  factory UsageBucket.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UsageBucket(
      minute: serializer.fromJson<int>(json['minute']),
      localDay: serializer.fromJson<String>(json['localDay']),
      localHour: serializer.fromJson<int>(json['localHour']),
      localDayStart: serializer.fromJson<int>(json['localDayStart']),
      bucketKey: serializer.fromJson<String>(json['bucketKey']),
      profileId: serializer.fromJson<int?>(json['profileId']),
      profileLabel: serializer.fromJson<String>(json['profileLabel']),
      route: serializer.fromJson<String>(json['route']),
      node: serializer.fromJson<String>(json['node']),
      process: serializer.fromJson<String>(json['process']),
      processPath: serializer.fromJson<String>(json['processPath']),
      domain: serializer.fromJson<String>(json['domain']),
      host: serializer.fromJson<String>(json['host']),
      destinationIp: serializer.fromJson<String>(json['destinationIp']),
      domainKey: serializer.fromJson<String>(json['domainKey']),
      upload: serializer.fromJson<int>(json['upload']),
      download: serializer.fromJson<int>(json['download']),
      connections: serializer.fromJson<int>(json['connections']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'minute': serializer.toJson<int>(minute),
      'localDay': serializer.toJson<String>(localDay),
      'localHour': serializer.toJson<int>(localHour),
      'localDayStart': serializer.toJson<int>(localDayStart),
      'bucketKey': serializer.toJson<String>(bucketKey),
      'profileId': serializer.toJson<int?>(profileId),
      'profileLabel': serializer.toJson<String>(profileLabel),
      'route': serializer.toJson<String>(route),
      'node': serializer.toJson<String>(node),
      'process': serializer.toJson<String>(process),
      'processPath': serializer.toJson<String>(processPath),
      'domain': serializer.toJson<String>(domain),
      'host': serializer.toJson<String>(host),
      'destinationIp': serializer.toJson<String>(destinationIp),
      'domainKey': serializer.toJson<String>(domainKey),
      'upload': serializer.toJson<int>(upload),
      'download': serializer.toJson<int>(download),
      'connections': serializer.toJson<int>(connections),
    };
  }

  UsageBucket copyWith({
    int? minute,
    String? localDay,
    int? localHour,
    int? localDayStart,
    String? bucketKey,
    Value<int?> profileId = const Value.absent(),
    String? profileLabel,
    String? route,
    String? node,
    String? process,
    String? processPath,
    String? domain,
    String? host,
    String? destinationIp,
    String? domainKey,
    int? upload,
    int? download,
    int? connections,
  }) => UsageBucket(
    minute: minute ?? this.minute,
    localDay: localDay ?? this.localDay,
    localHour: localHour ?? this.localHour,
    localDayStart: localDayStart ?? this.localDayStart,
    bucketKey: bucketKey ?? this.bucketKey,
    profileId: profileId.present ? profileId.value : this.profileId,
    profileLabel: profileLabel ?? this.profileLabel,
    route: route ?? this.route,
    node: node ?? this.node,
    process: process ?? this.process,
    processPath: processPath ?? this.processPath,
    domain: domain ?? this.domain,
    host: host ?? this.host,
    destinationIp: destinationIp ?? this.destinationIp,
    domainKey: domainKey ?? this.domainKey,
    upload: upload ?? this.upload,
    download: download ?? this.download,
    connections: connections ?? this.connections,
  );
  UsageBucket copyWithCompanion(UsageBucketsCompanion data) {
    return UsageBucket(
      minute: data.minute.present ? data.minute.value : this.minute,
      localDay: data.localDay.present ? data.localDay.value : this.localDay,
      localHour: data.localHour.present ? data.localHour.value : this.localHour,
      localDayStart: data.localDayStart.present
          ? data.localDayStart.value
          : this.localDayStart,
      bucketKey: data.bucketKey.present ? data.bucketKey.value : this.bucketKey,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      profileLabel: data.profileLabel.present
          ? data.profileLabel.value
          : this.profileLabel,
      route: data.route.present ? data.route.value : this.route,
      node: data.node.present ? data.node.value : this.node,
      process: data.process.present ? data.process.value : this.process,
      processPath: data.processPath.present
          ? data.processPath.value
          : this.processPath,
      domain: data.domain.present ? data.domain.value : this.domain,
      host: data.host.present ? data.host.value : this.host,
      destinationIp: data.destinationIp.present
          ? data.destinationIp.value
          : this.destinationIp,
      domainKey: data.domainKey.present ? data.domainKey.value : this.domainKey,
      upload: data.upload.present ? data.upload.value : this.upload,
      download: data.download.present ? data.download.value : this.download,
      connections: data.connections.present
          ? data.connections.value
          : this.connections,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UsageBucket(')
          ..write('minute: $minute, ')
          ..write('localDay: $localDay, ')
          ..write('localHour: $localHour, ')
          ..write('localDayStart: $localDayStart, ')
          ..write('bucketKey: $bucketKey, ')
          ..write('profileId: $profileId, ')
          ..write('profileLabel: $profileLabel, ')
          ..write('route: $route, ')
          ..write('node: $node, ')
          ..write('process: $process, ')
          ..write('processPath: $processPath, ')
          ..write('domain: $domain, ')
          ..write('host: $host, ')
          ..write('destinationIp: $destinationIp, ')
          ..write('domainKey: $domainKey, ')
          ..write('upload: $upload, ')
          ..write('download: $download, ')
          ..write('connections: $connections')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    minute,
    localDay,
    localHour,
    localDayStart,
    bucketKey,
    profileId,
    profileLabel,
    route,
    node,
    process,
    processPath,
    domain,
    host,
    destinationIp,
    domainKey,
    upload,
    download,
    connections,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UsageBucket &&
          other.minute == this.minute &&
          other.localDay == this.localDay &&
          other.localHour == this.localHour &&
          other.localDayStart == this.localDayStart &&
          other.bucketKey == this.bucketKey &&
          other.profileId == this.profileId &&
          other.profileLabel == this.profileLabel &&
          other.route == this.route &&
          other.node == this.node &&
          other.process == this.process &&
          other.processPath == this.processPath &&
          other.domain == this.domain &&
          other.host == this.host &&
          other.destinationIp == this.destinationIp &&
          other.domainKey == this.domainKey &&
          other.upload == this.upload &&
          other.download == this.download &&
          other.connections == this.connections);
}

class UsageBucketsCompanion extends UpdateCompanion<UsageBucket> {
  final Value<int> minute;
  final Value<String> localDay;
  final Value<int> localHour;
  final Value<int> localDayStart;
  final Value<String> bucketKey;
  final Value<int?> profileId;
  final Value<String> profileLabel;
  final Value<String> route;
  final Value<String> node;
  final Value<String> process;
  final Value<String> processPath;
  final Value<String> domain;
  final Value<String> host;
  final Value<String> destinationIp;
  final Value<String> domainKey;
  final Value<int> upload;
  final Value<int> download;
  final Value<int> connections;
  final Value<int> rowid;
  const UsageBucketsCompanion({
    this.minute = const Value.absent(),
    this.localDay = const Value.absent(),
    this.localHour = const Value.absent(),
    this.localDayStart = const Value.absent(),
    this.bucketKey = const Value.absent(),
    this.profileId = const Value.absent(),
    this.profileLabel = const Value.absent(),
    this.route = const Value.absent(),
    this.node = const Value.absent(),
    this.process = const Value.absent(),
    this.processPath = const Value.absent(),
    this.domain = const Value.absent(),
    this.host = const Value.absent(),
    this.destinationIp = const Value.absent(),
    this.domainKey = const Value.absent(),
    this.upload = const Value.absent(),
    this.download = const Value.absent(),
    this.connections = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UsageBucketsCompanion.insert({
    required int minute,
    this.localDay = const Value.absent(),
    this.localHour = const Value.absent(),
    this.localDayStart = const Value.absent(),
    required String bucketKey,
    this.profileId = const Value.absent(),
    this.profileLabel = const Value.absent(),
    required String route,
    this.node = const Value.absent(),
    this.process = const Value.absent(),
    this.processPath = const Value.absent(),
    this.domain = const Value.absent(),
    this.host = const Value.absent(),
    this.destinationIp = const Value.absent(),
    this.domainKey = const Value.absent(),
    this.upload = const Value.absent(),
    this.download = const Value.absent(),
    this.connections = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : minute = Value(minute),
       bucketKey = Value(bucketKey),
       route = Value(route);
  static Insertable<UsageBucket> custom({
    Expression<int>? minute,
    Expression<String>? localDay,
    Expression<int>? localHour,
    Expression<int>? localDayStart,
    Expression<String>? bucketKey,
    Expression<int>? profileId,
    Expression<String>? profileLabel,
    Expression<String>? route,
    Expression<String>? node,
    Expression<String>? process,
    Expression<String>? processPath,
    Expression<String>? domain,
    Expression<String>? host,
    Expression<String>? destinationIp,
    Expression<String>? domainKey,
    Expression<int>? upload,
    Expression<int>? download,
    Expression<int>? connections,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (minute != null) 'minute': minute,
      if (localDay != null) 'local_day': localDay,
      if (localHour != null) 'local_hour': localHour,
      if (localDayStart != null) 'local_day_start': localDayStart,
      if (bucketKey != null) 'bucket_key': bucketKey,
      if (profileId != null) 'profile_id': profileId,
      if (profileLabel != null) 'profile_label': profileLabel,
      if (route != null) 'route': route,
      if (node != null) 'node': node,
      if (process != null) 'process': process,
      if (processPath != null) 'process_path': processPath,
      if (domain != null) 'domain': domain,
      if (host != null) 'host': host,
      if (destinationIp != null) 'destination_ip': destinationIp,
      if (domainKey != null) 'domain_key': domainKey,
      if (upload != null) 'upload': upload,
      if (download != null) 'download': download,
      if (connections != null) 'connections': connections,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UsageBucketsCompanion copyWith({
    Value<int>? minute,
    Value<String>? localDay,
    Value<int>? localHour,
    Value<int>? localDayStart,
    Value<String>? bucketKey,
    Value<int?>? profileId,
    Value<String>? profileLabel,
    Value<String>? route,
    Value<String>? node,
    Value<String>? process,
    Value<String>? processPath,
    Value<String>? domain,
    Value<String>? host,
    Value<String>? destinationIp,
    Value<String>? domainKey,
    Value<int>? upload,
    Value<int>? download,
    Value<int>? connections,
    Value<int>? rowid,
  }) {
    return UsageBucketsCompanion(
      minute: minute ?? this.minute,
      localDay: localDay ?? this.localDay,
      localHour: localHour ?? this.localHour,
      localDayStart: localDayStart ?? this.localDayStart,
      bucketKey: bucketKey ?? this.bucketKey,
      profileId: profileId ?? this.profileId,
      profileLabel: profileLabel ?? this.profileLabel,
      route: route ?? this.route,
      node: node ?? this.node,
      process: process ?? this.process,
      processPath: processPath ?? this.processPath,
      domain: domain ?? this.domain,
      host: host ?? this.host,
      destinationIp: destinationIp ?? this.destinationIp,
      domainKey: domainKey ?? this.domainKey,
      upload: upload ?? this.upload,
      download: download ?? this.download,
      connections: connections ?? this.connections,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (minute.present) {
      map['minute'] = Variable<int>(minute.value);
    }
    if (localDay.present) {
      map['local_day'] = Variable<String>(localDay.value);
    }
    if (localHour.present) {
      map['local_hour'] = Variable<int>(localHour.value);
    }
    if (localDayStart.present) {
      map['local_day_start'] = Variable<int>(localDayStart.value);
    }
    if (bucketKey.present) {
      map['bucket_key'] = Variable<String>(bucketKey.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<int>(profileId.value);
    }
    if (profileLabel.present) {
      map['profile_label'] = Variable<String>(profileLabel.value);
    }
    if (route.present) {
      map['route'] = Variable<String>(route.value);
    }
    if (node.present) {
      map['node'] = Variable<String>(node.value);
    }
    if (process.present) {
      map['process'] = Variable<String>(process.value);
    }
    if (processPath.present) {
      map['process_path'] = Variable<String>(processPath.value);
    }
    if (domain.present) {
      map['domain'] = Variable<String>(domain.value);
    }
    if (host.present) {
      map['host'] = Variable<String>(host.value);
    }
    if (destinationIp.present) {
      map['destination_ip'] = Variable<String>(destinationIp.value);
    }
    if (domainKey.present) {
      map['domain_key'] = Variable<String>(domainKey.value);
    }
    if (upload.present) {
      map['upload'] = Variable<int>(upload.value);
    }
    if (download.present) {
      map['download'] = Variable<int>(download.value);
    }
    if (connections.present) {
      map['connections'] = Variable<int>(connections.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UsageBucketsCompanion(')
          ..write('minute: $minute, ')
          ..write('localDay: $localDay, ')
          ..write('localHour: $localHour, ')
          ..write('localDayStart: $localDayStart, ')
          ..write('bucketKey: $bucketKey, ')
          ..write('profileId: $profileId, ')
          ..write('profileLabel: $profileLabel, ')
          ..write('route: $route, ')
          ..write('node: $node, ')
          ..write('process: $process, ')
          ..write('processPath: $processPath, ')
          ..write('domain: $domain, ')
          ..write('host: $host, ')
          ..write('destinationIp: $destinationIp, ')
          ..write('domainKey: $domainKey, ')
          ..write('upload: $upload, ')
          ..write('download: $download, ')
          ..write('connections: $connections, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UsageIngestSessionsTable extends UsageIngestSessions
    with TableInfo<$UsageIngestSessionsTable, UsageIngestSession> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UsageIngestSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _maxSequenceMeta = const VerificationMeta(
    'maxSequence',
  );
  @override
  late final GeneratedColumn<int> maxSequence = GeneratedColumn<int>(
    'max_sequence',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [sessionId, maxSequence, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'usage_ingest_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<UsageIngestSession> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('max_sequence')) {
      context.handle(
        _maxSequenceMeta,
        maxSequence.isAcceptableOrUnknown(
          data['max_sequence']!,
          _maxSequenceMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_maxSequenceMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sessionId};
  @override
  UsageIngestSession map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UsageIngestSession(
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      maxSequence: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}max_sequence'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $UsageIngestSessionsTable createAlias(String alias) {
    return $UsageIngestSessionsTable(attachedDatabase, alias);
  }
}

class UsageIngestSession extends DataClass
    implements Insertable<UsageIngestSession> {
  final String sessionId;
  final int maxSequence;
  final DateTime updatedAt;
  const UsageIngestSession({
    required this.sessionId,
    required this.maxSequence,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['session_id'] = Variable<String>(sessionId);
    map['max_sequence'] = Variable<int>(maxSequence);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  UsageIngestSessionsCompanion toCompanion(bool nullToAbsent) {
    return UsageIngestSessionsCompanion(
      sessionId: Value(sessionId),
      maxSequence: Value(maxSequence),
      updatedAt: Value(updatedAt),
    );
  }

  factory UsageIngestSession.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UsageIngestSession(
      sessionId: serializer.fromJson<String>(json['sessionId']),
      maxSequence: serializer.fromJson<int>(json['maxSequence']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sessionId': serializer.toJson<String>(sessionId),
      'maxSequence': serializer.toJson<int>(maxSequence),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  UsageIngestSession copyWith({
    String? sessionId,
    int? maxSequence,
    DateTime? updatedAt,
  }) => UsageIngestSession(
    sessionId: sessionId ?? this.sessionId,
    maxSequence: maxSequence ?? this.maxSequence,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  UsageIngestSession copyWithCompanion(UsageIngestSessionsCompanion data) {
    return UsageIngestSession(
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      maxSequence: data.maxSequence.present
          ? data.maxSequence.value
          : this.maxSequence,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UsageIngestSession(')
          ..write('sessionId: $sessionId, ')
          ..write('maxSequence: $maxSequence, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(sessionId, maxSequence, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UsageIngestSession &&
          other.sessionId == this.sessionId &&
          other.maxSequence == this.maxSequence &&
          other.updatedAt == this.updatedAt);
}

class UsageIngestSessionsCompanion extends UpdateCompanion<UsageIngestSession> {
  final Value<String> sessionId;
  final Value<int> maxSequence;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const UsageIngestSessionsCompanion({
    this.sessionId = const Value.absent(),
    this.maxSequence = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UsageIngestSessionsCompanion.insert({
    required String sessionId,
    required int maxSequence,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : sessionId = Value(sessionId),
       maxSequence = Value(maxSequence),
       updatedAt = Value(updatedAt);
  static Insertable<UsageIngestSession> custom({
    Expression<String>? sessionId,
    Expression<int>? maxSequence,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sessionId != null) 'session_id': sessionId,
      if (maxSequence != null) 'max_sequence': maxSequence,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UsageIngestSessionsCompanion copyWith({
    Value<String>? sessionId,
    Value<int>? maxSequence,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return UsageIngestSessionsCompanion(
      sessionId: sessionId ?? this.sessionId,
      maxSequence: maxSequence ?? this.maxSequence,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (maxSequence.present) {
      map['max_sequence'] = Variable<int>(maxSequence.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UsageIngestSessionsCompanion(')
          ..write('sessionId: $sessionId, ')
          ..write('maxSequence: $maxSequence, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UsageDailyTotalsTable extends UsageDailyTotals
    with TableInfo<$UsageDailyTotalsTable, UsageDailyTotal> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UsageDailyTotalsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _dayMeta = const VerificationMeta('day');
  @override
  late final GeneratedColumn<String> day = GeneratedColumn<String>(
    'day',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _routeMeta = const VerificationMeta('route');
  @override
  late final GeneratedColumn<String> route = GeneratedColumn<String>(
    'route',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _uploadMeta = const VerificationMeta('upload');
  @override
  late final GeneratedColumn<int> upload = GeneratedColumn<int>(
    'upload',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _downloadMeta = const VerificationMeta(
    'download',
  );
  @override
  late final GeneratedColumn<int> download = GeneratedColumn<int>(
    'download',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _connectionsMeta = const VerificationMeta(
    'connections',
  );
  @override
  late final GeneratedColumn<int> connections = GeneratedColumn<int>(
    'connections',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    day,
    route,
    upload,
    download,
    connections,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'usage_daily_totals';
  @override
  VerificationContext validateIntegrity(
    Insertable<UsageDailyTotal> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('day')) {
      context.handle(
        _dayMeta,
        day.isAcceptableOrUnknown(data['day']!, _dayMeta),
      );
    } else if (isInserting) {
      context.missing(_dayMeta);
    }
    if (data.containsKey('route')) {
      context.handle(
        _routeMeta,
        route.isAcceptableOrUnknown(data['route']!, _routeMeta),
      );
    } else if (isInserting) {
      context.missing(_routeMeta);
    }
    if (data.containsKey('upload')) {
      context.handle(
        _uploadMeta,
        upload.isAcceptableOrUnknown(data['upload']!, _uploadMeta),
      );
    }
    if (data.containsKey('download')) {
      context.handle(
        _downloadMeta,
        download.isAcceptableOrUnknown(data['download']!, _downloadMeta),
      );
    }
    if (data.containsKey('connections')) {
      context.handle(
        _connectionsMeta,
        connections.isAcceptableOrUnknown(
          data['connections']!,
          _connectionsMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {day, route};
  @override
  UsageDailyTotal map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UsageDailyTotal(
      day: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}day'],
      )!,
      route: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}route'],
      )!,
      upload: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}upload'],
      )!,
      download: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}download'],
      )!,
      connections: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}connections'],
      )!,
    );
  }

  @override
  $UsageDailyTotalsTable createAlias(String alias) {
    return $UsageDailyTotalsTable(attachedDatabase, alias);
  }
}

class UsageDailyTotal extends DataClass implements Insertable<UsageDailyTotal> {
  final String day;
  final String route;
  final int upload;
  final int download;
  final int connections;
  const UsageDailyTotal({
    required this.day,
    required this.route,
    required this.upload,
    required this.download,
    required this.connections,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['day'] = Variable<String>(day);
    map['route'] = Variable<String>(route);
    map['upload'] = Variable<int>(upload);
    map['download'] = Variable<int>(download);
    map['connections'] = Variable<int>(connections);
    return map;
  }

  UsageDailyTotalsCompanion toCompanion(bool nullToAbsent) {
    return UsageDailyTotalsCompanion(
      day: Value(day),
      route: Value(route),
      upload: Value(upload),
      download: Value(download),
      connections: Value(connections),
    );
  }

  factory UsageDailyTotal.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UsageDailyTotal(
      day: serializer.fromJson<String>(json['day']),
      route: serializer.fromJson<String>(json['route']),
      upload: serializer.fromJson<int>(json['upload']),
      download: serializer.fromJson<int>(json['download']),
      connections: serializer.fromJson<int>(json['connections']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'day': serializer.toJson<String>(day),
      'route': serializer.toJson<String>(route),
      'upload': serializer.toJson<int>(upload),
      'download': serializer.toJson<int>(download),
      'connections': serializer.toJson<int>(connections),
    };
  }

  UsageDailyTotal copyWith({
    String? day,
    String? route,
    int? upload,
    int? download,
    int? connections,
  }) => UsageDailyTotal(
    day: day ?? this.day,
    route: route ?? this.route,
    upload: upload ?? this.upload,
    download: download ?? this.download,
    connections: connections ?? this.connections,
  );
  UsageDailyTotal copyWithCompanion(UsageDailyTotalsCompanion data) {
    return UsageDailyTotal(
      day: data.day.present ? data.day.value : this.day,
      route: data.route.present ? data.route.value : this.route,
      upload: data.upload.present ? data.upload.value : this.upload,
      download: data.download.present ? data.download.value : this.download,
      connections: data.connections.present
          ? data.connections.value
          : this.connections,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UsageDailyTotal(')
          ..write('day: $day, ')
          ..write('route: $route, ')
          ..write('upload: $upload, ')
          ..write('download: $download, ')
          ..write('connections: $connections')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(day, route, upload, download, connections);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UsageDailyTotal &&
          other.day == this.day &&
          other.route == this.route &&
          other.upload == this.upload &&
          other.download == this.download &&
          other.connections == this.connections);
}

class UsageDailyTotalsCompanion extends UpdateCompanion<UsageDailyTotal> {
  final Value<String> day;
  final Value<String> route;
  final Value<int> upload;
  final Value<int> download;
  final Value<int> connections;
  final Value<int> rowid;
  const UsageDailyTotalsCompanion({
    this.day = const Value.absent(),
    this.route = const Value.absent(),
    this.upload = const Value.absent(),
    this.download = const Value.absent(),
    this.connections = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UsageDailyTotalsCompanion.insert({
    required String day,
    required String route,
    this.upload = const Value.absent(),
    this.download = const Value.absent(),
    this.connections = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : day = Value(day),
       route = Value(route);
  static Insertable<UsageDailyTotal> custom({
    Expression<String>? day,
    Expression<String>? route,
    Expression<int>? upload,
    Expression<int>? download,
    Expression<int>? connections,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (day != null) 'day': day,
      if (route != null) 'route': route,
      if (upload != null) 'upload': upload,
      if (download != null) 'download': download,
      if (connections != null) 'connections': connections,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UsageDailyTotalsCompanion copyWith({
    Value<String>? day,
    Value<String>? route,
    Value<int>? upload,
    Value<int>? download,
    Value<int>? connections,
    Value<int>? rowid,
  }) {
    return UsageDailyTotalsCompanion(
      day: day ?? this.day,
      route: route ?? this.route,
      upload: upload ?? this.upload,
      download: download ?? this.download,
      connections: connections ?? this.connections,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (day.present) {
      map['day'] = Variable<String>(day.value);
    }
    if (route.present) {
      map['route'] = Variable<String>(route.value);
    }
    if (upload.present) {
      map['upload'] = Variable<int>(upload.value);
    }
    if (download.present) {
      map['download'] = Variable<int>(download.value);
    }
    if (connections.present) {
      map['connections'] = Variable<int>(connections.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UsageDailyTotalsCompanion(')
          ..write('day: $day, ')
          ..write('route: $route, ')
          ..write('upload: $upload, ')
          ..write('download: $download, ')
          ..write('connections: $connections, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UsageProfileLabelsTable extends UsageProfileLabels
    with TableInfo<$UsageProfileLabelsTable, UsageProfileLabel> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UsageProfileLabelsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _profileKeyMeta = const VerificationMeta(
    'profileKey',
  );
  @override
  late final GeneratedColumn<String> profileKey = GeneratedColumn<String>(
    'profile_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _lastSeenMinuteMeta = const VerificationMeta(
    'lastSeenMinute',
  );
  @override
  late final GeneratedColumn<int> lastSeenMinute = GeneratedColumn<int>(
    'last_seen_minute',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [profileKey, label, lastSeenMinute];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'usage_profile_labels';
  @override
  VerificationContext validateIntegrity(
    Insertable<UsageProfileLabel> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('profile_key')) {
      context.handle(
        _profileKeyMeta,
        profileKey.isAcceptableOrUnknown(data['profile_key']!, _profileKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_profileKeyMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    }
    if (data.containsKey('last_seen_minute')) {
      context.handle(
        _lastSeenMinuteMeta,
        lastSeenMinute.isAcceptableOrUnknown(
          data['last_seen_minute']!,
          _lastSeenMinuteMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastSeenMinuteMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {profileKey};
  @override
  UsageProfileLabel map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UsageProfileLabel(
      profileKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_key'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
      lastSeenMinute: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_seen_minute'],
      )!,
    );
  }

  @override
  $UsageProfileLabelsTable createAlias(String alias) {
    return $UsageProfileLabelsTable(attachedDatabase, alias);
  }
}

class UsageProfileLabel extends DataClass
    implements Insertable<UsageProfileLabel> {
  final String profileKey;
  final String label;
  final int lastSeenMinute;
  const UsageProfileLabel({
    required this.profileKey,
    required this.label,
    required this.lastSeenMinute,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['profile_key'] = Variable<String>(profileKey);
    map['label'] = Variable<String>(label);
    map['last_seen_minute'] = Variable<int>(lastSeenMinute);
    return map;
  }

  UsageProfileLabelsCompanion toCompanion(bool nullToAbsent) {
    return UsageProfileLabelsCompanion(
      profileKey: Value(profileKey),
      label: Value(label),
      lastSeenMinute: Value(lastSeenMinute),
    );
  }

  factory UsageProfileLabel.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UsageProfileLabel(
      profileKey: serializer.fromJson<String>(json['profileKey']),
      label: serializer.fromJson<String>(json['label']),
      lastSeenMinute: serializer.fromJson<int>(json['lastSeenMinute']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'profileKey': serializer.toJson<String>(profileKey),
      'label': serializer.toJson<String>(label),
      'lastSeenMinute': serializer.toJson<int>(lastSeenMinute),
    };
  }

  UsageProfileLabel copyWith({
    String? profileKey,
    String? label,
    int? lastSeenMinute,
  }) => UsageProfileLabel(
    profileKey: profileKey ?? this.profileKey,
    label: label ?? this.label,
    lastSeenMinute: lastSeenMinute ?? this.lastSeenMinute,
  );
  UsageProfileLabel copyWithCompanion(UsageProfileLabelsCompanion data) {
    return UsageProfileLabel(
      profileKey: data.profileKey.present
          ? data.profileKey.value
          : this.profileKey,
      label: data.label.present ? data.label.value : this.label,
      lastSeenMinute: data.lastSeenMinute.present
          ? data.lastSeenMinute.value
          : this.lastSeenMinute,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UsageProfileLabel(')
          ..write('profileKey: $profileKey, ')
          ..write('label: $label, ')
          ..write('lastSeenMinute: $lastSeenMinute')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(profileKey, label, lastSeenMinute);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UsageProfileLabel &&
          other.profileKey == this.profileKey &&
          other.label == this.label &&
          other.lastSeenMinute == this.lastSeenMinute);
}

class UsageProfileLabelsCompanion extends UpdateCompanion<UsageProfileLabel> {
  final Value<String> profileKey;
  final Value<String> label;
  final Value<int> lastSeenMinute;
  final Value<int> rowid;
  const UsageProfileLabelsCompanion({
    this.profileKey = const Value.absent(),
    this.label = const Value.absent(),
    this.lastSeenMinute = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UsageProfileLabelsCompanion.insert({
    required String profileKey,
    this.label = const Value.absent(),
    required int lastSeenMinute,
    this.rowid = const Value.absent(),
  }) : profileKey = Value(profileKey),
       lastSeenMinute = Value(lastSeenMinute);
  static Insertable<UsageProfileLabel> custom({
    Expression<String>? profileKey,
    Expression<String>? label,
    Expression<int>? lastSeenMinute,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (profileKey != null) 'profile_key': profileKey,
      if (label != null) 'label': label,
      if (lastSeenMinute != null) 'last_seen_minute': lastSeenMinute,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UsageProfileLabelsCompanion copyWith({
    Value<String>? profileKey,
    Value<String>? label,
    Value<int>? lastSeenMinute,
    Value<int>? rowid,
  }) {
    return UsageProfileLabelsCompanion(
      profileKey: profileKey ?? this.profileKey,
      label: label ?? this.label,
      lastSeenMinute: lastSeenMinute ?? this.lastSeenMinute,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (profileKey.present) {
      map['profile_key'] = Variable<String>(profileKey.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (lastSeenMinute.present) {
      map['last_seen_minute'] = Variable<int>(lastSeenMinute.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UsageProfileLabelsCompanion(')
          ..write('profileKey: $profileKey, ')
          ..write('label: $label, ')
          ..write('lastSeenMinute: $lastSeenMinute, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UsageApplicationLabelsTable extends UsageApplicationLabels
    with TableInfo<$UsageApplicationLabelsTable, UsageApplicationLabel> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UsageApplicationLabelsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _processPathKeyMeta = const VerificationMeta(
    'processPathKey',
  );
  @override
  late final GeneratedColumn<String> processPathKey = GeneratedColumn<String>(
    'process_path_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _lastSeenMinuteMeta = const VerificationMeta(
    'lastSeenMinute',
  );
  @override
  late final GeneratedColumn<int> lastSeenMinute = GeneratedColumn<int>(
    'last_seen_minute',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [processPathKey, label, lastSeenMinute];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'usage_application_labels';
  @override
  VerificationContext validateIntegrity(
    Insertable<UsageApplicationLabel> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('process_path_key')) {
      context.handle(
        _processPathKeyMeta,
        processPathKey.isAcceptableOrUnknown(
          data['process_path_key']!,
          _processPathKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_processPathKeyMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    }
    if (data.containsKey('last_seen_minute')) {
      context.handle(
        _lastSeenMinuteMeta,
        lastSeenMinute.isAcceptableOrUnknown(
          data['last_seen_minute']!,
          _lastSeenMinuteMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastSeenMinuteMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {processPathKey};
  @override
  UsageApplicationLabel map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UsageApplicationLabel(
      processPathKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}process_path_key'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
      lastSeenMinute: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_seen_minute'],
      )!,
    );
  }

  @override
  $UsageApplicationLabelsTable createAlias(String alias) {
    return $UsageApplicationLabelsTable(attachedDatabase, alias);
  }
}

class UsageApplicationLabel extends DataClass
    implements Insertable<UsageApplicationLabel> {
  final String processPathKey;
  final String label;
  final int lastSeenMinute;
  const UsageApplicationLabel({
    required this.processPathKey,
    required this.label,
    required this.lastSeenMinute,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['process_path_key'] = Variable<String>(processPathKey);
    map['label'] = Variable<String>(label);
    map['last_seen_minute'] = Variable<int>(lastSeenMinute);
    return map;
  }

  UsageApplicationLabelsCompanion toCompanion(bool nullToAbsent) {
    return UsageApplicationLabelsCompanion(
      processPathKey: Value(processPathKey),
      label: Value(label),
      lastSeenMinute: Value(lastSeenMinute),
    );
  }

  factory UsageApplicationLabel.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UsageApplicationLabel(
      processPathKey: serializer.fromJson<String>(json['processPathKey']),
      label: serializer.fromJson<String>(json['label']),
      lastSeenMinute: serializer.fromJson<int>(json['lastSeenMinute']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'processPathKey': serializer.toJson<String>(processPathKey),
      'label': serializer.toJson<String>(label),
      'lastSeenMinute': serializer.toJson<int>(lastSeenMinute),
    };
  }

  UsageApplicationLabel copyWith({
    String? processPathKey,
    String? label,
    int? lastSeenMinute,
  }) => UsageApplicationLabel(
    processPathKey: processPathKey ?? this.processPathKey,
    label: label ?? this.label,
    lastSeenMinute: lastSeenMinute ?? this.lastSeenMinute,
  );
  UsageApplicationLabel copyWithCompanion(
    UsageApplicationLabelsCompanion data,
  ) {
    return UsageApplicationLabel(
      processPathKey: data.processPathKey.present
          ? data.processPathKey.value
          : this.processPathKey,
      label: data.label.present ? data.label.value : this.label,
      lastSeenMinute: data.lastSeenMinute.present
          ? data.lastSeenMinute.value
          : this.lastSeenMinute,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UsageApplicationLabel(')
          ..write('processPathKey: $processPathKey, ')
          ..write('label: $label, ')
          ..write('lastSeenMinute: $lastSeenMinute')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(processPathKey, label, lastSeenMinute);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UsageApplicationLabel &&
          other.processPathKey == this.processPathKey &&
          other.label == this.label &&
          other.lastSeenMinute == this.lastSeenMinute);
}

class UsageApplicationLabelsCompanion
    extends UpdateCompanion<UsageApplicationLabel> {
  final Value<String> processPathKey;
  final Value<String> label;
  final Value<int> lastSeenMinute;
  final Value<int> rowid;
  const UsageApplicationLabelsCompanion({
    this.processPathKey = const Value.absent(),
    this.label = const Value.absent(),
    this.lastSeenMinute = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UsageApplicationLabelsCompanion.insert({
    required String processPathKey,
    this.label = const Value.absent(),
    required int lastSeenMinute,
    this.rowid = const Value.absent(),
  }) : processPathKey = Value(processPathKey),
       lastSeenMinute = Value(lastSeenMinute);
  static Insertable<UsageApplicationLabel> custom({
    Expression<String>? processPathKey,
    Expression<String>? label,
    Expression<int>? lastSeenMinute,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (processPathKey != null) 'process_path_key': processPathKey,
      if (label != null) 'label': label,
      if (lastSeenMinute != null) 'last_seen_minute': lastSeenMinute,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UsageApplicationLabelsCompanion copyWith({
    Value<String>? processPathKey,
    Value<String>? label,
    Value<int>? lastSeenMinute,
    Value<int>? rowid,
  }) {
    return UsageApplicationLabelsCompanion(
      processPathKey: processPathKey ?? this.processPathKey,
      label: label ?? this.label,
      lastSeenMinute: lastSeenMinute ?? this.lastSeenMinute,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (processPathKey.present) {
      map['process_path_key'] = Variable<String>(processPathKey.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (lastSeenMinute.present) {
      map['last_seen_minute'] = Variable<int>(lastSeenMinute.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UsageApplicationLabelsCompanion(')
          ..write('processPathKey: $processPathKey, ')
          ..write('label: $label, ')
          ..write('lastSeenMinute: $lastSeenMinute, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UsageQualityIntervalsTable extends UsageQualityIntervals
    with TableInfo<$UsageQualityIntervalsTable, UsageQualityInterval> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UsageQualityIntervalsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sequenceMeta = const VerificationMeta(
    'sequence',
  );
  @override
  late final GeneratedColumn<int> sequence = GeneratedColumn<int>(
    'sequence',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startMinuteMeta = const VerificationMeta(
    'startMinute',
  );
  @override
  late final GeneratedColumn<int> startMinute = GeneratedColumn<int>(
    'start_minute',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endMinuteMeta = const VerificationMeta(
    'endMinute',
  );
  @override
  late final GeneratedColumn<int> endMinute = GeneratedColumn<int>(
    'end_minute',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    sessionId,
    sequence,
    startMinute,
    endMinute,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'usage_quality_intervals';
  @override
  VerificationContext validateIntegrity(
    Insertable<UsageQualityInterval> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('sequence')) {
      context.handle(
        _sequenceMeta,
        sequence.isAcceptableOrUnknown(data['sequence']!, _sequenceMeta),
      );
    } else if (isInserting) {
      context.missing(_sequenceMeta);
    }
    if (data.containsKey('start_minute')) {
      context.handle(
        _startMinuteMeta,
        startMinute.isAcceptableOrUnknown(
          data['start_minute']!,
          _startMinuteMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startMinuteMeta);
    }
    if (data.containsKey('end_minute')) {
      context.handle(
        _endMinuteMeta,
        endMinute.isAcceptableOrUnknown(data['end_minute']!, _endMinuteMeta),
      );
    } else if (isInserting) {
      context.missing(_endMinuteMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sessionId, sequence};
  @override
  UsageQualityInterval map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UsageQualityInterval(
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      sequence: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sequence'],
      )!,
      startMinute: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_minute'],
      )!,
      endMinute: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_minute'],
      )!,
    );
  }

  @override
  $UsageQualityIntervalsTable createAlias(String alias) {
    return $UsageQualityIntervalsTable(attachedDatabase, alias);
  }
}

class UsageQualityInterval extends DataClass
    implements Insertable<UsageQualityInterval> {
  final String sessionId;
  final int sequence;
  final int startMinute;
  final int endMinute;
  const UsageQualityInterval({
    required this.sessionId,
    required this.sequence,
    required this.startMinute,
    required this.endMinute,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['session_id'] = Variable<String>(sessionId);
    map['sequence'] = Variable<int>(sequence);
    map['start_minute'] = Variable<int>(startMinute);
    map['end_minute'] = Variable<int>(endMinute);
    return map;
  }

  UsageQualityIntervalsCompanion toCompanion(bool nullToAbsent) {
    return UsageQualityIntervalsCompanion(
      sessionId: Value(sessionId),
      sequence: Value(sequence),
      startMinute: Value(startMinute),
      endMinute: Value(endMinute),
    );
  }

  factory UsageQualityInterval.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UsageQualityInterval(
      sessionId: serializer.fromJson<String>(json['sessionId']),
      sequence: serializer.fromJson<int>(json['sequence']),
      startMinute: serializer.fromJson<int>(json['startMinute']),
      endMinute: serializer.fromJson<int>(json['endMinute']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sessionId': serializer.toJson<String>(sessionId),
      'sequence': serializer.toJson<int>(sequence),
      'startMinute': serializer.toJson<int>(startMinute),
      'endMinute': serializer.toJson<int>(endMinute),
    };
  }

  UsageQualityInterval copyWith({
    String? sessionId,
    int? sequence,
    int? startMinute,
    int? endMinute,
  }) => UsageQualityInterval(
    sessionId: sessionId ?? this.sessionId,
    sequence: sequence ?? this.sequence,
    startMinute: startMinute ?? this.startMinute,
    endMinute: endMinute ?? this.endMinute,
  );
  UsageQualityInterval copyWithCompanion(UsageQualityIntervalsCompanion data) {
    return UsageQualityInterval(
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      sequence: data.sequence.present ? data.sequence.value : this.sequence,
      startMinute: data.startMinute.present
          ? data.startMinute.value
          : this.startMinute,
      endMinute: data.endMinute.present ? data.endMinute.value : this.endMinute,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UsageQualityInterval(')
          ..write('sessionId: $sessionId, ')
          ..write('sequence: $sequence, ')
          ..write('startMinute: $startMinute, ')
          ..write('endMinute: $endMinute')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(sessionId, sequence, startMinute, endMinute);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UsageQualityInterval &&
          other.sessionId == this.sessionId &&
          other.sequence == this.sequence &&
          other.startMinute == this.startMinute &&
          other.endMinute == this.endMinute);
}

class UsageQualityIntervalsCompanion
    extends UpdateCompanion<UsageQualityInterval> {
  final Value<String> sessionId;
  final Value<int> sequence;
  final Value<int> startMinute;
  final Value<int> endMinute;
  final Value<int> rowid;
  const UsageQualityIntervalsCompanion({
    this.sessionId = const Value.absent(),
    this.sequence = const Value.absent(),
    this.startMinute = const Value.absent(),
    this.endMinute = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UsageQualityIntervalsCompanion.insert({
    required String sessionId,
    required int sequence,
    required int startMinute,
    required int endMinute,
    this.rowid = const Value.absent(),
  }) : sessionId = Value(sessionId),
       sequence = Value(sequence),
       startMinute = Value(startMinute),
       endMinute = Value(endMinute);
  static Insertable<UsageQualityInterval> custom({
    Expression<String>? sessionId,
    Expression<int>? sequence,
    Expression<int>? startMinute,
    Expression<int>? endMinute,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sessionId != null) 'session_id': sessionId,
      if (sequence != null) 'sequence': sequence,
      if (startMinute != null) 'start_minute': startMinute,
      if (endMinute != null) 'end_minute': endMinute,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UsageQualityIntervalsCompanion copyWith({
    Value<String>? sessionId,
    Value<int>? sequence,
    Value<int>? startMinute,
    Value<int>? endMinute,
    Value<int>? rowid,
  }) {
    return UsageQualityIntervalsCompanion(
      sessionId: sessionId ?? this.sessionId,
      sequence: sequence ?? this.sequence,
      startMinute: startMinute ?? this.startMinute,
      endMinute: endMinute ?? this.endMinute,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (sequence.present) {
      map['sequence'] = Variable<int>(sequence.value);
    }
    if (startMinute.present) {
      map['start_minute'] = Variable<int>(startMinute.value);
    }
    if (endMinute.present) {
      map['end_minute'] = Variable<int>(endMinute.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UsageQualityIntervalsCompanion(')
          ..write('sessionId: $sessionId, ')
          ..write('sequence: $sequence, ')
          ..write('startMinute: $startMinute, ')
          ..write('endMinute: $endMinute, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UsageSettingsTable extends UsageSettings
    with TableInfo<$UsageSettingsTable, UsageSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UsageSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _consentAcceptedMeta = const VerificationMeta(
    'consentAccepted',
  );
  @override
  late final GeneratedColumn<bool> consentAccepted = GeneratedColumn<bool>(
    'consent_accepted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("consent_accepted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastCleanupMeta = const VerificationMeta(
    'lastCleanup',
  );
  @override
  late final GeneratedColumn<DateTime> lastCleanup = GeneratedColumn<DateTime>(
    'last_cleanup',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _localTimezoneOffsetMinutesMeta =
      const VerificationMeta('localTimezoneOffsetMinutes');
  @override
  late final GeneratedColumn<int> localTimezoneOffsetMinutes =
      GeneratedColumn<int>(
        'local_timezone_offset_minutes',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    enabled,
    consentAccepted,
    updatedAt,
    lastCleanup,
    localTimezoneOffsetMinutes,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'usage_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<UsageSetting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    if (data.containsKey('consent_accepted')) {
      context.handle(
        _consentAcceptedMeta,
        consentAccepted.isAcceptableOrUnknown(
          data['consent_accepted']!,
          _consentAcceptedMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('last_cleanup')) {
      context.handle(
        _lastCleanupMeta,
        lastCleanup.isAcceptableOrUnknown(
          data['last_cleanup']!,
          _lastCleanupMeta,
        ),
      );
    }
    if (data.containsKey('local_timezone_offset_minutes')) {
      context.handle(
        _localTimezoneOffsetMinutesMeta,
        localTimezoneOffsetMinutes.isAcceptableOrUnknown(
          data['local_timezone_offset_minutes']!,
          _localTimezoneOffsetMinutesMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UsageSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UsageSetting(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
      consentAccepted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}consent_accepted'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      lastCleanup: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_cleanup'],
      ),
      localTimezoneOffsetMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}local_timezone_offset_minutes'],
      ),
    );
  }

  @override
  $UsageSettingsTable createAlias(String alias) {
    return $UsageSettingsTable(attachedDatabase, alias);
  }
}

class UsageSetting extends DataClass implements Insertable<UsageSetting> {
  final int id;
  final bool enabled;
  final bool consentAccepted;
  final DateTime updatedAt;
  final DateTime? lastCleanup;
  final int? localTimezoneOffsetMinutes;
  const UsageSetting({
    required this.id,
    required this.enabled,
    required this.consentAccepted,
    required this.updatedAt,
    this.lastCleanup,
    this.localTimezoneOffsetMinutes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['enabled'] = Variable<bool>(enabled);
    map['consent_accepted'] = Variable<bool>(consentAccepted);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || lastCleanup != null) {
      map['last_cleanup'] = Variable<DateTime>(lastCleanup);
    }
    if (!nullToAbsent || localTimezoneOffsetMinutes != null) {
      map['local_timezone_offset_minutes'] = Variable<int>(
        localTimezoneOffsetMinutes,
      );
    }
    return map;
  }

  UsageSettingsCompanion toCompanion(bool nullToAbsent) {
    return UsageSettingsCompanion(
      id: Value(id),
      enabled: Value(enabled),
      consentAccepted: Value(consentAccepted),
      updatedAt: Value(updatedAt),
      lastCleanup: lastCleanup == null && nullToAbsent
          ? const Value.absent()
          : Value(lastCleanup),
      localTimezoneOffsetMinutes:
          localTimezoneOffsetMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(localTimezoneOffsetMinutes),
    );
  }

  factory UsageSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UsageSetting(
      id: serializer.fromJson<int>(json['id']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      consentAccepted: serializer.fromJson<bool>(json['consentAccepted']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      lastCleanup: serializer.fromJson<DateTime?>(json['lastCleanup']),
      localTimezoneOffsetMinutes: serializer.fromJson<int?>(
        json['localTimezoneOffsetMinutes'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'enabled': serializer.toJson<bool>(enabled),
      'consentAccepted': serializer.toJson<bool>(consentAccepted),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'lastCleanup': serializer.toJson<DateTime?>(lastCleanup),
      'localTimezoneOffsetMinutes': serializer.toJson<int?>(
        localTimezoneOffsetMinutes,
      ),
    };
  }

  UsageSetting copyWith({
    int? id,
    bool? enabled,
    bool? consentAccepted,
    DateTime? updatedAt,
    Value<DateTime?> lastCleanup = const Value.absent(),
    Value<int?> localTimezoneOffsetMinutes = const Value.absent(),
  }) => UsageSetting(
    id: id ?? this.id,
    enabled: enabled ?? this.enabled,
    consentAccepted: consentAccepted ?? this.consentAccepted,
    updatedAt: updatedAt ?? this.updatedAt,
    lastCleanup: lastCleanup.present ? lastCleanup.value : this.lastCleanup,
    localTimezoneOffsetMinutes: localTimezoneOffsetMinutes.present
        ? localTimezoneOffsetMinutes.value
        : this.localTimezoneOffsetMinutes,
  );
  UsageSetting copyWithCompanion(UsageSettingsCompanion data) {
    return UsageSetting(
      id: data.id.present ? data.id.value : this.id,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      consentAccepted: data.consentAccepted.present
          ? data.consentAccepted.value
          : this.consentAccepted,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      lastCleanup: data.lastCleanup.present
          ? data.lastCleanup.value
          : this.lastCleanup,
      localTimezoneOffsetMinutes: data.localTimezoneOffsetMinutes.present
          ? data.localTimezoneOffsetMinutes.value
          : this.localTimezoneOffsetMinutes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UsageSetting(')
          ..write('id: $id, ')
          ..write('enabled: $enabled, ')
          ..write('consentAccepted: $consentAccepted, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('lastCleanup: $lastCleanup, ')
          ..write('localTimezoneOffsetMinutes: $localTimezoneOffsetMinutes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    enabled,
    consentAccepted,
    updatedAt,
    lastCleanup,
    localTimezoneOffsetMinutes,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UsageSetting &&
          other.id == this.id &&
          other.enabled == this.enabled &&
          other.consentAccepted == this.consentAccepted &&
          other.updatedAt == this.updatedAt &&
          other.lastCleanup == this.lastCleanup &&
          other.localTimezoneOffsetMinutes == this.localTimezoneOffsetMinutes);
}

class UsageSettingsCompanion extends UpdateCompanion<UsageSetting> {
  final Value<int> id;
  final Value<bool> enabled;
  final Value<bool> consentAccepted;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> lastCleanup;
  final Value<int?> localTimezoneOffsetMinutes;
  const UsageSettingsCompanion({
    this.id = const Value.absent(),
    this.enabled = const Value.absent(),
    this.consentAccepted = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.lastCleanup = const Value.absent(),
    this.localTimezoneOffsetMinutes = const Value.absent(),
  });
  UsageSettingsCompanion.insert({
    this.id = const Value.absent(),
    this.enabled = const Value.absent(),
    this.consentAccepted = const Value.absent(),
    required DateTime updatedAt,
    this.lastCleanup = const Value.absent(),
    this.localTimezoneOffsetMinutes = const Value.absent(),
  }) : updatedAt = Value(updatedAt);
  static Insertable<UsageSetting> custom({
    Expression<int>? id,
    Expression<bool>? enabled,
    Expression<bool>? consentAccepted,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? lastCleanup,
    Expression<int>? localTimezoneOffsetMinutes,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (enabled != null) 'enabled': enabled,
      if (consentAccepted != null) 'consent_accepted': consentAccepted,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (lastCleanup != null) 'last_cleanup': lastCleanup,
      if (localTimezoneOffsetMinutes != null)
        'local_timezone_offset_minutes': localTimezoneOffsetMinutes,
    });
  }

  UsageSettingsCompanion copyWith({
    Value<int>? id,
    Value<bool>? enabled,
    Value<bool>? consentAccepted,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? lastCleanup,
    Value<int?>? localTimezoneOffsetMinutes,
  }) {
    return UsageSettingsCompanion(
      id: id ?? this.id,
      enabled: enabled ?? this.enabled,
      consentAccepted: consentAccepted ?? this.consentAccepted,
      updatedAt: updatedAt ?? this.updatedAt,
      lastCleanup: lastCleanup ?? this.lastCleanup,
      localTimezoneOffsetMinutes:
          localTimezoneOffsetMinutes ?? this.localTimezoneOffsetMinutes,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (consentAccepted.present) {
      map['consent_accepted'] = Variable<bool>(consentAccepted.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (lastCleanup.present) {
      map['last_cleanup'] = Variable<DateTime>(lastCleanup.value);
    }
    if (localTimezoneOffsetMinutes.present) {
      map['local_timezone_offset_minutes'] = Variable<int>(
        localTimezoneOffsetMinutes.value,
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UsageSettingsCompanion(')
          ..write('id: $id, ')
          ..write('enabled: $enabled, ')
          ..write('consentAccepted: $consentAccepted, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('lastCleanup: $lastCleanup, ')
          ..write('localTimezoneOffsetMinutes: $localTimezoneOffsetMinutes')
          ..write(')'))
        .toString();
  }
}

abstract class _$UsageDatabase extends GeneratedDatabase {
  _$UsageDatabase(QueryExecutor e) : super(e);
  $UsageDatabaseManager get managers => $UsageDatabaseManager(this);
  late final $UsageBucketsTable usageBuckets = $UsageBucketsTable(this);
  late final $UsageIngestSessionsTable usageIngestSessions =
      $UsageIngestSessionsTable(this);
  late final $UsageDailyTotalsTable usageDailyTotals = $UsageDailyTotalsTable(
    this,
  );
  late final $UsageProfileLabelsTable usageProfileLabels =
      $UsageProfileLabelsTable(this);
  late final $UsageApplicationLabelsTable usageApplicationLabels =
      $UsageApplicationLabelsTable(this);
  late final $UsageQualityIntervalsTable usageQualityIntervals =
      $UsageQualityIntervalsTable(this);
  late final $UsageSettingsTable usageSettings = $UsageSettingsTable(this);
  late final Index usageBucketRouteMinute = Index(
    'usage_bucket_route_minute',
    'CREATE INDEX usage_bucket_route_minute ON usage_buckets (route, minute)',
  );
  late final Index usageBucketProfileMinute = Index(
    'usage_bucket_profile_minute',
    'CREATE INDEX usage_bucket_profile_minute ON usage_buckets (profile_id, minute)',
  );
  late final Index usageBucketNodeMinute = Index(
    'usage_bucket_node_minute',
    'CREATE INDEX usage_bucket_node_minute ON usage_buckets (node, minute)',
  );
  late final Index usageBucketProcessPathMinute = Index(
    'usage_bucket_process_path_minute',
    'CREATE INDEX usage_bucket_process_path_minute ON usage_buckets (process_path, minute)',
  );
  late final Index usageBucketDomainKeyMinute = Index(
    'usage_bucket_domain_key_minute',
    'CREATE INDEX usage_bucket_domain_key_minute ON usage_buckets (domain_key, minute)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    usageBuckets,
    usageIngestSessions,
    usageDailyTotals,
    usageProfileLabels,
    usageApplicationLabels,
    usageQualityIntervals,
    usageSettings,
    usageBucketRouteMinute,
    usageBucketProfileMinute,
    usageBucketNodeMinute,
    usageBucketProcessPathMinute,
    usageBucketDomainKeyMinute,
  ];
}

typedef $$UsageBucketsTableCreateCompanionBuilder =
    UsageBucketsCompanion Function({
      required int minute,
      Value<String> localDay,
      Value<int> localHour,
      Value<int> localDayStart,
      required String bucketKey,
      Value<int?> profileId,
      Value<String> profileLabel,
      required String route,
      Value<String> node,
      Value<String> process,
      Value<String> processPath,
      Value<String> domain,
      Value<String> host,
      Value<String> destinationIp,
      Value<String> domainKey,
      Value<int> upload,
      Value<int> download,
      Value<int> connections,
      Value<int> rowid,
    });
typedef $$UsageBucketsTableUpdateCompanionBuilder =
    UsageBucketsCompanion Function({
      Value<int> minute,
      Value<String> localDay,
      Value<int> localHour,
      Value<int> localDayStart,
      Value<String> bucketKey,
      Value<int?> profileId,
      Value<String> profileLabel,
      Value<String> route,
      Value<String> node,
      Value<String> process,
      Value<String> processPath,
      Value<String> domain,
      Value<String> host,
      Value<String> destinationIp,
      Value<String> domainKey,
      Value<int> upload,
      Value<int> download,
      Value<int> connections,
      Value<int> rowid,
    });

class $$UsageBucketsTableFilterComposer
    extends Composer<_$UsageDatabase, $UsageBucketsTable> {
  $$UsageBucketsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get minute => $composableBuilder(
    column: $table.minute,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localDay => $composableBuilder(
    column: $table.localDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get localHour => $composableBuilder(
    column: $table.localHour,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get localDayStart => $composableBuilder(
    column: $table.localDayStart,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bucketKey => $composableBuilder(
    column: $table.bucketKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get profileLabel => $composableBuilder(
    column: $table.profileLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get route => $composableBuilder(
    column: $table.route,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get node => $composableBuilder(
    column: $table.node,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get process => $composableBuilder(
    column: $table.process,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get processPath => $composableBuilder(
    column: $table.processPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get domain => $composableBuilder(
    column: $table.domain,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get host => $composableBuilder(
    column: $table.host,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get destinationIp => $composableBuilder(
    column: $table.destinationIp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get domainKey => $composableBuilder(
    column: $table.domainKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get upload => $composableBuilder(
    column: $table.upload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get download => $composableBuilder(
    column: $table.download,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get connections => $composableBuilder(
    column: $table.connections,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UsageBucketsTableOrderingComposer
    extends Composer<_$UsageDatabase, $UsageBucketsTable> {
  $$UsageBucketsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get minute => $composableBuilder(
    column: $table.minute,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localDay => $composableBuilder(
    column: $table.localDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get localHour => $composableBuilder(
    column: $table.localHour,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get localDayStart => $composableBuilder(
    column: $table.localDayStart,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bucketKey => $composableBuilder(
    column: $table.bucketKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get profileLabel => $composableBuilder(
    column: $table.profileLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get route => $composableBuilder(
    column: $table.route,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get node => $composableBuilder(
    column: $table.node,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get process => $composableBuilder(
    column: $table.process,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get processPath => $composableBuilder(
    column: $table.processPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get domain => $composableBuilder(
    column: $table.domain,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get host => $composableBuilder(
    column: $table.host,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get destinationIp => $composableBuilder(
    column: $table.destinationIp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get domainKey => $composableBuilder(
    column: $table.domainKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get upload => $composableBuilder(
    column: $table.upload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get download => $composableBuilder(
    column: $table.download,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get connections => $composableBuilder(
    column: $table.connections,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UsageBucketsTableAnnotationComposer
    extends Composer<_$UsageDatabase, $UsageBucketsTable> {
  $$UsageBucketsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get minute =>
      $composableBuilder(column: $table.minute, builder: (column) => column);

  GeneratedColumn<String> get localDay =>
      $composableBuilder(column: $table.localDay, builder: (column) => column);

  GeneratedColumn<int> get localHour =>
      $composableBuilder(column: $table.localHour, builder: (column) => column);

  GeneratedColumn<int> get localDayStart => $composableBuilder(
    column: $table.localDayStart,
    builder: (column) => column,
  );

  GeneratedColumn<String> get bucketKey =>
      $composableBuilder(column: $table.bucketKey, builder: (column) => column);

  GeneratedColumn<int> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<String> get profileLabel => $composableBuilder(
    column: $table.profileLabel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get route =>
      $composableBuilder(column: $table.route, builder: (column) => column);

  GeneratedColumn<String> get node =>
      $composableBuilder(column: $table.node, builder: (column) => column);

  GeneratedColumn<String> get process =>
      $composableBuilder(column: $table.process, builder: (column) => column);

  GeneratedColumn<String> get processPath => $composableBuilder(
    column: $table.processPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get domain =>
      $composableBuilder(column: $table.domain, builder: (column) => column);

  GeneratedColumn<String> get host =>
      $composableBuilder(column: $table.host, builder: (column) => column);

  GeneratedColumn<String> get destinationIp => $composableBuilder(
    column: $table.destinationIp,
    builder: (column) => column,
  );

  GeneratedColumn<String> get domainKey =>
      $composableBuilder(column: $table.domainKey, builder: (column) => column);

  GeneratedColumn<int> get upload =>
      $composableBuilder(column: $table.upload, builder: (column) => column);

  GeneratedColumn<int> get download =>
      $composableBuilder(column: $table.download, builder: (column) => column);

  GeneratedColumn<int> get connections => $composableBuilder(
    column: $table.connections,
    builder: (column) => column,
  );
}

class $$UsageBucketsTableTableManager
    extends
        RootTableManager<
          _$UsageDatabase,
          $UsageBucketsTable,
          UsageBucket,
          $$UsageBucketsTableFilterComposer,
          $$UsageBucketsTableOrderingComposer,
          $$UsageBucketsTableAnnotationComposer,
          $$UsageBucketsTableCreateCompanionBuilder,
          $$UsageBucketsTableUpdateCompanionBuilder,
          (
            UsageBucket,
            BaseReferences<_$UsageDatabase, $UsageBucketsTable, UsageBucket>,
          ),
          UsageBucket,
          PrefetchHooks Function()
        > {
  $$UsageBucketsTableTableManager(_$UsageDatabase db, $UsageBucketsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UsageBucketsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UsageBucketsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UsageBucketsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> minute = const Value.absent(),
                Value<String> localDay = const Value.absent(),
                Value<int> localHour = const Value.absent(),
                Value<int> localDayStart = const Value.absent(),
                Value<String> bucketKey = const Value.absent(),
                Value<int?> profileId = const Value.absent(),
                Value<String> profileLabel = const Value.absent(),
                Value<String> route = const Value.absent(),
                Value<String> node = const Value.absent(),
                Value<String> process = const Value.absent(),
                Value<String> processPath = const Value.absent(),
                Value<String> domain = const Value.absent(),
                Value<String> host = const Value.absent(),
                Value<String> destinationIp = const Value.absent(),
                Value<String> domainKey = const Value.absent(),
                Value<int> upload = const Value.absent(),
                Value<int> download = const Value.absent(),
                Value<int> connections = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UsageBucketsCompanion(
                minute: minute,
                localDay: localDay,
                localHour: localHour,
                localDayStart: localDayStart,
                bucketKey: bucketKey,
                profileId: profileId,
                profileLabel: profileLabel,
                route: route,
                node: node,
                process: process,
                processPath: processPath,
                domain: domain,
                host: host,
                destinationIp: destinationIp,
                domainKey: domainKey,
                upload: upload,
                download: download,
                connections: connections,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int minute,
                Value<String> localDay = const Value.absent(),
                Value<int> localHour = const Value.absent(),
                Value<int> localDayStart = const Value.absent(),
                required String bucketKey,
                Value<int?> profileId = const Value.absent(),
                Value<String> profileLabel = const Value.absent(),
                required String route,
                Value<String> node = const Value.absent(),
                Value<String> process = const Value.absent(),
                Value<String> processPath = const Value.absent(),
                Value<String> domain = const Value.absent(),
                Value<String> host = const Value.absent(),
                Value<String> destinationIp = const Value.absent(),
                Value<String> domainKey = const Value.absent(),
                Value<int> upload = const Value.absent(),
                Value<int> download = const Value.absent(),
                Value<int> connections = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UsageBucketsCompanion.insert(
                minute: minute,
                localDay: localDay,
                localHour: localHour,
                localDayStart: localDayStart,
                bucketKey: bucketKey,
                profileId: profileId,
                profileLabel: profileLabel,
                route: route,
                node: node,
                process: process,
                processPath: processPath,
                domain: domain,
                host: host,
                destinationIp: destinationIp,
                domainKey: domainKey,
                upload: upload,
                download: download,
                connections: connections,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UsageBucketsTableProcessedTableManager =
    ProcessedTableManager<
      _$UsageDatabase,
      $UsageBucketsTable,
      UsageBucket,
      $$UsageBucketsTableFilterComposer,
      $$UsageBucketsTableOrderingComposer,
      $$UsageBucketsTableAnnotationComposer,
      $$UsageBucketsTableCreateCompanionBuilder,
      $$UsageBucketsTableUpdateCompanionBuilder,
      (
        UsageBucket,
        BaseReferences<_$UsageDatabase, $UsageBucketsTable, UsageBucket>,
      ),
      UsageBucket,
      PrefetchHooks Function()
    >;
typedef $$UsageIngestSessionsTableCreateCompanionBuilder =
    UsageIngestSessionsCompanion Function({
      required String sessionId,
      required int maxSequence,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$UsageIngestSessionsTableUpdateCompanionBuilder =
    UsageIngestSessionsCompanion Function({
      Value<String> sessionId,
      Value<int> maxSequence,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$UsageIngestSessionsTableFilterComposer
    extends Composer<_$UsageDatabase, $UsageIngestSessionsTable> {
  $$UsageIngestSessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get maxSequence => $composableBuilder(
    column: $table.maxSequence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UsageIngestSessionsTableOrderingComposer
    extends Composer<_$UsageDatabase, $UsageIngestSessionsTable> {
  $$UsageIngestSessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get maxSequence => $composableBuilder(
    column: $table.maxSequence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UsageIngestSessionsTableAnnotationComposer
    extends Composer<_$UsageDatabase, $UsageIngestSessionsTable> {
  $$UsageIngestSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<int> get maxSequence => $composableBuilder(
    column: $table.maxSequence,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$UsageIngestSessionsTableTableManager
    extends
        RootTableManager<
          _$UsageDatabase,
          $UsageIngestSessionsTable,
          UsageIngestSession,
          $$UsageIngestSessionsTableFilterComposer,
          $$UsageIngestSessionsTableOrderingComposer,
          $$UsageIngestSessionsTableAnnotationComposer,
          $$UsageIngestSessionsTableCreateCompanionBuilder,
          $$UsageIngestSessionsTableUpdateCompanionBuilder,
          (
            UsageIngestSession,
            BaseReferences<
              _$UsageDatabase,
              $UsageIngestSessionsTable,
              UsageIngestSession
            >,
          ),
          UsageIngestSession,
          PrefetchHooks Function()
        > {
  $$UsageIngestSessionsTableTableManager(
    _$UsageDatabase db,
    $UsageIngestSessionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UsageIngestSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UsageIngestSessionsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$UsageIngestSessionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> sessionId = const Value.absent(),
                Value<int> maxSequence = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UsageIngestSessionsCompanion(
                sessionId: sessionId,
                maxSequence: maxSequence,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String sessionId,
                required int maxSequence,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => UsageIngestSessionsCompanion.insert(
                sessionId: sessionId,
                maxSequence: maxSequence,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UsageIngestSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$UsageDatabase,
      $UsageIngestSessionsTable,
      UsageIngestSession,
      $$UsageIngestSessionsTableFilterComposer,
      $$UsageIngestSessionsTableOrderingComposer,
      $$UsageIngestSessionsTableAnnotationComposer,
      $$UsageIngestSessionsTableCreateCompanionBuilder,
      $$UsageIngestSessionsTableUpdateCompanionBuilder,
      (
        UsageIngestSession,
        BaseReferences<
          _$UsageDatabase,
          $UsageIngestSessionsTable,
          UsageIngestSession
        >,
      ),
      UsageIngestSession,
      PrefetchHooks Function()
    >;
typedef $$UsageDailyTotalsTableCreateCompanionBuilder =
    UsageDailyTotalsCompanion Function({
      required String day,
      required String route,
      Value<int> upload,
      Value<int> download,
      Value<int> connections,
      Value<int> rowid,
    });
typedef $$UsageDailyTotalsTableUpdateCompanionBuilder =
    UsageDailyTotalsCompanion Function({
      Value<String> day,
      Value<String> route,
      Value<int> upload,
      Value<int> download,
      Value<int> connections,
      Value<int> rowid,
    });

class $$UsageDailyTotalsTableFilterComposer
    extends Composer<_$UsageDatabase, $UsageDailyTotalsTable> {
  $$UsageDailyTotalsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get route => $composableBuilder(
    column: $table.route,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get upload => $composableBuilder(
    column: $table.upload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get download => $composableBuilder(
    column: $table.download,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get connections => $composableBuilder(
    column: $table.connections,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UsageDailyTotalsTableOrderingComposer
    extends Composer<_$UsageDatabase, $UsageDailyTotalsTable> {
  $$UsageDailyTotalsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get route => $composableBuilder(
    column: $table.route,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get upload => $composableBuilder(
    column: $table.upload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get download => $composableBuilder(
    column: $table.download,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get connections => $composableBuilder(
    column: $table.connections,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UsageDailyTotalsTableAnnotationComposer
    extends Composer<_$UsageDatabase, $UsageDailyTotalsTable> {
  $$UsageDailyTotalsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get day =>
      $composableBuilder(column: $table.day, builder: (column) => column);

  GeneratedColumn<String> get route =>
      $composableBuilder(column: $table.route, builder: (column) => column);

  GeneratedColumn<int> get upload =>
      $composableBuilder(column: $table.upload, builder: (column) => column);

  GeneratedColumn<int> get download =>
      $composableBuilder(column: $table.download, builder: (column) => column);

  GeneratedColumn<int> get connections => $composableBuilder(
    column: $table.connections,
    builder: (column) => column,
  );
}

class $$UsageDailyTotalsTableTableManager
    extends
        RootTableManager<
          _$UsageDatabase,
          $UsageDailyTotalsTable,
          UsageDailyTotal,
          $$UsageDailyTotalsTableFilterComposer,
          $$UsageDailyTotalsTableOrderingComposer,
          $$UsageDailyTotalsTableAnnotationComposer,
          $$UsageDailyTotalsTableCreateCompanionBuilder,
          $$UsageDailyTotalsTableUpdateCompanionBuilder,
          (
            UsageDailyTotal,
            BaseReferences<
              _$UsageDatabase,
              $UsageDailyTotalsTable,
              UsageDailyTotal
            >,
          ),
          UsageDailyTotal,
          PrefetchHooks Function()
        > {
  $$UsageDailyTotalsTableTableManager(
    _$UsageDatabase db,
    $UsageDailyTotalsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UsageDailyTotalsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UsageDailyTotalsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UsageDailyTotalsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> day = const Value.absent(),
                Value<String> route = const Value.absent(),
                Value<int> upload = const Value.absent(),
                Value<int> download = const Value.absent(),
                Value<int> connections = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UsageDailyTotalsCompanion(
                day: day,
                route: route,
                upload: upload,
                download: download,
                connections: connections,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String day,
                required String route,
                Value<int> upload = const Value.absent(),
                Value<int> download = const Value.absent(),
                Value<int> connections = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UsageDailyTotalsCompanion.insert(
                day: day,
                route: route,
                upload: upload,
                download: download,
                connections: connections,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UsageDailyTotalsTableProcessedTableManager =
    ProcessedTableManager<
      _$UsageDatabase,
      $UsageDailyTotalsTable,
      UsageDailyTotal,
      $$UsageDailyTotalsTableFilterComposer,
      $$UsageDailyTotalsTableOrderingComposer,
      $$UsageDailyTotalsTableAnnotationComposer,
      $$UsageDailyTotalsTableCreateCompanionBuilder,
      $$UsageDailyTotalsTableUpdateCompanionBuilder,
      (
        UsageDailyTotal,
        BaseReferences<
          _$UsageDatabase,
          $UsageDailyTotalsTable,
          UsageDailyTotal
        >,
      ),
      UsageDailyTotal,
      PrefetchHooks Function()
    >;
typedef $$UsageProfileLabelsTableCreateCompanionBuilder =
    UsageProfileLabelsCompanion Function({
      required String profileKey,
      Value<String> label,
      required int lastSeenMinute,
      Value<int> rowid,
    });
typedef $$UsageProfileLabelsTableUpdateCompanionBuilder =
    UsageProfileLabelsCompanion Function({
      Value<String> profileKey,
      Value<String> label,
      Value<int> lastSeenMinute,
      Value<int> rowid,
    });

class $$UsageProfileLabelsTableFilterComposer
    extends Composer<_$UsageDatabase, $UsageProfileLabelsTable> {
  $$UsageProfileLabelsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get profileKey => $composableBuilder(
    column: $table.profileKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastSeenMinute => $composableBuilder(
    column: $table.lastSeenMinute,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UsageProfileLabelsTableOrderingComposer
    extends Composer<_$UsageDatabase, $UsageProfileLabelsTable> {
  $$UsageProfileLabelsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get profileKey => $composableBuilder(
    column: $table.profileKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastSeenMinute => $composableBuilder(
    column: $table.lastSeenMinute,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UsageProfileLabelsTableAnnotationComposer
    extends Composer<_$UsageDatabase, $UsageProfileLabelsTable> {
  $$UsageProfileLabelsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get profileKey => $composableBuilder(
    column: $table.profileKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<int> get lastSeenMinute => $composableBuilder(
    column: $table.lastSeenMinute,
    builder: (column) => column,
  );
}

class $$UsageProfileLabelsTableTableManager
    extends
        RootTableManager<
          _$UsageDatabase,
          $UsageProfileLabelsTable,
          UsageProfileLabel,
          $$UsageProfileLabelsTableFilterComposer,
          $$UsageProfileLabelsTableOrderingComposer,
          $$UsageProfileLabelsTableAnnotationComposer,
          $$UsageProfileLabelsTableCreateCompanionBuilder,
          $$UsageProfileLabelsTableUpdateCompanionBuilder,
          (
            UsageProfileLabel,
            BaseReferences<
              _$UsageDatabase,
              $UsageProfileLabelsTable,
              UsageProfileLabel
            >,
          ),
          UsageProfileLabel,
          PrefetchHooks Function()
        > {
  $$UsageProfileLabelsTableTableManager(
    _$UsageDatabase db,
    $UsageProfileLabelsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UsageProfileLabelsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UsageProfileLabelsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UsageProfileLabelsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> profileKey = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<int> lastSeenMinute = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UsageProfileLabelsCompanion(
                profileKey: profileKey,
                label: label,
                lastSeenMinute: lastSeenMinute,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String profileKey,
                Value<String> label = const Value.absent(),
                required int lastSeenMinute,
                Value<int> rowid = const Value.absent(),
              }) => UsageProfileLabelsCompanion.insert(
                profileKey: profileKey,
                label: label,
                lastSeenMinute: lastSeenMinute,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UsageProfileLabelsTableProcessedTableManager =
    ProcessedTableManager<
      _$UsageDatabase,
      $UsageProfileLabelsTable,
      UsageProfileLabel,
      $$UsageProfileLabelsTableFilterComposer,
      $$UsageProfileLabelsTableOrderingComposer,
      $$UsageProfileLabelsTableAnnotationComposer,
      $$UsageProfileLabelsTableCreateCompanionBuilder,
      $$UsageProfileLabelsTableUpdateCompanionBuilder,
      (
        UsageProfileLabel,
        BaseReferences<
          _$UsageDatabase,
          $UsageProfileLabelsTable,
          UsageProfileLabel
        >,
      ),
      UsageProfileLabel,
      PrefetchHooks Function()
    >;
typedef $$UsageApplicationLabelsTableCreateCompanionBuilder =
    UsageApplicationLabelsCompanion Function({
      required String processPathKey,
      Value<String> label,
      required int lastSeenMinute,
      Value<int> rowid,
    });
typedef $$UsageApplicationLabelsTableUpdateCompanionBuilder =
    UsageApplicationLabelsCompanion Function({
      Value<String> processPathKey,
      Value<String> label,
      Value<int> lastSeenMinute,
      Value<int> rowid,
    });

class $$UsageApplicationLabelsTableFilterComposer
    extends Composer<_$UsageDatabase, $UsageApplicationLabelsTable> {
  $$UsageApplicationLabelsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get processPathKey => $composableBuilder(
    column: $table.processPathKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastSeenMinute => $composableBuilder(
    column: $table.lastSeenMinute,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UsageApplicationLabelsTableOrderingComposer
    extends Composer<_$UsageDatabase, $UsageApplicationLabelsTable> {
  $$UsageApplicationLabelsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get processPathKey => $composableBuilder(
    column: $table.processPathKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastSeenMinute => $composableBuilder(
    column: $table.lastSeenMinute,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UsageApplicationLabelsTableAnnotationComposer
    extends Composer<_$UsageDatabase, $UsageApplicationLabelsTable> {
  $$UsageApplicationLabelsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get processPathKey => $composableBuilder(
    column: $table.processPathKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<int> get lastSeenMinute => $composableBuilder(
    column: $table.lastSeenMinute,
    builder: (column) => column,
  );
}

class $$UsageApplicationLabelsTableTableManager
    extends
        RootTableManager<
          _$UsageDatabase,
          $UsageApplicationLabelsTable,
          UsageApplicationLabel,
          $$UsageApplicationLabelsTableFilterComposer,
          $$UsageApplicationLabelsTableOrderingComposer,
          $$UsageApplicationLabelsTableAnnotationComposer,
          $$UsageApplicationLabelsTableCreateCompanionBuilder,
          $$UsageApplicationLabelsTableUpdateCompanionBuilder,
          (
            UsageApplicationLabel,
            BaseReferences<
              _$UsageDatabase,
              $UsageApplicationLabelsTable,
              UsageApplicationLabel
            >,
          ),
          UsageApplicationLabel,
          PrefetchHooks Function()
        > {
  $$UsageApplicationLabelsTableTableManager(
    _$UsageDatabase db,
    $UsageApplicationLabelsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UsageApplicationLabelsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$UsageApplicationLabelsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$UsageApplicationLabelsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> processPathKey = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<int> lastSeenMinute = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UsageApplicationLabelsCompanion(
                processPathKey: processPathKey,
                label: label,
                lastSeenMinute: lastSeenMinute,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String processPathKey,
                Value<String> label = const Value.absent(),
                required int lastSeenMinute,
                Value<int> rowid = const Value.absent(),
              }) => UsageApplicationLabelsCompanion.insert(
                processPathKey: processPathKey,
                label: label,
                lastSeenMinute: lastSeenMinute,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UsageApplicationLabelsTableProcessedTableManager =
    ProcessedTableManager<
      _$UsageDatabase,
      $UsageApplicationLabelsTable,
      UsageApplicationLabel,
      $$UsageApplicationLabelsTableFilterComposer,
      $$UsageApplicationLabelsTableOrderingComposer,
      $$UsageApplicationLabelsTableAnnotationComposer,
      $$UsageApplicationLabelsTableCreateCompanionBuilder,
      $$UsageApplicationLabelsTableUpdateCompanionBuilder,
      (
        UsageApplicationLabel,
        BaseReferences<
          _$UsageDatabase,
          $UsageApplicationLabelsTable,
          UsageApplicationLabel
        >,
      ),
      UsageApplicationLabel,
      PrefetchHooks Function()
    >;
typedef $$UsageQualityIntervalsTableCreateCompanionBuilder =
    UsageQualityIntervalsCompanion Function({
      required String sessionId,
      required int sequence,
      required int startMinute,
      required int endMinute,
      Value<int> rowid,
    });
typedef $$UsageQualityIntervalsTableUpdateCompanionBuilder =
    UsageQualityIntervalsCompanion Function({
      Value<String> sessionId,
      Value<int> sequence,
      Value<int> startMinute,
      Value<int> endMinute,
      Value<int> rowid,
    });

class $$UsageQualityIntervalsTableFilterComposer
    extends Composer<_$UsageDatabase, $UsageQualityIntervalsTable> {
  $$UsageQualityIntervalsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sequence => $composableBuilder(
    column: $table.sequence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startMinute => $composableBuilder(
    column: $table.startMinute,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endMinute => $composableBuilder(
    column: $table.endMinute,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UsageQualityIntervalsTableOrderingComposer
    extends Composer<_$UsageDatabase, $UsageQualityIntervalsTable> {
  $$UsageQualityIntervalsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sequence => $composableBuilder(
    column: $table.sequence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startMinute => $composableBuilder(
    column: $table.startMinute,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endMinute => $composableBuilder(
    column: $table.endMinute,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UsageQualityIntervalsTableAnnotationComposer
    extends Composer<_$UsageDatabase, $UsageQualityIntervalsTable> {
  $$UsageQualityIntervalsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<int> get sequence =>
      $composableBuilder(column: $table.sequence, builder: (column) => column);

  GeneratedColumn<int> get startMinute => $composableBuilder(
    column: $table.startMinute,
    builder: (column) => column,
  );

  GeneratedColumn<int> get endMinute =>
      $composableBuilder(column: $table.endMinute, builder: (column) => column);
}

class $$UsageQualityIntervalsTableTableManager
    extends
        RootTableManager<
          _$UsageDatabase,
          $UsageQualityIntervalsTable,
          UsageQualityInterval,
          $$UsageQualityIntervalsTableFilterComposer,
          $$UsageQualityIntervalsTableOrderingComposer,
          $$UsageQualityIntervalsTableAnnotationComposer,
          $$UsageQualityIntervalsTableCreateCompanionBuilder,
          $$UsageQualityIntervalsTableUpdateCompanionBuilder,
          (
            UsageQualityInterval,
            BaseReferences<
              _$UsageDatabase,
              $UsageQualityIntervalsTable,
              UsageQualityInterval
            >,
          ),
          UsageQualityInterval,
          PrefetchHooks Function()
        > {
  $$UsageQualityIntervalsTableTableManager(
    _$UsageDatabase db,
    $UsageQualityIntervalsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UsageQualityIntervalsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$UsageQualityIntervalsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$UsageQualityIntervalsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> sessionId = const Value.absent(),
                Value<int> sequence = const Value.absent(),
                Value<int> startMinute = const Value.absent(),
                Value<int> endMinute = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UsageQualityIntervalsCompanion(
                sessionId: sessionId,
                sequence: sequence,
                startMinute: startMinute,
                endMinute: endMinute,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String sessionId,
                required int sequence,
                required int startMinute,
                required int endMinute,
                Value<int> rowid = const Value.absent(),
              }) => UsageQualityIntervalsCompanion.insert(
                sessionId: sessionId,
                sequence: sequence,
                startMinute: startMinute,
                endMinute: endMinute,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UsageQualityIntervalsTableProcessedTableManager =
    ProcessedTableManager<
      _$UsageDatabase,
      $UsageQualityIntervalsTable,
      UsageQualityInterval,
      $$UsageQualityIntervalsTableFilterComposer,
      $$UsageQualityIntervalsTableOrderingComposer,
      $$UsageQualityIntervalsTableAnnotationComposer,
      $$UsageQualityIntervalsTableCreateCompanionBuilder,
      $$UsageQualityIntervalsTableUpdateCompanionBuilder,
      (
        UsageQualityInterval,
        BaseReferences<
          _$UsageDatabase,
          $UsageQualityIntervalsTable,
          UsageQualityInterval
        >,
      ),
      UsageQualityInterval,
      PrefetchHooks Function()
    >;
typedef $$UsageSettingsTableCreateCompanionBuilder =
    UsageSettingsCompanion Function({
      Value<int> id,
      Value<bool> enabled,
      Value<bool> consentAccepted,
      required DateTime updatedAt,
      Value<DateTime?> lastCleanup,
      Value<int?> localTimezoneOffsetMinutes,
    });
typedef $$UsageSettingsTableUpdateCompanionBuilder =
    UsageSettingsCompanion Function({
      Value<int> id,
      Value<bool> enabled,
      Value<bool> consentAccepted,
      Value<DateTime> updatedAt,
      Value<DateTime?> lastCleanup,
      Value<int?> localTimezoneOffsetMinutes,
    });

class $$UsageSettingsTableFilterComposer
    extends Composer<_$UsageDatabase, $UsageSettingsTable> {
  $$UsageSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get consentAccepted => $composableBuilder(
    column: $table.consentAccepted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastCleanup => $composableBuilder(
    column: $table.lastCleanup,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get localTimezoneOffsetMinutes => $composableBuilder(
    column: $table.localTimezoneOffsetMinutes,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UsageSettingsTableOrderingComposer
    extends Composer<_$UsageDatabase, $UsageSettingsTable> {
  $$UsageSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get consentAccepted => $composableBuilder(
    column: $table.consentAccepted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastCleanup => $composableBuilder(
    column: $table.lastCleanup,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get localTimezoneOffsetMinutes => $composableBuilder(
    column: $table.localTimezoneOffsetMinutes,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UsageSettingsTableAnnotationComposer
    extends Composer<_$UsageDatabase, $UsageSettingsTable> {
  $$UsageSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<bool> get consentAccepted => $composableBuilder(
    column: $table.consentAccepted,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastCleanup => $composableBuilder(
    column: $table.lastCleanup,
    builder: (column) => column,
  );

  GeneratedColumn<int> get localTimezoneOffsetMinutes => $composableBuilder(
    column: $table.localTimezoneOffsetMinutes,
    builder: (column) => column,
  );
}

class $$UsageSettingsTableTableManager
    extends
        RootTableManager<
          _$UsageDatabase,
          $UsageSettingsTable,
          UsageSetting,
          $$UsageSettingsTableFilterComposer,
          $$UsageSettingsTableOrderingComposer,
          $$UsageSettingsTableAnnotationComposer,
          $$UsageSettingsTableCreateCompanionBuilder,
          $$UsageSettingsTableUpdateCompanionBuilder,
          (
            UsageSetting,
            BaseReferences<_$UsageDatabase, $UsageSettingsTable, UsageSetting>,
          ),
          UsageSetting,
          PrefetchHooks Function()
        > {
  $$UsageSettingsTableTableManager(
    _$UsageDatabase db,
    $UsageSettingsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UsageSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UsageSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UsageSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<bool> consentAccepted = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> lastCleanup = const Value.absent(),
                Value<int?> localTimezoneOffsetMinutes = const Value.absent(),
              }) => UsageSettingsCompanion(
                id: id,
                enabled: enabled,
                consentAccepted: consentAccepted,
                updatedAt: updatedAt,
                lastCleanup: lastCleanup,
                localTimezoneOffsetMinutes: localTimezoneOffsetMinutes,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<bool> consentAccepted = const Value.absent(),
                required DateTime updatedAt,
                Value<DateTime?> lastCleanup = const Value.absent(),
                Value<int?> localTimezoneOffsetMinutes = const Value.absent(),
              }) => UsageSettingsCompanion.insert(
                id: id,
                enabled: enabled,
                consentAccepted: consentAccepted,
                updatedAt: updatedAt,
                lastCleanup: lastCleanup,
                localTimezoneOffsetMinutes: localTimezoneOffsetMinutes,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UsageSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$UsageDatabase,
      $UsageSettingsTable,
      UsageSetting,
      $$UsageSettingsTableFilterComposer,
      $$UsageSettingsTableOrderingComposer,
      $$UsageSettingsTableAnnotationComposer,
      $$UsageSettingsTableCreateCompanionBuilder,
      $$UsageSettingsTableUpdateCompanionBuilder,
      (
        UsageSetting,
        BaseReferences<_$UsageDatabase, $UsageSettingsTable, UsageSetting>,
      ),
      UsageSetting,
      PrefetchHooks Function()
    >;

class $UsageDatabaseManager {
  final _$UsageDatabase _db;
  $UsageDatabaseManager(this._db);
  $$UsageBucketsTableTableManager get usageBuckets =>
      $$UsageBucketsTableTableManager(_db, _db.usageBuckets);
  $$UsageIngestSessionsTableTableManager get usageIngestSessions =>
      $$UsageIngestSessionsTableTableManager(_db, _db.usageIngestSessions);
  $$UsageDailyTotalsTableTableManager get usageDailyTotals =>
      $$UsageDailyTotalsTableTableManager(_db, _db.usageDailyTotals);
  $$UsageProfileLabelsTableTableManager get usageProfileLabels =>
      $$UsageProfileLabelsTableTableManager(_db, _db.usageProfileLabels);
  $$UsageApplicationLabelsTableTableManager get usageApplicationLabels =>
      $$UsageApplicationLabelsTableTableManager(
        _db,
        _db.usageApplicationLabels,
      );
  $$UsageQualityIntervalsTableTableManager get usageQualityIntervals =>
      $$UsageQualityIntervalsTableTableManager(_db, _db.usageQualityIntervals);
  $$UsageSettingsTableTableManager get usageSettings =>
      $$UsageSettingsTableTableManager(_db, _db.usageSettings);
}
