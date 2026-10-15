import 'dart:convert';

import 'package:drift/native.dart';
import 'package:fl_clash/ai/business_tools.dart';
import 'package:fl_clash/ai/runtime.dart';
import 'package:fl_clash/ai/tools.dart';
import 'package:fl_clash/configuration/changes.dart';
import 'package:fl_clash/configuration/resources.dart';
import 'package:fl_clash/database/workbench_database.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/policy/models.dart';
import 'package:fl_clash/policy/compiler.dart';
import 'package:fl_clash/policy/profile_service.dart';
import 'package:fl_clash/policy/simulation.dart';
import 'package:fl_clash/policy/sources.dart';
import 'package:fl_clash/providers/workbench.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

Map<String, Object?> _node(
  String name,
  String server, {
  String? region,
  double? multiplier,
}) => {
  'name': name,
  'type': 'ss',
  'server': '$server.invalid',
  'port': 443,
  'cipher': 'aes-128-gcm',
  'password': 'private-fixture',
  'flclash-region': ?region,
  'flclash-multiplier': ?multiplier,
};

LocalPolicyDocument _document({List<int> sources = const [1, 2]}) =>
    LocalPolicyDocument.fromJson({
      'schemaVersion': 4,
      'moduleEnabled': true,
      'integrationEnabled': true,
      'activeIntegrationId': localPolicyProfileId,
      'policiesEnabled': true,
      'integrations': [
        {
          'id': localPolicyProfileId,
          'label': 'Local',
          'sourceProfileIds': sources,
        },
      ],
      'nodeSets': [
        {
          'id': 'pool',
          'label': 'Pool',
          'targetId': localPolicyTargetId,
          'sourceIds': ['1'],
          'maxMultiplier': 2,
          'nameExcludes': ['excluded'],
        },
      ],
      'policies': [
        for (final (index, id) in ['alpha', 'beta'].indexed)
          {
            'id': id,
            'label': id,
            'targetId': localPolicyTargetId,
            'priority': 100 + index * 100,
            'action': 'direct',
            'scope': {
              'type': 'domainKeyword',
              'values': [id],
            },
          },
      ],
    }).asStandalone();

class _Backend implements ConfigurationBackend {
  _Backend(this.document);
  LocalPolicyDocument document;
  void Function()? onValidate;
  int writes = 0;

  @override
  Future<Map<String, Object?>> readState() async => {
    'policies': document.toJson(),
    'config': <String, Object?>{},
  };
  @override
  Future<Map<String, Object?>> validate(Map<String, Object?> candidate) async {
    LocalPolicyDocument.fromJson(
      policyObject(candidate['policies'], 'policies'),
    ).validate();
    onValidate?.call();
    return {};
  }

  @override
  bool isHighRisk(Map<String, Object?> before, Map<String, Object?> after) =>
      true;
  @override
  Future<void> persist(Map<String, Object?> candidate) async => writes++;
  @override
  Future<void> activate(Map<String, Object?> candidate) async {}
}

class _Environment extends Mock implements ResourceEnvironment {}

class _Gateway extends Mock implements AgentResourceGateway {
  List<Profile> profiles = [
    for (final id in [1, 2])
      Profile(
        id: id,
        label: 'Source $id',
        url: 'https://private.invalid/subscription?token=private-fixture',
        autoUpdateDuration: const Duration(days: 1),
      ),
  ];

  @override
  Future<List<Profile>> readProfiles() async => profiles;
}

class _Controller extends Mock implements WorkbenchController {
  _Controller(this.store, this.backendState) {
    changes = ConfigurationChangeService(backend: backendState, store: store);
    profiles = PolicyProfileService(
      loader: PolicySourceLoader(
        store: store,
        profilePath: (id) async => '$id',
        readFile: (path) async {
          reads++;
          return readOverride?.call(path) ?? content[path];
        },
      ),
    );
  }
  @override
  final WorkbenchDatabase store;
  final _Backend backendState;
  @override
  late final ConfigurationChangeService changes;
  @override
  late final PolicyProfileService profiles;
  final content = <String, String>{};
  String? Function(String)? readOverride;
  int reads = 0;
  LocalPolicyDocument? simulatedDocument;
  List<PolicySource>? simulatedSources;
  List<Map<String, Object?>>? simulatedFlows;

