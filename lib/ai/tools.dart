import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/configuration/changes.dart';
import 'package:fl_clash/capabilities/service.dart';
import 'package:fl_clash/configuration/resources.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/database/workbench_database.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/policy/models.dart';
import 'package:fl_clash/providers/usage.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/workbench.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/backup_and_restore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'policy_contract.dart';
import 'policy_summary.dart';
import 'runtime.dart';

abstract interface class AgentResourceGateway {
  Future<List<Profile>> readProfiles();
  Future<List<Script>> readScripts();
  Future<Map<String, Object?>> downloadProfile(String url);
  Future<Map<String, Object?>> usageSummary();
  Future<void> setUsageEnabled(bool enabled);
  Future<void> clearUsage();
  Future<Map<String, Object?>> updateResource(
    String kind,
    String? providerName, {
    bool Function()? isCurrent,
  });
  Future<Map<String, Object?>> openPanel(String panel);
}

final class FlutterAgentResourceGateway implements AgentResourceGateway {
  final Ref ref;
  final FlutterResourceEnvironment environment;
  final WorkbenchController controller;

  const FlutterAgentResourceGateway({
    required this.ref,
    required this.environment,
    required this.controller,
  });

  @override
  Future<List<Profile>> readProfiles() => environment.readProfiles();
  @override
  Future<List<Script>> readScripts() =>
      environment.database.scriptsDao.query().get();
  @override
  Future<Map<String, Object?>> downloadProfile(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !{'http', 'https'}.contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        url.length > 4096) {
      throw const ConfigurationChangeException('resource_url_invalid');
    }
    final response = await controller.fetchSourceResponse(url);
    final bytes = response.data;
    if (bytes == null || bytes.isEmpty || bytes.length > 8 * 1024 * 1024) {
      throw const ConfigurationChangeException('resource_download_invalid');
    }
    return {
      'protectedContent': utf8.decode(bytes),
      'subscriptionInfo': SubscriptionInfo.formHString(
        response.headers.value('subscription-userinfo'),
      ).toJson(),
    };
  }

  @override
  Future<Map<String, Object?>> usageSummary() async {
    final store = ref.read(usageStoreProvider);
    final summary = await store.todayProxySummary();
    return {
      'enabled': await store.watchEnabled().first,
      'upload': summary.upload,
      'download': summary.download,
      'connections': summary.connections,
    };
  }

  @override
  Future<void> setUsageEnabled(bool enabled) =>
      ref.read(usageRuntimeProvider.notifier).setEnabled(enabled);
  @override
  Future<void> clearUsage() => ref.read(usageRuntimeProvider.notifier).clear();
  @override
  Future<Map<String, Object?>> updateResource(
    String kind,
    String? providerName, {
    bool Function()? isCurrent,
  }) async {
    if (kind == 'provider') {
      final providers = await coreController.getExternalProviders();
      if (isCurrent?.call() == false) {
        throw const ConfigurationChangeException('configuration_cancelled');
      }
      if (providerName == null ||
          !providers.any((provider) => provider.name == providerName)) {
        throw const ConfigurationChangeException('resource_provider_missing');
      }
      final error = await coreController.updateExternalProvider(
        providerName: providerName,
      );
      if (error.isNotEmpty) {
        throw const ConfigurationChangeException('resource_update_failed');
      }
      return {'status': 'applied'};
    }
    final resource = GeoResource.values
        .where((resource) => resource.name.toLowerCase() == kind)
        .firstOrNull;
    if (resource == null) {
      throw const ConfigurationChangeException('resource_kind_invalid');
    }
    if ((await coreController.updateGeoData(resource.name)).isNotEmpty) {
      throw const ConfigurationChangeException('resource_update_failed');
    }
    return {'status': 'accepted', 'completionRequiresCoreEvent': true};
  }

  @override
  Future<Map<String, Object?>> openPanel(String panel) async {
    if (panel == 'profile_import') {
      ref.read(currentPageLabelProvider.notifier).toPage(PageLabel.profiles);
    } else {
      final navigator = globalState.navigatorKey.currentState;
      if (navigator != null) {
        unawaited(
          navigator.push<void>(
            MaterialPageRoute(builder: (_) => const BackupAndRestore()),
          ),
        );
      }
    }
    return {
      'status': 'requires_user_action',
      'panel': panel,
      'modelMayProvidePath': false,
    };
  }
}

final class AgentTools {
  final WorkbenchController controller;
  final ConfigurationApproval approve;
  final bool exposeApplication;
  late final ResourceChangeService resources;
  late final AgentResourceGateway gateway;

  AgentTools({
    required this.controller,
    required this.approve,
    this.exposeApplication = true,
    ResourceChangeService? resources,
    AgentResourceGateway? gateway,
  }) {
    this.resources = resources ?? controller.resources;
    final environment = this.resources.environment;
    this.gateway =
        gateway ??
        FlutterAgentResourceGateway(
          ref: controller.ref,
          environment: environment as FlutterResourceEnvironment,
          controller: controller,
        );
  }

  static const _object = <String, Object?>{'type': 'object'};
  static const _string = <String, Object?>{'type': 'string', 'maxLength': 4096};
  static const _id = <String, Object?>{
    'type': ['string', 'integer'],
    'maxLength': 19,
    'minimum': 1,
    'maximum': 9007199254740991,
  };
  static const _profileId = <String, Object?>{
    'type': ['string', 'integer'],
    'maxLength': 19,
    'minimum': 0,
    'maximum': 9007199254740991,
  };
  static const _boolean = <String, Object?>{'type': 'boolean'};
  static const _offset = <String, Object?>{
    'type': 'integer',
    'minimum': 0,
    'maximum': 9007199254740991,
  };
  static Map<String, Object?> _choice(List<String> values) => {
    'type': 'string',
    'enum': values,
  };
  static AgentToolDefinition _definition(
    String name,
    String description,
    Map<String, Object?> properties, [
    List<String> required = const [],
  ]) => AgentToolDefinition(
    name: name,
    description: description,
    parameters: {
      'type': 'object',
      'properties': properties,
      'required': required,
      'additionalProperties': false,
    },
  );

