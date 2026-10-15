import 'dart:convert';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:fl_clash/common/app_localizations.dart';
import 'package:fl_clash/configuration/changes.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/policy/models.dart';
import 'package:fl_clash/policy/compiler.dart';
import 'package:fl_clash/providers/workbench.dart';

import 'policy_contract.dart';
import 'policy_summary.dart';
import 'runtime.dart';

const agentResultBudget = 6 * 1024;

String agentShortText(String value, [int maximum = 240]) {
  final runes = value.runes.toList();
  return runes.length <= maximum
      ? value
      : '${String.fromCharCodes(runes.take(maximum))}…';
}

Map<String, Object?> agentPage(
  String key,
  List<Map<String, Object?>> rows,
  Map<String, Object?> args, {
  required String version,
  Map<String, Object?> metadata = const {},
  String? snapshotVersion,
}) {
  final query = {...args}
    ..remove('cursor')
    ..remove('version');
  final queryHash = policyDigest(query);
  var offset = 0;
  if (args['version'] != null && args['version'] != version) {
    throw const ConfigurationChangeException('configuration_version_conflict');
  }
  if (args['cursor'] case final String cursor) {
    final decoded = policyObject(
      jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(cursor)))),
      'cursor',
    );
    if (decoded['version'] != version ||
        decoded['snapshotVersion'] != snapshotVersion) {
      throw const ConfigurationChangeException(
        'configuration_snapshot_expired',
      );
    }
    if (decoded['query'] != queryHash) {
      throw const FormatException('Cursor belongs to another query');
    }
    offset = policyInt(decoded, 'offset', maximum: rows.length);
  }
  final limit = policyInt(
    args,
    'limit',
    fallback: 25,
    minimum: 1,
    maximum: 100,
  );
  final page = <Map<String, Object?>>[];
  Map<String, Object?> result() => {
    ...metadata,
    'version': version,
    key: page,
    'total': rows.length,
    'offset': offset,
    'complete': offset + page.length == rows.length,
    if (offset + page.length < rows.length)
      'nextCursor': base64Url.encode(
        utf8.encode(
          jsonEncode({
            'version': version,
            'snapshotVersion': ?snapshotVersion,
            'query': queryHash,
            'offset': offset + page.length,
          }),
        ),
      ),
  };
  for (final row in rows.skip(offset).take(limit)) {
    page.add(row);
    if (utf8.encode(jsonEncode(result())).length > agentResultBudget - 80) {
      page.removeLast();
      if (page.isEmpty) {
        page.add({
          'id': row['id'],
          'label': row['label'],
          'detailsAvailable': true,
          'detailsTool': row['detailsTool'] ?? 'policy_resource_read',
          if (row['path'] != null) 'path': row['path'],
        });
      }
      break;
    }
  }
  final value = result();
  if (utf8.encode(jsonEncode(value)).length > agentResultBudget - 80) {
    throw const ConfigurationChangeException('tool_result_budget_exceeded');
  }
  return value;
}

typedef AgentBusinessDelegate =
    Future<Map<String, Object?>> Function(AgentToolRequest request);

final class AgentEditValidationException implements Exception {
  final List<Map<String, Object?>> issues;
  final bool complete;

  const AgentEditValidationException(this.issues, {this.complete = true});

  Map<String, Object?> toJson() => {
    'code': 'tool_invalid_arguments',
    'writeApplied': false,
    'schemaTool': 'policy_edit_schema',
    'issues': issues,
    'issuesComplete': complete,
  };
}

final class _EditIssues {
  final List<Map<String, Object?>> values = [];
  bool complete = true;

  void add(
    int index,
    String kind,
    String field,
    String reason, {
    String? expectedPath,
  }) {
    if (values.length >= 10) {
      complete = false;
      return;
    }
    values.add({
      'actionIndex': index,
      'kind': kind,
      'field': field,
      'reason': reason,
      'schemaArguments': {'kind': kind == 'unknown' ? 'rule' : kind},
      'expectedPath': ?expectedPath,
    });
  }

  void check() {
    if (values.isNotEmpty) {
      throw AgentEditValidationException(values, complete: complete);
    }
  }
}

final class AgentBusinessTools {
  AgentBusinessTools({
    required this.controller,
    required this.readProfiles,
    required this.delegate,
    required this.propose,
    this.readRuntime,
    this.simulate,
  });

  final WorkbenchController controller;
  final Future<List<Profile>> Function() readProfiles;
  final AgentBusinessDelegate delegate;
  final Future<Map<String, Object?>> Function(
    LocalPolicyDocument document,
    List<PolicySource> sources,
    AgentToolRequest request,
  )?
  simulate;
  final Future<Map<String, Object?>> Function()? readRuntime;
  final Future<Map<String, Object?>> Function(
    LocalPolicyDocument document,
    String? draftId,
    AgentToolRequest request, [
    String? expectedPolicyDigest,
  ])
  propose;

  static const names = {
    'workspace_overview',
    'sources_query',
    'nodes_query',
    'node_sets_query',
    'rules_query',
    'policy_resource_read',
    'policy_edit_schema',
    'policy_draft_edit',
    'policy_draft_read',
    'policy_preview',
  };
  static const _text = {'type': 'string', 'maxLength': 1024};
  static const _strings = {'type': 'array', 'items': _text, 'maxItems': 100};
  static const _page = {
    'draftId': _text,
    'version': _text,
    'cursor': _text,
    'limit': {'type': 'integer', 'minimum': 1, 'maximum': 100},
  };
  static AgentToolDefinition _tool(
    String name,
    String description,
    Map<String, Object?> fields, [
    List<String> required = const [],
  ]) => AgentToolDefinition(
    name: name,
    description: description,
    parameters: {
      'type': 'object',
      'properties': fields,
      'required': required,
      'additionalProperties': false,
    },
  );

