import 'dart:convert';

import 'package:fl_clash/models/profile.dart';
import 'package:fl_clash/policy/models.dart';
import 'package:fl_clash/policy/source_change.dart';
import 'package:flutter_test/flutter_test.dart';

LocalPolicyDocument _document(List<int> ids, {String? filter}) =>
    LocalPolicyDocument.fromJson({
      ...const LocalPolicyDocument().asStandalone().toJson(),
      'integrations': [
        SubscriptionIntegration(
          id: localPolicyProfileId,
          label: 'Local',
          sourceProfileIds: ids,
          nameFilter: filter,
        ).toJson(),
      ],
    });

Profile _profile(int id, {bool known = true}) => Profile(
  id: id,
  label: 'Airport $id',
  autoUpdateDuration: const Duration(hours: 1),
  subscriptionInfo: known
      ? const SubscriptionInfo(
          total: 1000,
          upload: 100,
          download: 200,
          knownFields: {'total', 'upload', 'download'},
        )
      : null,
);

LocalNode _node(int id, String name) => LocalNode(
  id: '$id:$name',
  sourceId: '$id',
  label: name,
  sourceLabel: 'Airport $id',
  protocol: 'http',
  raw: const {},
  attributes: const NodeAttributes(),
);

void main() {
  test(
    'source additions and removals share one deduplicated inventory',
    () async {
      final reads = <int>[];
      final result = await summarizeLocalSourceChange(
        before: _document([1, 2]),
        after: _document([2, 3]),
        profiles: [for (var id = 1; id <= 3; id++) _profile(id)],
        loadNodes: (profile) async {
          reads.add(profile.id);
          return [_node(profile.id, 'JP'), _node(profile.id, 'JP')];
        },
      );
      expect(reads, [1, 2, 3]);
      expect(result!.addedSources, ['Airport 3']);
      expect(result.removedSources, ['Airport 1']);
      expect(result.before.nodeCount, 2);
      expect(result.after.nodeCount, 2);
      expect(result.after.remainingBytes, 1400);
      expect(result.after.nodesComplete, isTrue);
      final restored = LocalSourceChangeSummary.tryParse(
        jsonDecode(jsonEncode(result.toJson())),
      );
      expect(restored!.toJson(), result.toJson());
    },
  );

  test(
    'empty sources are zero while unavailable nodes and quotas stay unknown',
    () async {
      final result = await summarizeLocalSourceChange(
        before: _document([]),
        after: _document([1, 2]),
        profiles: [_profile(1), _profile(2, known: false)],
        loadNodes: (profile) async {
          if (profile.id == 2) {
            throw const FormatException('No cached provider');
          }
          return [_node(1, 'HK')];
        },
      );
      expect(result!.before.sourceCount, 0);
      expect(result.before.nodeCount, 0);
      expect(result.before.remainingBytes, 0);
      expect(result.before.nodesComplete, isTrue);
      expect(result.before.quotaComplete, isTrue);
      expect(result.after.nodeCount, 1);
      expect(result.after.unresolvedNodeSources, ['Airport 2']);
      expect(result.after.remainingBytes, 700);
      expect(result.after.unknownQuotaSources, ['Airport 2']);
    },
  );

  test(
    'counts the effective local name filter rather than original group count',
    () async {
      final result = await summarizeLocalSourceChange(
        before: _document([], filter: 'jp'),
        after: _document([1], filter: 'jp'),
        profiles: [_profile(1)],
        loadNodes: (_) async => [_node(1, 'JP'), _node(1, 'HK')],
      );
      expect(result!.after.nodeCount, 1);
    },
  );

  test(
    'other policy changes cannot be hidden behind a source summary',
    () async {
      var reads = 0;
      final unchanged = _document([1]);
      for (final next in [
        unchanged,
        _document([2], filter: 'changed'),
        LocalPolicyDocument.fromJson({
          ..._document([2]).toJson(),
          'policiesEnabled': true,
        }),
        _document([99]),
      ]) {
        expect(
          await summarizeLocalSourceChange(
            before: unchanged,
            after: next,
            profiles: [_profile(1), _profile(2)],
            loadNodes: (_) async {
              reads++;
              return [];
            },
          ),
          isNull,
        );
      }
      expect(reads, 0);
    },
  );

  test(
    'archived integration changes remain visible alongside local sources',
    () async {
      final before = LocalPolicyDocument.fromJson({
        ..._document([]).toJson(),
        'integrations': [
          ..._document([]).toJson()['integrations'] as List,
          const SubscriptionIntegration(
            id: 'archived',
            label: 'Archived',
            sourceProfileIds: [2],
          ).toJson(),
        ],
      });
      expect(
        await summarizeLocalSourceChange(
          before: before,
          after: _document([1]),
          profiles: [_profile(1), _profile(2)],
          loadNodes: (_) async => [],
        ),
        isNull,
      );
    },
  );

  test('malformed summaries do not replace concrete configuration changes', () {
    for (final value in [
      null,
      <String, Object?>{},
      {'before': -1},
    ]) {
      expect(LocalSourceChangeSummary.tryParse(value), isNull);
    }
    const totals = LocalSourceChangeTotals(
      sourceCount: 0,
      nodeCount: 0,
      remainingBytes: 0,
    );
    final value = const LocalSourceChangeSummary(
      addedSources: [],
      removedSources: [],
      before: totals,
      after: totals,
    ).toJson();
    value['after'] = {...totals.toJson(), 'nodeCount': -1};
    expect(LocalSourceChangeSummary.tryParse(value), isNull);
  });
}