  List<AgentToolDefinition> get definitions => [
    if (exposeApplication) ...[
      _definition(
        'application_catalog',
        'Discover all typed macOS capabilities, input schemas, authorization and completion contracts.',
        {},
      ),
      _definition(
        'application_invoke',
        'Invoke a discovered application capability. Mutations retain local approval; never supply passwords, shell commands or arbitrary Core RPC.',
        {'command': _string, 'params': _object, 'idempotencyKey': _string},
        ['command', 'params'],
      ),
      _definition(
        'application_operation',
        'Query durable operation completion, failure, pending user input or recovery.',
        {'operationId': _string},
        ['operationId'],
      ),
    ],
    _definition(
      'settings_catalog',
      'Read validated setting capabilities and types.',
      {},
    ),
    _definition('settings_read', 'Read redacted local settings.', {}),
    _definition(
      'settings_propose',
      'Create a validated settings draft. No application occurs.',
      {'patch': _object},
      ['patch'],
    ),
    _definition(
      'policies_read',
      'Read independent local policies and dynamic nodeSets, their target, reference semantics and examples. No subscription profile selection is required.',
      {},
    ),
    _definition(
      'policies_catalog',
      'Discover the complete local policy patch schema, matching, ordering, nodeSet references and safe drafting examples.',
      {},
    ),
    _definition(
      'policies_draft_read',
      'Read an existing pending local policy draft, including authoritative businessSummary with actual rule order and validation. Always read after the last write before reporting draft_ready; summarize businessSummary rather than remembering earlier plans. Credentials and application configuration are withheld.',
      {'id': _string},
      ['id'],
    ),
    _definition(
      'nodes_list',
      'List stable node identities, labels and protocols only.',
      {
        'targetId': _string,
        'offset': _offset,
        'limit': {'type': 'integer', 'minimum': 1, 'maximum': 200},
      },
      ['targetId'],
    ),
    _definition(
      'policies_propose',
      'Create an independent local policy draft. Merge by stable IDs, preserving omitted fields; reuse draftId and rule IDs to revise a pending draft. Never applies changes; changes_commit requests local approval.',
      {
        'patch': AgentPolicyContract.patchSchema,
        'draftId': _string,
        'removePolicyIds': {'type': 'array', 'items': _string, 'maxItems': 100},
        'removeNodeSetIds': {
          'type': 'array',
          'items': _string,
          'maxItems': 100,
        },
        'removeIntegrationIds': {
          'type': 'array',
          'items': _string,
          'maxItems': 20,
        },
      },
      ['patch'],
    ),
    _definition(
      'policies_simulate',
      'Run a read-only cold-start scenario of the committed policy document, never an uncommitted draft. Read policies_draft_read to inspect drafts. Use supplied health assumptions and local usage. Existing live selection, probe age, latency, cooldown and recovery state are not restored; this does not predict current runtime behavior.',
      {
        'targetId': _string,
        'health': _object,
        'localUsage': _object,
        'now': {'type': 'integer', 'minimum': 1, 'maximum': 9007199254740991},
        'steps': {'type': 'array', 'items': _object, 'maxItems': 32},
      },
      ['targetId'],
    ),
    _definition(
      'changes_recover_propose',
      'Create a version-bound, fully validated recovery proposal for a failed change. Keep-current is an explicit checked decision; failure evidence remains.',
      {'id': _string, 'keepCurrent': _boolean},
      ['id'],
    ),
    _definition(
      'changes_commit',
      'Submit a saved draft to local approval and commit. Risk level and approval are controlled locally.',
      {'id': _string},
      ['id'],
    ),
    _definition(
      'changes_status',
      'Read safe journal status, excluding before and after payloads.',
      {'id': _string},
    ),
    _definition(
      'changes_undo',
      'Create a new draft restoring a previously applied reversible change.',
      {'id': _string},
      ['id'],
    ),
    _definition(
      'profiles_list',
      'Read profile identities and redacted subscription metadata.',
      {
        'offset': _offset,
        'limit': {'type': 'integer', 'minimum': 1, 'maximum': 200},
      },
    ),
    _definition(
      'profile_propose',
      'Draft adding, editing, deleting or refreshing a selected subscription. Imported file content is never exposed to the model.',
      {
        'operation': _choice(['add', 'edit', 'delete', 'refresh']),
        'profileId': _id,
        'patch': _object,
      },
      ['operation'],
    ),
    _definition(
      'rules_read',
      'Read subscription appended/custom rules for one profile or global subscription appended rules. Independent local rules use policies_read.',
      {
        'profileId': _profileId,
        'scene': _choice(['added', 'custom', 'disabled']),
      },
      ['profileId', 'scene'],
    ),
    _definition(
      'rule_propose',
      'Draft a subscription appended/custom rule add, edit, delete or order change. Independent local rules and nodeSets use policies_propose without profile selection.',
      {
        'profileId': _profileId,
        'scene': _choice(['added', 'custom']),
        'operation': _choice(['add', 'edit', 'delete', 'reorder']),
        'ruleId': _id,
        'rule': _object,
        'order': {'type': 'array', 'items': _id, 'maxItems': 5000},
      },
      ['profileId', 'scene', 'operation'],
    ),
    _definition(
      'rule_set_disabled',
      'Draft enabling or disabling an existing appended rule for one profile without changing shared rule content.',
      {'profileId': _id, 'ruleId': _id, 'disabled': _boolean},
      ['profileId', 'ruleId', 'disabled'],
    ),
    _definition(
      'groups_read',
      'Read subscription custom proxy groups scoped to one profile. These are not independent local nodeSets; use policies_read for those.',
      {'profileId': _id},
      ['profileId'],
    ),
    _definition(
      'group_propose',
      'Draft adding, editing or deleting a subscription custom proxy group and update exact subscription references on rename. Independent local nodeSets use policies_propose.',
      {
        'profileId': _id,
        'operation': _choice(['add', 'edit', 'delete']),
        'groupId': _id,
        'group': _object,
      },
      ['profileId', 'operation'],
    ),
    _definition(
      'scripts_list',
      'Read script IDs, labels and modification times only.',
      {},
    ),
    _definition(
      'script_propose',
      'Draft a script add, edit or delete. Existing script source is withheld; execution requires a separate local approval.',
      {
        'operation': _choice(['add', 'edit', 'delete']),
        'scriptId': _id,
        'label': _string,
        'content': {'type': 'string', 'maxLength': 524288},
      },
      ['operation'],
    ),
    _definition(
      'script_select',
      'Draft selecting and enabling or disabling an existing script for one profile.',
      {
        'profileId': _id,
        'scriptId': {
          'type': ['string', 'integer', 'null'],
          'maxLength': 19,
          'minimum': 1,
          'maximum': 9007199254740991,
        },
        'enabled': _boolean,
      },
      ['profileId', 'scriptId', 'enabled'],
    ),
    _definition(
      'resource_update',
      'Request a selected existing provider or geographic resource update after local approval.',
      {
        'kind': _choice(['provider', 'mmdb', 'asn', 'geoip', 'geosite']),
        'providerName': _string,
      },
      ['kind'],
    ),
    _definition('usage_read', 'Read aggregate local usage only.', {}),
    _definition(
      'usage_set_enabled',
      'Change usage recording after local approval; source budget accounting remains independent.',
      {'enabled': _boolean},
      ['enabled'],
    ),
    _definition(
      'usage_clear',
      'Clear graph history after local approval. This action has no undo and does not clear source budgets.',
      {},
    ),
    _definition(
      'backup_panel',
      'Require the native backup panel and user-selected destination; no model paths or implicit WebDAV upload.',
      {
        'action': _choice(['backup', 'restore', 'webdav_upload']),
      },
      ['action'],
    ),
    _definition(
      'profile_import_panel',
      'Require user selection through the existing file import panel.',
      {},
    ),
  ];

  void _current(AgentToolRequest request) {
    if (!request.isCurrent()) {
      throw const ConfigurationChangeException('configuration_cancelled');
    }
  }

  static void validateArguments(
    AgentToolDefinition definition,
    Map<String, Object?> arguments,
  ) {
    final properties = policyObject(
      definition.parameters['properties'],
      'properties',
    );
    policyKeys(arguments, properties.keys.toSet());
    final required = definition.parameters['required'] as List;
    if (required.any((key) => !arguments.containsKey(key))) {
      throw const FormatException('Missing argument');
    }
    for (final entry in arguments.entries) {
      _checkArgument(
        entry.value,
        policyObject(properties[entry.key], 'schema'),
      );
    }
  }

