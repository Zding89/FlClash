import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:fl_clash/ai/runtime.dart';
import 'package:fl_clash/ai/tools.dart';
import 'package:fl_clash/capabilities/gateway.dart';
import 'package:fl_clash/capabilities/service.dart';
import 'package:fl_clash/configuration/changes.dart';
import 'package:fl_clash/configuration/resources.dart';
import 'package:fl_clash/database/workbench_database.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/workbench.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Environment implements ResourceEnvironment {
  int writes = 0;
  final snapshots = <String, Map<String, Object?>>{};
  @override
  Future<Map<String, Object?>> read(ResourceScope scope) async =>
      Map<String, Object?>.from(
        jsonDecode(
              jsonEncode(
                snapshots.putIfAbsent(
                  scope.category,
                  () => {
                    'scope': scope.toJson(),
                    'profile': _profile(scope.id).toJson(),
                    'protectedContent': 'old source',
                    'protectedScriptContent': null,
                    'selectedProfileId': 7,
                    'addedRules': <Object?>[],
                    'customRules': <Object?>[],
                    'disabledRules': <Object?>[],
                    'groups': <Object?>[],
                  },
                ),
              ),
            )
            as Map,
      );
  @override
  Future<ResourceValidation> validate(
    ResourceScope scope,
    Map<String, Object?> candidate, {
    required bool approvedScript,
  }) async =>
      const ResourceValidation({'validated': true}, generatedYaml: 'fixture');
  @override
  Future<void> persist(
    ResourceScope scope,
    Map<String, Object?> candidate,
  ) async {
    writes++;
    snapshots[scope.category] = Map.of(candidate);
  }

  @override
  Future<void> activate(
    ResourceScope scope,
    Map<String, Object?> candidate, {
    String? generatedYaml,
    Map<String, Object?>? previousSnapshot,
  }) async {}
}

Profile _profile(int id) => Profile(
  id: id,
  label: 'Subscription $id',
  url: 'https://source$id.invalid/subscription',
  autoUpdateDuration: const Duration(hours: 1),
);

class _Controller extends Mock implements WorkbenchController {
  _Controller(this.store);
  @override
  final WorkbenchDatabase store;
  @override
  late Ref ref;
}

class _InternalGateway extends Mock implements AgentResourceGateway {
  int calls = 0;
  int downloads = 0;
  final profiles = <Profile>[];
  final failedUrls = <String>{};
  @override
  Future<List<Profile>> readProfiles() async => profiles;
  @override
  Future<Map<String, Object?>> downloadProfile(String url) async {
    downloads++;
    if (failedUrls.contains(url)) {
      throw const ConfigurationChangeException('resource_download_failed');
    }
    return {
      'protectedContent': 'downloaded source',
      'subscriptionInfo': const SubscriptionInfo().toJson(),
    };
  }

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
  late _Environment environment;
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
    environment = _Environment();
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
      environment: environment,
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
          expect(approvals, 1);
        },
      );
    }
  }
  for (final command in ['profile_propose', 'profiles_refresh_all']) {
    test(
      '$command reviews downloads before network and returns unapplied child cards',
      () async {
        internal.profiles.addAll([_profile(7), _profile(8)]);
        final params = command == 'profile_propose'
            ? <String, Object?>{'operation': 'refresh', 'profileId': '7'}
            : <String, Object?>{};
        AgentToolRequest action() => command == 'profile_propose'
            ? request(command, params)
            : request('application_invoke', {
                'command': command,
                'params': params,
              });
        allow = false;
        final cancelled = await tools.execute(action());
        expect(cancelled.value['status'], 'cancelled');
        expect(internal.downloads, 0);
        expect(environment.writes, 0);
        allow = true;
        final prepared = await tools.execute(action());
        expect(prepared.value['status'], 'accepted');
        await service.drain();
        final operation = await query(prepared.value['operationId'] as String);
        expect(operation['status'], 'proposal_ready');
        expect(internal.downloads, command == 'profile_propose' ? 1 : 2);
        expect(environment.writes, 0);
        final result = operation['result'] as Map;
        final child = command == 'profile_propose'
            ? result
            : (result['proposals'] as List).first as Map;
        final childId = child['operationId'] as String;
        expect((await store.readChange(childId))!.status, 'draft');
        final review = await service.reviewChange(childId);
        expect(review.validation['reviewTarget'], 'Subscription 7');
        var confirmations = 0;
        final applied = await service.confirmReviewedChange(
          childId,
          approve: (proposal) async {
            confirmations++;
            expect(proposal.validation['reviewTarget'], 'Subscription 7');
            return true;
          },
        );
        expect(applied['status'], 'applied');
        expect(environment.writes, 1);
        expect(confirmations, 1);
        expect(approvals, 2);
        expect(gateway.calls, 0);
      },
    );
  }
  for (final allFailed in [false, true]) {
    test(
      'batch subscription errors retain accurate child statuses allFailed=$allFailed',
      () async {
        internal.profiles.addAll([_profile(7), _profile(8)]);
        internal.failedUrls.add(_profile(7).url);
        if (allFailed) internal.failedUrls.add(_profile(8).url);
        final prepared = await tools.execute(
          request('application_invoke', {
            'command': 'profiles_refresh_all',
            'params': <String, Object?>{},
          }),
        );
        await service.drain();
        final operation = await query(prepared.value['operationId'] as String);
        expect(operation['status'], allFailed ? 'failed' : 'proposal_ready');
        final result = operation['result'] as Map;
        expect(result['failedCount'], allFailed ? 2 : 1);
        final children = result['proposals'] as List;
        expect(children.length, 2);
        expect((children.first as Map)['status'], 'failed');
        expect(
          (children.first as Map)['errorCode'],
          'resource_download_failed',
        );
        expect(
          (children.last as Map)['status'],
          allFailed ? 'failed' : 'pending_confirmation',
        );
        expect(environment.writes, 0);
        expect(internal.downloads, 2);
      },
    );
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
      expect((await service.cancelReviewedChange(id))['status'], 'cancelled');
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