  static List<AgentToolDefinition> get definitions => [
    _tool(
      'workspace_overview',
      'Read compact actual configuration, local policy counts, readiness and current version. Start here; queries do not activate configurations.',
      {},
    ),
    _tool(
      'sources_query',
      'Find subscription sources by name or ID. Names, IDs, node counts, update time and explicit read failures only; never subscription URLs or credentials.',
      {..._page, 'search': _text, 'sourceIds': _strings},
    ),
    _tool(
      'nodes_query',
      'Filter the complete local node inventory by source IDs, ISO regions, name or known multiplier. Default rows contain only stable IDs, names and source names. countOnly avoids enumeration. fields opt into attributes and their inference basis; no raw connection data. health is unknown until separately checked.',
      {
        ..._page,
        'sourceIds': _strings,
        'regions': _strings,
        'nodeIds': _strings,
        'search': _text,
        'maxMultiplier': {
          'type': 'number',
          'exclusiveMinimum': 0,
          'maximum': 1000,
        },
        'sort': {
          'type': 'string',
          'enum': ['name', 'multiplier'],
        },
        'fields': {
          'type': 'array',
          'items': {
            'type': 'string',
            'enum': ['attributes', 'protocol', 'health'],
          },
          'maxItems': 3,
        },
        'countOnly': {'type': 'boolean'},
      },
    ),
    _tool(
      'node_sets_query',
      'Read reusable local node sets, exact saved filters, full-inventory candidate counts and rule references. For one set, members=true returns a bounded member page; nodeId explains its exclusion. Sets are not subscription proxy groups.',
      {
        ..._page,
        'id': _text,
        'search': _text,
        'members': {'type': 'boolean'},
        'nodeId': _text,
      },
    ),
    _tool(
      'rules_query',
      'Find ordered local rules in the saved document or specified draft. Returns business summaries and stable references. Use policy_resource_read for exact fields; policy_preview for compiler and scenario evidence.',
      {..._page, 'id': _text, 'search': _text},
    ),
    _tool(
      'policy_resource_read',
      'Read one exact local rule or node-set field as bounded JSON fragments. Reuse version and nextOffset to finish a large field. Only application policy resources; no filesystem or raw nodes.',
      {
        'draftId': _text,
        'kind': {
          'type': 'string',
          'enum': ['rule', 'nodeSet', 'node'],
        },
        'id': _text,
        'field': _text,
        'version': _text,
        'offset': {'type': 'integer', 'minimum': 0},
      },
      ['kind', 'id'],
    ),
    _tool(
      'policy_edit_schema',
      'Read editable fields for one resource type before creating or changing it. Schemas describe real local model semantics; use IDs returned by edits for later references.',
      {
        'kind': {
          'type': 'string',
          'enum': ['rule', 'nodeSet', 'settings', 'sources'],
        },
      },
      ['kind'],
    ),
    _tool(
      'policy_draft_edit',
      'Create or continue a version-bound local policy draft using typed actions. To continue an unapplied draft, supply BOTH draftId=policy_draft_read.id and version=policy_draft_read.version. Without draftId this edits the saved document and requires workspace_overview.version. Creates allocate IDs locally; clientKey can reference a new set within this batch. Update preserves omitted fields. moveRule uses beforeId, or null to move last. No application occurs.',
      {
        'draftId': {
          ..._text,
          'description':
              'Required when continuing an unapplied draft; use the id returned by policy_draft_read.',
        },
        'version': {
          ..._text,
          'description':
              'Use the version returned by policy_draft_read for draftId, otherwise use workspace_overview.version. Never mix these targets.',
        },
        'actions': {
          'type': 'array',
          'minItems': 1,
          'maxItems': 100,
          'items': {
            'type': 'object',
            'properties': {
              'action': {
                'type': 'string',
                'enum': [
                  'createRule',
                  'updateRule',
                  'removeRule',
                  'moveRule',
                  'createNodeSet',
                  'updateNodeSet',
                  'removeNodeSet',
                  'updateSettings',
                  'updateSources',
                ],
              },
              'id': _text,
              'clientKey': _text,
              'beforeId': {
                'type': ['string', 'null'],
                'maxLength': 128,
              },
              'fields': {'type': 'object'},
            },
            'required': ['action'],
            'additionalProperties': false,
          },
        },
      },
      ['version', 'actions'],
    ),
    _tool(
      'policy_draft_read',
      'Read the real latest draft status, version, validation and bounded business summary. Expired or superseded drafts fail. Use rules_query/node_sets_query with draftId for complete pages. Always reread after the final edit.',
      {'id': _text},
      ['id'],
    ),
    _tool(
      'policy_preview',
      'Compile the specified draft or saved policies with all selected sources. Candidate counts and optional cold-start flows, rule traces, decisions and timeline use bounded results pages. Use resultKind or nextCursor for details. Unknown match facts remain unknown; never claim live traffic verification.',
      {
        'draftId': _text,
        'version': _text,
        'health': {'type': 'object'},
        'localUsage': {'type': 'object'},
        'steps': {
          'type': 'array',
          'items': {'type': 'object'},
          'maxItems': 32,
        },
        'flows': {
          'type': 'array',
          'items': {
            'type': 'object',
            'properties': {
              for (final key in [
                'host',
                'destinationIp',
                'processName',
                'processPath',
                'network',
              ])
                key: _text,
            },
            'additionalProperties': false,
          },
          'maxItems': 8,
        },
        'cursor': _text,
        'limit': {'type': 'integer', 'minimum': 1, 'maximum': 100},
        'resultKind': {
          'type': 'string',
          'enum': ['nodeSet', 'policy', 'flow', 'timeline', 'validation'],
        },
      },
    ),
  ];