  static void _checkArgument(Object? value, Map<String, Object?> schema) {
    final type = schema['type'];
    if (type is List) {
      if (value == null && type.contains('null')) return;
      for (final option in type.where((item) => item != 'null')) {
        try {
          _checkArgument(value, {...schema, 'type': option});
          return;
        } on FormatException {
          continue;
        }
      }
      throw const FormatException('Invalid argument type');
    }
    final valid = switch (type) {
      'string' => value is String,
      'integer' => value is int,
      'number' => value is num && value.isFinite,
      'boolean' => value is bool,
      'object' => value is Map<String, Object?>,
      'array' => value is List,
      _ => false,
    };
    if (!valid ||
        schema['enum'] is List && !(schema['enum'] as List).contains(value) ||
        value is String &&
            schema['maxLength'] is int &&
            value.length > (schema['maxLength'] as int) ||
        value is num &&
            schema['minimum'] is num &&
            value < (schema['minimum'] as num) ||
        value is num &&
            schema['maximum'] is num &&
            value > (schema['maximum'] as num)) {
      throw const FormatException('Invalid argument');
    }
    if (value is String &&
            (schema['minLength'] is int &&
                    value.length < (schema['minLength'] as int) ||
                schema['pattern'] is String &&
                    !RegExp(schema['pattern'] as String).hasMatch(value)) ||
        value is num &&
            schema['exclusiveMinimum'] is num &&
            value <= (schema['exclusiveMinimum'] as num)) {
      throw const FormatException('Invalid argument');
    }
    if (value is Map<String, Object?>) {
      final properties = policyObject(
        schema['properties'] ?? <String, Object?>{},
        'properties',
      );
      final required = schema['required'] as List? ?? const [];
      if (required.any((key) => !value.containsKey(key)) ||
          schema['maxProperties'] is int &&
              value.length > (schema['maxProperties'] as int)) {
        throw const FormatException('Invalid object');
      }
      for (final entry in value.entries) {
        final nested = properties[entry.key] ?? schema['additionalProperties'];
        if (nested == false) throw const FormatException('Unknown field');
        if (nested is Map) {
          _checkArgument(entry.value, policyObject(nested, 'property'));
        }
      }
    }
    if (value is List && schema['items'] != null) {
      if (schema['maxItems'] is int &&
              value.length > (schema['maxItems'] as int) ||
          schema['minItems'] is int &&
              value.length < (schema['minItems'] as int) ||
          schema['uniqueItems'] == true &&
              value.map(policyDigest).toSet().length != value.length) {
        throw const FormatException('Too many items');
      }
      final items = policyObject(schema['items'], 'items');
      for (final item in value) {
        _checkArgument(item, items);
      }
    }
  }

  List<Map<String, Object?>> _simulationSteps(Object? value) {
    if (value == null) return const [];
    if (value is! List || value.length > 32) {
      throw const FormatException('Invalid steps');
    }
    return value.map((item) {
      final step = policyObject(item, 'step');
      policyKeys(step, {'at', 'probes', 'sources', 'usage'});
      policyInt(step, 'at', minimum: 1, maximum: 9007199254740991);
      for (final key in ['probes', 'sources']) {
        if (step.containsKey(key) && step[key] is! List) {
          throw const FormatException('Invalid event list');
        }
      }
      if (step.containsKey('usage') && step['usage'] is! Map<String, Object?>) {
        throw const FormatException('Invalid usage');
      }
      for (final probe in policyItems(
        step,
        'probes',
        (value) => value,
        maximum: 5000,
      )) {
        policyKeys(probe, {'nodeId', 'success'});
        policyString(probe, 'nodeId', maximum: 256);
        if (probe['success'] is! bool) {
          throw const FormatException('Invalid probe');
        }
      }
      final sources = policyItems(
        step,
        'sources',
        (value) => value,
        maximum: 20,
      );
      final ids = <String>{};
      for (final source in sources) {
        policyKeys(source, {'id', 'expiresAt', 'remainingBytes', 'observedAt'});
        if (!ids.add(policyString(source, 'id', maximum: 128))) {
          throw const FormatException('Duplicate source');
        }
        for (final key in ['expiresAt', 'remainingBytes', 'observedAt']) {
          if (source[key] != null) {
            policyInt(source, key, minimum: 0, maximum: 9007199254740991);
          }
        }
      }
      final usage = policyObject(step['usage'] ?? <String, Object?>{}, 'usage');
      if (usage.length > 20 ||
          usage.values.any(
            (value) => value is! int || value < 0 || value > 9007199254740991,
          )) {
        throw const FormatException('Invalid usage');
      }
      return step;
    }).toList();
  }

  Future<AgentToolResult> execute(AgentToolRequest request) async {
    try {
      _current(request);
      if (jsonEncode(request.arguments).length > 1024 * 1024) {
        throw const ConfigurationChangeException('tool_input_limit');
      }
      final definition = definitions
          .where((definition) => definition.name == request.name)
          .firstOrNull;
      if (definition == null) {
        throw const ConfigurationChangeException('tool_unknown');
      }
      final properties = policyObject(
        definition.parameters['properties'],
        'properties',
      );
      policyKeys(request.arguments, properties.keys.toSet());
      final required = definition.parameters['required'] as List<String>;
      if (required.any((key) => !request.arguments.containsKey(key))) {
        throw const FormatException('Missing argument');
      }
      for (final entry in request.arguments.entries) {
        _checkArgument(
          entry.value,
          policyObject(properties[entry.key], 'schema'),
        );
      }
      final value = await _execute(request);
      _current(request);
      return AgentToolResult(redactResource(value));
    } on ConfigurationChangeException catch (error) {
      return AgentToolResult({
        'code': _safeErrorCode(error.code),
      }, isError: true);
    } on ScriptExecutionException catch (error) {
      return AgentToolResult({
        'code': _safeErrorCode(error.code),
      }, isError: true);
    } on PolicySourceException {
      return const AgentToolResult({
        'code': 'source_option_unsupported',
      }, isError: true);
    } on FormatException {
      return const AgentToolResult({
        'code': 'tool_invalid_arguments',
      }, isError: true);
    } on ArgumentError {
      return const AgentToolResult({
        'code': 'tool_invalid_arguments',
      }, isError: true);
    } catch (_) {
      return const AgentToolResult({'code': 'tool_failed'}, isError: true);
    }
  }

  static String _safeErrorCode(String value) =>
      RegExp(
        r'^(configuration|resource|script|tool|action|source)_[a-z0-9_]{1,80}$',
      ).hasMatch(value)
      ? value
      : 'tool_failed';

