import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart' show BooleanExpressionOperators, Value;
import 'package:fl_clash/ai/runtime.dart';
import 'package:fl_clash/ai/tools.dart';
import 'package:fl_clash/configuration/changes.dart';
import 'package:fl_clash/configuration/resources.dart';
import 'package:fl_clash/database/workbench_database.dart';
import 'package:fl_clash/policy/models.dart';
import 'package:fl_clash/providers/workbench.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/ai/approval.dart';

import 'gateway.dart';
import 'manifest.dart';

final applicationCapabilityServiceProvider =
    Provider<ApplicationCapabilityService>(
      (ref) => ApplicationCapabilityService(
        ref: ref,
        controller: ref.read(workbenchControllerProvider),
      ),
    );

class ApplicationCapabilityService {
  ApplicationCapabilityService({
    required Ref ref,
    required this.controller,
    ConfigurationApproval? approve,
    ApplicationCapabilityGateway? gateway,
    AgentTools? tools,
  }) : _approve = approve,
       gateway =
           gateway ??
           FlutterApplicationCapabilityGateway(
             ref: ref,
             controller: controller,
           ) {
    _baseTools =
        tools ??
        AgentTools(
          controller: controller,
          approve: (proposal) =>
              _approve?.call(proposal) ?? Future.value(false),
          exposeApplication: false,
        );
  }

  final WorkbenchController controller;
  final ApplicationCapabilityGateway gateway;
  final ConfigurationApproval? _approve;
  late final AgentTools _baseTools;
  Future<void> _tail = Future.value();
  Future<void> _workTail = Future.value();
  int _pending = 0;
  final Map<String, Future<void>> _active = {};
  int? _credentialGeneration;
  final Set<String> _manualWaiting = {};
  final Set<String> _cancelledActions = {};

  Future<void> drain() async {
    await _tail;
    while (true) {
      final writes = _active.entries
          .where((entry) => !_manualWaiting.contains(entry.key))
          .map((entry) => entry.value)
          .toList();
      if (writes.isEmpty) return;
      await Future.wait(writes);
    }
  }

  Future<bool> _resourceChange(WorkbenchChange row) async {
    if (row.category.startsWith('resource:') ||
        row.category.startsWith('repair:')) {
      return true;
    }
    if (!row.category.startsWith('recovery:')) return false;
    final original = await controller.store.readChange(
      row.category.substring('recovery:'.length),
    );
    return original?.category.startsWith('resource:') == true;
  }

  ConfigurationProposal _capabilityProposal(WorkbenchChange row) {
    final before = policyObject(jsonDecode(row.beforePayload), 'before');
    final after = policyObject(jsonDecode(row.afterPayload), 'after');
    final command = row.category.substring('capability:'.length);
    final review = before['review'] is Map
        ? policyObject(before['review'], 'review')
        : {
            'command': command,
            'before': <String, Object?>{},
            'after': after['params'] ?? <String, Object?>{},
            'labels': <String, String>{},
          };
    return ConfigurationProposal(
      id: row.id,
      summary: row.summary,
      highRisk: row.highRisk,
      expiresAt: row.expiresAt,
      differences: configurationDifferences(review['before'], review['after']),
      validation: {'reversible': false, 'agentReview': review},
    );
  }

  ConfigurationProposal _withReviewTarget(
    ConfigurationProposal proposal,
    WorkbenchChange row,
  ) {
    if (row.category.startsWith('capability:')) return proposal;
    String? target;
    final connections = <String, Map<String, String>>{};
    for (final payload in {
      'after': row.afterPayload,
      'before': row.beforePayload,
    }.entries) {
      final data = policyObject(jsonDecode(payload.value), 'resource');
      final ai = data['ai'];
      if (ai is Map && ai['connections'] is List) {
        connections[payload.key] = {
          for (final connection in (ai['connections'] as List).whereType<Map>())
            if (connection['id'] is String && connection['label'] is String)
              connection['id'] as String: connection['label'] as String,
        };
      }
      final resource = data['resource'] is Map
          ? policyObject(data['resource'], 'resource')
          : data;
      for (final key in ['profile', 'script']) {
        final item = resource[key];
        if (item is! Map) continue;
        final label = item['label'] ?? item['name'];
        if (target == null && label is String && label.trim().isNotEmpty) {
          target = label;
          break;
        }
      }
    }
    if (target == null && connections.isEmpty) return proposal;
    return ConfigurationProposal(
      id: proposal.id,
      summary: proposal.summary,
      highRisk: proposal.highRisk,
      expiresAt: proposal.expiresAt,
      differences: proposal.differences,
      validation: {
        ...proposal.validation,
        'reviewTarget': ?target,
        if (connections.isNotEmpty) 'aiReviewConnections': connections,
      },
    );
  }

  Future<ConfigurationProposal> reviewChange(String id) async {
    final row = await controller.store.readChange(id);
    if (row == null) {
      throw const ConfigurationChangeException(
        'configuration_proposal_missing',
      );
    }
    final original = row.category.startsWith('capability:')
        ? _capabilityProposal(row)
        : await _resourceChange(row)
        ? await _baseTools.resources.readProposal(id)
        : await controller.changes.readProposal(id);
    final proposal = _withReviewTarget(original, row);
    return ConfigurationProposal(
      id: proposal.id,
      summary: proposal.summary,
      highRisk: proposal.highRisk,
      expiresAt: proposal.expiresAt,
      differences: proposal.differences,
      validation: {
        ...proposal.validation,
        'reviewStatus':
            {'draft', 'pending_confirmation'}.contains(row.status) &&
                row.expiresAt <= DateTime.now().millisecondsSinceEpoch
            ? 'expired'
            : row.status,
        'reviewCategory': row.category,
      },
    );
  }