  Future<LocalPolicyDocument> _document(Map<String, Object?> args) async =>
      (args['draftId'] == null
              ? await controller.readPolicies()
              : await controller.readPolicyDraft(policyString(args, 'draftId')))
          .asStandalone();

  static String version(LocalPolicyDocument document) =>
      policyDigest(document.toJson());

  static void _checkVersion(
    Map<String, Object?> args,
    LocalPolicyDocument document,
  ) {
    if (args['version'] != null && args['version'] != version(document)) {
      throw const ConfigurationChangeException(
        'configuration_version_conflict',
      );
    }
  }

  Future<List<LocalNode>> _nodes(
    LocalPolicyDocument document, {
    List<String>? sourceIds,
  }) async {
    var queryDocument = document;
    if (sourceIds != null) {
      final profiles = await readProfiles();
      if (!profiles
          .map((profile) => '${profile.id}')
          .toSet()
          .containsAll(sourceIds)) {
        throw const ConfigurationChangeException('resource_profile_missing');
      }
      queryDocument = LocalPolicyDocument.fromJson({
        ...document.toJson(),
        'integrations': [
          {...document.localProfile.toJson(), 'sourceProfileIds': sourceIds},
        ],
      });
    }
    return controller.profiles.nodesForTarget(
      document: queryDocument,
      profiles: await readProfiles(),
      targetId: localPolicyTargetId,
      includeAllSources: true,
    );
  }

  static Map<String, Object?> _node(LocalNode node, Set<String> fields) => {
    'id': node.id,
    'sourceId': node.sourceId,
    'label': agentShortText(node.label),
    'sourceLabel': agentShortText(node.sourceLabel),
    if (node.label.runes.length > 240 || node.sourceLabel.runes.length > 240)
      'labelTruncated': true,
    if (fields.contains('attributes')) 'attributes': node.attributes.toJson(),
    if (fields.contains('protocol')) 'protocol': node.protocol,
    if (fields.contains('health'))
      'health': {'status': 'unknown', 'checkedAt': null},
  };

  static Map<String, Object?> _validation(LocalPolicyDocument document) {
    final value = policyPlanValidation(document);
    return {
      'valid': value['valid'],
      'issues': (value['issues'] as List).take(4).toList(),
      'warnings': (value['warnings'] as List).take(4).toList(),
      'issueCount': (value['issues'] as List).length,
      'warningCount': (value['warnings'] as List).length,
      'detailsTool': 'policy_preview',
    };
  }

  static Map<String, Object?> _editableSchema(
    String kind,
    Map<String, Object?> fields,
  ) {
    if (kind == 'settings') {
      return {
        'type': 'object',
        'properties': {
          for (final key in [
            'moduleEnabled',
            'policiesEnabled',
            'integrationEnabled',
            'budgetsEnabled',
            'sourceUpdateRoute',
          ])
            key: fields[key],
        },
        'additionalProperties': false,
      };
    }
    final source = policyObject(
      (fields[kind == 'rule'
              ? 'policies'
              : kind == 'nodeSet'
              ? 'nodeSets'
              : 'integrations']
          as Map)['items'],
      'schema',
    );
    final properties = policyObject(source['properties'], 'properties');
    properties.removeWhere(
      (key, _) => kind == 'sources'
          ? !{'sourceProfileIds', 'nameFilter', 'excludedNodeIds'}.contains(key)
          : {
              'id',
              'targetId',
              'origin',
              'userModified',
              'priority',
            }.contains(key),
    );
    return {...source, 'properties': properties, 'required': <String>[]};
  }