  Map<String, Object?> _proposal(ConfigurationProposal proposal) => {
    'proposal': {
      ...proposal.toJson(),
      'validation': {
        for (final entry in proposal.validation.entries)
          if (!{
            'finalConfigDifferences',
            'localPolicyDocuments',
          }.contains(entry.key))
            entry.key: entry.value,
        if (proposal.validation.containsKey('finalConfigDifferences'))
          'finalDifferencesAvailableLocally': true,
      },
      'differences': proposal.differences.map((difference) {
        if (RegExp(
          r'(protected|secret|password|token|credential|authorization|api.?key)',
          caseSensitive: false,
        ).hasMatch(difference.path)) {
          return {'path': difference.path, 'redacted': true};
        }
        final key = difference.path.split('.').last;
        return {
          'path': difference.path,
          'before': redactResource({key: difference.before})[key],
          'after': redactResource({key: difference.after})[key],
        };
      }).toList(),
    },
  };

  Future<Map<String, Object?>> _execute(AgentToolRequest request) async {
    final args = request.arguments;
    switch (request.name) {
      case 'application_catalog':
        return controller.ref
            .read(applicationCapabilityServiceProvider)
            .execute(
              'capabilities',
              {},
              origin: 'agent',
              isCurrent: request.isCurrent,
              approve: approve,
            );
      case 'application_invoke':
        return controller.ref
            .read(applicationCapabilityServiceProvider)
            .execute(
              policyString(args, 'command', maximum: 96),
              policyObject(args['params'], 'params'),
              idempotencyKey: args['idempotencyKey'] as String?,
              origin: 'agent',
              isCurrent: request.isCurrent,
              approve: approve,
            );
      case 'application_operation':
        return controller.ref
            .read(applicationCapabilityServiceProvider)
            .execute(
              'operation_query',
              {'operationId': policyString(args, 'operationId', maximum: 96)},
              origin: 'agent',
              isCurrent: request.isCurrent,
            );
      case 'settings_catalog':
        return {
          'settings': controller.backend.catalog.capabilities.values
              .map(
                (setting) => {
                  ...setting.toJson(),
                  if (setting.path == 'currentProfileId') ...{
                    'type': 'string',
                    'identifierFormat': 'decimal-int64',
                    'minimum': '1',
                    'maximum': '9223372036854775807',
                  },
                },
              )
              .toList(),
        };
      case 'settings_read':
        final state = await controller.backend.readState();
        _current(request);
        return {
          'settings': controller.backend.catalog.redact(
            policyObject(state['config'], 'config'),
          ),
        };
      case 'settings_propose':
        final patch = policyObject(args['patch'], 'patch');
        if (patch.containsKey('currentProfileId') &&
            patch['currentProfileId'] != null) {
          patch['currentProfileId'] = resourceId(patch, 'currentProfileId');
        }
        final proposal = await controller.proposeSettingsPatch(patch);
        return _proposal(proposal);
      case 'policies_catalog':
        final document = await controller.readPolicies();
        return {
          'contract': AgentPolicyContract.describe(document),
          'patchSchema': AgentPolicyContract.patchSchema,
        };
      case 'policies_read':
        final document = await controller.readPolicies();
        return {
          'document': document.asStandalone().toJson(),
          'contract': AgentPolicyContract.describe(document),
        };
      case 'policies_draft_read':
        final id = policyString(args, 'id');
        final document = await controller.readPolicyDraft(id);
        return {
          'id': id,
          'status': 'draft',
          'document': document.toJson(),
          'contract': AgentPolicyContract.describe(document),
          'businessSummary': policyBusinessSummary(
            document,
            currentAppLocalizations,
            sourceLabels: {
              for (final profile in await gateway.readProfiles())
                '${profile.id}': profile.realLabel,
            },
          ),
          'validation': policyPlanValidation(document),
        };
      case 'nodes_list':
        final nodes = await controller.loadNodes(
          policyString(args, 'targetId'),
        );
        _current(request);
        final offset = policyInt(args, 'offset', fallback: 0);
        final limit = policyInt(
          args,
          'limit',
          fallback: 100,
          minimum: 1,
          maximum: 200,
        );
        return {
          'nodes': nodes
              .skip(offset)
              .take(limit)
              .map((node) => node.summary)
              .toList(),
          'total': nodes.length,
          'offset': offset,
        };
      case 'policies_propose':
        final draftId = args['draftId'] as String?;
        final document =
            (draftId == null
                    ? await controller.readPolicies()
                    : await controller.readPolicyDraft(draftId))
                .asStandalone();
        _current(request);
        final patch = policyObject(args['patch'], 'patch');
        policyKeys(patch, {
          'moduleEnabled',
          'nodeSets',
          'nodeAttributes',
          'policiesEnabled',
          'integrationEnabled',
          'budgetsEnabled',
          'sourceUpdateRoute',
          'activeIntegrationId',
          'integrations',
          'policies',
          'budgets',
          'overrides',
        });
        final candidate = document.toJson();
        for (final entry in patch.entries) {
          if ({
            'policies',
            'nodeSets',
            'integrations',
            'budgets',
            'overrides',
          }.contains(entry.key)) {
            final key = entry.key == 'budgets'
                ? 'sourceId'
                : entry.key == 'overrides'
                ? 'policyId'
                : 'id';
            final existing = (candidate[entry.key] as List)
                .map((value) => policyObject(value, entry.key))
                .toList();
            if (entry.value is! List || (entry.value as List).length > 100) {
              throw const FormatException('Invalid items');
            }
            for (final update in entry.value as List) {
              final object = policyObject(update, 'update');
              if (entry.key == 'integrations' &&
                  object.containsKey('sourceProfileIds')) {
                final values = object['sourceProfileIds'];
                if (values is! List || values.length > 20) {
                  throw const FormatException('Invalid source identifiers');
                }
                object['sourceProfileIds'] = values
                    .map((value) => resourceId({'id': value}, 'id').toString())
                    .toList();
              }
              final id = policyString(object, key);
              if (entry.key == 'integrations' && id != localPolicyProfileId) {
                throw const FormatException(
                  'Only the local configuration can be changed',
                );
              }
              final index = existing.indexWhere((item) => item[key] == id);
              if (index == -1) {
                if (entry.key == 'policies') {
                  final inserted = insertPolicy(
                    existing.map(LocalPolicy.fromJson).toList(),
                    LocalPolicy.fromJson({...object, 'origin': 'ai'}),
                    generated: true,
                  );
                  existing
                    ..clear()
                    ..addAll(inserted.map((policy) => policy.toJson()));
                } else {
                  existing.add(object);
                }
              } else {
                existing[index] = _merge(existing[index], {
                  ...object,
                  if (entry.key == 'policies')
                    'origin': existing[index]['origin'] ?? 'unknown',
                });
              }
            }
            candidate[entry.key] = existing;
          } else if (entry.key == 'nodeAttributes') {
            candidate[entry.key] = _merge(
              policyObject(candidate[entry.key], 'nodeAttributes'),
              policyObject(entry.value, 'nodeAttributes'),
            );
          } else {
            candidate[entry.key] = entry.value;
          }
        }
        for (final pair in [
          ('removePolicyIds', 'policies'),
          ('removeNodeSetIds', 'nodeSets'),
          ('removeIntegrationIds', 'integrations'),
        ]) {
          final ids = policyStrings(
            {pair.$1: args[pair.$1] ?? <Object?>[]},
            pair.$1,
            maximum: 100,
          ).toSet();
          candidate[pair.$2] = (candidate[pair.$2] as List)
              .where((value) => !ids.contains((value as Map)['id']))
              .toList();
        }
        final next = LocalPolicyDocument.fromJson(candidate).asStandalone();
        final validation = policyPlanValidation(next);
        if (validation['valid'] != true) {
          return {
            'status': 'failed',
            'code': 'configuration_policy_plan_invalid',
            'validation': validation,
          };
        }
        final labels = {
          for (final profile in await gateway.readProfiles())
            '${profile.id}': profile.realLabel,
        };
        final before = await controller.readPolicies();
        _current(request);
        final proposal = await controller.proposePolicies(
          next,
          draftId: draftId,
        );
        final summary = policyBusinessSummary(
          next,
          currentAppLocalizations,
          sourceLabels: labels,
        );
        final value = _proposal(
          ConfigurationProposal(
            id: proposal.id,
            summary: proposal.summary,
            highRisk: proposal.highRisk,
            expiresAt: proposal.expiresAt,
            differences: proposal.differences,
            validation: {
              ...proposal.validation,
              'localPolicyPlan': {
                'before': policyBusinessSummary(
                  before,
                  currentAppLocalizations,
                  sourceLabels: labels,
                ),
                'after': summary,
              },
            },
          ),
        );
        return {
          ...value,
          'supersedesId': ?draftId,
          'businessSummary': summary,
          'validation': validation,
        };
      case 'policies_simulate':
        final document = await controller.readPolicies();
        _current(request);
        final target = policyString(args, 'targetId');
        final profiles = await gateway.readProfiles();
        _current(request);
        final integration = document.integrations
            .where((entry) => entry.targetId == target)
            .firstOrNull;
        final ids =
            integration?.sourceProfileIds.toSet() ??
            document.sourceProfileIdsForTarget(target);
        final selected = profiles
            .where((profile) => ids.contains(profile.id))
            .toList();
        if (selected.length != ids.length) {
          throw const ConfigurationChangeException('resource_profile_missing');
        }
        final sources = await controller.profiles.loader.load(selected);
        _current(request);
        final rawHealth = policyObject(
          args['health'] ?? <String, Object?>{},
          'health',
        );
        if (rawHealth.values.any((value) => value != null && value is! bool)) {
          throw const FormatException('Invalid health');
        }
        final health = rawHealth.map(
          (key, value) => MapEntry(key, value as bool?),
        );
        final rawUsage = policyObject(
          args['localUsage'] ?? <String, Object?>{},
          'localUsage',
        );
        if (rawUsage.values.any(
          (value) => value is! int || value < 0 || value > 9007199254740991,
        )) {
          throw const FormatException('Invalid usage');
        }
        final simulation = await controller.simulatePolicies(
          document: document,
          targetId: target,
          sources: sources,
          health: health,
          now: args['now'] == null
              ? DateTime.now()
              : DateTime.fromMillisecondsSinceEpoch(
                  policyInt(args, 'now', minimum: 1),
                ),
          localUsage: rawUsage.map((key, value) => MapEntry(key, value as int)),
          steps: _simulationSteps(args['steps']),
        );
        _current(request);
        return {
          'documentSource': 'committed',
          'simulation': true,
          'mode': 'cold_start',
          'predictsCurrentRuntime': false,
          'results': simulation.results,
          if (simulation.timeline.isNotEmpty) 'timeline': simulation.timeline,
        };
      case 'changes_recover_propose':
        final id = policyString(args, 'id');
        final row = await controller.store.readChange(id);
        _current(request);
        if (row == null || row.category.startsWith('capability:')) {
          throw const ConfigurationChangeException(
            'configuration_recovery_missing',
          );
        }
        return _proposal(
          row.category.startsWith('resource:')
              ? await resources.proposeRecovery(
                  id,
                  keepCurrent: policyBool(args, 'keepCurrent'),
                )
              : await controller.changes.proposeRecovery(
                  id,
                  keepCurrent: policyBool(args, 'keepCurrent'),
                ),
        );
      case 'changes_commit':
        final id = policyString(args, 'id');
        final row = await controller.store.readChange(id);
        _current(request);
        if (row == null) {
          throw const ConfigurationChangeException(
            'configuration_proposal_missing',
          );
        }
        if (row.category.startsWith('repair:')) {
          return resources.commit(
            id,
            approve: approve,
            isCurrent: request.isCurrent,
          );
        }
        if (row.category.startsWith('recovery:')) {
          final original = await controller.store.readChange(
            row.category.substring('recovery:'.length),
          );
          _current(request);
          if (original == null) {
            throw const ConfigurationChangeException(
              'configuration_recovery_missing',
            );
          }
          return original.category.startsWith('resource:')
              ? resources.commit(
                  id,
                  approve: approve,
                  isCurrent: request.isCurrent,
                )
              : controller.changes.commitRecovery(
                  await controller.changes.readProposal(id),
                  approve: approve,
                  isCurrent: request.isCurrent,
                );
        }
        if (row.category.startsWith('capability:')) {
          throw const ConfigurationChangeException(
            'configuration_not_undoable',
          );
        }
        if (row.category.startsWith('resource:')) {
          return resources.commit(
            id,
            approve: approve,
            isCurrent: request.isCurrent,
          );
        }
        if (row.category.startsWith('action:')) {
          throw const ConfigurationChangeException(
            'configuration_not_undoable',
          );
        }
        final proposal = await controller.changes.readProposal(id);
        _current(request);
        final validation = await controller.changes.backend.validate(
          policyObject(jsonDecode(row.afterPayload), 'after'),
        );
        _current(request);
        if (validation['requiresScriptExecutionApproval'] == true) {
          await controller.changes.prepareApprovedValidation(
            id: id,
            approve: approve,
            isCurrent: request.isCurrent,
          );
        }
        _current(request);
        return controller.commit(
          proposal,
          approve: approve,
          isCurrent: request.isCurrent,
        );
      case 'changes_status':
        final id = args['id'];
        if (id != null) {
          final row = await controller.store.readChange(
            policyString(args, 'id'),
          );
          return {'change': row == null ? null : _status(row)};
        }
        return {
          'changes': (await controller.store.watchChanges().first)
              .map(_status)
              .toList(),
        };
      case 'changes_undo':
        final id = policyString(args, 'id');
        final row = await controller.store.readChange(id);
        _current(request);
        if (row == null || row.category.startsWith('action:')) {
          throw const ConfigurationChangeException(
            'configuration_not_undoable',
          );
        }
        return _proposal(
          row.category.startsWith('resource:')
              ? await resources.undo(id)
              : await controller.changes.proposeUndo(id),
        );
      case 'profiles_list':
        final profiles = await gateway.readProfiles();
        final offset = policyInt(args, 'offset', fallback: 0);
        final limit = policyInt(
          args,
          'limit',
          fallback: 100,
          minimum: 1,
          maximum: 200,
        );
        return {
          'profiles': profiles
              .skip(offset)
              .take(limit)
              .map(
                (profile) => {
                  'id': profile.id,
                  'label': profile.label,
                  'url': profile.url,
                  'autoUpdate': profile.autoUpdate,
                  'overwriteType': profile.overwriteType.name,
                  'scriptId': profile.scriptId,
                  'lastUpdateAt':
                      profile.lastUpdateDate?.millisecondsSinceEpoch,
                  'subscriptionInfo': profile.subscriptionInfo?.toJson(),
                },
              )
              .toList(),
          'total': profiles.length,
        };
      case 'profile_propose':
        return _profileProposal(request);
      case 'rules_read':
      case 'groups_read':
        final scope = request.name == 'groups_read'
            ? ResourceScope(ResourceKind.groups, resourceId(args, 'profileId'))
            : _ruleScope(args);
        final state = await resources.environment.read(scope);
        return {
          'items':
              state[scope.kind == ResourceKind.groups
                  ? 'groups'
                  : '${scope.scene!.name}Rules'],
        };
      case 'rule_propose':
        return _ruleProposal(request);
      case 'rule_set_disabled':
        final id = resourceId(args, 'profileId');
        final ruleId = resourceId(args, 'ruleId');
        final scope = ResourceScope(
          ResourceKind.rules,
          id,
          scene: RuleScene.disabled,
        );
        final state = await resources.environment.read(scope);
        _current(request);
        final global = await resources.environment.read(
          const ResourceScope(ResourceKind.rules, 0, scene: RuleScene.added),
        );
        _current(request);
        final rule = [
          ...policyItems(state, 'addedRules', Rule.fromJson),
          ...policyItems(global, 'addedRules', Rule.fromJson),
        ].where((rule) => rule.id == ruleId).firstOrNull;
        if (rule == null) {
          throw const ConfigurationChangeException('resource_rule_missing');
        }
        final disabled = policyItems(
          state,
          'disabledRules',
          Rule.fromJson,
        ).where((rule) => rule.id != ruleId).toList();
        if (args['disabled'] == true) disabled.add(rule);
        state['disabledRules'] = disabled.map((rule) => rule.toJson()).toList();
        return _proposal(
          await resources.propose(
            scope,
            state,
            summary: currentAppLocalizations.rule,
          ),
        );
      case 'group_propose':
        return _groupProposal(request);
      case 'scripts_list':
        return {
          'scripts': (await gateway.readScripts())
              .map(
                (script) => {
                  'id': script.id,
                  'label': script.label,
                  'updatedAt': script.lastUpdateTime.millisecondsSinceEpoch,
                },
              )
              .toList(),
        };
      case 'script_propose':
        return _scriptProposal(request);
      case 'script_select':
        final scope = ResourceScope(
          ResourceKind.profile,
          resourceId(args, 'profileId'),
        );
        final state = await resources.environment.read(scope);
        _current(request);
        final profile = Profile.fromJson(
          policyObject(state['profile'], 'profile'),
        );
        final enabled = args['enabled'];
        if (enabled is! bool) throw const FormatException('Invalid enabled');
        final id = args['scriptId'] == null
            ? null
            : resourceId(args, 'scriptId');
        if (enabled && id == null) {
          throw const ConfigurationChangeException('resource_script_missing');
        }
        final scriptState = id == null
            ? null
            : await resources.environment.read(
                ResourceScope(ResourceKind.script, id),
              );
        _current(request);
        if (id != null && scriptState?['script'] == null) {
          throw const ConfigurationChangeException('resource_script_missing');
        }
        state['profile'] = profile
            .copyWith(
              scriptId: id,
              overwriteType: enabled
                  ? OverwriteType.script
                  : profile.overwriteType == OverwriteType.script
                  ? OverwriteType.standard
                  : profile.overwriteType,
            )
            .toJson();
        state['protectedScriptContent'] = scriptState?['protectedContent'];
        return _proposal(
          await resources.propose(
            scope,
            state,
            summary: currentAppLocalizations.script,
          ),
        );
      case 'resource_update':
        final kind = policyString(args, 'kind');
        if (!{'provider', 'mmdb', 'asn', 'geoip', 'geosite'}.contains(kind)) {
          throw const FormatException('Invalid resource');
        }
        final name = args['providerName'];
        if (name != null &&
                (name is! String || name.isEmpty || name.length > 256) ||
            kind == 'provider' && name == null ||
            kind != 'provider' && name != null) {
          throw const FormatException('Invalid provider');
        }
        if (exposeApplication) return _applicationCommand(request);
        return _action(
          request,
          currentAppLocalizations.update,
          () => gateway.updateResource(
            kind,
            name as String?,
            isCurrent: request.isCurrent,
          ),
        );
      case 'usage_read':
        return gateway.usageSummary();
      case 'usage_set_enabled':
        if (args['enabled'] is! bool) {
          throw const FormatException('Invalid enabled');
        }
        return _action(request, currentAppLocalizations.usage, () async {
          await gateway.setUsageEnabled(args['enabled'] as bool);
          return {'status': 'applied'};
        });
      case 'usage_clear':
        return _action(request, currentAppLocalizations.usage, () async {
          await gateway.clearUsage();
          return {'status': 'applied', 'reversible': false};
        });
      case 'backup_panel':
        final action = policyString(args, 'action');
        if (!{'backup', 'restore', 'webdav_upload'}.contains(action)) {
          throw const FormatException('Invalid panel');
        }
        if (exposeApplication) return _applicationCommand(request);
        return gateway.openPanel(action);
      case 'profile_import_panel':
        if (exposeApplication) return _applicationCommand(request);
        return gateway.openPanel('profile_import');
      default:
        throw const ConfigurationChangeException('tool_unknown');
    }
  }

