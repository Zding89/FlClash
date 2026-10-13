import 'package:drift/native.dart';
import 'package:fl_clash/database/workbench_database.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/policy/models.dart';
import 'package:fl_clash/providers/workbench.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class FakeBackend extends Mock implements FlutterConfigurationBackend {}

class TestWorkbench extends WorkbenchController {
  final FakeBackend fakeBackend;
  final List<LocalNode> fakeNodes;
  TestWorkbench(
    super.ref, {
    required super.store,
    required this.fakeBackend,
    required this.fakeNodes,
  });
  @override
  FlutterConfigurationBackend get backend => fakeBackend;
  @override
  Future<List<LocalNode>> loadNodes(
    String targetId, {
    bool refresh = false,
    LocalPolicyDocument? document,
  }) async => fakeNodes;
}

void main() {
  test(
    'R11 actual workbench proposal drops original-set override and retains other-set/fixed compatibility',
    () async {
      await AppLocalizations.load(const Locale('en'));
      final store = WorkbenchDatabase(NativeDatabase.memory());
      final backend = FakeBackend();
      final node = LocalNode(
        id: '1:a',
        sourceId: '1',
        label: 'Node',
        sourceLabel: 'Source',
        protocol: 'http',
        raw: {},
        attributes: const NodeAttributes(
          region: 'JP',
          regionBasis: NodeAttributeBasis.name,
        ),
      );
      const rule = LocalPolicy(
        id: 'rule',
        label: 'Rule',
        targetId: 'profile:1',
        choices: [
          PolicyChoice(type: PolicyChoiceType.node, id: '1:a'),
          PolicyChoice(type: PolicyChoiceType.nodeSet, id: 'set_a'),
          PolicyChoice(type: PolicyChoiceType.nodeSet, id: 'set_b'),
        ],
      );
      const a = PolicyNodeSet(
        id: 'set_a',
        label: 'A',
        targetId: 'profile:1',
        sourceIds: ['1'],
        regions: ['HK'],
      );
      const b = PolicyNodeSet(
        id: 'set_b',
        label: 'B',
        targetId: 'profile:1',
        sourceIds: ['1'],
        regions: ['JP'],
      );
      final provider = Provider<TestWorkbench>(
        (ref) => TestWorkbench(
          ref,
          store: store,
          fakeBackend: backend,
          fakeNodes: [node],
        ),
      );
      final container = ProviderContainer();
      addTearDown(() async {
        container.dispose();
        await store.close();
      });
      Map<String, Object?>? submitted;
      when(() => backend.readState()).thenAnswer(
        (_) async => {
          'policies': const LocalPolicyDocument(revision: 8).toJson(),
        },
      );
      when(() => backend.validate(any())).thenAnswer((invocation) async {
        submitted = Map<String, Object?>.from(
          invocation.positionalArguments.single as Map,
        );
        return {};
      });
      when(() => backend.isHighRisk(any(), any())).thenReturn(false);
      final controller = container.read(provider);
      for (final origin in ['set_a', 'set_b', null]) {
        final draft = LocalPolicyDocument(
          policies: const [rule],
          nodeSets: const [a, b],
          overrides: [
            PolicyOverride(
              policyId: 'rule',
              nodeId: '1:a',
              nodeSetId: origin,
              expiresAt: 9999999999999,
            ),
          ],
        );
        await controller.proposePolicies(draft);
        final normalized = LocalPolicyDocument.fromJson(
          policyObject(submitted!['policies'], 'policies'),
        );
        expect(normalized.revision, 9);
        if (origin == 'set_a') {
          expect(normalized.overrides, isEmpty);
        } else {
          expect(normalized.overrides.single.nodeSetId, origin);
        }
      }
      verify(() => backend.validate(any())).called(3);
    },
  );
}
