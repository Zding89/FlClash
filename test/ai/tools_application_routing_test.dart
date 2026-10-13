import 'dart:async';

import 'package:drift/native.dart';
import 'package:fl_clash/ai/runtime.dart';
import 'package:fl_clash/ai/tools.dart';
import 'package:fl_clash/capabilities/gateway.dart';
import 'package:fl_clash/capabilities/service.dart';
import 'package:fl_clash/configuration/changes.dart';
import 'package:fl_clash/configuration/resources.dart';
import 'package:fl_clash/database/workbench_database.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/providers/workbench.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Environment extends Mock implements ResourceEnvironment {}

class _Controller extends Mock implements WorkbenchController {
  _Controller(this.store);
  @override
  final WorkbenchDatabase store;
  @override
  late Ref ref;
}

class _InternalGateway extends Mock implements AgentResourceGateway {
  int calls = 0;
  @override
  Future<Map<String, Object?>> updateResource(
    String kind,
    String? providerName, {
    bool Function()? isCurrent,
  }) async {
    calls++;
    return {'status': 'applied'};
  }

  @override
  Future<Map<String, Object?>> openPanel(String panel) async {
    calls++;
    return {'status': 'requires_user_action'};
  }
}

class _SharedGateway implements ApplicationCapabilityGateway {
  _SharedGateway(this.store);
  final WorkbenchDatabase store;
  final started = Completer<void>();
  Completer<Map<String, Object?>>? pending;
  Future<bool> Function()? begin;
  int calls = 0;
  String outcome = 'completed';
  bool automaticBegin = true;
  String? origin;
  @override
  bool get supported => true;
  @override
  Future<String> version() async => 'fixture-version';
  @override
  Future<Map<String, Object?>> execute(
    String command,
    Map<String, Object?> params, {
    required String origin,
    Future<bool> Function()? beginMutation,
    bool Function()? isCurrent,
  }) async {
    calls++;
    this.origin = origin;
    begin = beginMutation;
    if (automaticBegin && beginMutation != null && !await beginMutation()) {
      return {'status': 'cancelled'};
    }
    if (!started.isCompleted) started.complete();
    if (pending != null) return pending!.future;
    if (outcome == 'failed') {
      throw const ConfigurationChangeException('fixture_operation_failed');
    }
    if (outcome == 'completed' && command == 'profile_import_panel') {
      final now = DateTime.now().millisecondsSinceEpoch;
      await store.saveChange(
        id: 'fixture-import-proposal',
        category: 'resource:profile:1',
        summary: 'Fixture import',
        highRisk: true,
        fingerprint: 'fixture-version',
        before: const {},
        after: const {},
        createdAt: now,
        expiresAt: now + 600000,
      );
      return {
        'proposal': {'id': 'fixture-import-proposal'},
      };
    }
    return {'status': outcome};
  }
}

