import 'dart:async';

import 'package:fl_clash/capabilities/service.dart';
import 'package:fl_clash/common/system.dart';
import 'package:fl_clash/common/print.dart';
import 'package:fl_clash/configuration/barrier.dart';
import 'package:fl_clash/control/password.dart';
import 'package:fl_clash/control/operations.dart';
import 'package:fl_clash/control/service.dart';
import 'package:fl_clash/control/transport.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'workbench.dart';

final localControlServiceProvider = Provider<LocalControlService>((ref) {
  final capabilities = ref.read(applicationCapabilityServiceProvider);
  final service = LocalControlService(
    passwordStore: const KeychainControlPasswordStore(),
    transport: NativeControlTransport(),
    supported: system.isMacOS,
    onDiagnostic: (event) => commonPrint.log('Local control: $event'),
    operations: ControlRequestLedger(
      load: () =>
          ref.read(workbenchDatabaseProvider).readSection('control.requests'),
      save: (value) => ref
          .read(workbenchDatabaseProvider)
          .writeSection('control.requests', value),
    ),
    executor: (command) => capabilities.execute(
      command.command,
      command.params,
      idempotencyKey: command.idempotencyKey,
      credentialGeneration: command.credentialGeneration,
    ),
    drainCapabilities: () async {
      await capabilities.drain();
      await configurationWriteBarrier.wait();
    },
    onCredentialRotated: (generation) async =>
        capabilities.invalidateCredentialGeneration(generation),
    onEnabledChanged: (enabled) => ref
        .read(workbenchDatabaseProvider)
        .writeSection('localControl', {'enabled': enabled}),
  );
  ref.onDispose(() => unawaited(service.close()));
  return service;
});
