import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:fl_clash/common/path.dart';
import 'package:fl_clash/policy/models.dart';
import 'package:path/path.dart' as paths;

part 'generated/workbench_database.g.dart';

class WorkbenchRecords extends Table {
  TextColumn get section => text()();
  TextColumn get payload => text()();
  IntColumn get revision => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {section};
}

class WorkbenchChanges extends Table {
  TextColumn get id => text()();
  TextColumn get category => text()();
  TextColumn get summary => text()();
  TextColumn get status => text()();
  BoolColumn get highRisk => boolean()();
  TextColumn get fingerprint => text()();
  TextColumn get beforePayload => text()();
  TextColumn get afterPayload => text()();
  TextColumn get error => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get expiresAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class WorkbenchSourceCaches extends Table {
  IntColumn get profileId => integer()();
  TextColumn get payload => text()();
  TextColumn get digest => text()();
  IntColumn get observedAt => integer()();

  @override
  Set<Column> get primaryKey => {profileId};
}

@DriftDatabase(
  tables: [WorkbenchRecords, WorkbenchChanges, WorkbenchSourceCaches],
)
class WorkbenchDatabase extends _$WorkbenchDatabase {
  WorkbenchDatabase([QueryExecutor? executor])
    : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  static LazyDatabase _openConnection() => LazyDatabase(() async {
    final path = paths.join(await appPath.homeDirPath, 'workbench.sqlite');
    return NativeDatabase.createInBackground(File(path));
  });

  Future<Map<String, Object?>?> readSection(String section) async {
    final row = await (select(
      workbenchRecords,
    )..where((table) => table.section.equals(section))).getSingleOrNull();
    return row == null ? null : policyObject(jsonDecode(row.payload), section);
  }

  Stream<Map<String, Object?>?> watchSection(String section) =>
      (select(workbenchRecords)
            ..where((table) => table.section.equals(section)))
          .watchSingleOrNull()
          .map(
            (row) => row == null
                ? null
                : policyObject(jsonDecode(row.payload), section),
          );

  Future<void> writeSection(
    String section,
    Map<String, Object?> payload,
  ) async {
    await into(workbenchRecords).insertOnConflictUpdate(
      WorkbenchRecordsCompanion.insert(
        section: section,
        payload: jsonEncode(payload),
        revision: Value(
          payload['revision'] is int ? payload['revision'] as int : 0,
        ),
      ),
    );
  }

  Future<LocalPolicyDocument> readPolicies() async =>
      LocalPolicyDocument.fromJson(
        await readSection('policies') ?? const {},
      ).asStandalone();

  Stream<LocalPolicyDocument> watchPolicies() => watchSection('policies').map(
    (value) => LocalPolicyDocument.fromJson(value ?? const {}).asStandalone(),
  );

  Future<WorkbenchChange?> readChange(String id) => (select(
    workbenchChanges,
  )..where((table) => table.id.equals(id))).getSingleOrNull();

  Stream<List<WorkbenchChange>> watchChanges() =>
      (select(workbenchChanges)
            ..orderBy([(table) => OrderingTerm.desc(table.createdAt)])
            ..limit(100))
          .watch();

  Future<void> saveChange({
    required String id,
    required String category,
    required String summary,
    required bool highRisk,
    required String fingerprint,
    required Map<String, Object?> before,
    required Map<String, Object?> after,
    required int createdAt,
    required int expiresAt,
  }) async {
    await into(workbenchChanges).insert(
      WorkbenchChangesCompanion.insert(
        id: id,
        category: category,
        summary: summary,
        status: 'draft',
        highRisk: highRisk,
        fingerprint: fingerprint,
        beforePayload: jsonEncode(before),
        afterPayload: jsonEncode(after),
        createdAt: createdAt,
        expiresAt: expiresAt,
      ),
    );
  }

  Future<void> changeStatus(String id, String status, {String? error}) async {
    await (update(
      workbenchChanges,
    )..where((table) => table.id.equals(id))).write(
      WorkbenchChangesCompanion(status: Value(status), error: Value(error)),
    );
  }

  Future<List<WorkbenchChange>> interruptedChanges() =>
      (select(workbenchChanges)
            ..where(
              (table) =>
                  table.status.isIn(['committing', 'persisted', 'restoring']),
            )
            ..orderBy([(table) => OrderingTerm.asc(table.createdAt)]))
          .get();

  Future<List<WorkbenchChange>> recoveryChanges() =>
      (select(workbenchChanges)
            ..where((t) => t.status.equals('recovery_required'))
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .get();

  Future<Map<String, Object?>?> readSourceCache(int profileId) async {
    final row = await (select(
      workbenchSourceCaches,
    )..where((table) => table.profileId.equals(profileId))).getSingleOrNull();
    return row == null
        ? null
        : policyObject(jsonDecode(row.payload), 'sourceCache');
  }

  Future<void> saveSourceCache(
    int profileId,
    Map<String, Object?> payload,
  ) async {
    await into(workbenchSourceCaches).insertOnConflictUpdate(
      WorkbenchSourceCachesCompanion.insert(
        profileId: Value(profileId),
        payload: jsonEncode(payload),
        digest: policyDigest(payload),
        observedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Future<void> pruneChanges(DateTime now) async {
    final cutoff = now
        .subtract(const Duration(days: 30))
        .millisecondsSinceEpoch;
    await (delete(workbenchChanges)..where(
          (table) =>
              table.createdAt.isSmallerThanValue(cutoff) &
              table.status.isIn([
                'draft',
                'rejected',
                'failed',
                'restored',
                'superseded',
                'undone',
              ]),
        ))
        .go();
  }
}

final workbenchDatabase = WorkbenchDatabase();
