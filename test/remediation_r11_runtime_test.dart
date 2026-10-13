import 'package:drift/native.dart';
import 'package:fl_clash/configuration/changes.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/database/workbench_database.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/policy/models.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/workbench.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class FakeCore extends Mock implements CoreHandlerInterface {}

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
String key(String nodeId, {String? set}) => PolicyOverride(
  policyId: 'rule',
  nodeId: nodeId,
  nodeSetId: set,
  expiresAt: 1,
).selectionKey;
void main() {
  late WorkbenchDatabase store;
  late ProviderContainer container;
  late WorkbenchController workbench;
  late FakeCore fake;
  late CoreController core;
  late Map<String, Object?> snapshot;
  late Map<String, List<Map<String, Object?>>> rows;
  late List<Map<String, Object?>> requests;
  Map<String, Object?> Function(Map<String, Object?> request)? change;
  const document = LocalPolicyDocument(revision: 7);
  setUp(() {
    store = WorkbenchDatabase(NativeDatabase.memory());
    final provider = Provider<WorkbenchController>(
      (ref) => WorkbenchController(ref, store: store),
    );
    container = ProviderContainer(
      overrides: [
        coreStatusProvider.overrideWithBuild(
          (ref, notifier) => CoreStatus.connected,
        ),
      ],
    );
    workbench = container.read(provider);
    fake = FakeCore();
    core = CoreController.test(fake);
    snapshot = {'enabled': true, 'revision': 10, 'documentRevision': 7};
    rows = {
      'rule': [
        {'nodeId': '1:a', 'eligible': true, 'fixedEligible': false},
        {'nodeId': '1:b', 'eligible': false},
      ],
      'set_a': [
        {'nodeId': '1:a', 'eligible': false},
      ],
      'set_b': [
        {'nodeId': '1:a', 'eligible': true},
        {'nodeId': '1:b', 'eligible': true},
      ],
    };
    requests = [];
    change = null;
    when(() => fake.getLocalPolicyStatus()).thenAnswer((_) async => snapshot);
    when(() => fake.getLocalPolicyDetails(any())).thenAnswer((
      invocation,
    ) async {
      final request = Map<String, Object?>.from(
        invocation.positionalArguments.single as Map,
      );
      requests.add(request);
      if (change != null) return change!(request);
      final identity = request['policyId'] ?? request['nodeSetId'];
      return {
        'revision': 10,
        'targetId': 'profile:1',
        if (request['policyId'] != null) 'policyId': identity,
        if (request['nodeSetId'] != null) 'nodeSetId': identity,
        'offset': request['offset'],
        'hasMore': false,
        'nodes': rows[identity],
      };
    });
  });
  tearDown(() async {
    container.dispose();
    await store.close();
    CoreController.resetInstance();
  });
  test(
    'R11 fixed health cannot borrow collection health; dynamic origin uses both guards',
    () async {
      final eligible = await workbench.eligibleOverrideChoices(
        document,
        rule,
        controller: core,
      );
      expect(eligible, {key('1:a', set: 'set_b')});
      expect(eligible.contains(key('1:a')), isFalse);
      expect(eligible.contains(key('1:a', set: 'set_a')), isFalse);
      expect(eligible.contains(key('1:b', set: 'set_b')), isFalse);
      expect(requests.length, 3);
    },
  );
  test(
    'R11 new and legacy fixed eligible true selectable; missing field remains unknown',
    () async {
      const old = LocalPolicy(
        id: 'rule',
        label: 'Rule',
        targetId: 'profile:1',
        candidateNodeIds: ['1:a'],
      );
      rows['rule'] = [
        {'nodeId': '1:a', 'eligible': true, 'fixedEligible': true},
      ];
      expect(
        await workbench.eligibleOverrideChoices(
          document,
          old,
          controller: core,
        ),
        {key('1:a')},
      );
      expect(
        (await workbench.eligibleOverrideChoices(
          document,
          rule,
          controller: core,
        )).contains(key('1:a')),
        isTrue,
      );
      rows['rule'] = [
        {'nodeId': '1:a', 'eligible': true},
      ];
      expect(
        await workbench.eligibleOverrideChoices(
          document,
          old,
          controller: core,
        ),
        isEmpty,
      );
    },
  );
  test(
    'R11 snapshot of different document is rejected before paging',
    () async {
      snapshot['documentRevision'] = 6;
      await expectLater(
        workbench.eligibleOverrideChoices(document, rule, controller: core),
        throwsA(isA<ConfigurationChangeException>()),
      );
      expect(requests, isEmpty);
    },
  );
  test(
    'R11 pagination reads beyond first 200 and rejects stale revision',
    () async {
      change = (request) => {
        'revision': 10,
        'targetId': 'profile:1',
        if (request['policyId'] != null) 'policyId': request['policyId'],
        if (request['nodeSetId'] != null) 'nodeSetId': request['nodeSetId'],
        'offset': request['offset'],
        'hasMore': request['policyId'] != null && request['offset'] == 0,
        'nodes': request['policyId'] != null && request['offset'] == 200
            ? [
                {'nodeId': '1:a', 'eligible': true, 'fixedEligible': true},
              ]
            : <Object?>[],
      };
      expect(
        await workbench.eligibleOverrideChoices(
          document,
          rule,
          controller: core,
        ),
        {key('1:a')},
      );
      expect(requests.any((request) => request['offset'] == 200), isTrue);
      change = (request) => {
        'revision': 11,
        'targetId': 'profile:1',
        'policyId': 'rule',
        'offset': 0,
        'nodes': <Object?>[],
      };
      await expectLater(
        workbench.eligibleOverrideChoices(document, rule, controller: core),
        throwsA(isA<ConfigurationChangeException>()),
      );
    },
  );
  test('R11 wrong origin page cannot authorize selection', () async {
    change = (request) => {
      'revision': 10,
      'targetId': 'profile:1',
      'policyId': 'other',
      'offset': 0,
      'nodes': <Object?>[],
    };
    await expectLater(
      workbench.eligibleOverrideChoices(document, rule, controller: core),
      throwsA(isA<ConfigurationChangeException>()),
    );
  });
  test('R11 page collection has strict 5000 scan bound', () async {
    change = (request) => {
      'revision': 10,
      'targetId': 'profile:1',
      'policyId': 'rule',
      'offset': request['offset'],
      'hasMore': true,
      'nodes': <Object?>[],
    };
    await expectLater(
      workbench.eligibleOverrideChoices(document, rule, controller: core),
      throwsA(isA<ConfigurationChangeException>()),
    );
    expect(requests.length, 25);
    expect(requests.last['offset'], 4800);
  });
}
