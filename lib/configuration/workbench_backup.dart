import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:fl_clash/ai/credentials.dart';
import 'package:fl_clash/ai/context.dart';
import 'package:fl_clash/ai/history.dart';
import 'package:fl_clash/ai/settings.dart';
import 'package:fl_clash/database/workbench_database.dart';
import 'package:fl_clash/policy/models.dart';

const _sections = {
  'policies',
  'ai',
  'aiCredentials',
  'aiConversations',
  'localBudgetHistory',
};
const _terminalStatuses = {
  'rejected',
  'failed',
  'restored',
  'superseded',
  'undone',
  'resolved',
};
const _statuses = {
  ..._terminalStatuses,
  'applied',
  'draft',
  'committing',
  'persisted',
  'restoring',
  'recovery_required',
};

final class WorkbenchBackup {
  WorkbenchBackup._(Map<String, Object?> value) : _encoded = jsonEncode(value);

  final String _encoded;

  Map<String, Object?> toJson() =>
      policyObject(jsonDecode(_encoded), 'workbench');

  static Future<WorkbenchBackup> parse(
    Object? value, {
    required Set<int> profileIds,
  }) async {
    _validateBounds(value);
    final encoded = jsonEncode(value);
    if (utf8.encode(encoded).length > 12 * 1024 * 1024) {
      throw const FormatException('Workbench backup exceeds 12 MiB');
    }
    final json = policyObject(jsonDecode(encoded), 'workbench');
    policyKeys(json, {'version', 'sections', 'changes'});
    if (policyInt(json, 'version') != 1) {
      throw const FormatException('Unsupported workbench backup version');
    }
    final sections = policyObject(json['sections'], 'sections');
    policyKeys(sections, _sections);
    if (sections.length != _sections.length) {
      throw const FormatException('Incomplete workbench backup sections');
    }
    final policies = LocalPolicyDocument.fromJson(
      policyObject(sections['policies'], 'policies'),
    ).asStandalone();
    _validateProfileReferences(policies, profileIds);
    final ai = AgentSettings.fromJson(policyObject(sections['ai'], 'ai'));
    if (ai.selectedConnectionId != null && ai.selected == null) {
      throw const FormatException('Missing selected AI connection');
    }
    final credentials = policyObject(
      sections['aiCredentials'],
      'aiCredentials',
    );
    final values = policyObject(credentials['values'], 'values');
    final credentialIds = ai.connections.map((c) => c.credentialId).toSet();
    if (values.keys.any((id) => !credentialIds.contains(id))) {
      throw const FormatException(
        'AI credentials refer to a missing connection',
      );
    }
    if (!values.keys.toSet().containsAll(credentialIds)) {
      throw const FormatException('Missing AI credentials in backup');
    }
    policyStrings(credentials, 'legacyAttempted', maximum: 256);
    await EncryptedConfigAgentCredentialStore.validateSection(credentials);
    credentials['legacyAttempted'] = credentialIds.toList();
    final changes = policyItems(
      json,
      'changes',
      _validateChange,
      maximum: 3000,
    );
    final changeIds = changes.map((change) => change['id'] as String).toSet();
    if (changeIds.length != changes.length) {
      throw const FormatException('Duplicate workbench history IDs');
    }
    final conversations = _validateConversations(
      policyObject(sections['aiConversations'], 'aiConversations'),
      changeIds,
    );
    final history = policyObject(
      sections['localBudgetHistory'],
      'localBudgetHistory',
    );
    if (history.length > 100) {
      throw const FormatException('Too many budget history entries');
    }
    for (final entry in history.entries) {
      _requireProfile(entry.key, profileIds);
      final row = policyObject(entry.value, 'budget history');
      policyKeys(row, {
        'sourceId',
        'periodStart',
        'usedBytes',
        'limitBytes',
        'trusted',
        'sampleAt',
      });
      if (policyString(row, 'sourceId', maximum: 128) != entry.key) {
        throw const FormatException('Budget history source mismatch');
      }
      for (final key in [
        'periodStart',
        'usedBytes',
        'limitBytes',
        'sampleAt',
      ]) {
        policyInt(row, key);
      }
      policyBool(row, 'trusted');
    }
    return WorkbenchBackup._({
      'version': 1,
      'sections': {
        'policies': policies.toJson(),
        'ai': ai.toJson(),
        'aiCredentials': credentials,
        'aiConversations': conversations,
        'localBudgetHistory': history,
      },
      'changes': changes,
    });
  }
}