  Future<Map<String, Object?>> execute(AgentToolRequest request) async {
    final args = request.arguments;
    final document = await _document(args);
    if (!request.isCurrent()) {
      throw const ConfigurationChangeException('configuration_cancelled');
    }
    if (request.name == 'workspace_overview') {
      final state = await controller.backend.readState();
      final config = policyObject(state['config'], 'config');
      final runtime = readRuntime == null
          ? <String, Object?>{'status': 'unavailable'}
          : await readRuntime!();
      return {
        'version': version(document),
        'targetId': localPolicyTargetId,
        'moduleEnabled': document.moduleEnabled,
        'integrationEnabled': document.integrationEnabled,
        'policiesEnabled': document.policiesEnabled,
        'selectedSourceIds': document.localProfile.sourceProfileIds
            .map((id) => '$id')
            .toList(),
        'selectedProfileId': config['currentProfileId'],
        'sourceCount': (await readProfiles()).length,
        'nodeSetCount': document.nodeSets.length,
        'ruleCount': document.policies.length,
        'runtime': runtime,
        'runtimeTool': 'application_invoke',
        'runtimeCommand': 'runtime_read',
        'validation': _validation(document),
      };
    }
    if (request.name == 'policy_edit_schema') {
      final fields = policyObject(
        AgentPolicyContract.patchSchema['properties'],
        'properties',
      );
      final kind = policyString(args, 'kind');
      return {
        'kind': kind,
        'targetId': localPolicyTargetId,
        'schema': _editableSchema(kind, fields),
        'createRequired': switch (kind) {
          'rule' => ['label'],
          'nodeSet' => ['label', 'sourceIds'],
          _ => <String>[],
        },
        'identity':
            'Create actions allocate id and targetId locally; omit them in fields. Use clientKey for same-batch references. Update uses id and preserves omitted fields.',
        if (kind == 'nodeSet')
          'sourceSelection':
              'sourceIds is the eligible source universe: omitted sources are excluded. To prefer a source while retaining fallback, include every allowed source in preferred order and use preferences [{type: source, direction: ascending}]. sourceIds order affects ranking only with source preference. excludedSourceIds is a hard exclusion, never a preference.',
        if (kind == 'rule')
          'fieldPlacement': {
            'probe': 'fields.probe',
            'recoverySeconds': 'fields.recoverySeconds',
            'cooldownSeconds': 'fields.cooldownSeconds',
            'scope':
                'fields.scope; CN uses type destinationRegion and values [CN]; all/any require >=2 children',
          },
        'semantics':
            'Rules are ordered; empty candidate choices continue to the next matching rule. CN is GeoIP, not GEOSITE. Save node-set filters for future source updates. Unknown metadata is not measured health.',
      };
    }
    if (request.name == 'policy_draft_edit') return _edit(request, document);
    if (request.name == 'policy_draft_read') {
      final id = policyString(args, 'id');
      final draft = await controller.readPolicyDraft(id);
      final summary = policyBusinessSummary(
        draft,
        currentAppLocalizations,
        sourceLabels: {
          for (final profile in await readProfiles())
            '${profile.id}': profile.realLabel,
        },
      );
      final reply = summary['reply'] as String;
      final bounded = utf8.encode(jsonEncode(summary)).length <= 3500;
      return {
        'id': id,
        'status': 'draft',
        'version': version(draft),
        'validation': _validation(draft),
        'businessSummary': bounded
            ? summary
            : {
                'ruleCount': draft.policies.length,
                'nodeSetCount': draft.nodeSets.length,
                'complete': false,
                'rulesTool': 'rules_query',
                'nodeSetsTool': 'node_sets_query',
                if (utf8.encode(reply).length <= 1500) 'reply': reply,
              },
      };
    }
    if (request.name == 'sources_query') {
      final profiles = await readProfiles();
      final search = (args['search'] as String? ?? '').toLowerCase();
      final ids = args['sourceIds'] == null
          ? null
          : policyStrings(args, 'sourceIds').toSet();
      final rows = <Map<String, Object?>>[];
      for (final profile in profiles) {
        if (ids != null && !ids.contains('${profile.id}')) continue;
        if (!profile.realLabel.toLowerCase().contains(search)) continue;
        int? count;
        var status = 'available';
        try {
          final source = (await controller.profiles.loader.load([
            profile,
          ])).single;
          count = controller.profiles.compiler.extractNodes(source).length;
        } catch (_) {
          status = 'source_unavailable';
        }
        rows.add({
          'id': '${profile.id}',
          'label': agentShortText(profile.realLabel),
          'nodeCount': count,
          'status': status,
          'updatedAt': profile.lastUpdateDate?.millisecondsSinceEpoch,
          'selected': document.localProfile.sourceProfileIds.contains(
            profile.id,
          ),
        });
      }
      return agentPage('sources', rows, args, version: policyDigest(rows));
    }
    if (request.name == 'rules_query') {
      final summary = policyBusinessSummary(document, currentAppLocalizations);
      final search = (args['search'] as String? ?? '').toLowerCase();
      final rows = (summary['rules'] as List)
          .map((value) => policyObject(value, 'rule'))
          .where(
            (row) =>
                (args['id'] == null || row['id'] == args['id']) &&
                jsonEncode(row).toLowerCase().contains(search),
          )
          .map(
            (row) => {
              ...row,
              'label': agentShortText(row['label'] as String),
              'match': agentShortText(row['match'] as String),
              'detailsAvailable': true,
            },
          )
          .toList();
      return agentPage('rules', rows, args, version: version(document));
    }
    if (request.name == 'policy_resource_read') {
      final id = policyString(args, 'id');
      final kind = policyString(args, 'kind');
      Map<String, Object?>? resource;
      var resourceVersion = version(document);
      if (kind == 'node') {
        final nodes = await _nodes(document, sourceIds: [id.split(':').first]);
        final node = nodes.firstWhereOrNull((node) => node.id == id);
        if (node != null) {
          resource = {
            ..._node(node, {'attributes', 'protocol', 'health'}),
            'label': node.label,
            'sourceLabel': node.sourceLabel,
          };
          resourceVersion = policyDigest(node.summary);
        }
      } else {
        resource = kind == 'rule'
            ? document.policies
                  .firstWhereOrNull((rule) => rule.id == id)
                  ?.toJson()
            : document.nodeSets
                  .firstWhereOrNull((set) => set.id == id)
                  ?.toJson();
      }
      if (args['version'] != null && args['version'] != resourceVersion) {
        throw const ConfigurationChangeException(
          'configuration_version_conflict',
        );
      }
      if (resource == null) {
        throw const ConfigurationChangeException('resource_policy_missing');
      }
      final field = args['field'] as String?;
      if (field != null && !resource.containsKey(field)) {
        throw const FormatException('Unknown field');
      }
      final text = jsonEncode(field == null ? resource : resource[field]);
      final runes = text.runes.toList();
      final offset = policyInt(
        args,
        'offset',
        fallback: 0,
        maximum: runes.length,
      );
      final fragment = String.fromCharCodes(runes.skip(offset).take(650));
      final next = offset + fragment.runes.length;
      return {
        'id': id,
        'version': resourceVersion,
        'encoding': 'json_fragment',
        'content': fragment,
        'offset': offset,
        'complete': next == runes.length,
        if (next < runes.length) 'nextOffset': next,
      };
    }
    if (request.name == 'policy_preview') return _preview(request, document);
    final sourceIds = args['sourceIds'] == null
        ? null
        : policyStrings(args, 'sourceIds', maximum: 20);
    final nodes = await _nodes(document, sourceIds: sourceIds);
    final snapshot = policyDigest({
      'document': document.toJson(),
      'nodes': nodes.map((node) => node.summary).toList(),
    });
    if (request.name == 'node_sets_query') {
      final selected = document.nodeSets
          .where(
            (set) =>
                (args['id'] == null || set.id == args['id']) &&
                set.label.toLowerCase().contains(
                  (args['search'] as String? ?? '').toLowerCase(),
                ),
          )
          .toList();
      if (args['members'] == true || args['nodeId'] != null) {
        if (selected.length != 1 || args['id'] == null) {
          throw const FormatException('Specify one node set');
        }
        final set = selected.single;
        if (args['nodeId'] case final String id) {
          final node = nodes.firstWhereOrNull((node) => node.id == id);
          return {
            'version': snapshot,
            'nodeSetId': set.id,
            'node': node == null ? null : _node(node, {'attributes'}),
            'exclusion': node == null ? 'node_missing' : set.exclusion(node),
            'healthEvaluated': false,
          };
        }
        return agentPage(
          'nodes',
          nodes
              .where((node) => set.exclusion(node) == null)
              .map((node) => _node(node, {}))
              .toList(),
          args,
          version: snapshot,
          metadata: {'nodeSetId': set.id, 'healthEvaluated': false},
        );
      }
      return agentPage(
        'nodeSets',
        [
          for (final set in selected)
            {
              'id': set.id,
              'label': agentShortText(set.label),
              'filter': {
                for (final key in [
                  'sourceIds',
                  'regions',
                  'excludedSourceIds',
                  'excludedRegions',
                  'nameIncludes',
                  'nameExcludes',
                  'maxMultiplier',
                  'unknownMultiplier',
                  'allowUnknownRegion',
                  'preferences',
                  'selectionMode',
                ])
                  key: set.toJson()[key],
              },
              'candidateCount': nodes
                  .where((node) => set.exclusion(node) == null)
                  .length,
              'healthEvaluated': false,
              'ruleIds': document.policies
                  .where(
                    (rule) => rule.choices.any(
                      (choice) =>
                          choice.type == PolicyChoiceType.nodeSet &&
                          choice.id == set.id,
                    ),
                  )
                  .map((rule) => rule.id)
                  .toList(),
            },
        ],
        args,
        version: snapshot,
      );
    }
    final regions = args['regions'] == null
        ? null
        : policyStrings(args, 'regions').toSet();
    final ids = args['nodeIds'] == null
        ? null
        : policyStrings(args, 'nodeIds').toSet();
    final search = (args['search'] as String? ?? '').toLowerCase();
    final maximum = args['maxMultiplier'] as num?;
    final filtered = nodes
        .where(
          (node) =>
              (regions == null || regions.contains(node.attributes.region)) &&
              (ids == null || ids.contains(node.id)) &&
              node.label.toLowerCase().contains(search) &&
              (maximum == null ||
                  node.attributes.multiplier != null &&
                      node.attributes.multiplier! <= maximum),
        )
        .toList();
    filtered.sort((left, right) {
      if (args['sort'] == 'multiplier') {
        final compare = (left.attributes.multiplier ?? double.infinity)
            .compareTo(right.attributes.multiplier ?? double.infinity);
        if (compare != 0) return compare;
      }
      final compare = left.label.compareTo(right.label);
      return compare == 0 ? left.id.compareTo(right.id) : compare;
    });
    if (args['countOnly'] == true) {
      if (args['version'] != null && args['version'] != snapshot) {
        throw const ConfigurationChangeException(
          'configuration_snapshot_expired',
        );
      }
      return {
        'version': snapshot,
        'total': filtered.length,
        'inventoryUnknownRegion': nodes
            .where((node) => node.attributes.region == null)
            .length,
        'inventoryUnknownMultiplier': nodes
            .where((node) => node.attributes.multiplier == null)
            .length,
        'complete': true,
      };
    }
    final fields = args['fields'] == null
        ? <String>{}
        : policyStrings(args, 'fields').toSet();
    return agentPage(
      'nodes',
      filtered.map((node) => _node(node, fields)).toList(),
      args,
      version: snapshot,
    );
  }