  Future<Map<String, Object?>> confirmReviewedChange(
    String id, {
    required ConfigurationApproval approve,
    bool Function()? isCurrent,
  }) async {
    final row = await controller.store.readChange(id);
    if (row == null) {
      throw const ConfigurationChangeException(
        'configuration_proposal_missing',
      );
    }
    if (isCurrent?.call() == false) {
      return {'operationId': id, 'status': 'cancelled'};
    }
    final capability = row.category.startsWith('capability:');
    final before = capability
        ? policyObject(jsonDecode(row.beforePayload), 'before')
        : <String, Object?>{};
    final result = await execute(
      capability ? 'capability_confirm' : 'changes_commit',
      capability
          ? {
              'operationId': id,
              'digest': before['digest'],
              'version': before['version'],
            }
          : {'id': id},
      origin: 'agent',
      isCurrent: isCurrent,
      approve: (proposal) async => approve(_withReviewTarget(proposal, row)),
    );
    if (result['status'] != 'accepted') return result;
    await _active[id];
    return _query(id);
  }

  Future<Map<String, Object?>> cancelReviewedChange(String id) async {
    final row = await controller.store.readChange(id);
    if (row == null) {
      throw const ConfigurationChangeException(
        'configuration_proposal_missing',
      );
    }
    if (row.category.startsWith('capability:')) {
      return execute('operation_cancel', {'operationId': id}, origin: 'ui');
    }
    return await _resourceChange(row)
        ? _baseTools.resources.reject(id)
        : controller.changes.reject(id);
  }

  void invalidateCredentialGeneration(int generation) {
    _credentialGeneration = generation;
  }

  List<Map<String, Object?>> get manifest => [
    for (final capability in applicationCapabilities) capability.toJson(),
    for (final definition in _baseTools.definitions)
      {
        'command': definition.name,
        'domain': _domain(definition.name),
        'description': definition.description,
        'parameters': definition.parameters,
        'platforms': ['macos'],
        'risk':
            definition.name.endsWith('_read') ||
                definition.name.endsWith('_list') ||
                definition.name.endsWith('_catalog') ||
                definition.name.endsWith('_status') ||
                definition.name.endsWith('_simulate')
            ? 'read'
            : 'proposal_or_local_approval',
        'completion': 'operation_query',
      },
  ];

  static String _domain(String command) => switch (command.split('_').first) {
    'settings' => 'appearance_network',
    'policies' || 'nodes' => 'policies',
    'changes' => 'operations',
    'profile' || 'profiles' => 'profiles',
    'rule' || 'rules' || 'group' || 'groups' => 'rules',
    'script' || 'scripts' => 'scripts',
    'usage' => 'usage',
    'resource' => 'resources',
    'backup' => 'backup',
    _ => 'application',
  };

  Future<Map<String, Object?>> execute(
    String command,
    Map<String, Object?> params, {
    String? idempotencyKey,
    int? credentialGeneration,
    String origin = 'cli',
    bool Function()? isCurrent,
    ConfigurationApproval? approve,
  }) {
    if (_pending >= 16) {
      return Future.value({
        'status': 'failed',
        'errorCode': 'capability_queue_full',
      });
    }
    _pending++;
    final completion = Completer<Map<String, Object?>>();
    _tail = _tail.then((_) async {
      try {
        completion.complete(
          _bounded(
            await _execute(
              command,
              params,
              idempotencyKey: idempotencyKey,
              credentialGeneration: credentialGeneration,
              origin: origin,
              isCurrent: isCurrent ?? () => true,
              approve: approve,
            ),
          ),
        );
      } on FormatException {
        completion.complete({
          'status': 'failed',
          'errorCode': 'invalid_arguments',
        });
      } on ConfigurationChangeException catch (error) {
        completion.complete({'status': 'failed', 'errorCode': error.code});
      } catch (_) {
        completion.complete({
          'status': 'failed',
          'errorCode': 'command_failed',
        });
      }
    });
    return completion.future.whenComplete(() => _pending--);
  }

  static Map<String, Object?> _bounded(Map<String, Object?> result) {
    if (utf8.encode(jsonEncode(result)).length <= 768 * 1024) return result;
    return {
      'status': 'failed',
      'errorCode': 'result_limit',
      'useNarrowerQueryOrLocalExport': true,
    };
  }