  Future<Map<String, Object?>> _applicationCommand(AgentToolRequest request) =>
      controller.ref
          .read(applicationCapabilityServiceProvider)
          .execute(
            request.name,
            request.arguments,
            idempotencyKey: policyDigest({
              'requestId': request.requestId,
              'toolCallId': request.toolCallId,
              'name': request.name,
            }),
            origin: 'agent',
            isCurrent: request.isCurrent,
            approve: approve,
          );

  static Map<String, Object?> _merge(
    Map<String, Object?> before,
    Map<String, Object?> patch,
  ) => {
    ...before,
    for (final entry in patch.entries)
      entry.key: entry.value is Map && before[entry.key] is Map
          ? _merge(
              policyObject(before[entry.key], 'before'),
              policyObject(entry.value, 'patch'),
            )
          : entry.value,
  };

  static Map<String, Object?> _status(WorkbenchChange row) => {
    'id': row.id,
    'category': row.category,
    'summary': row.summary,
    'status': row.status,
    'highRisk': row.highRisk,
    'createdAt': row.createdAt,
    'expiresAt': row.expiresAt,
    'error': row.error,
  };

  ResourceScope _ruleScope(Map<String, Object?> args) {
    final id = resourceId(args, 'profileId', allowZero: true);
    final scene = RuleScene.values
        .where((scene) => scene.name == policyString(args, 'scene'))
        .firstOrNull;
    if (scene == null || id == 0 && scene != RuleScene.added) {
      throw const FormatException('Invalid scene');
    }
    return ResourceScope(ResourceKind.rules, id, scene: scene);
  }

