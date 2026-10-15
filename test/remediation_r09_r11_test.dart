import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/policy/models.dart';
import 'package:fl_clash/views/policy/editors.dart';
import 'package:fl_clash/views/policy/node_set_editor.dart';
import 'package:fl_clash/views/policy/widgets.dart';
import 'package:fl_clash/views/policy/selection_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget app(Widget child) => MaterialApp(
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.delegate.supportedLocales,
  home: Scaffold(body: child),
);

final node = LocalNode(
  id: '1:a',
  sourceId: '1',
  label: 'Node',
  sourceLabel: 'Source',
  protocol: 'http',
  raw: {},
  attributes: const NodeAttributes(
    region: 'JP',
    multiplier: 1,
    regionBasis: NodeAttributeBasis.name,
    multiplierBasis: NodeAttributeBasis.name,
  ),
);
const setA = PolicyNodeSet(
  id: 'set_a',
  label: 'same name',
  targetId: 'profile:1',
  sourceIds: ['1'],
  regions: ['JP'],
);
const setB = PolicyNodeSet(
  id: 'set_b',
  label: 'same name',
  targetId: 'profile:1',
  sourceIds: ['1'],
  regions: ['JP'],
);
const dynamicRule = LocalPolicy(
  id: 'rule',
  label: 'Rule',
  targetId: 'profile:1',
  choices: [
    PolicyChoice(type: PolicyChoiceType.nodeSet, id: 'set_a'),
    PolicyChoice(type: PolicyChoiceType.nodeSet, id: 'set_b'),
  ],
);
PolicyOverride override({String? set}) => PolicyOverride(
  policyId: 'rule',
  nodeId: node.id,
  nodeSetId: set,
  expiresAt: 9999999999999,
);
Finder field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

Future<void> selectSource(WidgetTester tester) async {
  final sourceField = find.byWidgetPredicate(
    (widget) =>
        widget is PolicyMultiSelect &&
        widget.label == AppLocalizations.current.policyIncludeSources,
  );
  if (tester.widget<PolicyMultiSelect>(sourceField).value.contains('1')) return;
  await tester.ensureVisible(sourceField);
  await tester.tap(sourceField);
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(CheckboxListTile, 'Source'));
  await tester.tap(find.text(AppLocalizations.current.confirm));
  await tester.pumpAndSettle();
}

Future<PolicyOverride?> openOverride(
  WidgetTester tester,
  LocalPolicy rule, {
  List<LocalNode>? nodes,
  Set<String> eligible = const {},
  String? selectSet,
}) async {
  PolicyOverride? saved;
  await tester.pumpWidget(
    app(
      Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            saved = await showDialog<PolicyOverride>(
              context: context,
              builder: (_) => PolicyOverrideEditor(
                policy: rule,
                nodes: nodes ?? [node],
                nodeSets: const [setA, setB],
                eligibleChoices: eligible,
              ),
            );
          },
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  if (selectSet != null) {
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('[$selectSet]').last);
    await tester.pumpAndSettle();
  }
  final button = tester.widget<FilledButton>(find.byType(FilledButton));
  if (button.onPressed != null) {
    await tester.tap(find.text(AppLocalizations.current.save));
    await tester.pumpAndSettle();
  }
  expect(tester.takeException(), isNull);
  return saved;
}