void _validateBounds(Object? value, [int depth = 0]) {
  if (depth > 32) throw const FormatException('Workbench backup nesting limit');
  if (value is String) {
    if (value.length > 256 * 1024) {
      throw const FormatException('Workbench backup string limit');
    }
  } else if (value is Map) {
    if (value.length > 5000 ||
        value.keys.any((key) => key is! String || key.length > 1024)) {
      throw const FormatException('Workbench backup object limit');
    }
    for (final entry in value.values) {
      _validateBounds(entry, depth + 1);
    }
  } else if (value is List) {
    if (value.length > 5000) {
      throw const FormatException('Workbench backup array limit');
    }
    for (final entry in value) {
      _validateBounds(entry, depth + 1);
    }
  } else if (value != null &&
      value is! bool &&
      value is! int &&
      value is! double) {
    throw const FormatException('Invalid workbench backup value');
  } else if (value is double && !value.isFinite) {
    throw const FormatException('Invalid workbench backup number');
  }
}

void _requireProfile(String value, Set<int> profileIds) {
  if (!profileIds.contains(policyIdentifier(value))) {
    throw const FormatException('Workbench refers to a missing profile');
  }
}

void _validateProfileReferences(
  LocalPolicyDocument document,
  Set<int> profileIds,
) {
  for (final integration
      in document.isStandalone
          ? [document.localProfile]
          : document.integrations) {
    if (!profileIds.containsAll(integration.sourceProfileIds)) {
      throw const FormatException('Integration refers to a missing profile');
    }
  }
  for (final target in [
    ...document.policies.map((p) => p.targetId),
    ...document.nodeSets.map((s) => s.targetId),
  ]) {
    if (target.startsWith('profile:')) {
      _requireProfile(target.substring('profile:'.length), profileIds);
    }
  }
  if (document.activeIntegrationId != null &&
      document.activeIntegration == null) {
    throw const FormatException('Missing active integration');
  }
  for (final set in document.nodeSets) {
    for (final id in [...set.sourceIds, ...set.excludedSourceIds]) {
      _requireProfile(id, profileIds);
    }
    final allowed = set.targetId.startsWith('profile:')
        ? profileIds
        : document.integrations
              .firstWhere((i) => i.targetId == set.targetId)
              .sourceProfileIds
              .toSet();
    if (!document.isStandalone &&
        !allowed.containsAll(set.sourceIds.map(policyIdentifier))) {
      throw const FormatException('Node set source belongs to another target');
    }
  }
  for (final nodeId in [
    for (final rule in document.policies) ...[
      ...rule.candidateNodeIds,
      ...rule.choices
          .where((choice) => choice.type == PolicyChoiceType.node)
          .map((choice) => choice.id),
    ],
    ...document.overrides.map((override) => override.nodeId),
  ]) {
    final sourceId = int.tryParse(nodeId.split(':').first);
    if (sourceId != null && !profileIds.contains(sourceId)) {
      throw const FormatException('Node refers to a missing profile');
    }
  }
  for (final budget in document.budgets) {
    _requireProfile(budget.sourceId, profileIds);
  }
}

Map<String, Object?> _validateChange(Map<String, Object?> json) {
  policyKeys(json, {
    'id',
    'category',
    'summary',
    'status',
    'highRisk',
    'error',
    'createdAt',
  });
  final id = policyString(json, 'id', maximum: 160);
  final status = policyString(json, 'status', maximum: 64);
  if (id.isEmpty || !_statuses.contains(status)) {
    throw const FormatException('Invalid workbench history identity or status');
  }
  final error = json['error'];
  if (error != null && (error is! String || error.length > 1024)) {
    throw const FormatException('Invalid workbench history error');
  }
  return {
    'id': id,
    'category': policyString(json, 'category', maximum: 200),
    'summary': policyString(json, 'summary', maximum: 2000),
    'status': _terminalStatuses.contains(status) ? status : 'superseded',
    'highRisk': policyBool(json, 'highRisk'),
    'error': error,
    'createdAt': policyInt(json, 'createdAt'),
  };
}

Map<String, Object?> _validateConversations(
  Map<String, Object?> json,
  Set<String> changeIds,
) {
  policyKeys(json, {'version', 'conversations'});
  if (policyInt(json, 'version') != 1) {
    throw const FormatException('Unsupported AI conversation version');
  }
  final ids = <String>{};
  final entries = policyItems(json, 'conversations', (entry) {
    policyKeys(entry, {
      'id',
      'updatedAt',
      'messages',
      'targetLabel',
      'changeIds',
      'context',
      'diagnostics',
      'recoveryRequired',
    });
    final id = policyString(entry, 'id', maximum: 32);
    if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(id) || !ids.add(id)) {
      throw const FormatException('Invalid AI conversation identity');
    }
    final refs = policyStrings(entry, 'changeIds', maximum: 96);
    if (refs.toSet().length != refs.length || !changeIds.containsAll(refs)) {
      throw const FormatException('AI conversation refers to missing history');
    }
    var bytes = 0;
    final messages = policyItems(entry, 'messages', (message) {
      policyKeys(message, {'role', 'content'});
      final role = policyString(message, 'role', maximum: 16);
      final content = policyString(message, 'content', maximum: 256 * 1024);
      bytes += utf8.encode(content).length;
      if (!{'user', 'assistant'}.contains(role) || bytes > 256 * 1024) {
        throw const FormatException('Invalid AI conversation messages');
      }
      return {'role': role, 'content': content};
    }, maximum: 80);
    if (messages.isEmpty) throw const FormatException('Empty AI conversation');
    return {
      'id': id,
      'updatedAt': policyInt(entry, 'updatedAt'),
      'messages': messages,
      if (entry['targetLabel'] != null)
        'targetLabel': policyString(entry, 'targetLabel', maximum: 160),
      'changeIds': refs,
      if (entry['recoveryRequired'] == true) 'recoveryRequired': true,
      if (entry['context'] != null)
        'context': aiContextMessages(entry['context']),
      if (entry['diagnostics'] != null)
        'diagnostics': aiDiagnosticEvents(entry['diagnostics']),
    };
  }, maximum: 20);
  return {'version': 1, 'conversations': entries};
}