  static String _actionKind(Object? action) => switch (action) {
    'createRule' || 'updateRule' || 'removeRule' || 'moveRule' => 'rule',
    'createNodeSet' || 'updateNodeSet' || 'removeNodeSet' => 'nodeSet',
    'updateSettings' => 'settings',
    'updateSources' => 'sources',
    _ => 'unknown',
  };

  static void validateEditArguments(Map<String, Object?> args) {
    final issues = _EditIssues();
    final actions = args['actions'];
    if (actions is! List || actions.isEmpty || actions.length > 100) {
      issues.add(-1, 'unknown', 'actions', 'Provide 1 to 100 actions.');
      issues.check();
      return;
    }
    final fields = policyObject(
      AgentPolicyContract.patchSchema['properties'],
      'properties',
    );
    final envelope = policyObject(
      ((definitions
                  .firstWhere((entry) => entry.name == 'policy_draft_edit')
                  .parameters['properties']
              as Map)['actions']
          as Map)['items'],
      'action schema',
    );
    var visits = 0;
    for (var index = 0; index < actions.length; index++) {
      final action = actions[index];
      final kind = action is Map ? _actionKind(action['action']) : 'unknown';
      final editable = kind == 'unknown'
          ? <String, Object?>{}
          : _editableSchema(kind, fields);
      final rootProperties = editable['properties'] as Map? ?? {};
      void validate(Object? value, Map<String, Object?> schema, String path) {
        if (++visits > 8000) {
          if (visits == 8001) {
            issues.complete = false;
            issues.add(
              index,
              kind,
              path,
              'Validation limit exceeded; split the batch.',
            );
          }
          return;
        }
        final type = schema['type'];
        final types = type is List ? type : [type];
        bool isType(Object? type) => switch (type) {
          'null' => value == null,
          'object' => value is Map,
          'array' => value is List,
          'string' => value is String,
          'integer' => value is int,
          'number' => value is num && value.isFinite,
          'boolean' => value is bool,
          _ => false,
        };
        if (!types.any(isType)) {
          issues.add(
            index,
            kind,
            path,
            'Expected type: ${types.join(' or ')}.',
          );
          return;
        }
        if (schema['enum'] case final List allowed) {
          if (!allowed.contains(value)) {
            issues.add(index, kind, path, 'Use an allowed schema enum value.');
            return;
          }
        }
        if (value is String) {
          if (schema['maxLength'] is int &&
                  value.length > (schema['maxLength'] as int) ||
              schema['minLength'] is int &&
                  value.length < (schema['minLength'] as int) ||
              schema['pattern'] is String &&
                  !RegExp(schema['pattern'] as String).hasMatch(value)) {
            issues.add(
              index,
              kind,
              path,
              'String must satisfy the schema length and pattern.',
            );
          }
        }
        if (value is num &&
            (schema['minimum'] is num && value < (schema['minimum'] as num) ||
                schema['maximum'] is num &&
                    value > (schema['maximum'] as num) ||
                schema['exclusiveMinimum'] is num &&
                    value <= (schema['exclusiveMinimum'] as num))) {
          issues.add(
            index,
            kind,
            path,
            'Number must satisfy the schema bounds.',
          );
        }
        if (value is List) {
          if (schema['maxItems'] is int &&
                  value.length > (schema['maxItems'] as int) ||
              schema['minItems'] is int &&
                  value.length < (schema['minItems'] as int) ||
              schema['uniqueItems'] == true &&
                  value.map(policyDigest).toSet().length != value.length) {
            issues.add(
              index,
              kind,
              path,
              'Array must satisfy schema size and uniqueness constraints.',
            );
          }
          if (schema['items'] case final Map itemSchema) {
            for (
              var position = 0;
              position < min(value.length, 101);
              position++
            ) {
              validate(
                value[position],
                policyObject(itemSchema, 'items'),
                '$path[$position]',
              );
            }
          }
        }
        if (value is Map) {
          final properties = schema['properties'] as Map? ?? {};
          for (final required in schema['required'] as List? ?? []) {
            if (!value.containsKey(required)) {
              issues.add(
                index,
                kind,
                '$path.$required',
                'Required field is missing.',
              );
            }
          }
          for (final entry in value.entries.take(128)) {
            final childSchema = properties[entry.key];
            if (childSchema is Map) {
              validate(
                entry.value,
                policyObject(childSchema, 'property'),
                path.isEmpty ? '${entry.key}' : '$path.${entry.key}',
              );
            } else if (schema['additionalProperties'] == false) {
              final recognized = rootProperties.containsKey(entry.key);
              final safePath = recognized
                  ? (path.isEmpty ? '${entry.key}' : '$path.${entry.key}')
                  : path;
              issues.add(
                index,
                kind,
                safePath,
                recognized
                    ? 'Field belongs directly inside fields, outside nested objects.'
                    : 'Unknown field; use only the schema properties.',
                expectedPath: recognized ? 'fields.${entry.key}' : null,
              );
            }
          }
          if (value.length > 128) {
            issues.add(
              index,
              kind,
              path,
              'Object exceeds the validation field limit.',
            );
          }
        }
      }

      validate(action, envelope, '');
      if (action is! Map || kind == 'unknown') continue;
      final supplied = action['fields'] ?? <String, Object?>{};
      validate(supplied, editable, 'fields');
      if (action['action'] == 'createRule' ||
          action['action'] == 'createNodeSet') {
        for (final required
            in kind == 'rule' ? ['label'] : ['label', 'sourceIds']) {
          if (supplied is Map && !supplied.containsKey(required)) {
            issues.add(
              index,
              kind,
              'fields.$required',
              'Create requires this field.',
            );
          }
        }
      }
    }
    issues.check();
  }

