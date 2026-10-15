import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/policy/source_change.dart';
import 'package:fl_clash/models/common.dart';
import 'package:flutter/material.dart';

class LocalSourceChangeSummaryView extends StatelessWidget {
  const LocalSourceChangeSummaryView({super.key, required this.summary});

  final LocalSourceChangeSummary summary;

  @override
  Widget build(BuildContext context) {
    final strings = context.appLocalizations;
    final before = summary.before;
    final after = summary.after;
    String value(String display, int sourceCount, List<String> unknown) =>
        unknown.isEmpty
        ? display
        : unknown.length >= sourceCount
        ? strings.policyUnknownAttribute
        : '$display (${strings.policySourceChangePartiallyUnknown})';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (summary.addedSources.isNotEmpty) ...[
          Text(
            strings.policySourceChangeAdded,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          SelectableText(summary.addedSources.join('\n')),
          const SizedBox(height: 12),
        ],
        if (summary.removedSources.isNotEmpty) ...[
          Text(
            strings.policySourceChangeRemoved,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          SelectableText(summary.removedSources.join('\n')),
          const SizedBox(height: 12),
        ],
        _SourceChangeMetric(
          title: strings.policySourceChangeNodeTotal,
          before: value(
            '${before.nodeCount}',
            before.sourceCount,
            before.unresolvedNodeSources,
          ),
          after: value(
            '${after.nodeCount}',
            after.sourceCount,
            after.unresolvedNodeSources,
          ),
          unknownLabel: strings.policySourceChangeUnresolvedNodes,
          unknownBefore: before.unresolvedNodeSources,
          unknownAfter: after.unresolvedNodeSources,
        ),
        const SizedBox(height: 12),
        _SourceChangeMetric(
          title: strings.policySourceChangeRemaining,
          before: value(
            before.remainingBytes.traffic.show,
            before.sourceCount,
            before.unknownQuotaSources,
          ),
          after: value(
            after.remainingBytes.traffic.show,
            after.sourceCount,
            after.unknownQuotaSources,
          ),
          unknownLabel: strings.policyQuotaUnknown,
          unknownBefore: before.unknownQuotaSources,
          unknownAfter: after.unknownQuotaSources,
        ),
      ],
    );
  }
}

class _SourceChangeMetric extends StatelessWidget {
  const _SourceChangeMetric({
    required this.title,
    required this.before,
    required this.after,
    required this.unknownLabel,
    required this.unknownBefore,
    required this.unknownAfter,
  });

  final String title;
  final String before;
  final String after;
  final String unknownLabel;
  final List<String> unknownBefore;
  final List<String> unknownAfter;

  @override
  Widget build(BuildContext context) {
    final strings = context.appLocalizations;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: Theme.of(context).textTheme.labelLarge),
        SelectableText('$before → $after'),
        if (unknownBefore.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('${strings.aiBefore} · $unknownLabel'),
          SelectableText(unknownBefore.join('\n')),
        ],
        if (unknownAfter.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('${strings.aiAfter} · $unknownLabel'),
          SelectableText(unknownAfter.join('\n')),
        ],
      ],
    );
  }
}
