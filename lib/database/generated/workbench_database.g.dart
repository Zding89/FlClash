// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../workbench_database.dart';

// ignore_for_file: type=lint
class $WorkbenchRecordsTable extends WorkbenchRecords
    with TableInfo<$WorkbenchRecordsTable, WorkbenchRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkbenchRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sectionMeta = const VerificationMeta(
    'section',
  );
  @override
  late final GeneratedColumn<String> section = GeneratedColumn<String>(
    'section',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [section, payload, revision];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'workbench_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<WorkbenchRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('section')) {
      context.handle(
        _sectionMeta,
        section.isAcceptableOrUnknown(data['section']!, _sectionMeta),
      );
    } else if (isInserting) {
      context.missing(_sectionMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {section};
  @override
  WorkbenchRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorkbenchRecord(
      section: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}section'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
    );
  }

  @override
  $WorkbenchRecordsTable createAlias(String alias) {
    return $WorkbenchRecordsTable(attachedDatabase, alias);
  }
}

class WorkbenchRecord extends DataClass implements Insertable<WorkbenchRecord> {
  final String section;
  final String payload;
  final int revision;
  const WorkbenchRecord({
    required this.section,
    required this.payload,
    required this.revision,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['section'] = Variable<String>(section);
    map['payload'] = Variable<String>(payload);
    map['revision'] = Variable<int>(revision);
    return map;
  }

  WorkbenchRecordsCompanion toCompanion(bool nullToAbsent) {
    return WorkbenchRecordsCompanion(
      section: Value(section),
      payload: Value(payload),
      revision: Value(revision),
    );
  }

  factory WorkbenchRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorkbenchRecord(
      section: serializer.fromJson<String>(json['section']),
      payload: serializer.fromJson<String>(json['payload']),
      revision: serializer.fromJson<int>(json['revision']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'section': serializer.toJson<String>(section),
      'payload': serializer.toJson<String>(payload),
      'revision': serializer.toJson<int>(revision),
    };
  }

  WorkbenchRecord copyWith({String? section, String? payload, int? revision}) =>
      WorkbenchRecord(
        section: section ?? this.section,
        payload: payload ?? this.payload,
        revision: revision ?? this.revision,
      );
  WorkbenchRecord copyWithCompanion(WorkbenchRecordsCompanion data) {
    return WorkbenchRecord(
      section: data.section.present ? data.section.value : this.section,
      payload: data.payload.present ? data.payload.value : this.payload,
      revision: data.revision.present ? data.revision.value : this.revision,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorkbenchRecord(')
          ..write('section: $section, ')
          ..write('payload: $payload, ')
          ..write('revision: $revision')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(section, payload, revision);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkbenchRecord &&
          other.section == this.section &&
          other.payload == this.payload &&
          other.revision == this.revision);
}

class WorkbenchRecordsCompanion extends UpdateCompanion<WorkbenchRecord> {
  final Value<String> section;
  final Value<String> payload;
  final Value<int> revision;
  final Value<int> rowid;
  const WorkbenchRecordsCompanion({
    this.section = const Value.absent(),
    this.payload = const Value.absent(),
    this.revision = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WorkbenchRecordsCompanion.insert({
    required String section,
    required String payload,
    this.revision = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : section = Value(section),
       payload = Value(payload);
  static Insertable<WorkbenchRecord> custom({
    Expression<String>? section,
    Expression<String>? payload,
    Expression<int>? revision,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (section != null) 'section': section,
      if (payload != null) 'payload': payload,
      if (revision != null) 'revision': revision,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WorkbenchRecordsCompanion copyWith({
    Value<String>? section,
    Value<String>? payload,
    Value<int>? revision,
    Value<int>? rowid,
  }) {
    return WorkbenchRecordsCompanion(
      section: section ?? this.section,
      payload: payload ?? this.payload,
      revision: revision ?? this.revision,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (section.present) {
      map['section'] = Variable<String>(section.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorkbenchRecordsCompanion(')
          ..write('section: $section, ')
          ..write('payload: $payload, ')
          ..write('revision: $revision, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WorkbenchChangesTable extends WorkbenchChanges
    with TableInfo<$WorkbenchChangesTable, WorkbenchChange> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkbenchChangesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _summaryMeta = const VerificationMeta(
    'summary',
  );
  @override
  late final GeneratedColumn<String> summary = GeneratedColumn<String>(
    'summary',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _highRiskMeta = const VerificationMeta(
    'highRisk',
  );
  @override
  late final GeneratedColumn<bool> highRisk = GeneratedColumn<bool>(
    'high_risk',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("high_risk" IN (0, 1))',
    ),
  );
  static const VerificationMeta _fingerprintMeta = const VerificationMeta(
    'fingerprint',
  );
  @override
  late final GeneratedColumn<String> fingerprint = GeneratedColumn<String>(
    'fingerprint',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _beforePayloadMeta = const VerificationMeta(
    'beforePayload',
  );
  @override
  late final GeneratedColumn<String> beforePayload = GeneratedColumn<String>(
    'before_payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _afterPayloadMeta = const VerificationMeta(
    'afterPayload',
  );
  @override
  late final GeneratedColumn<String> afterPayload = GeneratedColumn<String>(
    'after_payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _errorMeta = const VerificationMeta('error');
  @override
  late final GeneratedColumn<String> error = GeneratedColumn<String>(
    'error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _expiresAtMeta = const VerificationMeta(
    'expiresAt',
  );
  @override
  late final GeneratedColumn<int> expiresAt = GeneratedColumn<int>(
    'expires_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    category,
    summary,
    status,
    highRisk,
    fingerprint,
    beforePayload,
    afterPayload,
    error,
    createdAt,
    expiresAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'workbench_changes';
  @override
  VerificationContext validateIntegrity(
    Insertable<WorkbenchChange> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('summary')) {
      context.handle(
        _summaryMeta,
        summary.isAcceptableOrUnknown(data['summary']!, _summaryMeta),
      );
    } else if (isInserting) {
      context.missing(_summaryMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('high_risk')) {
      context.handle(
        _highRiskMeta,
        highRisk.isAcceptableOrUnknown(data['high_risk']!, _highRiskMeta),
      );
    } else if (isInserting) {
      context.missing(_highRiskMeta);
    }
    if (data.containsKey('fingerprint')) {
      context.handle(
        _fingerprintMeta,
        fingerprint.isAcceptableOrUnknown(
          data['fingerprint']!,
          _fingerprintMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_fingerprintMeta);
    }
    if (data.containsKey('before_payload')) {
      context.handle(
        _beforePayloadMeta,
        beforePayload.isAcceptableOrUnknown(
          data['before_payload']!,
          _beforePayloadMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_beforePayloadMeta);
    }
    if (data.containsKey('after_payload')) {
      context.handle(
        _afterPayloadMeta,
        afterPayload.isAcceptableOrUnknown(
          data['after_payload']!,
          _afterPayloadMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_afterPayloadMeta);
    }
    if (data.containsKey('error')) {
      context.handle(
        _errorMeta,
        error.isAcceptableOrUnknown(data['error']!, _errorMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('expires_at')) {
      context.handle(
        _expiresAtMeta,
        expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta),
      );
    } else if (isInserting) {
      context.missing(_expiresAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WorkbenchChange map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorkbenchChange(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      summary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      highRisk: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}high_risk'],
      )!,
      fingerprint: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fingerprint'],
      )!,
      beforePayload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}before_payload'],
      )!,
      afterPayload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}after_payload'],
      )!,
      error: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      expiresAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}expires_at'],
      )!,
    );
  }

  @override
  $WorkbenchChangesTable createAlias(String alias) {
    return $WorkbenchChangesTable(attachedDatabase, alias);
  }
}

class WorkbenchChange extends DataClass implements Insertable<WorkbenchChange> {
  final String id;
  final String category;
  final String summary;
  final String status;
  final bool highRisk;
  final String fingerprint;
  final String beforePayload;
  final String afterPayload;
  final String? error;
  final int createdAt;
  final int expiresAt;
  const WorkbenchChange({
    required this.id,
    required this.category,
    required this.summary,
    required this.status,
    required this.highRisk,
    required this.fingerprint,
    required this.beforePayload,
    required this.afterPayload,
    this.error,
    required this.createdAt,
    required this.expiresAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['category'] = Variable<String>(category);
    map['summary'] = Variable<String>(summary);
    map['status'] = Variable<String>(status);
    map['high_risk'] = Variable<bool>(highRisk);
    map['fingerprint'] = Variable<String>(fingerprint);
    map['before_payload'] = Variable<String>(beforePayload);
    map['after_payload'] = Variable<String>(afterPayload);
    if (!nullToAbsent || error != null) {
      map['error'] = Variable<String>(error);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['expires_at'] = Variable<int>(expiresAt);
    return map;
  }

  WorkbenchChangesCompanion toCompanion(bool nullToAbsent) {
    return WorkbenchChangesCompanion(
      id: Value(id),
      category: Value(category),
      summary: Value(summary),
      status: Value(status),
      highRisk: Value(highRisk),
      fingerprint: Value(fingerprint),
      beforePayload: Value(beforePayload),
      afterPayload: Value(afterPayload),
      error: error == null && nullToAbsent
          ? const Value.absent()
          : Value(error),
      createdAt: Value(createdAt),
      expiresAt: Value(expiresAt),
    );
  }

  factory WorkbenchChange.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorkbenchChange(
      id: serializer.fromJson<String>(json['id']),
      category: serializer.fromJson<String>(json['category']),
      summary: serializer.fromJson<String>(json['summary']),
      status: serializer.fromJson<String>(json['status']),
      highRisk: serializer.fromJson<bool>(json['highRisk']),
      fingerprint: serializer.fromJson<String>(json['fingerprint']),
      beforePayload: serializer.fromJson<String>(json['beforePayload']),
      afterPayload: serializer.fromJson<String>(json['afterPayload']),
      error: serializer.fromJson<String?>(json['error']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      expiresAt: serializer.fromJson<int>(json['expiresAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'category': serializer.toJson<String>(category),
      'summary': serializer.toJson<String>(summary),
      'status': serializer.toJson<String>(status),
      'highRisk': serializer.toJson<bool>(highRisk),
      'fingerprint': serializer.toJson<String>(fingerprint),
      'beforePayload': serializer.toJson<String>(beforePayload),
      'afterPayload': serializer.toJson<String>(afterPayload),
      'error': serializer.toJson<String?>(error),
      'createdAt': serializer.toJson<int>(createdAt),
      'expiresAt': serializer.toJson<int>(expiresAt),
    };
  }

  WorkbenchChange copyWith({
    String? id,
    String? category,
    String? summary,
    String? status,
    bool? highRisk,
    String? fingerprint,
    String? beforePayload,
    String? afterPayload,
    Value<String?> error = const Value.absent(),
    int? createdAt,
    int? expiresAt,
  }) => WorkbenchChange(
    id: id ?? this.id,
    category: category ?? this.category,
    summary: summary ?? this.summary,
    status: status ?? this.status,
    highRisk: highRisk ?? this.highRisk,
    fingerprint: fingerprint ?? this.fingerprint,
    beforePayload: beforePayload ?? this.beforePayload,
    afterPayload: afterPayload ?? this.afterPayload,
    error: error.present ? error.value : this.error,
    createdAt: createdAt ?? this.createdAt,
    expiresAt: expiresAt ?? this.expiresAt,
  );
  WorkbenchChange copyWithCompanion(WorkbenchChangesCompanion data) {
    return WorkbenchChange(
      id: data.id.present ? data.id.value : this.id,
      category: data.category.present ? data.category.value : this.category,
      summary: data.summary.present ? data.summary.value : this.summary,
      status: data.status.present ? data.status.value : this.status,
      highRisk: data.highRisk.present ? data.highRisk.value : this.highRisk,
      fingerprint: data.fingerprint.present
          ? data.fingerprint.value
          : this.fingerprint,
      beforePayload: data.beforePayload.present
          ? data.beforePayload.value
          : this.beforePayload,
      afterPayload: data.afterPayload.present
          ? data.afterPayload.value
          : this.afterPayload,
      error: data.error.present ? data.error.value : this.error,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorkbenchChange(')
          ..write('id: $id, ')
          ..write('category: $category, ')
          ..write('summary: $summary, ')
          ..write('status: $status, ')
          ..write('highRisk: $highRisk, ')
          ..write('fingerprint: $fingerprint, ')
          ..write('beforePayload: $beforePayload, ')
          ..write('afterPayload: $afterPayload, ')
          ..write('error: $error, ')
          ..write('createdAt: $createdAt, ')
          ..write('expiresAt: $expiresAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    category,
    summary,
    status,
    highRisk,
    fingerprint,
    beforePayload,
    afterPayload,
    error,
    createdAt,
    expiresAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkbenchChange &&
          other.id == this.id &&
          other.category == this.category &&
          other.summary == this.summary &&
          other.status == this.status &&
          other.highRisk == this.highRisk &&
          other.fingerprint == this.fingerprint &&
          other.beforePayload == this.beforePayload &&
          other.afterPayload == this.afterPayload &&
          other.error == this.error &&
          other.createdAt == this.createdAt &&
          other.expiresAt == this.expiresAt);
}

class WorkbenchChangesCompanion extends UpdateCompanion<WorkbenchChange> {
  final Value<String> id;
  final Value<String> category;
  final Value<String> summary;
  final Value<String> status;
  final Value<bool> highRisk;
  final Value<String> fingerprint;
  final Value<String> beforePayload;
  final Value<String> afterPayload;
  final Value<String?> error;
  final Value<int> createdAt;
  final Value<int> expiresAt;
  final Value<int> rowid;
  const WorkbenchChangesCompanion({
    this.id = const Value.absent(),
    this.category = const Value.absent(),
    this.summary = const Value.absent(),
    this.status = const Value.absent(),
    this.highRisk = const Value.absent(),
    this.fingerprint = const Value.absent(),
    this.beforePayload = const Value.absent(),
    this.afterPayload = const Value.absent(),
    this.error = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WorkbenchChangesCompanion.insert({
    required String id,
    required String category,
    required String summary,
    required String status,
    required bool highRisk,
    required String fingerprint,
    required String beforePayload,
    required String afterPayload,
    this.error = const Value.absent(),
    required int createdAt,
    required int expiresAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       category = Value(category),
       summary = Value(summary),
       status = Value(status),
       highRisk = Value(highRisk),
       fingerprint = Value(fingerprint),
       beforePayload = Value(beforePayload),
       afterPayload = Value(afterPayload),
       createdAt = Value(createdAt),
       expiresAt = Value(expiresAt);
  static Insertable<WorkbenchChange> custom({
    Expression<String>? id,
    Expression<String>? category,
    Expression<String>? summary,
    Expression<String>? status,
    Expression<bool>? highRisk,
    Expression<String>? fingerprint,
    Expression<String>? beforePayload,
    Expression<String>? afterPayload,
    Expression<String>? error,
    Expression<int>? createdAt,
    Expression<int>? expiresAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (category != null) 'category': category,
      if (summary != null) 'summary': summary,
      if (status != null) 'status': status,
      if (highRisk != null) 'high_risk': highRisk,
      if (fingerprint != null) 'fingerprint': fingerprint,
      if (beforePayload != null) 'before_payload': beforePayload,
      if (afterPayload != null) 'after_payload': afterPayload,
      if (error != null) 'error': error,
      if (createdAt != null) 'created_at': createdAt,
      if (expiresAt != null) 'expires_at': expiresAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WorkbenchChangesCompanion copyWith({
    Value<String>? id,
    Value<String>? category,
    Value<String>? summary,
    Value<String>? status,
    Value<bool>? highRisk,
    Value<String>? fingerprint,
    Value<String>? beforePayload,
    Value<String>? afterPayload,
    Value<String?>? error,
    Value<int>? createdAt,
    Value<int>? expiresAt,
    Value<int>? rowid,
  }) {
    return WorkbenchChangesCompanion(
      id: id ?? this.id,
      category: category ?? this.category,
      summary: summary ?? this.summary,
      status: status ?? this.status,
      highRisk: highRisk ?? this.highRisk,
      fingerprint: fingerprint ?? this.fingerprint,
      beforePayload: beforePayload ?? this.beforePayload,
      afterPayload: afterPayload ?? this.afterPayload,
      error: error ?? this.error,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (summary.present) {
      map['summary'] = Variable<String>(summary.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (highRisk.present) {
      map['high_risk'] = Variable<bool>(highRisk.value);
    }
    if (fingerprint.present) {
      map['fingerprint'] = Variable<String>(fingerprint.value);
    }
    if (beforePayload.present) {
      map['before_payload'] = Variable<String>(beforePayload.value);
    }
    if (afterPayload.present) {
      map['after_payload'] = Variable<String>(afterPayload.value);
    }
    if (error.present) {
      map['error'] = Variable<String>(error.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<int>(expiresAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorkbenchChangesCompanion(')
          ..write('id: $id, ')
          ..write('category: $category, ')
          ..write('summary: $summary, ')
          ..write('status: $status, ')
          ..write('highRisk: $highRisk, ')
          ..write('fingerprint: $fingerprint, ')
          ..write('beforePayload: $beforePayload, ')
          ..write('afterPayload: $afterPayload, ')
          ..write('error: $error, ')
          ..write('createdAt: $createdAt, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WorkbenchSourceCachesTable extends WorkbenchSourceCaches
    with TableInfo<$WorkbenchSourceCachesTable, WorkbenchSourceCache> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkbenchSourceCachesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<int> profileId = GeneratedColumn<int>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _digestMeta = const VerificationMeta('digest');
  @override
  late final GeneratedColumn<String> digest = GeneratedColumn<String>(
    'digest',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _observedAtMeta = const VerificationMeta(
    'observedAt',
  );
  @override
  late final GeneratedColumn<int> observedAt = GeneratedColumn<int>(
    'observed_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    profileId,
    payload,
    digest,
    observedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'workbench_source_caches';
  @override
  VerificationContext validateIntegrity(
    Insertable<WorkbenchSourceCache> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('digest')) {
      context.handle(
        _digestMeta,
        digest.isAcceptableOrUnknown(data['digest']!, _digestMeta),
      );
    } else if (isInserting) {
      context.missing(_digestMeta);
    }
    if (data.containsKey('observed_at')) {
      context.handle(
        _observedAtMeta,
        observedAt.isAcceptableOrUnknown(data['observed_at']!, _observedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_observedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {profileId};
  @override
  WorkbenchSourceCache map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorkbenchSourceCache(
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}profile_id'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      digest: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}digest'],
      )!,
      observedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}observed_at'],
      )!,
    );
  }

  @override
  $WorkbenchSourceCachesTable createAlias(String alias) {
    return $WorkbenchSourceCachesTable(attachedDatabase, alias);
  }
}

class WorkbenchSourceCache extends DataClass
    implements Insertable<WorkbenchSourceCache> {
  final int profileId;
  final String payload;
  final String digest;
  final int observedAt;
  const WorkbenchSourceCache({
    required this.profileId,
    required this.payload,
    required this.digest,
    required this.observedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['profile_id'] = Variable<int>(profileId);
    map['payload'] = Variable<String>(payload);
    map['digest'] = Variable<String>(digest);
    map['observed_at'] = Variable<int>(observedAt);
    return map;
  }

  WorkbenchSourceCachesCompanion toCompanion(bool nullToAbsent) {
    return WorkbenchSourceCachesCompanion(
      profileId: Value(profileId),
      payload: Value(payload),
      digest: Value(digest),
      observedAt: Value(observedAt),
    );
  }

  factory WorkbenchSourceCache.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorkbenchSourceCache(
      profileId: serializer.fromJson<int>(json['profileId']),
      payload: serializer.fromJson<String>(json['payload']),
      digest: serializer.fromJson<String>(json['digest']),
      observedAt: serializer.fromJson<int>(json['observedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'profileId': serializer.toJson<int>(profileId),
      'payload': serializer.toJson<String>(payload),
      'digest': serializer.toJson<String>(digest),
      'observedAt': serializer.toJson<int>(observedAt),
    };
  }

  WorkbenchSourceCache copyWith({
    int? profileId,
    String? payload,
    String? digest,
    int? observedAt,
  }) => WorkbenchSourceCache(
    profileId: profileId ?? this.profileId,
    payload: payload ?? this.payload,
    digest: digest ?? this.digest,
    observedAt: observedAt ?? this.observedAt,
  );
  WorkbenchSourceCache copyWithCompanion(WorkbenchSourceCachesCompanion data) {
    return WorkbenchSourceCache(
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      payload: data.payload.present ? data.payload.value : this.payload,
      digest: data.digest.present ? data.digest.value : this.digest,
      observedAt: data.observedAt.present
          ? data.observedAt.value
          : this.observedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorkbenchSourceCache(')
          ..write('profileId: $profileId, ')
          ..write('payload: $payload, ')
          ..write('digest: $digest, ')
          ..write('observedAt: $observedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(profileId, payload, digest, observedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkbenchSourceCache &&
          other.profileId == this.profileId &&
          other.payload == this.payload &&
          other.digest == this.digest &&
          other.observedAt == this.observedAt);
}

class WorkbenchSourceCachesCompanion
    extends UpdateCompanion<WorkbenchSourceCache> {
  final Value<int> profileId;
  final Value<String> payload;
  final Value<String> digest;
  final Value<int> observedAt;
  const WorkbenchSourceCachesCompanion({
    this.profileId = const Value.absent(),
    this.payload = const Value.absent(),
    this.digest = const Value.absent(),
    this.observedAt = const Value.absent(),
  });
  WorkbenchSourceCachesCompanion.insert({
    this.profileId = const Value.absent(),
    required String payload,
    required String digest,
    required int observedAt,
  }) : payload = Value(payload),
       digest = Value(digest),
       observedAt = Value(observedAt);
  static Insertable<WorkbenchSourceCache> custom({
    Expression<int>? profileId,
    Expression<String>? payload,
    Expression<String>? digest,
    Expression<int>? observedAt,
  }) {
    return RawValuesInsertable({
      if (profileId != null) 'profile_id': profileId,
      if (payload != null) 'payload': payload,
      if (digest != null) 'digest': digest,
      if (observedAt != null) 'observed_at': observedAt,
    });
  }

  WorkbenchSourceCachesCompanion copyWith({
    Value<int>? profileId,
    Value<String>? payload,
    Value<String>? digest,
    Value<int>? observedAt,
  }) {
    return WorkbenchSourceCachesCompanion(
      profileId: profileId ?? this.profileId,
      payload: payload ?? this.payload,
      digest: digest ?? this.digest,
      observedAt: observedAt ?? this.observedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (profileId.present) {
      map['profile_id'] = Variable<int>(profileId.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (digest.present) {
      map['digest'] = Variable<String>(digest.value);
    }
    if (observedAt.present) {
      map['observed_at'] = Variable<int>(observedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorkbenchSourceCachesCompanion(')
          ..write('profileId: $profileId, ')
          ..write('payload: $payload, ')
          ..write('digest: $digest, ')
          ..write('observedAt: $observedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$WorkbenchDatabase extends GeneratedDatabase {
  _$WorkbenchDatabase(QueryExecutor e) : super(e);
  $WorkbenchDatabaseManager get managers => $WorkbenchDatabaseManager(this);
  late final $WorkbenchRecordsTable workbenchRecords = $WorkbenchRecordsTable(
    this,
  );
  late final $WorkbenchChangesTable workbenchChanges = $WorkbenchChangesTable(
    this,
  );
  late final $WorkbenchSourceCachesTable workbenchSourceCaches =
      $WorkbenchSourceCachesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    workbenchRecords,
    workbenchChanges,
    workbenchSourceCaches,
  ];
}

typedef $$WorkbenchRecordsTableCreateCompanionBuilder =
    WorkbenchRecordsCompanion Function({
      required String section,
      required String payload,
      Value<int> revision,
      Value<int> rowid,
    });
typedef $$WorkbenchRecordsTableUpdateCompanionBuilder =
    WorkbenchRecordsCompanion Function({
      Value<String> section,
      Value<String> payload,
      Value<int> revision,
      Value<int> rowid,
    });

class $$WorkbenchRecordsTableFilterComposer
    extends Composer<_$WorkbenchDatabase, $WorkbenchRecordsTable> {
  $$WorkbenchRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get section => $composableBuilder(
    column: $table.section,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WorkbenchRecordsTableOrderingComposer
    extends Composer<_$WorkbenchDatabase, $WorkbenchRecordsTable> {
  $$WorkbenchRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get section => $composableBuilder(
    column: $table.section,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WorkbenchRecordsTableAnnotationComposer
    extends Composer<_$WorkbenchDatabase, $WorkbenchRecordsTable> {
  $$WorkbenchRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get section =>
      $composableBuilder(column: $table.section, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);
}

class $$WorkbenchRecordsTableTableManager
    extends
        RootTableManager<
          _$WorkbenchDatabase,
          $WorkbenchRecordsTable,
          WorkbenchRecord,
          $$WorkbenchRecordsTableFilterComposer,
          $$WorkbenchRecordsTableOrderingComposer,
          $$WorkbenchRecordsTableAnnotationComposer,
          $$WorkbenchRecordsTableCreateCompanionBuilder,
          $$WorkbenchRecordsTableUpdateCompanionBuilder,
          (
            WorkbenchRecord,
            BaseReferences<
              _$WorkbenchDatabase,
              $WorkbenchRecordsTable,
              WorkbenchRecord
            >,
          ),
          WorkbenchRecord,
          PrefetchHooks Function()
        > {
  $$WorkbenchRecordsTableTableManager(
    _$WorkbenchDatabase db,
    $WorkbenchRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorkbenchRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorkbenchRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WorkbenchRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> section = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorkbenchRecordsCompanion(
                section: section,
                payload: payload,
                revision: revision,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String section,
                required String payload,
                Value<int> revision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorkbenchRecordsCompanion.insert(
                section: section,
                payload: payload,
                revision: revision,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WorkbenchRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$WorkbenchDatabase,
      $WorkbenchRecordsTable,
      WorkbenchRecord,
      $$WorkbenchRecordsTableFilterComposer,
      $$WorkbenchRecordsTableOrderingComposer,
      $$WorkbenchRecordsTableAnnotationComposer,
      $$WorkbenchRecordsTableCreateCompanionBuilder,
      $$WorkbenchRecordsTableUpdateCompanionBuilder,
      (
        WorkbenchRecord,
        BaseReferences<
          _$WorkbenchDatabase,
          $WorkbenchRecordsTable,
          WorkbenchRecord
        >,
      ),
      WorkbenchRecord,
      PrefetchHooks Function()
    >;
typedef $$WorkbenchChangesTableCreateCompanionBuilder =
    WorkbenchChangesCompanion Function({
      required String id,
      required String category,
      required String summary,
      required String status,
      required bool highRisk,
      required String fingerprint,
      required String beforePayload,
      required String afterPayload,
      Value<String?> error,
      required int createdAt,
      required int expiresAt,
      Value<int> rowid,
    });
typedef $$WorkbenchChangesTableUpdateCompanionBuilder =
    WorkbenchChangesCompanion Function({
      Value<String> id,
      Value<String> category,
      Value<String> summary,
      Value<String> status,
      Value<bool> highRisk,
      Value<String> fingerprint,
      Value<String> beforePayload,
      Value<String> afterPayload,
      Value<String?> error,
      Value<int> createdAt,
      Value<int> expiresAt,
      Value<int> rowid,
    });

class $$WorkbenchChangesTableFilterComposer
    extends Composer<_$WorkbenchDatabase, $WorkbenchChangesTable> {
  $$WorkbenchChangesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get highRisk => $composableBuilder(
    column: $table.highRisk,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fingerprint => $composableBuilder(
    column: $table.fingerprint,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get beforePayload => $composableBuilder(
    column: $table.beforePayload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get afterPayload => $composableBuilder(
    column: $table.afterPayload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WorkbenchChangesTableOrderingComposer
    extends Composer<_$WorkbenchDatabase, $WorkbenchChangesTable> {
  $$WorkbenchChangesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get highRisk => $composableBuilder(
    column: $table.highRisk,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fingerprint => $composableBuilder(
    column: $table.fingerprint,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get beforePayload => $composableBuilder(
    column: $table.beforePayload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get afterPayload => $composableBuilder(
    column: $table.afterPayload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WorkbenchChangesTableAnnotationComposer
    extends Composer<_$WorkbenchDatabase, $WorkbenchChangesTable> {
  $$WorkbenchChangesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get summary =>
      $composableBuilder(column: $table.summary, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<bool> get highRisk =>
      $composableBuilder(column: $table.highRisk, builder: (column) => column);

  GeneratedColumn<String> get fingerprint => $composableBuilder(
    column: $table.fingerprint,
    builder: (column) => column,
  );

  GeneratedColumn<String> get beforePayload => $composableBuilder(
    column: $table.beforePayload,
    builder: (column) => column,
  );

  GeneratedColumn<String> get afterPayload => $composableBuilder(
    column: $table.afterPayload,
    builder: (column) => column,
  );

  GeneratedColumn<String> get error =>
      $composableBuilder(column: $table.error, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);
}

class $$WorkbenchChangesTableTableManager
    extends
        RootTableManager<
          _$WorkbenchDatabase,
          $WorkbenchChangesTable,
          WorkbenchChange,
          $$WorkbenchChangesTableFilterComposer,
          $$WorkbenchChangesTableOrderingComposer,
          $$WorkbenchChangesTableAnnotationComposer,
          $$WorkbenchChangesTableCreateCompanionBuilder,
          $$WorkbenchChangesTableUpdateCompanionBuilder,
          (
            WorkbenchChange,
            BaseReferences<
              _$WorkbenchDatabase,
              $WorkbenchChangesTable,
              WorkbenchChange
            >,
          ),
          WorkbenchChange,
          PrefetchHooks Function()
        > {
  $$WorkbenchChangesTableTableManager(
    _$WorkbenchDatabase db,
    $WorkbenchChangesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorkbenchChangesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorkbenchChangesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WorkbenchChangesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<String> summary = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<bool> highRisk = const Value.absent(),
                Value<String> fingerprint = const Value.absent(),
                Value<String> beforePayload = const Value.absent(),
                Value<String> afterPayload = const Value.absent(),
                Value<String?> error = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> expiresAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorkbenchChangesCompanion(
                id: id,
                category: category,
                summary: summary,
                status: status,
                highRisk: highRisk,
                fingerprint: fingerprint,
                beforePayload: beforePayload,
                afterPayload: afterPayload,
                error: error,
                createdAt: createdAt,
                expiresAt: expiresAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String category,
                required String summary,
                required String status,
                required bool highRisk,
                required String fingerprint,
                required String beforePayload,
                required String afterPayload,
                Value<String?> error = const Value.absent(),
                required int createdAt,
                required int expiresAt,
                Value<int> rowid = const Value.absent(),
              }) => WorkbenchChangesCompanion.insert(
                id: id,
                category: category,
                summary: summary,
                status: status,
                highRisk: highRisk,
                fingerprint: fingerprint,
                beforePayload: beforePayload,
                afterPayload: afterPayload,
                error: error,
                createdAt: createdAt,
                expiresAt: expiresAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WorkbenchChangesTableProcessedTableManager =
    ProcessedTableManager<
      _$WorkbenchDatabase,
      $WorkbenchChangesTable,
      WorkbenchChange,
      $$WorkbenchChangesTableFilterComposer,
      $$WorkbenchChangesTableOrderingComposer,
      $$WorkbenchChangesTableAnnotationComposer,
      $$WorkbenchChangesTableCreateCompanionBuilder,
      $$WorkbenchChangesTableUpdateCompanionBuilder,
      (
        WorkbenchChange,
        BaseReferences<
          _$WorkbenchDatabase,
          $WorkbenchChangesTable,
          WorkbenchChange
        >,
      ),
      WorkbenchChange,
      PrefetchHooks Function()
    >;
typedef $$WorkbenchSourceCachesTableCreateCompanionBuilder =
    WorkbenchSourceCachesCompanion Function({
      Value<int> profileId,
      required String payload,
      required String digest,
      required int observedAt,
    });
typedef $$WorkbenchSourceCachesTableUpdateCompanionBuilder =
    WorkbenchSourceCachesCompanion Function({
      Value<int> profileId,
      Value<String> payload,
      Value<String> digest,
      Value<int> observedAt,
    });

class $$WorkbenchSourceCachesTableFilterComposer
    extends Composer<_$WorkbenchDatabase, $WorkbenchSourceCachesTable> {
  $$WorkbenchSourceCachesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get digest => $composableBuilder(
    column: $table.digest,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get observedAt => $composableBuilder(
    column: $table.observedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WorkbenchSourceCachesTableOrderingComposer
    extends Composer<_$WorkbenchDatabase, $WorkbenchSourceCachesTable> {
  $$WorkbenchSourceCachesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get digest => $composableBuilder(
    column: $table.digest,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get observedAt => $composableBuilder(
    column: $table.observedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WorkbenchSourceCachesTableAnnotationComposer
    extends Composer<_$WorkbenchDatabase, $WorkbenchSourceCachesTable> {
  $$WorkbenchSourceCachesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<String> get digest =>
      $composableBuilder(column: $table.digest, builder: (column) => column);

  GeneratedColumn<int> get observedAt => $composableBuilder(
    column: $table.observedAt,
    builder: (column) => column,
  );
}

class $$WorkbenchSourceCachesTableTableManager
    extends
        RootTableManager<
          _$WorkbenchDatabase,
          $WorkbenchSourceCachesTable,
          WorkbenchSourceCache,
          $$WorkbenchSourceCachesTableFilterComposer,
          $$WorkbenchSourceCachesTableOrderingComposer,
          $$WorkbenchSourceCachesTableAnnotationComposer,
          $$WorkbenchSourceCachesTableCreateCompanionBuilder,
          $$WorkbenchSourceCachesTableUpdateCompanionBuilder,
          (
            WorkbenchSourceCache,
            BaseReferences<
              _$WorkbenchDatabase,
              $WorkbenchSourceCachesTable,
              WorkbenchSourceCache
            >,
          ),
          WorkbenchSourceCache,
          PrefetchHooks Function()
        > {
  $$WorkbenchSourceCachesTableTableManager(
    _$WorkbenchDatabase db,
    $WorkbenchSourceCachesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorkbenchSourceCachesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$WorkbenchSourceCachesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$WorkbenchSourceCachesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> profileId = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<String> digest = const Value.absent(),
                Value<int> observedAt = const Value.absent(),
              }) => WorkbenchSourceCachesCompanion(
                profileId: profileId,
                payload: payload,
                digest: digest,
                observedAt: observedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> profileId = const Value.absent(),
                required String payload,
                required String digest,
                required int observedAt,
              }) => WorkbenchSourceCachesCompanion.insert(
                profileId: profileId,
                payload: payload,
                digest: digest,
                observedAt: observedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WorkbenchSourceCachesTableProcessedTableManager =
    ProcessedTableManager<
      _$WorkbenchDatabase,
      $WorkbenchSourceCachesTable,
      WorkbenchSourceCache,
      $$WorkbenchSourceCachesTableFilterComposer,
      $$WorkbenchSourceCachesTableOrderingComposer,
      $$WorkbenchSourceCachesTableAnnotationComposer,
      $$WorkbenchSourceCachesTableCreateCompanionBuilder,
      $$WorkbenchSourceCachesTableUpdateCompanionBuilder,
      (
        WorkbenchSourceCache,
        BaseReferences<
          _$WorkbenchDatabase,
          $WorkbenchSourceCachesTable,
          WorkbenchSourceCache
        >,
      ),
      WorkbenchSourceCache,
      PrefetchHooks Function()
    >;

class $WorkbenchDatabaseManager {
  final _$WorkbenchDatabase _db;
  $WorkbenchDatabaseManager(this._db);
  $$WorkbenchRecordsTableTableManager get workbenchRecords =>
      $$WorkbenchRecordsTableTableManager(_db, _db.workbenchRecords);
  $$WorkbenchChangesTableTableManager get workbenchChanges =>
      $$WorkbenchChangesTableTableManager(_db, _db.workbenchChanges);
  $$WorkbenchSourceCachesTableTableManager get workbenchSourceCaches =>
      $$WorkbenchSourceCachesTableTableManager(_db, _db.workbenchSourceCaches);
}