  static void _validateEditedModel(
    Map<String, Object?> value,
    int index,
    String kind,
    _EditIssues issues,
  ) {
    final scope = value['scope'];
    void match(Map<String, Object?> json, String path) {
      try {
        PolicyMatch.fromJson(json);
      } on FormatException catch (error) {
        final failure = switch (error.message) {
          'Logical scope requires at least two conditions' => (
            'children',
            'all/any require at least 2 children and no values; use the single child directly for one condition.',
          ),
          'Not scope requires exactly one condition' => (
            'children',
            'not requires exactly 1 child and no values.',
          ),
          'Choose a destination region' => (
            'values',
            'destinationRegion values must be ISO codes such as CN or !CN.',
          ),
          'Match scope requires values' => (
            'values',
            'This scope needs nonempty values and no children.',
          ),
          'Global/group scopes cannot be nested' => (
            'children',
            'Nested global/group scopes are not allowed.',
          ),
          'Enter a domain without protocol or path' => (
            'values',
            'Use a domain without a protocol or path.',
          ),
          _ => (
            '',
            'Scope violates the match model; check its type, values, children and depth.',
          ),
        };
        final children = json['children'];
        if (children is List && children.length >= 2) {
          final before = issues.values.length;
          for (var child = 0; child < children.length; child++) {
            if (children[child] is Map) {
              match(
                policyObject(children[child], 'scope'),
                '$path.children[$child]',
              );
            }
          }
          if (issues.values.length > before) return;
        }
        issues.add(
          index,
          kind,
          failure.$1.isEmpty ? path : '$path.${failure.$1}',
          failure.$2,
        );
      }
    }

    if (kind == 'rule' && scope is Map) {
      match(policyObject(scope, 'scope'), 'fields.scope');
    }
    try {
      if (kind == 'rule') {
        LocalPolicy.fromJson(value);
      } else {
        PolicyNodeSet.fromJson(value);
      }
    } on FormatException catch (error) {
      if (kind == 'rule' &&
          issues.values.any(
            (issue) =>
                issue['actionIndex'] == index &&
                (issue['field'] as String).startsWith('fields.scope'),
          )) {
        return;
      }
      final failure = switch (error.message) {
        'Invalid probe URL or timing' => (
          'fields.probe',
          'Use an HTTP(S) URL without credentials; timeoutSeconds < intervalSeconds <= validitySeconds.',
        ),
        'Invalid expected HTTP status' => (
          'fields.probe.expectedStatus',
          'Use HTTP status 100-599 or an ascending range such as 200-399.',
        ),
        'Policy requires a unique ordered candidate list' => (
          'fields.choices',
          'Proxy needs nonempty unique choices; direct/reject need empty choices. Do not combine choices with legacy candidateNodeIds.',
        ),
        'Invalid policy identity or target' => (
          'fields.label',
          'A rule label must be nonempty; identity and target are assigned locally.',
        ),
        _ => (
          'fields',
          'Edited resource violates its actual model; consult the editable schema.',
        ),
      };
      issues.add(index, kind, failure.$1, failure.$2);
    } on ArgumentError {
      issues.add(
        index,
        kind,
        'fields',
        'Use only enum values defined in the editable schema.',
      );
    }
  }