Future<Map<String, Object?>> exportWorkbenchBackup(
  WorkbenchDatabase store, {
  required Set<int> profileIds,
}) => store.transaction(() async {
  final sections = <String, Object?>{
    'policies':
        await store.readSection('policies') ??
        const LocalPolicyDocument().toJson(),
    'ai': await store.readSection('ai') ?? const AgentSettings().toJson(),
    'aiCredentials':
        await store.readSection('aiCredentials') ??
        {
          'version': 1,
          'values': <String, Object?>{},
          'legacyAttempted': <String>[],
        },
    'aiConversations':
        await store.readSection('aiConversations') ??
        {'version': 1, 'conversations': <Object?>[]},
    'localBudgetHistory':
        await store.readSection('localBudgetHistory') ?? <String, Object?>{},
  };
  final credentialIds = AgentSettings.fromJson(
    policyObject(sections['ai'], 'ai'),
  ).connections.map((c) => c.credentialId).toSet();
  final credentials = policyObject(sections['aiCredentials'], 'aiCredentials');
  credentials['values'] = policyObject(credentials['values'], 'values')
    ..removeWhere((key, _) => !credentialIds.contains(key));
  credentials['legacyAttempted'] = credentialIds.toList();
  sections['aiCredentials'] = credentials;
  final conversations = policyObject(
    sections['aiConversations'],
    'aiConversations',
  );
  final linked = <String>{};
  for (final entry in policyItems(
    conversations,
    'conversations',
    (entry) => entry,
    maximum: 20,
  )) {
    linked.addAll(policyStrings(entry, 'changeIds', maximum: 96));
  }
  final recent =
      await (store.select(store.workbenchChanges)
            ..where((t) => t.status.isIn([..._terminalStatuses, 'applied']))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
            ..limit(1000))
          .get();
  final related = linked.isEmpty
      ? <WorkbenchChange>[]
      : await (store.select(
          store.workbenchChanges,
        )..where((t) => t.id.isIn(linked))).get();
  final changes = {
    for (final row in [...recent, ...related]) row.id: row,
  };
  conversations['conversations'] = policyItems(
    conversations,
    'conversations',
    (entry) => {
      ...entry,
      'changeIds': policyStrings(
        entry,
        'changeIds',
        maximum: 96,
      ).where(changes.containsKey).toList(),
    },
    maximum: 20,
  );
  sections['aiConversations'] = conversations;
  final backup = await WorkbenchBackup.parse({
    'version': 1,
    'sections': sections,
    'changes': changes.values
        .map(
          (row) => {
            'id': row.id,
            'category': row.category,
            'summary': row.summary,
            'status': row.status,
            'highRisk': row.highRisk,
            'error': row.error,
            'createdAt': row.createdAt,
          },
        )
        .toList(),
  }, profileIds: profileIds);
  return backup.toJson();
});

Future<void> restoreWorkbenchBackup(
  WorkbenchDatabase store,
  WorkbenchBackup backup,
) {
  EncryptedConfigAgentCredentialStore.invalidatePendingMigrations(store);
  return AiHistoryStore.replaceForRestore(
    store,
    () => store.transaction(() async {
      final json = backup.toJson();
      final sections = policyObject(json['sections'], 'sections');
      for (final entry in sections.entries) {
        await store.writeSection(
          entry.key,
          policyObject(entry.value, entry.key),
        );
      }
      await store.delete(store.workbenchChanges).go();
      for (final change in policyItems(
        json,
        'changes',
        (entry) => entry,
        maximum: 3000,
      )) {
        await store
            .into(store.workbenchChanges)
            .insert(
              WorkbenchChangesCompanion.insert(
                id: change['id'] as String,
                category: change['category'] as String,
                summary: change['summary'] as String,
                status: change['status'] as String,
                highRisk: change['highRisk'] as bool,
                fingerprint: '',
                beforePayload: '{}',
                afterPayload: '{}',
                error: Value(change['error'] as String?),
                createdAt: change['createdAt'] as int,
                expiresAt: 0,
              ),
            );
      }
    }),
  );
}