  Future<Map<String, Object?>> _profileProposal(
    AgentToolRequest request,
  ) async {
    final args = request.arguments;
    final operation = policyString(args, 'operation');
    final patch = policyObject(args['patch'] ?? <String, Object?>{}, 'patch');
    policyKeys(patch, {
      'label',
      'url',
      'autoUpdate',
      'autoUpdateMinutes',
      'overwriteType',
    });
    if (patch.containsKey('overwriteType') &&
        !{'standard', 'custom'}.contains(patch['overwriteType'])) {
      throw const FormatException('Invalid overwrite type');
    }
    if (!{'add', 'edit', 'delete', 'refresh'}.contains(operation)) {
      throw const FormatException('Invalid operation');
    }
    if ({'delete', 'refresh'}.contains(operation) && patch.isNotEmpty) {
      throw const FormatException('Unexpected patch');
    }
    final id = operation == 'add'
        ? snowflake.id
        : resourceId(args, 'profileId');
    if (operation == 'add' && args['profileId'] != null) {
      throw const FormatException('Unexpected ID');
    }
    final scope = ResourceScope(ResourceKind.profile, id);
    final state = await resources.environment.read(scope);
    _current(request);
    var profile = state['profile'] == null
        ? null
        : Profile.fromJson(policyObject(state['profile'], 'profile'));
    if (operation != 'add' && profile == null) {
      throw const ConfigurationChangeException('resource_profile_missing');
    }
    if (operation == 'delete') {
      state['profile'] = null;
      state['protectedContent'] = null;
      state['protectedScriptContent'] = null;
      for (final key in [
        'addedRules',
        'customRules',
        'disabledRules',
        'groups',
      ]) {
        state[key] = <Object?>[];
      }
      if (state['selectedProfileId'] == id) state['selectedProfileId'] = null;
    } else {
      profile ??= Profile(id: id, autoUpdateDuration: const Duration(hours: 1));
      if (patch['autoUpdate'] != null && patch['autoUpdate'] is! bool) {
        throw const FormatException('Invalid autoUpdate');
      }
      profile = profile.copyWith(
        label: patch.containsKey('label')
            ? policyString(patch, 'label', maximum: 256)
            : profile.label,
        url: patch.containsKey('url')
            ? policyString(patch, 'url', maximum: 4096)
            : profile.url,
        autoUpdate: patch['autoUpdate'] as bool? ?? profile.autoUpdate,
        overwriteType: patch.containsKey('overwriteType')
            ? OverwriteType.values.singleWhere(
                (value) => value.name == patch['overwriteType'],
              )
            : profile.overwriteType,
        autoUpdateDuration: patch.containsKey('autoUpdateMinutes')
            ? Duration(
                minutes: policyInt(
                  patch,
                  'autoUpdateMinutes',
                  minimum: 1,
                  maximum: 43200,
                ),
              )
            : profile.autoUpdateDuration,
      );
      if (operation == 'add' ||
          operation == 'refresh' ||
          patch.containsKey('url')) {
        final download = await gateway.downloadProfile(profile.url);
        _current(request);
        state['protectedContent'] = download['protectedContent'];
        profile = profile.copyWith(
          subscriptionInfo: SubscriptionInfo.fromJson(
            policyObject(download['subscriptionInfo'], 'subscriptionInfo'),
          ),
          lastUpdateDate: DateTime.now(),
        );
      }
      state['profile'] = profile.toJson();
    }
    return _proposal(
      await resources.propose(
        scope,
        state,
        summary: currentAppLocalizations.profiles,
      ),
    );
  }