  Future<Map<String, Object?>> _execute(
    String command,
    Map<String, Object?> params, {
    required String? idempotencyKey,
    required int? credentialGeneration,
    required String origin,
    required bool Function() isCurrent,
    required ConfigurationApproval? approve,
  }) async {
    if (!{'cli', 'agent', 'ui'}.contains(origin) ||
        command.length > 96 ||
        utf8.encode(jsonEncode(params)).length > AgentRuntime.maxFrameBytes ||
        idempotencyKey != null &&
            !RegExp(r'^[A-Za-z0-9_-]{1,96}$').hasMatch(idempotencyKey)) {
      throw const FormatException();
    }
    if (!gateway.supported) {
      return {'status': 'unsupported', 'errorCode': 'macos_required'};
    }
    if (!isCurrent() ||
        origin == 'cli' &&
            _credentialGeneration != null &&
            credentialGeneration != _credentialGeneration) {
      return {'status': 'cancelled', 'errorCode': 'credential_rotated'};
    }
    if (command == 'capabilities' || command == 'capabilities_list') {
      policyKeys(params, {});
      return {
        'status': 'completed',
        'result': {'capabilities': manifest},
      };
    }
    if (command == 'profiles_refresh_all' && origin != 'agent') {
      policyKeys(params, {});
      final result = await _refreshProfiles(
        isCurrent,
        origin,
        credentialGeneration,
      );
      return {
        'status': result['status'] == 'proposal_ready'
            ? 'pending_confirmation'
            : result['status'],
        'result': {
          'proposals': result['proposals'],
          'failedCount': result['failedCount'],
        },
      };
    }
    if (command == 'profile_propose' &&
        origin == 'agent' &&
        (params['operation'] == 'add' ||
            params['operation'] == 'refresh' ||
            params['patch'] is Map &&
                (params['patch'] as Map).containsKey('url'))) {
      final definition = _baseTools.definitions.singleWhere(
        (definition) => definition.name == command,
      );
      AgentTools.validateArguments(definition, params);
      return _prepare(
        ApplicationCapability(
          command: command,
          domain: 'profiles',
          description: definition.description,
          mutating: true,
          parameters: definition.parameters,
        ),
        params,
        idempotencyKey,
        origin,
        credentialGeneration,
        isCurrent,
        approve ?? _approve,
      );
    }
    final capability = applicationCapabilities
        .where((capability) => capability.command == command)
        .firstOrNull;
    if (capability != null) {
      AgentTools.validateArguments(capability.tool, params);
      if (command == 'local_policy_details' &&
          (params['policyId'] == null) == (params['nodeSetId'] == null)) {
        throw const FormatException();
      }
      if (command == 'operation_query') {
        return _query(policyString(params, 'operationId', maximum: 96));
      }
      if (command == 'operation_cancel' && origin != 'agent') {
        return _cancelOperation(
          policyString(params, 'operationId', maximum: 96),
        );
      }
      if (command == 'capability_confirm') {
        return _confirm(
          params,
          origin,
          credentialGeneration,
          isCurrent,
          approve: approve ?? _approve,
        );
      }
      if (origin == 'cli' &&
          {'credentials_panel', 'profile_qr_import'}.contains(command)) {
        return _prepareManual(
          capability,
          params,
          origin,
          credentialGeneration,
          idempotencyKey,
        );
      }
      if (capability.mutating) {
        return _prepare(
          capability,
          params,
          idempotencyKey,
          origin,
          credentialGeneration,
          isCurrent,
          approve ?? _approve,
        );
      }
      if (command == 'source_repair_propose' ||
          command == 'profile_file_propose' ||
          command == 'script_patch' ||
          command == 'agent_settings_propose') {
        final lookupSection = idempotencyKey == null
            ? null
            : 'capability.lookup.${policyDigest({'origin': origin, 'key': idempotencyKey})}';
        final fingerprint = policyDigest({
          'command': command,
          'params': params,
        });
        if (lookupSection != null) {
          final lookup = await controller.store.readSection(lookupSection);
          if (lookup != null) {
            if (lookup['fingerprint'] != fingerprint) {
              return {
                'status': 'conflict',
                'errorCode': 'idempotency_conflict',
              };
            }
            if (lookup['operationId'] is String) {
              return _query(lookup['operationId'] as String);
            }
          }
        }
        final result = await gateway.execute(command, params, origin: origin);
        final response = await _decorateProposal(
          result,
          origin: origin,
          credentialGeneration: credentialGeneration,
        );
        if (lookupSection != null && response['operationId'] is String) {
          await controller.store.writeSection(lookupSection, {
            'fingerprint': fingerprint,
            'operationId': response['operationId'],
          });
        }
        return response;
      }
      if (command == 'credentials_panel' ||
          command == 'profile_qr_import' ||
          command == 'file_grant' && origin == 'agent') {
        return _prepareManual(
          capability,
          params,
          origin,
          credentialGeneration,
          idempotencyKey,
        );
      }
      final result = await gateway.execute(command, params, origin: origin);
      return {
        'status': result['status'] ?? 'completed',
        'result': redactResource(result),
      };
    }
    if (command == 'backup_panel' || command == 'profile_import_panel') {
      final definition = _baseTools.definitions.singleWhere(
        (definition) => definition.name == command,
      );
      AgentTools.validateArguments(definition, params);
      if (origin == 'agent') {
        return _prepare(
          ApplicationCapability(
            command: command,
            domain: 'files',
            description: definition.description,
            mutating: true,
            parameters: definition.parameters,
          ),
          params,
          idempotencyKey,
          origin,
          credentialGeneration,
          isCurrent,
          approve ?? _approve,
        );
      }
      return _prepareManual(
        ApplicationCapability(
          command: command,
          domain: 'files',
          description: definition.description,
        ),
        params,
        origin,
        credentialGeneration,
        idempotencyKey,
      );
    }
    if ({
      'resource_update',
      'usage_set_enabled',
      'usage_clear',
    }.contains(command)) {
      final definition = _baseTools.definitions.singleWhere(
        (definition) => definition.name == command,
      );
      AgentTools.validateArguments(definition, params);
      return _prepare(
        ApplicationCapability(
          command: command,
          domain: _domain(command),
          description: definition.description,
          mutating: true,
          parameters: definition.parameters,
        ),
        params,
        idempotencyKey,
        origin,
        credentialGeneration,
        isCurrent,
        approve ?? _approve,
      );
    }
    final definition = _baseTools.definitions
        .where((definition) => definition.name == command)
        .firstOrNull;
    if (definition == null) {
      return {'status': 'failed', 'errorCode': 'command_unknown'};
    }
    final arguments = Map<String, Object?>.from(params);
    final confirmation = arguments.remove('confirmation');
    AgentTools.validateArguments(definition, arguments);
    ConfigurationApproval? localApproval = approve ?? _approve;
    if (origin == 'cli' && command == 'changes_commit') {
      final row = await controller.store.readChange(
        policyString(arguments, 'id'),
      );
      if (row == null || row.category.startsWith('capability:')) {
        return {'status': 'failed', 'errorCode': 'proposal_missing'};
      }
      if (confirmation is! Map ||
          confirmation['digest'] != _proposalDigest(row) ||
          confirmation['version'] != row.fingerprint) {
        return {'status': 'conflict', 'errorCode': 'confirmation_mismatch'};
      }
      final authority = await controller.store.readSection(
        'capability.authority.${row.id}',
      );
      if (authority?['origin'] == 'cli' &&
          authority?['credentialGeneration'] != credentialGeneration) {
        return {
          'status': 'conflict',
          'operationId': row.id,
          'errorCode': 'confirmation_stale',
        };
      }
      final cliOwned = authority?['origin'] == 'cli';
      localApproval = (proposal) async {
        if (!cliOwned ||
            proposal.validation['requiresScriptExecutionApproval'] == true ||
            proposal.validation.containsKey('finalConfigDifferences')) {
          final context = globalState.navigatorKey.currentContext;
          return context != null && context.mounted
              ? showAiConfigurationApproval(context, proposal)
              : false;
        }
        return true;
      };
    } else if (confirmation != null) {
      throw const FormatException();
    }
    final lookupSection = idempotencyKey == null
        ? null
        : 'capability.lookup.${policyDigest({'origin': origin, 'key': idempotencyKey})}';
    final lookupFingerprint = policyDigest({
      'command': command,
      'params': params,
    });
    if (lookupSection != null && command != 'changes_commit') {
      final lookup = await controller.store.readSection(lookupSection);
      if (lookup != null) {
        if (lookup['fingerprint'] != lookupFingerprint) {
          return {'status': 'conflict', 'errorCode': 'idempotency_conflict'};
        }
        if (lookup['operationId'] is String) {
          return _query(lookup['operationId'] as String);
        }
      }
    }
    final tools = AgentTools(
      controller: controller,
      approve: localApproval ?? (_) async => false,
      requireApproval: origin == 'agent',
      resources: _baseTools.resources,
      gateway: _baseTools.gateway,
      exposeApplication: false,
    );
    Future<Map<String, Object?>> invoke() async {
      final result = await tools.execute(
        AgentToolRequest(
          requestId: idempotencyKey ?? _id(),
          toolCallId: idempotencyKey ?? _id(),
          name: command,
          arguments: arguments,
          isCurrent: isCurrent,
        ),
      );
      if (result.isError) {
        return {'status': 'failed', 'errorCode': result.value['code']};
      }
      final response = await _decorateProposal(
        result.value,
        origin:
            command.endsWith('_propose') ||
                {
                  'changes_undo',
                  'rule_set_disabled',
                  'script_select',
                }.contains(command)
            ? origin
            : null,
        credentialGeneration: credentialGeneration,
      );
      if (lookupSection != null && response['operationId'] is String) {
        await controller.store.writeSection(lookupSection, {
          'fingerprint': lookupFingerprint,
          'operationId': response['operationId'],
        });
      }
      return response;
    }

    if (command == 'changes_commit') {
      final id = policyString(arguments, 'id');
      if (_active.containsKey(id)) {
        return {'status': 'accepted', 'operationId': id};
      }
      if (_active.length >= 16) {
        return {'status': 'failed', 'errorCode': 'capability_queue_full'};
      }
      final work = _workTail
          .then((_) async {
            final result = await invoke();
            await controller.store.writeSection(
              'capability.result.$id',
              result,
            );
          })
          .catchError((Object _) async {
            await controller.store.writeSection('capability.result.$id', {
              'status': 'failed',
              'errorCode': 'operation_failed',
            });
          });
      _workTail = work;
      _active[id] = work;
      unawaited(
        work.whenComplete(() {
          _active.remove(id);
          _manualWaiting.remove(id);
          _cancelledActions.remove(id);
        }),
      );
      return {'status': 'accepted', 'operationId': id};
    }
    return invoke();
  }