  Future<Map<String, Object?>> _edit(
    AgentToolRequest request,
    LocalPolicyDocument document,
  ) async {
    final args = request.arguments;
    _checkVersion(args, document);
    final rows = (args['actions'] as List)
        .map((action) => policyObject(action, 'action'))
        .toList();
    validateEditArguments(args);
    final modelIssues = _EditIssues();
    final aliases = <String, String>{};
    final assigned = <String, String>{};
    String allocate() =>
        'ai_${List.generate(16, (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
    for (var index = 0; index < rows.length; index++) {
      final row = rows[index];
      if (!{'createRule', 'createNodeSet'}.contains(row['action'])) continue;
      final id = allocate();
      assigned['$index'] = id;
      if (row['clientKey'] case final String key) {
        if (aliases.containsKey(key) ||
            document.nodeSets.any((set) => set.id == key) ||
            document.policies.any((rule) => rule.id == key)) {
          throw const FormatException('Ambiguous client key');
        }
        aliases[key] = id;
      }
    }
    final candidate = document.toJson();
    final rules = orderedPolicies(
      document.policies,
    ).map((rule) => rule.toJson()).toList();
    final sets = document.nodeSets.map((set) => set.toJson()).toList();
    var orderChanged = false;
    for (var index = 0; index < rows.length; index++) {
      final row = rows[index];
      final action = policyString(row, 'action');
      final fields = policyObject(row['fields'] ?? {}, 'fields');
      if (fields.containsKey('id') ||
          fields.containsKey('targetId') ||
          fields.containsKey('origin') ||
          fields.containsKey('userModified') ||
          fields.containsKey('priority')) {
        throw const FormatException('Identity and order are locally owned');
      }
      final id = aliases[row['id']] ?? row['id'];
      if (fields['choices'] case final List choices) {
        fields['choices'] = choices.map((choice) {
          final value = policyObject(choice, 'choice');
          return {...value, 'id': aliases[value['id']] ?? value['id']};
        }).toList();
      }
      if (action == 'updateSettings') {
        policyKeys(fields, {
          'moduleEnabled',
          'policiesEnabled',
          'integrationEnabled',
          'budgetsEnabled',
          'sourceUpdateRoute',
        });
        candidate.addAll(fields);
        continue;
      }
      if (action == 'updateSources') {
        policyKeys(fields, {
          'sourceProfileIds',
          'nameFilter',
          'excludedNodeIds',
        });
        candidate['integrations'] = [
          {
            ...policyObject(
              (candidate['integrations'] as List).single,
              'integration',
            ),
            ...fields,
          },
        ];
        continue;
      }
      final isRule = action.endsWith('Rule');
      final list = isRule ? rules : sets;
      if (action.startsWith('create')) {
        if (row['id'] != null) {
          throw const FormatException('Create identity is locally allocated');
        }
        final priority = isRule
            ? rules.fold<int>(
                    0,
                    (maximum, rule) =>
                        max(maximum, rule['priority'] as int? ?? 0),
                  ) +
                  100
            : 0;
        if (priority > 1000000) orderChanged = true;
        final created = {
          ...fields,
          'id': assigned['$index'],
          'targetId': localPolicyTargetId,
          if (isRule) ...{'origin': 'ai', 'priority': min(priority, 1000000)},
        };
        _validateEditedModel(
          created,
          index,
          isRule ? 'rule' : 'nodeSet',
          modelIssues,
        );
        list.add(created);
      } else {
        final position = list.indexWhere((item) => item['id'] == id);
        if (position < 0) {
          throw const ConfigurationChangeException('resource_policy_missing');
        }
        if (action.startsWith('remove')) {
          if (fields.isNotEmpty) {
            throw const FormatException('Remove has no fields');
          }
          list.removeAt(position);
        } else if (action == 'moveRule') {
          final before = aliases[row['beforeId']] ?? row['beforeId'];
          if (before == id || fields.isNotEmpty) {
            throw const FormatException('Invalid move');
          }
          final moved = list.removeAt(position);
          final next = before == null
              ? list.length
              : list.indexWhere((item) => item['id'] == before);
          if (next < 0) {
            throw const ConfigurationChangeException('resource_policy_missing');
          }
          list.insert(next, moved);
          orderChanged = true;
        } else {
          final updated = _merge(list[position], fields);
          _validateEditedModel(
            updated,
            index,
            isRule ? 'rule' : 'nodeSet',
            modelIssues,
          );
          list[position] = updated;
        }
      }
    }
    modelIssues.check();
    candidate['policies'] = [
      for (var index = 0; index < rules.length; index++)
        {...rules[index], if (orderChanged) 'priority': (index + 1) * 100},
    ];
    candidate['nodeSets'] = sets;
    final setIds = sets.map((set) => set['id']).toSet();
    for (final rule in rules) {
      for (final choice in rule['choices'] as List? ?? []) {
        final value = policyObject(choice, 'choice');
        if (value['type'] == 'nodeSet' && !setIds.contains(value['id'])) {
          throw const ConfigurationChangeException(
            'resource_node_set_referenced',
          );
        }
      }
    }
    final next = LocalPolicyDocument.fromJson(candidate).asStandalone();
    if (!request.isCurrent()) {
      throw const ConfigurationChangeException('configuration_cancelled');
    }
    final current = await _document(args);
    if (version(current) != version(document)) {
      throw const ConfigurationChangeException(
        'configuration_version_conflict',
      );
    }
    final expected = args['draftId'] == null
        ? version(document)
        : version(await controller.readPolicies());
    final result = await propose(
      next,
      args['draftId'] as String?,
      request,
      expected,
    );
    return {
      ...result,
      'createdResources': [
        for (final entry in assigned.entries)
          {
            'actionIndex': int.parse(entry.key),
            'kind': rows[int.parse(entry.key)]['action'],
            'id': entry.value,
          },
      ],
      'assignedIds': {
        for (final entry in aliases.entries) entry.key: entry.value,
      },
    };
  }