  Future<Map<String, Object?>> _ruleProposal(AgentToolRequest request) async {
    final args = request.arguments;
    final scope = _ruleScope(args);
    final state = await resources.environment.read(scope);
    _current(request);
    final key = '${scope.scene!.name}Rules';
    final rules = policyItems(
      state,
      key,
      Rule.fromJson,
      maximum: 5000,
    ).toList();
    final operation = policyString(args, 'operation');
    if (operation == 'reorder') {
      if (args['rule'] != null ||
          args['ruleId'] != null ||
          args['order'] is! List) {
        throw const FormatException('Invalid order');
      }
      final order = (args['order'] as List).map((value) {
        return resourceId({'id': value}, 'id');
      }).toList();
      if (order.length != rules.length ||
          order.toSet().length != rules.length ||
          !order.toSet().containsAll(rules.map((rule) => rule.id))) {
        throw const FormatException('Invalid order');
      }
      final sorted = order
          .map((id) => rules.singleWhere((rule) => rule.id == id))
          .toList();
      rules
        ..clear()
        ..addAll(sorted);
    } else {
      if (!{'add', 'edit', 'delete'}.contains(operation) ||
          args['order'] != null) {
        throw const FormatException('Invalid operation');
      }
      final id = operation == 'add' ? snowflake.id : resourceId(args, 'ruleId');
      if (operation == 'add' && args['ruleId'] != null) {
        throw const FormatException('Unexpected ID');
      }
      final index = rules.indexWhere((rule) => rule.id == id);
      if (operation != 'add' && index == -1) {
        throw const ConfigurationChangeException('resource_rule_missing');
      }
      if (operation == 'delete') {
        if (args['rule'] != null) {
          throw const FormatException('Unexpected rule');
        }
        rules.removeAt(index);
      } else {
        final value = policyObject(args['rule'], 'rule');
        policyKeys(value, {
          'ruleAction',
          'content',
          'ruleTarget',
          'ruleProvider',
          'subRule',
          'noResolve',
          'src',
        });
        for (final field in ['noResolve', 'src']) {
          if (value[field] != null && value[field] is! bool) {
            throw const FormatException('Invalid boolean');
          }
        }
        for (final field in [
          'content',
          'ruleTarget',
          'ruleProvider',
          'subRule',
        ]) {
          if (value[field] != null &&
              (value[field] is! String ||
                  (value[field] as String).length > 4096)) {
            throw const FormatException('Invalid string');
          }
        }
        if (value['ruleAction'] != null &&
            !RuleAction.values.any(
              (action) => action.name == value['ruleAction'],
            )) {
          throw const FormatException('Invalid action');
        }
        final rule = Rule.fromJson({
          if (index != -1) ...rules[index].toJson(),
          ...value,
          'id': id,
        });
        if (index == -1) {
          rules.add(rule);
        } else {
          rules[index] = rule;
        }
      }
    }
    final orders = indexing.generateNKeys(rules.length);
    state[key] = rules
        .mapIndexed(
          (index, rule) => rule.copyWith(order: orders[index]).toJson(),
        )
        .toList();
    return _proposal(
      await resources.propose(
        scope,
        state,
        summary: currentAppLocalizations.rule,
      ),
    );
  }