  Future<Map<String, Object?>> _cancelOperation(String id) async {
    final row = await controller.store.readChange(id);
    if (row == null || !row.category.startsWith('capability:')) {
      return {'status': 'failed', 'errorCode': 'operation_missing'};
    }
    if (row.category == 'capability:proxy_test' && _active.containsKey(id)) {
      _cancelledActions.add(id);
      return {
        'status': 'pending',
        'operationId': id,
        'cancellationRequested': true,
      };
    }
    if (row.status == 'queued') {
      if (_active.containsKey(id)) _cancelledActions.add(id);
      await controller.store.changeStatus(id, 'cancelled');
      return {'status': 'cancelled', 'operationId': id};
    }
    if (_active.containsKey(id) && !_manualWaiting.contains(id) ||
        row.status == 'running') {
      return {
        'status': 'pending',
        'operationId': id,
        'errorCode': 'transaction_in_progress',
      };
    }
    if (!{
      'pending_confirmation',
      'requires_user_action',
    }.contains(row.status)) {
      return _query(id);
    }
    if (_active.containsKey(id)) _cancelledActions.add(id);
    await controller.store.changeStatus(id, 'cancelled');
    return {'status': 'cancelled', 'operationId': id};
  }

  Future<Map<String, Object?>> _refreshProfiles(
    bool Function() isCurrent,
    String origin,
    int? credentialGeneration,
  ) async {
    final profiles = await _baseTools.gateway.readProfiles();
    if (profiles.length > 100) throw const FormatException();
    final proposals = <Map<String, Object?>>[];
    for (final profile in profiles.where((profile) => profile.url.isNotEmpty)) {
      if (!isCurrent()) {
        return {'status': 'cancelled', 'proposals': proposals};
      }
      final result = await _baseTools.execute(
        AgentToolRequest(
          requestId: _id(),
          toolCallId: _id(),
          name: 'profile_propose',
          arguments: {'operation': 'refresh', 'profileId': '${profile.id}'},
          isCurrent: isCurrent,
        ),
      );
      proposals.add({
        'profileId': '${profile.id}',
        if (result.isError) ...{
          'status': 'failed',
          'errorCode': result.value['code'],
          'result': result.value,
        } else
          ...await _decorateProposal(
            result.value,
            origin: origin,
            credentialGeneration: credentialGeneration,
          ),
      });
    }
    final failed = proposals.where((row) => row['status'] == 'failed').length;
    return {
      'status': proposals.isEmpty
          ? 'completed'
          : failed == proposals.length
          ? 'failed'
          : 'proposal_ready',
      'proposals': proposals,
      'failedCount': failed,
    };
  }

