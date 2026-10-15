import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/profile.dart';
import 'package:fl_clash/policy/models.dart';
import 'package:fl_clash/policy/quota_overview.dart';
import 'package:fl_clash/views/policy/node_set_members.dart';
import 'package:fl_clash/views/policy/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

const _checkedAt = 1791939600000;

LocalNode _node(
  String id, {
  String? label,
  String source = '1',
  String? sourceLabel,
  String? region = 'JP',
  double? multiplier = 1,
}) => LocalNode(
  id: id,
  sourceId: source,
  label: label ?? id,
  sourceLabel: sourceLabel ?? 'Airport $source',
  protocol: 'ss',
  raw: const {},
  attributes: NodeAttributes(region: region, multiplier: multiplier),
);

Map<String, Object?> _healthy(int latency) => {
  'lastProbeAt': _checkedAt,
  'healthy': true,
  'eligible': true,
  'latencyMillis': latency,
};

Future<void> _mount(
  WidgetTester tester, {
  required List<LocalNode> nodes,
  Map<String, Map<String, Object?>> states = const {},
  Map<String, QuotaSourceSummary> sources = const {},
  bool draft = false,
  bool busy = false,
  bool assumeUnknownMultiplier = false,
  VoidCallback? onCheck,
  ValueChanged<LocalNode>? onEdit,
  Size size = const Size(1440, 900),
  bool dark = false,
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('zh', 'CN'),
      theme: dark
          ? ThemeData.dark(useMaterial3: true)
          : ThemeData(useMaterial3: true),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.delegate.supportedLocales,
      home: Scaffold(
        body: PolicyNodeSetMembersView(
          nodes: nodes,
          states: states,
          sourceSummaries: sources,
          draft: draft,
          busy: busy,
          assumeUnknownMultiplier: assumeUnknownMultiplier,
          onCheck: onCheck,
          onEditAttributes: onEdit,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

List<String> _shown(WidgetTester tester) => tester
    .widget<DataTable>(find.byKey(const ValueKey('node-members-table')))
    .rows
    .map(
      (row) =>
          (row.key! as ValueKey<String>).value.replaceFirst('node-member-', ''),
    )
    .toList();

String _cellText(WidgetTester tester, String id, int column) {
  final row = tester
      .widget<DataTable>(find.byType(DataTable))
      .rows
      .singleWhere((row) => row.key == ValueKey('node-member-$id'));
  final tooltip = row.cells[column].child as Tooltip;
  final box = tooltip.child! as SizedBox;
  return (box.child! as Text).data!;
}

Future<void> _choose(WidgetTester tester, String key, String label) async {
  final dropdown = find.byKey(ValueKey(key));
  await tester.ensureVisible(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'combines list filters without changing membership or node attributes',
    (tester) async {
      final nodes = [
        _node('a', label: 'Tokyo selected'),
        _node('b', label: 'Tokyo failed'),
        _node('c', label: 'Tokyo other multiplier', multiplier: 2),
        _node('d', label: 'Hong Kong', region: 'HK'),
        _node('e', label: 'Tokyo other airport', source: '2'),
      ];
      final original = nodes.map((node) => node.summary).toList();
      await _mount(
        tester,
        nodes: nodes,
        states: {
          'a': _healthy(20),
          'b': {
            'lastProbeAt': _checkedAt,
            'healthy': false,
            'latencyMillis': null,
          },
          'c': _healthy(10),
          'd': _healthy(30),
          'e': _healthy(40),
        },
      );
      final strings = AppLocalizations.current;
      await _choose(tester, 'node-members-source-filter', 'Airport 1');
      await _choose(
        tester,
        'node-members-region-filter',
        strings.policyRegionJP,
      );
      await _choose(tester, 'node-members-multiplier-filter', '1×');
      await _choose(
        tester,
        'node-members-status-filter',
        strings.policyMembersHealthy,
      );
      await tester.enterText(
        find.byKey(const ValueKey('node-members-search')),
        'selected',
      );
      await tester.pumpAndSettle();
      expect(_shown(tester), ['a']);
      expect(nodes.map((node) => node.summary).toList(), original);
      expect(find.text('${strings.policyMembersTitle} · 5'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'search uses every member and resets pagination to the first match',
    (tester) async {
      final nodes = [
        for (var index = 0; index < 61; index++)
          _node('node-${index.toString().padLeft(3, '0')}'),
      ];
      await _mount(tester, nodes: nodes);
      expect(_shown(tester), hasLength(50));
      expect(_shown(tester), isNot(contains('node-060')));
      final next = find.byKey(const ValueKey('node-members-next-page'));
      await tester.ensureVisible(next);
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(_shown(tester), hasLength(11));
      expect(_shown(tester).first, 'node-050');
      final search = find.byKey(const ValueKey('node-members-search'));
      await tester.ensureVisible(search);
      await tester.enterText(search, 'node-001');
      await tester.pumpAndSettle();
      expect(_shown(tester), ['node-001']);
      await tester.enterText(search, 'node-060');
      await tester.pumpAndSettle();
      expect(_shown(tester), ['node-060']);
      expect(nodes, hasLength(61));
      expect(find.text('1–1 / 1'), findsOneWidget);
    },
  );

  testWidgets(
    'distinguishes missing, unchecked, pending, expired, restricted and failed results',
    (tester) async {
      final ids = [
        'missing',
        'unchecked',
        'pending',
        'probing',
        'expired',
        'source',
        'budget',
        'failed',
        'healthy',
      ];
      await _mount(
        tester,
        nodes: ids.map((id) => _node(id)).toList(),
        states: {
          'unchecked': {'healthy': false, 'latencyMillis': null},
          'pending': {..._healthy(10), 'probePending': true},
          'probing': {'reason': 'probing', 'healthy': false},
          'expired': {..._healthy(10), 'reason': 'probe_expired'},
          'source': {
            ..._healthy(15),
            'reason': 'source_remaining',
            'eligible': false,
            'probePending': true,
          },
          'budget': {
            ..._healthy(25),
            'reason': 'budget_exceeded',
            'eligible': false,
          },
          'failed': {
            'lastProbeAt': _checkedAt,
            'healthy': false,
            'latencyMillis': null,
          },
          'healthy': _healthy(30),
        },
      );
      final strings = AppLocalizations.current;
      expect(_cellText(tester, 'missing', 6), strings.policyMembersNoResult);
      expect(_cellText(tester, 'unchecked', 6), strings.policyMembersUnchecked);
      expect(_cellText(tester, 'pending', 6), strings.policyMembersChecking);
      expect(_cellText(tester, 'probing', 6), strings.policyMembersChecking);
      expect(_cellText(tester, 'expired', 6), strings.policyMembersExpired);
      expect(_cellText(tester, 'source', 6), strings.policyMembersRestricted);
      expect(_cellText(tester, 'budget', 6), strings.policyMembersRestricted);
      expect(_cellText(tester, 'failed', 6), strings.policyMembersFailed);
      expect(_cellText(tester, 'healthy', 6), strings.policyMembersHealthy);
      expect(_cellText(tester, 'failed', 7), '—');
      expect(_cellText(tester, 'pending', 7), '—');
      expect(_cellText(tester, 'expired', 7), '—');
      expect(_cellText(tester, 'healthy', 7), '30 ms');
      expect(
        _cellText(tester, 'healthy', 8),
        policyBeijingTime(_checkedAt).split(' ').last,
      );
      expect(find.byTooltip(policyBeijingTime(_checkedAt)), findsWidgets);
      expect(
        find.byTooltip(
          '${strings.policyMembersRestricted} · ${strings.policySubscriptionExhausted}',
        ),
        findsOneWidget,
      );
      expect(_shown(tester), hasLength(ids.length));
    },
  );

  testWidgets(
    'drafts never display runtime checks or expose the check action',
    (tester) async {
      var checked = false;
      await _mount(
        tester,
        nodes: [_node('draft')],
        states: {'draft': _healthy(10)},
        draft: true,
        onCheck: () => checked = true,
      );
      final strings = AppLocalizations.current;
      expect(_cellText(tester, 'draft', 6), strings.policyMembersUnchecked);
      expect(_cellText(tester, 'draft', 7), '—');
      expect(_cellText(tester, 'draft', 8), '—');
      expect(find.text(strings.policyMembersDraft), findsOneWidget);
      expect(find.byKey(const ValueKey('node-members-check')), findsNothing);
      expect(checked, isFalse);
    },
  );

  testWidgets(
    'quota belongs to the source and unknown expiry is distinct from unlimited',
    (tester) async {
      final profiles = [
        const Profile(
          id: 1,
          label: 'Unknown',
          autoUpdateDuration: Duration.zero,
        ),
        const Profile(
          id: 2,
          label: 'Unlimited',
          autoUpdateDuration: Duration.zero,
          subscriptionInfo: SubscriptionInfo(
            total: 1024,
            upload: 256,
            knownFields: {'total', 'upload', 'download', 'expire'},
            expire: 0,
          ),
        ),
        const Profile(
          id: 3,
          label: 'Dated',
          autoUpdateDuration: Duration.zero,
          subscriptionInfo: SubscriptionInfo(
            total: 1024,
            knownFields: {'total', 'upload', 'download', 'expire'},
            expire: 1791939600,
          ),
        ),
      ];
      final sources = const LocalQuotaOverviewCalculator()
          .calculate(profiles: profiles)
          .sources;
      await _mount(
        tester,
        nodes: [
          _node('unknown'),
          _node('unlimited-a', source: '2'),
          _node('unlimited-b', source: '2'),
          _node('dated', source: '3'),
        ],
        sources: {
          for (final source in sources) source.profile.id.toString(): source,
        },
      );
      final strings = AppLocalizations.current;
      expect(_cellText(tester, 'unknown', 4), strings.policyQuotaUnknown);
      expect(_cellText(tester, 'unknown', 5), strings.policyQuotaUnknownExpiry);
      expect(_cellText(tester, 'unlimited-a', 5), strings.policyQuotaUnlimited);
      expect(
        _cellText(tester, 'unlimited-a', 4),
        _cellText(tester, 'unlimited-b', 4),
      );
      expect(_cellText(tester, 'unlimited-a', 4), '768B');
      expect(
        _cellText(tester, 'dated', 5),
        policyBeijingTime(_checkedAt).split(' ').first,
      );
    },
  );

  testWidgets(
    'assumed unknown multiplier is marked and can be filtered as one',
    (tester) async {
      final unknown = _node('unknown', multiplier: null);
      await _mount(
        tester,
        nodes: [unknown, _node('known'), _node('double', multiplier: 2)],
        assumeUnknownMultiplier: true,
      );
      final strings = AppLocalizations.current;
      expect(_cellText(tester, 'unknown', 3), '1×(${strings.defaultText})');
      expect(find.byTooltip(strings.policyUnknownOneHint), findsOneWidget);
      await _choose(tester, 'node-members-multiplier-filter', '1×');
      expect(_shown(tester), ['known', 'unknown']);
      expect(unknown.attributes.multiplier, isNull);
      await _mount(tester, nodes: [unknown, _node('known')]);
      await _choose(
        tester,
        'node-members-multiplier-filter',
        strings.policyUnknownAttribute,
      );
      expect(_shown(tester), ['unknown']);
      expect(_cellText(tester, 'unknown', 3), strings.policyUnknownAttribute);
    },
  );

  testWidgets(
    'name and latency sorting remain display only and actions respect busy',
    (tester) async {
      var checks = 0;
      LocalNode? edited;
      final nodes = [_node('z'), _node('a'), _node('m')];
      await _mount(
        tester,
        nodes: nodes,
        states: {'z': _healthy(10), 'a': _healthy(30)},
        onCheck: () => checks++,
        onEdit: (node) => edited = node,
      );
      expect(_shown(tester), ['a', 'm', 'z']);
      final table = tester.widget<DataTable>(find.byType(DataTable));
      table.columns[7].onSort!(7, true);
      await tester.pumpAndSettle();
      expect(_shown(tester), ['z', 'a', 'm']);
      expect(nodes.map((node) => node.id), ['z', 'a', 'm']);
      tester
          .widget<DataTable>(find.byType(DataTable))
          .rows
          .first
          .onSelectChanged!(true);
      await tester.tap(find.byKey(const ValueKey('node-members-check')));
      expect(edited?.id, 'z');
      expect(checks, 1);
      await _mount(
        tester,
        nodes: nodes,
        busy: true,
        onCheck: () => checks++,
        onEdit: (node) => edited = node,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const ValueKey('node-members-check')),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<DataTable>(find.byType(DataTable))
            .rows
            .every((row) => row.onSelectChanged == null),
        isTrue,
      );
    },
  );

  for (final size in [const Size(320, 700), const Size(1440, 900)]) {
    testWidgets(
      'table preserves text size and scrolls at ${size.width} with dark enlarged text',
      (tester) async {
        final long = List.filled(10, 'Long airport and node').join(' ');
        await _mount(
          tester,
          nodes: [
            for (var index = 0; index < 16; index++)
              _node('node-$index', label: '$index $long', sourceLabel: long),
          ],
          size: size,
          dark: true,
          textScale: 1.5,
        );
        expect(tester.takeException(), isNull);
        final table = tester.widget<DataTable>(find.byType(DataTable));
        expect(table.dataTextStyle?.fontSize, 14);
        expect(table.headingTextStyle?.fontSize, 12);
        expect(find.byTooltip('0 $long'), findsOneWidget);
        final horizontalFinder = find.byKey(
          const ValueKey('node-members-horizontal-scroll'),
        );
        await tester.ensureVisible(horizontalFinder);
        await tester.pumpAndSettle();
        final horizontal = tester
            .widget<SingleChildScrollView>(horizontalFinder)
            .controller!;
        final viewport = tester.getRect(find.byType(Scaffold));
        final visible = tester.getRect(horizontalFinder).intersect(viewport);
        expect(visible.isEmpty, isFalse);
        if (horizontal.position.maxScrollExtent > 0) {
          final previous = horizontal.offset;
          await tester.dragFrom(visible.center, Offset(-visible.width * .4, 0));
          await tester.pumpAndSettle();
          expect(horizontal.offset, greaterThan(previous));
        } else {
          expect(size.width, 1440);
        }
        await tester.drag(
          find.byKey(const ValueKey('node-members-scroll')),
          const Offset(0, -700),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(_shown(tester), hasLength(16));
      },
    );
  }
}