  static Map<String, Object?> _merge(
    Map<String, Object?> before,
    Map<String, Object?> patch,
  ) => {
    ...before,
    for (final entry in patch.entries)
      entry.key: entry.value is Map && before[entry.key] is Map
          ? _merge(
              policyObject(before[entry.key], entry.key),
              policyObject(entry.value, entry.key),
            )
          : entry.value,
  };

  Future<Map<String, Object?>> _preview(
    AgentToolRequest request,
    LocalPolicyDocument document,
  ) async {
    _checkVersion(request.arguments, document);
    final allProfiles = await readProfiles();
    final selected = allProfiles
        .where(
          (profile) =>
              document.localProfile.sourceProfileIds.contains(profile.id),
        )
        .toList();
    if (selected.length != document.localProfile.sourceProfileIds.length) {
      throw const ConfigurationChangeException('resource_profile_missing');
    }
    final sources = await controller.profiles.loader.load(selected);
    final compiled = controller.profiles.compiler.compile(
      document: LocalPolicyDocument.fromJson({
        ...document.toJson(),
        'moduleEnabled': true,
        'integrationEnabled': true,
        'activeIntegrationId': localPolicyProfileId,
      }),
      sources: sources,
      profileId: null,
      baseConfig: const {},
    );
    final nodes = compiled.nodes;
    final validation = policyPlanValidation(document);
    final counts = {
      for (final set in document.nodeSets)
        set.id: nodes.where((node) => set.exclusion(node) == null).length,
    };
    final scenario =
        (request.arguments.containsKey('steps') ||
                request.arguments.containsKey('flows')) &&
            simulate != null
        ? await simulate!(document, sources, request)
        : null;
    final rows = <Map<String, Object?>>[
      for (final set in document.nodeSets)
        {
          'kind': 'nodeSet',
          'id': set.id,
          'label': agentShortText(set.label),
          'candidateCount': counts[set.id],
          'healthEvaluated': false,
        },
      for (final kind in ['issues', 'warnings'])
        for (final issue in validation[kind] as List)
          {
            'kind': 'validation',
            'severity': kind,
            ...policyObject(issue, 'issue'),
          },
      if (scenario != null) ...[
        for (final value in scenario['results'] as List? ?? [])
          {
            'kind': 'policy',
            for (final key in [
              'policyId',
              'selectedNodeId',
              'fallback',
              'reason',
            ])
              key: (value as Map)[key],
            'candidateCount':
                ((value as Map)['candidates'] as List? ?? []).length,
          },
        for (final value in scenario['flowResults'] as List? ?? [])
          {
            ...policyObject(value, 'flow'),
            'kind': 'flow',
            'trace': ((value as Map)['trace'] as List? ?? []).take(6).toList(),
            'traceTruncated':
                (value)['traceTruncated'] == true ||
                ((value)['trace'] as List? ?? []).length > 6,
          },
        for (final value in scenario['timeline'] as List? ?? [])
          {
            'kind': 'timeline',
            'at': (value as Map)['at'],
            'decisions': ((value)['decisions'] as List? ?? []).take(5).toList(),
            'decisionCount': ((value)['decisions'] as List? ?? []).length,
          },
      ],
    ];
    final kind =
        request.arguments['resultKind'] ??
        (request.arguments.containsKey('flows') ? 'flow' : null);
    return agentPage(
      'results',
      rows.where((row) => kind == null || row['kind'] == kind).toList(),
      request.arguments,
      version: version(document),
      snapshotVersion: policyDigest(
        sources
            .map(
              (source) => {
                'id': source.id,
                'content': source.raw,
                'expiresAt': source.expiresAt,
                'remainingBytes': source.remainingBytes,
              },
            )
            .toList(),
      ),
      metadata: {
        'documentSource': request.arguments['draftId'] == null
            ? 'committed'
            : 'draft',
        'validation': {
          'valid': validation['valid'],
          'issueCount': (validation['issues'] as List).length,
          'warningCount': (validation['warnings'] as List).length,
        },
        'compiled': true,
        'nodeCount': nodes.length,
        if (utf8.encode(jsonEncode(counts)).length <= 1024)
          'nodeSetCounts': counts,
        'runtimeVerified': false,
        'candidateHealthEvaluated': false,
        'activationAssumed':
            !document.moduleEnabled || !document.integrationEnabled,
        'compiledTargetId': compiled.targetId,
        if (scenario != null)
          'scenario': {
            'documentSource': scenario['documentSource'],
            'simulation': true,
            'mode': 'cold_start',
            'predictsCurrentRuntime': false,
          },
      },
    );
  }
}