  Future<Map<String, Object?>> _executePrepared(
    String command,
    Map<String, Object?> params,
    String origin,
    int? generation,
    bool Function() isCurrent,
    Future<bool> Function()? beginMutation,
  ) async {
    if (command == 'operation_cancel') {
      return _cancelOperation(policyString(params, 'operationId', maximum: 96));
    }
    if (command == 'profiles_refresh_all') {
      return _refreshProfiles(isCurrent, origin, generation);
    }
    if (command == 'profile_propose') {
      final result = await _baseTools.execute(
        AgentToolRequest(
          requestId: _id(),
          toolCallId: _id(),
          name: command,
          arguments: params,
          isCurrent: isCurrent,
        ),
      );
      return result.isError
          ? {'status': 'failed', 'errorCode': result.value['code']}
          : result.value;
    }
    return gateway.execute(
      command,
      params,
      origin: origin,
      isCurrent: isCurrent,
      beginMutation: beginMutation,
    );
  }

  static Map<String, Object?> _safeProposal(Map<String, Object?> result) {
    final proposal = result['proposal'];
    if (proposal is! Map) return redactResource(result);
    final validation = proposal['validation'] is Map
        ? Map<String, Object?>.from(proposal['validation'] as Map)
        : <String, Object?>{};
    final localOnly = validation.remove('finalConfigDifferences') != null;
    final differences = proposal['differences'] is List
        ? proposal['differences'] as List
        : const [];
    return {
      ...redactResource(result),
      'proposal': {
        ...Map<String, Object?>.from(proposal),
        'validation': {
          ...redactResource(validation),
          if (localOnly) 'finalDifferencesAvailableLocally': true,
        },
        'differenceCount': differences.length,
        'differences': [
          for (final difference in differences.take(50))
            if (difference is Map)
              if (RegExp(
                r'(protected|secret|password|token|credential|authorization|api.?key)',
                caseSensitive: false,
              ).hasMatch('${difference['path']}'))
                {'path': difference['path'], 'redacted': true}
              else
                redactResource(Map<String, Object?>.from(difference)),
        ],
      },
    };
  }

  Future<Map<String, Object?>> _decorateProposal(
    Map<String, Object?> result, {
    String? origin,
    int? credentialGeneration,
  }) async {
    result = _safeProposal(result);
    final proposal = result['proposal'];
    if (proposal is Map && proposal['id'] is String) {
      final row = await controller.store.readChange(proposal['id'] as String);
      if (row != null) {
        if (origin != null &&
            row.status == 'draft' &&
            await controller.store.readSection(
                  'capability.authority.${row.id}',
                ) ==
                null) {
          await controller.store.writeSection(
            'capability.authority.${row.id}',
            {'origin': origin, 'credentialGeneration': credentialGeneration},
          );
        }
        return {
          'status': 'pending_confirmation',
          'operationId': row.id,
          'result': result,
          'confirmation': {
            'digest': _proposalDigest(row),
            'version': row.fingerprint,
          },
        };
      }
    }
    return {'status': result['status'] ?? 'completed', 'result': result};
  }

  static String _proposalDigest(WorkbenchChange row) => policyDigest({
    'id': row.id,
    'fingerprint': row.fingerprint,
    'afterDigest': policyDigest(jsonDecode(row.afterPayload)),
    'expiresAt': row.expiresAt,
  });