  @override
  Future<LocalPolicyDocument> readPolicies() async => backendState.document;
  @override
  Future<LocalPolicyDocument> readPolicyDraft(String id) =>
      changes.readPolicyDraft(id);
  @override
  Future<ConfigurationProposal> proposePolicies(
    LocalPolicyDocument document, {
    String? draftId,
    String? expectedPolicyDigest,
  }) async => changes.propose(
    category: 'policies',
    summary: 'Local policy draft',
    candidate: {
      ...await backendState.readState(),
      'policies': document.toJson(),
    },
    baseDraftId: draftId,
    expectedPolicyDigest: expectedPolicyDigest,
  );
  @override
  Future<PolicySimulationResult> simulatePolicies({
    required LocalPolicyDocument document,
    required String targetId,
    required List<PolicySource> sources,
    required Map<String, bool?> health,
    required DateTime now,
    Map<String, int> localUsage = const {},
    List<Map<String, Object?>> steps = const [],
    List<Map<String, Object?>> flows = const [],
  }) async {
    simulatedDocument = document;
    simulatedSources = sources;
    simulatedFlows = flows;
    return const PolicySimulationResult(
      snapshot: {},
      results: [],
      timeline: [],
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late WorkbenchDatabase store;
  late _Backend backend;
  late _Controller controller;
  late _Gateway gateway;
  late AgentTools tools;
  var sequence = 0;

  setUpAll(() async => AppLocalizations.load(const Locale('en')));
  setUp(() {
    store = WorkbenchDatabase(NativeDatabase.memory());
    backend = _Backend(_document());
    controller = _Controller(store, backend);
    gateway = _Gateway();
    controller.content.addAll({
      '1': jsonEncode({
        'proxies': [_node('Shared', 'first')],
      }),
      '2': jsonEncode({
        'proxies': [_node('Shared', 'second')],
      }),
    });
    tools = AgentTools(
      controller: controller,
      gateway: gateway,
      resources: ResourceChangeService(
        store: store,
        environment: _Environment(),
      ),
      approve: (_) async => false,
    );
  });
  tearDown(() => store.close());

  Future<AgentToolResult> execute(
    String name, [
    Map<String, Object?> args = const {},
  ]) => tools.execute(
    AgentToolRequest(
      requestId: 'business-request',
      toolCallId: '${sequence++}',
      name: name,
      arguments: args,
      isCurrent: () => true,
    ),
  );
  Future<Map<String, Object?>> success(
    String name, [
    Map<String, Object?> args = const {},
  ]) async {
    final result = await execute(name, args);
    expect(result.isError, isFalse, reason: '$name: ${result.value}');
    return result.value;
  }

  String version() => AgentBusinessTools.version(backend.document);
  String draftId(Map<String, Object?> result) =>
      (result['proposal'] as Map)['id'] as String;

  for (final size in [20, 100, 1000, 5000]) {
    test(
      'full inventory filtering and bounded first page at $size nodes',
      () async {
        controller.content['1'] = jsonEncode({
          'proxies': List.generate(
            size,
            (index) => _node(
              '节点 $index',
              'scale-$index',
              region: index.isEven ? 'US' : 'HK',
              multiplier: index % 4 == 0 ? 0.1 : 2,
            ),
          ),
        });
        final page = await success('nodes_query', {
          'sourceIds': ['1'],
          'limit': 100,
        });
        expect(page['total'], size);
        expect(
          utf8.encode(jsonEncode(page)).length,
          lessThanOrEqualTo(agentResultBudget),
        );
        final rows = (page['nodes'] as List).cast<Map>();
        expect(rows, isNotEmpty);
        expect(
          rows.every(
            (row) => row.keys.toSet().difference({
              'id',
              'sourceId',
              'label',
              'sourceLabel',
            }).isEmpty,
          ),
          isTrue,
        );
        final filtered = await success('nodes_query', {
          'sourceIds': ['1'],
          'regions': ['US'],
          'maxMultiplier': 0.1,
          'countOnly': true,
        });
        expect(filtered['total'], size ~/ 4);
        expect(filtered.containsKey('nodes'), isFalse);
      },
    );
  }

  test(
    'long-name pages fit the budget and enumerate the complete inventory',
    () async {
      final longName = List.filled(300, '节点').join();
      controller.content['1'] = jsonEncode({
        'proxies': List.generate(137, (i) => _node('$longName-$i', 'node-$i')),
      });
      gateway.profiles = [
        gateway.profiles.first.copyWith(label: longName),
        gateway.profiles.last,
      ];
      final seen = <String>{};
      Map<String, Object?> args = {'limit': 100};
      var pages = 0;
      while (true) {
        final page = await success('nodes_query', args);
        expect(
          utf8.encode(jsonEncode(page)).length,
          lessThanOrEqualTo(agentResultBudget),
        );
        expect(page['total'], 138);
        final rows = page['nodes'] as List;
        expect(rows, isNotEmpty);
        for (final row in rows.cast<Map>()) {
          expect(seen.add(row['id'] as String), isTrue);
          expect(row.keys, isNot(contains('server')));
          expect(row.keys, isNot(contains('password')));
        }
        pages++;
        if (page['complete'] == true) break;
        expect(pages, lessThan(140));
        args = {
          'limit': 100,
          'cursor': page['nextCursor'],
          'version': page['version'],
        };
      }
      expect(seen, hasLength(138));
      expect(pages, greaterThan(1));
      expect((await success('nodes_query', {'countOnly': true}))['total'], 138);
    },
  );

  test(
    'pagination rejects changed query and changed source snapshots',
    () async {
      final page = await success('nodes_query', {'limit': 1});
      final different = await execute('nodes_query', {
        'limit': 1,
        'cursor': page['nextCursor'],
        'search': 'Shared',
      });
      expect(different.isError, isTrue);
      controller.content['1'] = jsonEncode({
        'proxies': [_node('Changed', 'third')],
      });
      final expired = await execute('nodes_query', {
        'limit': 1,
        'cursor': page['nextCursor'],
      });
      expect(expired.value['code'], 'configuration_snapshot_expired');
    },
  );

  test(
    'same node names remain distinct and stable IDs select exactly one source',
    () async {
      final rows = (await success('nodes_query'))['nodes'] as List;
      expect(rows.map((row) => (row as Map)['label']), ['Shared', 'Shared']);
      expect(rows.map((row) => (row as Map)['id']).toSet(), hasLength(2));
      final selected = await success('nodes_query', {
        'nodeIds': [(rows.last as Map)['id']],
      });
      expect((selected['nodes'] as List).single, containsPair('sourceId', '2'));
      expect(
        (await success('nodes_query', {
          'sourceIds': ['1'],
          'countOnly': true,
        }))['total'],
        1,
      );
      final encoded = jsonEncode((await success('sources_query')));
      expect(encoded, isNot(contains('private-fixture')));
      expect(encoded, isNot(contains('subscription?')));
    },
  );

  test(
    'unknown multiplier and region are not zero or measured health',
    () async {
      controller.content['1'] = jsonEncode({
        'proxies': [
          _node('Unclassified', 'unknown'),
          _node('Known low', 'low', region: 'US', multiplier: 0.1),
          _node('Known high', 'high', region: 'JP', multiplier: 2),
        ],
      });
      final rows =
          (await success('nodes_query', {
                'sourceIds': ['1'],
                'sort': 'multiplier',
                'fields': ['attributes', 'health'],
              }))['nodes']
              as List;
      expect(rows.map((row) => (row as Map)['label']), [
        'Known low',
        'Known high',
        'Unclassified',
      ]);
      final unknown = rows.last as Map;
      expect((unknown['attributes'] as Map)['multiplier'], isNull);
      expect((unknown['attributes'] as Map)['regionBasis'], 'unknown');
      expect(unknown['health'], {'status': 'unknown', 'checkedAt': null});
      expect(
        (await success('nodes_query', {
          'sourceIds': ['1'],
          'maxMultiplier': 0.1,
          'countOnly': true,
        }))['total'],
        1,
      );
      expect(
        (await success('nodes_query', {
          'sourceIds': ['1'],
          'regions': ['US'],
          'countOnly': true,
        }))['total'],
        1,
      );
    },
  );

  test(
    'two draft continuations preserve earlier edits, untouched fields and explicit order',
    () async {
      final first = await success('policy_draft_edit', {
        'version': version(),
        'actions': [
          {
            'action': 'updateRule',
            'id': 'alpha',
            'fields': {'label': 'Edited alpha'},
          },
          {
            'action': 'createRule',
            'clientKey': 'new',
            'fields': {
              'label': 'Gamma',
              'action': 'reject',
              'scope': {
                'type': 'domainKeyword',
                'values': ['gamma'],
              },
            },
          },
        ],
      });
      final firstId = draftId(first);
      final newId = (first['assignedIds'] as Map)['new'];
      final missingReference = await execute('policy_draft_edit', {
        'version': first['version'],
        'actions': [
          {
            'action': 'updateRule',
            'id': 'beta',
            'fields': {'label': 'Must not overwrite saved state'},
          },
        ],
      });
      expect(missingReference.value['code'], 'configuration_version_conflict');
      expect(
        (missingReference.value['recovery'] as Map)['writeApplied'],
        isFalse,
      );
      expect((await store.readChange(firstId))!.status, 'draft');
      expect(await store.watchChanges().first, hasLength(1));
      final second = await success('policy_draft_edit', {
        'draftId': firstId,
        'version': first['version'],
        'actions': [
          {
            'action': 'updateRule',
            'id': 'beta',
            'fields': {
              'label': 'Edited beta',
              'scope': {
                'values': ['beta-new'],
              },
            },
          },
        ],
      });
      final secondId = draftId(second);
      final third = await success('policy_draft_edit', {
        'draftId': secondId,
        'version': second['version'],
        'actions': [
          {'action': 'moveRule', 'id': newId, 'beforeId': 'alpha'},
          {
            'action': 'updateNodeSet',
            'id': 'pool',
            'fields': {'maxMultiplier': 0.1},
          },
        ],
      });
      final finalId = draftId(third);
      final draft = await controller.readPolicyDraft(finalId);
      expect(orderedPolicies(draft.policies).map((rule) => rule.id), [
        newId,
        'alpha',
        'beta',
      ]);
      expect(
        draft.policies.firstWhere((rule) => rule.id == 'alpha').label,
        'Edited alpha',
      );
      final beta = draft.policies.firstWhere((rule) => rule.id == 'beta');
      expect(beta.label, 'Edited beta');
      expect(beta.scope.type, PolicyMatchType.domainKeyword);
      expect(beta.scope.values, ['beta-new']);
      expect(draft.nodeSets.single.sourceIds, ['1']);
      expect(draft.nodeSets.single.nameExcludes, ['excluded']);
      expect(draft.nodeSets.single.maxMultiplier, 0.1);
      expect((await store.readChange(firstId))!.status, 'superseded');
      expect((await store.readChange(secondId))!.status, 'superseded');
      expect((await store.readChange(finalId))!.status, 'draft');
      expect(backend.writes, 0);
      expect(backend.document.policies.first.label, 'alpha');
      final stale = await execute('policy_draft_edit', {
        'draftId': secondId,
        'version': second['version'],
        'actions': [
          {'action': 'removeRule', 'id': 'alpha'},
        ],
      });
      expect(stale.isError, isTrue);
      final page = await success('rules_query', {'draftId': finalId});
      expect((page['rules'] as List).map((row) => (row as Map)['id']), [
        newId,
        'alpha',
        'beta',
      ]);
    },
  );

  test(
    'optimistic conflict during validation publishes no stale draft',
    () async {
      backend.onValidate = () => backend.document = backend.document
          .withRevision(backend.document.revision + 1);
      final result = await execute('policy_draft_edit', {
        'version': version(),
        'actions': [
          {
            'action': 'updateRule',
            'id': 'alpha',
            'fields': {'label': 'Stale'},
          },
        ],
      });
      expect(result.value['code'], 'configuration_version_conflict');
      expect(await store.watchChanges().first, isEmpty);
      expect(backend.writes, 0);
    },
  );

  test(
    'explicit edit actions cannot override identity or order through fields',
    () async {
      for (final field in ['id', 'targetId', 'origin', 'priority']) {
        final result = await execute('policy_draft_edit', {
          'version': version(),
          'actions': [
            {
              'action': 'updateRule',
              'id': 'alpha',
              'fields': {field: 'forged'},
            },
          ],
        });
        expect(result.value['code'], 'tool_invalid_arguments');
      }
      final invalid = await execute('policy_draft_edit', {
        'version': version(),
        'actions': [
          {'action': 'eraseEverything'},
        ],
      });
      expect(invalid.value['code'], 'tool_invalid_arguments');
      expect(await store.watchChanges().first, isEmpty);
    },
  );

  test(
    'action validation returns safe repair paths and leaves the retained draft untouched',
    () async {
      final initial = await success('policy_draft_edit', {
        'version': version(),
        'actions': [
          {
            'action': 'updateRule',
            'id': 'alpha',
            'fields': {'label': 'Retained'},
          },
        ],
      });
      final id = draftId(initial);
      final snapshot = (await store.readChange(id))!.afterPayload;
      final examples = <Map<String, Object?>>[
        {
          'action': 'createRule',
          'probe': {'url': 'https://secret.invalid/?token=DO_NOT_ECHO'},
          'fields': {'label': 'DO_NOT_ECHO', 'action': 'direct'},
        },
        {
          'action': 'createRule',
          'fields': {
            'label': 'DO_NOT_ECHO',
            'action': 'direct',
            'probe': {'recoverySeconds': 30, 'cooldownSeconds': 10},
          },
        },
        {
          'action': 'createRule',
          'fields': {
            'label': 'DO_NOT_ECHO',
            'action': 'direct',
            'scope': {
              'type': 'any',
              'children': [
                {
                  'type': 'domainSuffix',
                  'values': ['DO_NOT_ECHO.invalid'],
                },
              ],
            },
          },
        },
        {
          'action': 'createRule',
          'fields': {
            'label': 'DO_NOT_ECHO',
            'action': 'direct',
            'scope': {
              'type': 'region',
              'values': ['CN'],
            },
          },
        },
      ];
      final expectedFields = [
        'probe',
        'fields.probe.recoverySeconds',
        'fields.scope.children',
        'fields.scope.type',
      ];
      for (var index = 0; index < examples.length; index++) {
        final failure = await execute('policy_draft_edit', {
          'draftId': id,
          'version': initial['version'],
          'actions': [
            {
              'action': 'updateRule',
              'id': 'beta',
              'fields': {'label': 'must not persist'},
            },
            examples[index],
          ],
        });
        expect(failure.isError, isTrue);
        expect(failure.value['code'], 'tool_invalid_arguments');
        expect(failure.value['writeApplied'], isFalse);
        expect(failure.value['schemaTool'], 'policy_edit_schema');
        final issues = failure.value['issues'] as List;
        expect(
          issues.any(
            (issue) =>
                (issue as Map)['actionIndex'] == 1 &&
                issue['field'] == expectedFields[index],
          ),
          isTrue,
          reason: '${failure.value}',
        );
        if (index == 1) {
          expect(
            issues.any(
              (issue) =>
                  (issue as Map)['expectedPath'] == 'fields.recoverySeconds',
            ),
            isTrue,
          );
          expect(
            issues.any(
              (issue) =>
                  (issue as Map)['expectedPath'] == 'fields.cooldownSeconds',
            ),
            isTrue,
          );
        }
        final encoded = jsonEncode(failure.value);
        expect(encoded, isNot(contains('DO_NOT_ECHO')));
        expect(utf8.encode(encoded).length, lessThanOrEqualTo(6144));
        expect((await store.readChange(id))!.afterPayload, snapshot);
        expect((await store.readChange(id))!.status, 'draft');
        expect(await store.watchChanges().first, hasLength(1));
        expect(backend.writes, 0);
      }
    },
  );

  test(
    'corrected complete batch creates every resource and semantic scopes without writes',
    () async {
      final result = await success('policy_draft_edit', {
        'version': version(),
        'actions': [
          {
            'action': 'createNodeSet',
            'clientKey': 'preferred',
            'fields': {
              'label': 'HK preferred',
              'sourceIds': ['2', '1'],
              'regions': ['HK'],
              'preferences': [
                {'type': 'source', 'direction': 'ascending'},
              ],
            },
          },
          for (final type in [
            'domainSuffix',
            'destinationRegion',
            'global',
            'any',
          ])
            {
              'action': 'createRule',
              'fields': {
                'label': type,
                'scope': {
                  'type': type,
                  if (type == 'domainSuffix') 'values': ['example.com'],
                  if (type == 'destinationRegion') 'values': ['CN'],
                  if (type == 'any')
                    'children': [
                      {
                        'type': 'domainSuffix',
                        'values': ['example.com'],
                      },
                      {
                        'type': 'domainSuffix',
                        'values': ['example.net'],
                      },
                    ],
                },
                'choices': [
                  {'type': 'nodeSet', 'id': 'preferred'},
                ],
                'probe': {'intervalSeconds': 30, 'timeoutSeconds': 5},
                'recoverySeconds': 30,
                'cooldownSeconds': 10,
              },
            },
        ],
      });
      final document = await controller.readPolicyDraft(draftId(result));
      expect(document.policies, hasLength(6));
      expect(document.nodeSets, hasLength(2));
      expect((result['createdResources'] as List), hasLength(5));
      expect(backend.writes, 0);
      final schema = await success('policy_edit_schema', {'kind': 'nodeSet'});
      expect(schema['sourceSelection'], contains('hard exclusion'));
    },
  );

  test(
    'many invalid fields remain bounded and never echo user-supplied keys or values',
    () async {
      final result = await execute('policy_draft_edit', {
        'version': version(),
        'actions': [
          for (var index = 0; index < 100; index++)
            {
              'action': 'createRule',
              'fields': {'DO_NOT_ECHO_$index': 'private-fixture'},
            },
        ],
      });
      expect(result.isError, isTrue);
      expect(result.value['writeApplied'], isFalse);
      expect(result.value['issuesComplete'], isFalse);
      final encoded = jsonEncode(result.value);
      expect(encoded, isNot(contains('DO_NOT_ECHO')));
      expect(encoded, isNot(contains('private-fixture')));
      expect(utf8.encode(encoded).length, lessThanOrEqualTo(6144));
      expect(await store.watchChanges().first, isEmpty);
    },
  );

  test(
    'specified draft preview compiles and simulates that draft, using one source snapshot',
    () async {
      final proposal = await success('policy_draft_edit', {
        'version': version(),
        'actions': [
          {
            'action': 'updateSources',
            'fields': {
              'sourceProfileIds': ['2'],
            },
          },
        ],
      });
      final id = draftId(proposal);
      controller.reads = 0;
      final preview = await success('policy_preview', {
        'draftId': id,
        'version': proposal['version'],
        'flows': [
          {'host': 'api.example.com', 'network': 'tcp'},
        ],
      });
      expect(preview['documentSource'], 'draft');
      expect(preview['compiled'], isTrue);
      expect(preview['nodeCount'], 1);
      expect(preview['runtimeVerified'], isFalse);
      expect(controller.simulatedDocument!.localProfile.sourceProfileIds, [2]);
      expect(controller.simulatedSources!.map((source) => source.id), ['2']);
      expect(controller.simulatedFlows, [
        {'host': 'api.example.com', 'network': 'tcp'},
      ]);
      expect(controller.reads, 1);
      expect(backend.document.localProfile.sourceProfileIds, [1, 2]);
    },
  );

  test(
    'preview counts use the compiled snapshot even when a subsequent read changes',
    () async {
      backend.document = _document(sources: [1]);
      var reads = 0;
      controller.readOverride = (_) => jsonEncode({
        'proxies': List.generate(
          ++reads,
          (i) => _node('Node $i', 'changing-$i'),
        ),
      });
      final preview = await success('policy_preview');
      expect(preview['nodeCount'], 1);
      expect((preview['nodeSetCounts'] as Map)['pool'], 1);
      expect(reads, 1);
    },
  );
}