void main() {
  test('R11 new choices take precedence over retained legacy candidates', () {
    const policy = LocalPolicy(
      id: 'rule',
      label: 'Rule',
      targetId: 'profile:1',
      candidateNodeIds: ['1:old'],
      choices: [PolicyChoice(type: PolicyChoiceType.node, id: '1:new')],
    );
    expect(
      const PolicyOverride(
        policyId: 'rule',
        nodeId: '1:old',
        expiresAt: 1,
      ).references(policy),
      isFalse,
    );
    expect(
      const PolicyOverride(
        policyId: 'rule',
        nodeId: '1:new',
        expiresAt: 1,
      ).references(policy),
      isTrue,
    );
  });
  test(
    'R11 legacy fixed JSON stays compatible; dynamic identity round trips',
    () {
      final old = PolicyOverride.fromJson({
        'policyId': 'rule',
        'nodeId': '1:a',
        'expiresAt': 1,
      });
      expect(old.nodeSetId, isNull);
      expect(old.toJson().containsKey('nodeSetId'), isFalse);
      expect(
        PolicyOverride.fromJson({...old.toJson(), 'nodeSetId': ''}).nodeSetId,
        isNull,
      );
      expect(
        PolicyOverride.fromJson(override(set: 'set_b').toJson()).nodeSetId,
        'set_b',
      );
      expect(
        override(set: 'set_a').selectionKey,
        isNot(override(set: 'set_b').selectionKey),
      );
      expect(
        override().selectionKey,
        isNot(override(set: 'set_a').selectionKey),
      );
    },
  );
  test('R11 document rejects guessed or unreferenced dynamic origin', () {
    LocalPolicyDocument doc(PolicyOverride value) => LocalPolicyDocument(
      policies: const [dynamicRule],
      nodeSets: const [setA, setB],
      overrides: [value],
    );
    expect(
      () => LocalPolicyDocument.fromJson(doc(override()).toJson()),
      throwsFormatException,
    );
    expect(
      () => LocalPolicyDocument.fromJson(doc(override(set: 'other')).toJson()),
      throwsFormatException,
    );
    expect(
      LocalPolicyDocument.fromJson(
        doc(override(set: 'set_a')).toJson(),
      ).overrides.single.nodeSetId,
      'set_a',
    );
  });
  test(
    'R11 removal from original set clears identity despite other set membership',
    () {
      final changedA = PolicyNodeSet.fromJson({
        ...setA.toJson(),
        'regions': ['HK'],
      });
      expect(
        override(set: 'set_a').allows(dynamicRule, node, [setA, setB]),
        isTrue,
      );
      expect(
        override(set: 'set_a').allows(dynamicRule, node, [changedA, setB]),
        isFalse,
      );
      expect(
        override(set: 'set_b').allows(dynamicRule, node, [changedA, setB]),
        isTrue,
      );
      const old = LocalPolicy(
        id: 'rule',
        label: 'Rule',
        targetId: 'profile:1',
        candidateNodeIds: ['1:a'],
      );
      const fixed = LocalPolicy(
        id: 'rule',
        label: 'Rule',
        targetId: 'profile:1',
        choices: [PolicyChoice(type: PolicyChoiceType.node, id: '1:a')],
      );
      expect(override().allows(old, node, []), isTrue);
      expect(override().allows(fixed, node, []), isTrue);
      expect(override(set: 'set_a').allows(fixed, node, [setA]), isFalse);
    },
  );
  testWidgets(
    'R09 optional numeric blank and whitespace pass, malformed finite checks fail',
    (tester) async {
      final key = GlobalKey<FormState>();
      final text = TextEditingController();
      addTearDown(text.dispose);
      await tester.pumpWidget(
        app(
          Form(
            key: key,
            child: PolicyField(
              controller: text,
              label: 'optional',
              numeric: true,
            ),
          ),
        ),
      );
      for (final value in ['', '   ', '1.2']) {
        text.text = value;
        expect(key.currentState!.validate(), isTrue, reason: value);
      }
      for (final value in ['abc', 'NaN', 'Infinity', '1e999']) {
        text.text = value;
        expect(key.currentState!.validate(), isFalse, reason: value);
      }
      await tester.pumpWidget(
        app(
          Form(
            key: key,
            child: PolicyField(
              controller: text,
              label: 'required',
              numeric: true,
              required: true,
            ),
          ),
        ),
      );
      text.text = '';
      expect(key.currentState!.validate(), isFalse);
    },
  );
  for (final width in [1200.0, 430.0]) {
    testWidgets('R09 node set empty cap saves null at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      PolicyNodeSetEdit? saved;
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                await showDialog<PolicyNodeSetEdit>(
                  context: context,
                  builder: (_) => PolicyNodeSetEditor(
                    targetId: 'profile:1',
                    sources: const {'1': 'Source'},
                    nodes: [node],
                    onSave: (value) async {
                      saved = value;
                    },
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await selectSource(tester);
      await tester.tap(find.text(AppLocalizations.current.policyCheckSave));
      await tester.pumpAndSettle();
      expect(saved, isNotNull);
      expect(saved!.nodeSet.maxMultiplier, isNull);
      expect(saved!.nodeSet.toJson()['maxMultiplier'], isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('R09 positive multiplier is saved as number', (tester) async {
    PolicyNodeSetEdit? saved;
    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              await showDialog<PolicyNodeSetEdit>(
                context: context,
                builder: (_) => PolicyNodeSetEditor(
                  existing: setA,
                  targetId: 'profile:1',
                  sources: const {'1': 'Source'},
                  nodes: [node],
                  onSave: (value) async {
                    saved = value;
                  },
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(
      field(AppLocalizations.current.policyMultiplierLimit),
      '1.2',
    );
    await tester.tap(find.text(AppLocalizations.current.policyCheckSave));
    await tester.pumpAndSettle();
    expect(saved!.nodeSet.maxMultiplier, 1.2);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  for (final cap in ['abc', '0', '-1', 'NaN', 'Infinity']) {
    testWidgets('R09 node set rejects cap $cap without save', (tester) async {
      PolicyNodeSetEdit? saved;
      await tester.pumpWidget(
        app(
          PolicyNodeSetEditor(
            targetId: 'profile:1',
            sources: const {'1': 'Source'},
            nodes: [node],
            onSave: (value) async {
              saved = value;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        field(AppLocalizations.current.policyMultiplierLimit),
        cap,
      );
      await selectSource(tester);
      await tester.tap(find.text(AppLocalizations.current.policyCheckSave));
      await tester.pumpAndSettle();
      expect(saved, isNull);
      expect(
        find.text(AppLocalizations.current.policyInvalidData),
        findsAtLeastNWidgets(1),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('R11 legacy fixed and new fixed choices save fixed identity', (
    tester,
  ) async {
    for (final rule in [
      const LocalPolicy(
        id: 'rule',
        label: 'Rule',
        targetId: 'profile:1',
        candidateNodeIds: ['1:a'],
      ),
      const LocalPolicy(
        id: 'rule',
        label: 'Rule',
        targetId: 'profile:1',
        choices: [PolicyChoice(type: PolicyChoiceType.node, id: '1:a')],
      ),
    ]) {
      final saved = await openOverride(
        tester,
        rule,
        eligible: {override().selectionKey},
      );
      expect(saved?.nodeId, '1:a');
      expect(saved?.nodeSetId, isNull);
      await tester.pumpWidget(const SizedBox());
    }
  });
  testWidgets(
    'R11 same node from two same-name sets has distinct labels and saved origin',
    (tester) async {
      final saved = await openOverride(
        tester,
        dynamicRule,
        eligible: {
          override(set: 'set_a').selectionKey,
          override(set: 'set_b').selectionKey,
        },
        selectSet: 'set_b',
      );
      expect(saved?.nodeId, '1:a');
      expect(saved?.nodeSetId, 'set_b');
    },
  );
  testWidgets(
    'R11 origin labels remain distinguishable and unavailable fixed is disabled',
    (tester) async {
      await tester.pumpWidget(
        app(
          PolicyOverrideEditor(
            policy: dynamicRule,
            nodes: [node],
            nodeSets: const [setA, setB],
            eligibleChoices: {
              override(set: 'set_a').selectionKey,
              override(set: 'set_b').selectionKey,
            },
          ),
        ),
      );
      final dropdown = tester.widget<DropdownButtonFormField<String>>(
        find.byType(DropdownButtonFormField<String>),
      );
      expect(dropdown, isNotNull);
      final tooltips = tester
          .widgetList<Tooltip>(find.byType(Tooltip))
          .map((w) => w.message)
          .toList();
      expect(tooltips.any((label) => label!.contains('[set_a]')), isTrue);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      expect(find.textContaining('[set_a]'), findsAtLeastNWidgets(1));
      expect(find.textContaining('[set_b]'), findsAtLeastNWidgets(1));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'R11 empty nodes and old Core unknown eligibility cannot save or crash',
    (tester) async {
      for (final nodes in [
        <LocalNode>[],
        [node],
      ]) {
        final saved = await openOverride(tester, dynamicRule, nodes: nodes);
        expect(saved, isNull);
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull,
        );
        expect(
          find.text(
            nodes.isEmpty
                ? AppLocalizations.current.policyNoMembers
                : AppLocalizations.current.policyCheckPending,
          ),
          findsAtLeastNWidgets(1),
        );
        await tester.pumpWidget(const SizedBox());
      }
    },
  );
}