  Future<Map<String, Object?>> _groupProposal(AgentToolRequest request) async {
    final args = request.arguments;
    final scope = ResourceScope(
      ResourceKind.groups,
      resourceId(args, 'profileId'),
    );
    final state = await resources.environment.read(scope);
    _current(request);
    final groups = policyItems(
      state,
      'groups',
      ProxyGroup.fromJson,
      maximum: 1000,
    ).toList();
    final operation = policyString(args, 'operation');
    if (!{'add', 'edit', 'delete'}.contains(operation)) {
      throw const FormatException('Invalid operation');
    }
    final id = operation == 'add' ? snowflake.id : resourceId(args, 'groupId');
    if (operation == 'add' && args['groupId'] != null) {
      throw const FormatException('Unexpected ID');
    }
    final index = groups.indexWhere((group) => group.id == id);
    if (operation != 'add' && index == -1) {
      throw const ConfigurationChangeException('resource_group_missing');
    }
    final rules = policyItems(
      state,
      'customRules',
      Rule.fromJson,
      maximum: 5000,
    ).toList();
    if (operation == 'delete') {
      if (args['group'] != null) {
        throw const FormatException('Unexpected group');
      }
      final name = groups[index].name;
      if (rules.any((rule) => rule.ruleTarget == name) ||
          groups.any(
            (group) =>
                group.id != id && (group.proxies?.contains(name) ?? false),
          )) {
        throw const ConfigurationChangeException('resource_group_referenced');
      }
      groups.removeAt(index);
    } else {
      final value = policyObject(args['group'], 'group');
      policyKeys(value, {
        'name',
        'type',
        'proxies',
        'use',
        'interval',
        'lazy',
        'disable-udp',
        'url',
        'timeout',
        'max-failed-times',
        'filter',
        'exclude-filter',
        'exclude-type',
        'expected-status',
        'include-all',
        'include-all-proxies',
        'include-all-providers',
        'hidden',
        'icon',
      });
      for (final field in [
        'lazy',
        'disable-udp',
        'include-all',
        'include-all-proxies',
        'include-all-providers',
        'hidden',
      ]) {
        if (value[field] != null && value[field] is! bool) {
          throw const FormatException('Invalid boolean');
        }
      }
      for (final field in ['interval', 'timeout', 'max-failed-times']) {
        if (value[field] != null &&
            (value[field] is! int ||
                value[field] as int < 0 ||
                value[field] as int > 86400000)) {
          throw const FormatException('Invalid integer');
        }
      }
      for (final field in [
        'name',
        'url',
        'filter',
        'exclude-filter',
        'exclude-type',
        'expected-status',
        'icon',
      ]) {
        if (value[field] != null &&
            (value[field] is! String ||
                (value[field] as String).length > 4096)) {
          throw const FormatException('Invalid string');
        }
      }
      for (final field in ['proxies', 'use']) {
        if (value[field] != null) {
          policyStrings(value, field, maximum: 5000);
        }
      }
      if (value['type'] != null &&
          !GroupType.values.any((type) => type.value == value['type'])) {
        throw const FormatException('Invalid group type');
      }
      final group = ProxyGroup.fromJson({
        if (index != -1) ...groups[index].toJson(),
        ...value,
        'id': id,
        'profileId': scope.id,
      });
      if (index == -1) {
        groups.add(group);
      } else {
        final old = groups[index].name;
        groups[index] = group;
        if (old != group.name) {
          for (var i = 0; i < groups.length; i++) {
            groups[i] = groups[i].copyWith(
              proxies: groups[i].proxies
                  ?.map((name) => name == old ? group.name : name)
                  .toList(),
            );
          }
          for (var i = 0; i < rules.length; i++) {
            if (rules[i].ruleTarget == old) {
              rules[i] = rules[i].copyWith(ruleTarget: group.name);
            }
          }
        }
      }
    }
    final orders = indexing.generateNKeys(groups.length);
    state['groups'] = groups
        .mapIndexed(
          (index, group) => group.copyWith(order: orders[index]).toJson(),
        )
        .toList();
    state['customRules'] = rules.map((rule) => rule.toJson()).toList();
    return _proposal(
      await resources.propose(
        scope,
        state,
        summary: currentAppLocalizations.proxies,
      ),
    );
  }

  Future<Map<String, Object?>> _scriptProposal(AgentToolRequest request) async {
    final args = request.arguments;
    final operation = policyString(args, 'operation');
    if (!{'add', 'edit', 'delete'}.contains(operation)) {
      throw const FormatException('Invalid operation');
    }
    final id = operation == 'add' ? snowflake.id : resourceId(args, 'scriptId');
    if (operation == 'add' && args['scriptId'] != null) {
      throw const FormatException('Unexpected ID');
    }
    final scope = ResourceScope(ResourceKind.script, id);
    final state = await resources.environment.read(scope);
    _current(request);
    final old = state['script'] == null
        ? null
        : Script.fromJson(policyObject(state['script'], 'script'));
    if (operation != 'add' && old == null) {
      throw const ConfigurationChangeException('resource_script_missing');
    }
    if (operation == 'delete') {
      if (args['label'] != null || args['content'] != null) {
        throw const FormatException('Unexpected content');
      }
      state['script'] = null;
      state['protectedContent'] = null;
    } else {
      final label = args.containsKey('label')
          ? policyString(args, 'label', maximum: 256)
          : old?.label ?? '';
      if (label.isEmpty) throw const FormatException('Missing label');
      final content = args['content'];
      if (content != null &&
          (content is! String || content.length > 512 * 1024)) {
        throw const FormatException('Invalid script');
      }
      if (operation == 'add' && content == null) {
        throw const FormatException('Missing content');
      }
      state['script'] = Script(
        id: id,
        label: label,
        lastUpdateTime: DateTime.now(),
      ).toJson();
      if (content != null) state['protectedContent'] = content;
    }
    return _proposal(
      await resources.propose(
        scope,
        state,
        summary: currentAppLocalizations.script,
      ),
    );
  }

  Future<Map<String, Object?>> _action(
    AgentToolRequest request,
    String summary,
    Future<Map<String, Object?>> Function() action,
  ) async {
    final id = policyDigest({
      'requestId': request.requestId,
      'toolCallId': request.toolCallId,
      'name': request.name,
      'arguments': request.arguments,
    });
    final existing = await controller.store.readChange(id);
    _current(request);
    if (existing != null) {
      if ({'applied', 'accepted', 'rejected'}.contains(existing.status)) {
        return {'id': id, 'status': existing.status, 'replayed': true};
      }
      throw const ConfigurationChangeException('action_not_retryable');
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final expires = now + 600000;
    await controller.store.saveChange(
      id: id,
      category: 'action:${request.name}',
      summary: summary,
      highRisk: true,
      fingerprint: policyDigest(request.arguments),
      before: const {},
      after: request.arguments,
      createdAt: now,
      expiresAt: expires,
    );
    _current(request);
    final proposal = ConfigurationProposal(
      id: id,
      summary: summary,
      highRisk: true,
      expiresAt: expires,
      differences: [
        ConfigurationDifference(
          path: request.name,
          before: null,
          after: request.arguments,
        ),
      ],
      validation: const {'reversible': false},
    );
    if (!await approve(proposal)) {
      await controller.store.changeStatus(id, 'rejected');
      return {'id': id, 'status': 'rejected'};
    }
    _current(request);
    if (DateTime.now().millisecondsSinceEpoch >= expires) {
      throw const ConfigurationChangeException(
        'configuration_proposal_expired',
      );
    }
    await controller.store.changeStatus(id, 'committing');
    _current(request);
    try {
      final result = await action();
      final status = result['status'] == 'accepted' ? 'accepted' : 'applied';
      await controller.store.changeStatus(id, status);
      return {'id': id, ...result};
    } catch (_) {
      await controller.store.changeStatus(id, 'failed', error: 'action_failed');
      rethrow;
    }
  }
}