  static String _id() => List.generate(
    16,
    (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();

  Future<Map<String, Object?>> _prepare(
    ApplicationCapability capability,
    Map<String, Object?> params,
    String? idempotencyKey,
    String origin,
    int? credentialGeneration,
    bool Function() isCurrent,
    ConfigurationApproval? approve,
  ) async {
    if (_active.length >= 16) {
      throw const ConfigurationChangeException('capability_queue_full');
    }
    final id = idempotencyKey == null
        ? _id()
        : policyDigest({'origin': origin, 'key': idempotencyKey});
    final fingerprint = policyDigest({
      'command': capability.command,
      'params': params,
    });
    final existing = await controller.store.readChange(id);
    if (existing != null) {
      if (existing.fingerprint != fingerprint) {
        return {
          'status': 'conflict',
          'operationId': id,
          'errorCode': 'idempotency_conflict',
        };
      }
      return _query(id);
    }
    final version = await gateway.version();
    final review = gateway is ApplicationReviewGateway
        ? await (gateway as ApplicationReviewGateway).reviewState(
            capability.command,
            params,
          )
        : {
            'command': capability.command,
            'before': <String, Object?>{},
            'after': redactResource(params),
            'labels': <String, String>{},
          };
    final digest = policyDigest({
      'command': capability.command,
      'params': params,
      'version': version,
    });
    final now = DateTime.now().millisecondsSinceEpoch;
    await controller.store.saveChange(
      id: id,
      category: 'capability:${capability.command}',
      summary: capability.description,
      highRisk: true,
      fingerprint: fingerprint,
      before: {
        'version': version,
        'digest': digest,
        'origin': origin,
        'credentialGeneration': credentialGeneration,
        'review': review,
      },
      after: {'command': capability.command, 'params': params},
      createdAt: now,
      expiresAt: now + 600000,
    );
    await controller.store.changeStatus(id, 'pending_confirmation');
    if (origin != 'cli' && approve != null) {
      return _confirm(
        {'operationId': id, 'digest': digest, 'version': version},
        origin,
        credentialGeneration,
        isCurrent,
        approve: approve,
      );
    }
    return _query(id);
  }

  Future<Map<String, Object?>> _confirm(
    Map<String, Object?> params,
    String origin,
    int? credentialGeneration,
    bool Function() isCurrent, {
    ConfigurationApproval? approve,
  }) async {
    final id = policyString(params, 'operationId', maximum: 96);
    final row = await controller.store.readChange(id);
    if (row == null || !row.category.startsWith('capability:')) {
      return {'status': 'failed', 'errorCode': 'operation_missing'};
    }
    if (row.status != 'pending_confirmation') return _query(id);
    final before = policyObject(jsonDecode(row.beforePayload), 'before');
    final after = policyObject(jsonDecode(row.afterPayload), 'after');
    final command = policyString(after, 'command', maximum: 96);
    final arguments = policyObject(after['params'], 'params');
    if (before['origin'] != origin ||
        before['digest'] != params['digest'] ||
        before['version'] != params['version'] ||
        origin == 'cli' &&
            (before['credentialGeneration'] != credentialGeneration ||
                _credentialGeneration != null &&
                    credentialGeneration != _credentialGeneration) ||
        !isCurrent() ||
        await gateway.version() != before['version'] ||
        !await _reviewMatches(before, command, arguments) ||
        DateTime.now().millisecondsSinceEpoch >= row.expiresAt) {
      return {
        'status': 'conflict',
        'operationId': id,
        'errorCode': 'confirmation_stale',
      };
    }
    if (_active.length >= 16) {
      return {
        'status': 'failed',
        'operationId': id,
        'errorCode': 'capability_queue_full',
      };
    }
    if (origin != 'cli') {
      final accepted = await approve?.call(_capabilityProposal(row));
      if (accepted != true || !isCurrent()) {
        await (controller.store.update(controller.store.workbenchChanges)
              ..where(
                (change) =>
                    change.id.equals(id) &
                    change.status.equals('pending_confirmation'),
              ))
            .write(const WorkbenchChangesCompanion(status: Value('cancelled')));
        return _query(id);
      }
    }
    if (!isCurrent() ||
        await gateway.version() != before['version'] ||
        !await _reviewMatches(before, command, arguments) ||
        DateTime.now().millisecondsSinceEpoch >= row.expiresAt) {
      return {
        'status': 'conflict',
        'operationId': id,
        'errorCode': 'confirmation_stale',
      };
    }
    final claimed =
        await (controller.store.update(controller.store.workbenchChanges)
              ..where(
                (change) =>
                    change.id.equals(id) &
                    change.status.equals('pending_confirmation'),
              ))
            .write(const WorkbenchChangesCompanion(status: Value('queued')));
    if (claimed != 1) return _query(id);
    final lifecycle = {
      'connection_set',
      'core_restart',
      'operation_cancel',
    }.contains(command);
    final work = lifecycle
        ? _run(
            id,
            command,
            arguments,
            origin,
            generation: credentialGeneration,
            isCurrent: isCurrent,
          )
        : _workTail.then(
            (_) => _run(
              id,
              command,
              arguments,
              origin,
              generation: credentialGeneration,
              isCurrent: isCurrent,
            ),
          );
    if (!lifecycle) _workTail = work;
    _active[id] = work;
    unawaited(
      work.whenComplete(() {
        _active.remove(id);
        _manualWaiting.remove(id);
        _cancelledActions.remove(id);
      }),
    );
    return {'status': 'accepted', 'operationId': id};
  }

  Future<bool> _reviewMatches(
    Map<String, Object?> before,
    String command,
    Map<String, Object?> params,
  ) async {
    if (before['review'] == null || gateway is! ApplicationReviewGateway) {
      return true;
    }
    final current = await (gateway as ApplicationReviewGateway).reviewState(
      command,
      params,
    );
    return policyDigest(current) == policyDigest(before['review']);
  }

  Future<void> _run(
    String id,
    String command,
    Map<String, Object?> params,
    String origin, {
    bool manual = false,
    int? generation,
    bool Function()? isCurrent,
  }) async {
    bool current() =>
        isCurrent?.call() != false && !_cancelledActions.contains(id);
    try {
      if (!manual) {
        final row = await controller.store.readChange(id);
        if (row == null) {
          throw const ConfigurationChangeException('operation_missing');
        }
        final before = policyObject(jsonDecode(row.beforePayload), 'before');
        Future<bool> valid() async {
          if (row.status == 'cancelled' || !current()) {
            await controller.store.changeStatus(id, 'cancelled');
            return false;
          }
          if (row.status != 'queued' ||
              DateTime.now().millisecondsSinceEpoch >= row.expiresAt ||
              origin == 'cli' &&
                  _credentialGeneration != null &&
                  generation != _credentialGeneration ||
              origin == 'cli' && before['credentialGeneration'] != generation) {
            await controller.store.changeStatus(
              id,
              'conflict',
              error: 'confirmation_stale',
            );
            return false;
          }
          return true;
        }

        if (!await valid()) return;
        if (await gateway.version() != before['version'] ||
            !await _reviewMatches(before, command, params)) {
          await controller.store.changeStatus(
            id,
            'conflict',
            error: 'configuration_version_conflict',
          );
          return;
        }
        if (!await valid()) return;
        await controller.store.changeStatus(id, 'running');
        if (!await valid()) return;
      }
      if (command == 'connection_set' &&
          gateway is ApplicationCompletionGateway) {
        final basis = await (gateway as ApplicationCompletionGateway)
            .captureActivationBasis();
        if (basis != null) {
          await controller.store.writeSection(
            'capability.activation.$id',
            basis.toJson(),
          );
        }
      }
      final localInput = {
        'backup_panel',
        'profile_import_panel',
        'profile_qr_import',
        'credentials_panel',
        'file_grant',
      }.contains(command);
      if (localInput && !manual) {
        _manualWaiting.add(id);
        await controller.store.changeStatus(id, 'requires_user_action');
      }
      final result = await _executePrepared(
        command,
        params,
        origin,
        generation,
        current,
        manual || localInput
            ? () async {
                final row = await controller.store.readChange(id);
                if (row == null ||
                    row.status == 'cancelled' ||
                    !current() ||
                    DateTime.now().millisecondsSinceEpoch >= row.expiresAt ||
                    origin == 'cli' &&
                        _credentialGeneration != null &&
                        generation != _credentialGeneration) {
                  return false;
                }
                _manualWaiting.remove(id);
                await controller.store.changeStatus(id, 'running');
                return true;
              }
            : null,
      );
      final row = await controller.store.readChange(id);
      if (row?.status == 'cancelled') return;
      await controller.store.writeSection(
        'capability.result.$id',
        result['proposal'] is Map
            ? await _decorateProposal(
                result,
                origin: origin,
                credentialGeneration: generation,
              )
            : _safeProposal(result),
      );
      await controller.store.changeStatus(
        id,
        result['proposal'] is Map
            ? 'proposal_ready'
            : result['status'] as String? ?? 'completed',
      );
    } on ConfigurationChangeException catch (error) {
      await controller.store.changeStatus(id, 'failed', error: error.code);
    } catch (_) {
      await controller.store.changeStatus(
        id,
        'failed',
        error: 'operation_failed',
      );
    }
  }

  Future<Map<String, Object?>> _prepareManual(
    ApplicationCapability capability,
    Map<String, Object?> params,
    String origin,
    int? generation,
    String? idempotencyKey,
  ) async {
    if (_active.length >= 16) {
      throw const ConfigurationChangeException('capability_queue_full');
    }
    final id = idempotencyKey == null
        ? _id()
        : policyDigest({'origin': origin, 'key': idempotencyKey});
    final fingerprint = policyDigest({
      'command': capability.command,
      'params': params,
    });
    final existing = await controller.store.readChange(id);
    if (existing != null) {
      if (existing.fingerprint != fingerprint) {
        return {
          'status': 'conflict',
          'operationId': id,
          'errorCode': 'idempotency_conflict',
        };
      }
      return _query(id);
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    await controller.store.saveChange(
      id: id,
      category: 'capability:${capability.command}',
      summary: capability.description,
      highRisk: false,
      fingerprint: fingerprint,
      before: {},
      after: {'command': capability.command},
      createdAt: now,
      expiresAt: now + 600000,
    );
    await controller.store.changeStatus(id, 'requires_user_action');
    _manualWaiting.add(id);
    final work = _run(
      id,
      capability.command,
      params,
      origin,
      manual: true,
      generation: generation,
    );
    _active[id] = work;
    unawaited(
      work.whenComplete(() {
        _active.remove(id);
        _manualWaiting.remove(id);
        _cancelledActions.remove(id);
      }),
    );
    return {'status': 'requires_user_action', 'operationId': id};
  }

  Future<Map<String, Object?>?> _refreshCompletion(
    WorkbenchChange operation,
    Map<String, Object?>? result,
  ) async {
    if (!{'applied', 'completed'}.contains(operation.status) ||
        _active.containsKey(operation.id)) {
      return result;
    }
    const categories = {'policies', 'settings', 'ai', 'target', 'undo'};
    var changeId = categories.contains(operation.category)
        ? operation.id
        : null;
    final command = operation.category.startsWith('capability:')
        ? operation.category.substring('capability:'.length)
        : null;
    if (command == 'profile_select' && result?['id'] is String) {
      final selected = await controller.store.readChange(
        result!['id'] as String,
      );
      if (selected?.category == 'target') changeId = selected!.id;
    }
    if (command == 'profile_select' && changeId == null) {
      return <String, Object?>{...?result, 'currentStateMatches': false}
        ..remove('completion');
    }
    if (operation.category.startsWith('recovery:')) {
      final original = await controller.store.readChange(
        operation.category.substring('recovery:'.length),
      );
      if (original != null && categories.contains(original.category)) {
        changeId = operation.id;
      }
    }
    if (changeId != null) {
      final refreshed = <String, Object?>{...?result, 'id': changeId}
        ..remove('completion');
      try {
        refreshed.addAll(await controller.changes.completionStatus(changeId));
      } catch (_) {
        refreshed['currentStateMatches'] = false;
      }
      return refreshed;
    }
    if (command == 'connection_set' &&
        gateway is ApplicationCompletionGateway) {
      final stored = await controller.store.readSection(
        'capability.activation.${operation.id}',
      );
      if (stored == null) return result;
      final refreshed = Map<String, Object?>.from(result ?? {})
        ..remove('completion');
      try {
        final receipt = await (gateway as ApplicationCompletionGateway)
            .readActivationBasis(ConfigurationActivationBasis.fromJson(stored));
        final payload = policyObject(
          jsonDecode(operation.afterPayload),
          'operation',
        );
        final arguments = policyObject(payload['params'], 'params');
        final requested = policyBool(arguments, 'running');
        final matches =
            receipt.currentStateMatches &&
            receipt.activation?.running == requested;
        refreshed['completion'] = ConfigurationCompletionReceipt(
          persisted: receipt.persisted,
          currentStateMatches: matches,
          scope: receipt.scope,
          activation: receipt.activation,
        ).toJson();
        refreshed['currentStateMatches'] = matches;
        refreshed['running'] = receipt.activation?.running;
        refreshed['requestedRunning'] = requested;
      } catch (_) {
        refreshed['currentStateMatches'] = false;
      }
      return refreshed;
    }
    return result;
  }

  Future<Map<String, Object?>> _query(String id) async {
    final row = await controller.store.readChange(id);
    if (row == null) {
      return {'status': 'failed', 'errorCode': 'operation_missing'};
    }
    if (!row.category.startsWith('capability:')) {
      final result = await _refreshCompletion(
        row,
        await controller.store.readSection('capability.result.$id'),
      );
      return {
        'status': _active.containsKey(id)
            ? 'running'
            : result?['status'] ??
                  (row.status == 'draft' ? 'pending_confirmation' : row.status),
        'operationId': id,
        'errorCode': result?['errorCode'] ?? row.error,
        'result':
            result ??
            (row.status == 'draft'
                ? _safeProposal({
                    'proposal': {
                      'id': row.id,
                      'summary': row.summary,
                      'highRisk': row.highRisk,
                      'expiresAt': row.expiresAt,
                      'differences': configurationDifferences(
                        jsonDecode(row.beforePayload),
                        jsonDecode(row.afterPayload),
                      ).map((difference) => difference.toJson()).toList(),
                    },
                  })
                : null),
        if (row.status == 'draft')
          'confirmation': {
            'digest': _proposalDigest(row),
            'version': row.fingerprint,
          },
      };
    }
    final before = policyObject(jsonDecode(row.beforePayload), 'before');
    if (row.status == 'requires_user_action' && !_active.containsKey(id)) {
      await controller.store.changeStatus(
        id,
        'cancelled',
        error: 'manual_operation_interrupted',
      );
      return {
        'status': 'cancelled',
        'operationId': id,
        'errorCode': 'manual_operation_interrupted',
      };
    }
    final status =
        {'running', 'queued'}.contains(row.status) && !_active.containsKey(id)
        ? 'requires_recovery'
        : row.status;
    return {
      'status': status,
      'operationId': id,
      'summary': row.summary,
      'createdAt': row.createdAt,
      'errorCode': row.error,
      if (row.status == 'pending_confirmation')
        'preview': redactResource(
          policyObject(jsonDecode(row.afterPayload), 'after'),
        ),
      if (row.status == 'pending_confirmation')
        'proposal': _capabilityProposal(row).toJson(),
      if (row.status == 'pending_confirmation')
        'confirmation': {
          'digest': before['digest'],
          'version': before['version'],
        },
      'result': await _refreshCompletion(
        row,
        await controller.store.readSection('capability.result.$id'),
      ),
    };
  }
}