void main() {
  late WorkbenchDatabase store;
  late _Controller controller;
  late _InternalGateway internal;
  late _SharedGateway gateway;
  late ProviderContainer container;
  late ApplicationCapabilityService service;
  late AgentTools tools;
  var builds = 0;
  var approvals = 0;
  var sequence = 0;
  var current = true;
  var allow = true;
  var cancelAtApproval = false;
  String? approvedId;
  setUp(() async {
    await AppLocalizations.load(const Locale('en'));
    store = WorkbenchDatabase(NativeDatabase.memory());
    controller = _Controller(store);
    internal = _InternalGateway();
    gateway = _SharedGateway(store);
    builds = 0;
    approvals = 0;
    sequence = 0;
    current = true;
    allow = true;
    cancelAtApproval = false;
    approvedId = null;
    final resources = ResourceChangeService(
      store: store,
      environment: _Environment(),
    );
    container = ProviderContainer(
      overrides: [
        applicationCapabilityServiceProvider.overrideWith((ref) {
          builds++;
          return ApplicationCapabilityService(
            ref: ref,
            controller: controller,
            gateway: gateway,
            tools: AgentTools(
              controller: controller,
              exposeApplication: false,
              approve: (_) async => false,
              resources: resources,
              gateway: internal,
            ),
          );
        }),
      ],
    );
    controller.ref = container.read(Provider<Ref>((ref) => ref));
    service = container.read(applicationCapabilityServiceProvider);
    tools = AgentTools(
      controller: controller,
      resources: resources,
      gateway: internal,
      approve: (proposal) async {
        approvals++;
        approvedId = proposal.id;
        if (cancelAtApproval) current = false;
        return allow;
      },
    );
  });
  tearDown(() async {
    if (gateway.pending != null && !gateway.pending!.isCompleted) {
      gateway.pending!.complete({'status': 'cancelled'});
    }
    await Future<void>.delayed(Duration.zero);
    await service.drain();
    container.dispose();
    await store.close();
  });
  AgentToolRequest request(String name, Map<String, Object?> args) =>
      AgentToolRequest(
        requestId: 'fixture-request',
        toolCallId: 'fixture-call-${sequence++}',
        name: name,
        arguments: args,
        isCurrent: () => current,
      );
  Future<Map<String, Object?>> query(String id) =>
      service.execute('operation_query', {'operationId': id}, origin: 'agent');
  for (final command in [
    'resource_update',
    'backup_panel',
    'profile_import_panel',
  ]) {
    for (final outcome in ['completed', 'failed', 'cancelled']) {
      test(
        'direct $command preserves queryable $outcome through the shared owner',
        () async {
          gateway.outcome = outcome;
          final params = switch (command) {
            'resource_update' => <String, Object?>{'kind': 'mmdb'},
            'backup_panel' => <String, Object?>{'action': 'backup'},
            _ => <String, Object?>{},
          };
          final result = await tools.execute(request(command, params));
          expect(result.isError, false);
          final id = result.value['operationId'] as String;
          await gateway.started.future;
          await service.drain();
          final operation = await query(id);
          if (command == 'profile_import_panel' && outcome == 'completed') {
            expect(operation['status'], 'proposal_ready');
            expect(
              (operation['result'] as Map)['operationId'],
              'fixture-import-proposal',
            );
            expect(
              (operation['result'] as Map)['status'],
              'pending_confirmation',
            );
          } else {
            expect(operation['status'], outcome);
          }
          if (outcome == 'failed') {
            expect(operation['errorCode'], 'fixture_operation_failed');
          }
          expect(gateway.origin, 'agent');
          expect(gateway.calls, 1);
          expect(internal.calls, 0);
          expect(builds, 1);
          expect(approvals, command == 'resource_update' ? 1 : 0);
        },
      );
    }
  }
  test(
    'resource approval denial and request cancellation prevent gateway work',
    () async {
      allow = false;
      final rejected = await tools.execute(
        request('resource_update', {'kind': 'mmdb'}),
      );
      expect(rejected.value['status'], 'cancelled');
      expect(
        (await query(rejected.value['operationId'] as String))['status'],
        'cancelled',
      );
      allow = true;
      cancelAtApproval = true;
      final cancelled = await tools.execute(
        request('resource_update', {'kind': 'geoip'}),
      );
      expect(cancelled.isError, true);
      expect(cancelled.value['code'], 'configuration_cancelled');
      expect((await query(approvedId!))['status'], 'cancelled');
      expect(gateway.calls, 0);
    },
  );
  test(
    'pending native input cancellation closes the mutation boundary',
    () async {
      gateway.automaticBegin = false;
      gateway.pending = Completer();
      final call = request('backup_panel', {'action': 'restore'});
      final result = await tools.execute(call);
      final id = result.value['operationId'] as String;
      await gateway.started.future;
      expect((await tools.execute(call)).value['operationId'], id);
      expect(gateway.calls, 1);
      expect((await query(id))['status'], 'requires_user_action');
      expect(
        (await service.execute('operation_cancel', {
          'operationId': id,
        }, origin: 'agent'))['status'],
        'cancelled',
      );
      expect(await gateway.begin!(), false);
      gateway.pending!.complete({'status': 'cancelled'});
      expect((await query(id))['status'], 'cancelled');
    },
  );
  test(
    'retrying one Agent tool call reuses the durable completed operation',
    () async {
      final call = request('resource_update', {'kind': 'mmdb'});
      final first = await tools.execute(call);
      await service.drain();
      final replay = await tools.execute(call);
      expect(replay.value['operationId'], first.value['operationId']);
      expect(replay.value['status'], 'completed');
      expect(gateway.calls, 1);
      expect(approvals, 1);
      final changed = AgentToolRequest(
        requestId: call.requestId,
        toolCallId: call.toolCallId,
        name: call.name,
        arguments: const {'kind': 'geoip'},
        isCurrent: () => current,
      );
      expect((await tools.execute(changed)).value['status'], 'conflict');
      expect(gateway.calls, 1);
    },
  );
  test(
    'internal tools do not forward or recurse into the shared service',
    () async {
      final runner = AgentTools(
        controller: controller,
        exposeApplication: false,
        approve: (_) async => true,
        resources: tools.resources,
        gateway: internal,
      );
      expect(
        (await runner.execute(
          request('resource_update', {'kind': 'mmdb'}),
        )).value['status'],
        'applied',
      );
      expect(
        (await runner.execute(
          request('backup_panel', {'action': 'backup'}),
        )).value['status'],
        'requires_user_action',
      );
      expect(
        (await runner.execute(
          request('profile_import_panel', {}),
        )).value['status'],
        'requires_user_action',
      );
      expect(internal.calls, 3);
      expect(gateway.calls, 0);
      expect(builds, 1);
    },
  );
}
