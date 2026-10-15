import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/common.dart';
import 'package:fl_clash/policy/source_change.dart';
import 'package:flutter/material.dart';

class LocalSourceChangeSummaryView extends StatelessWidget {
  const LocalSourceChangeSummaryView({super.key, required this.summary});

  final LocalSourceChangeSummary summary;

  @override
  Widget build(BuildContext context) {
    final strings = context.appLocalizations;
    final colors = Theme.of(context).colorScheme;
    final before = summary.before;
    final after = summary.after;
    final unknownSources = {
      ...before.unresolvedNodeSources,
      ...before.unknownQuotaSources,
      ...after.unresolvedNodeSources,
      ...after.unknownQuotaSources,
    };
    List<String> reasons(LocalSourceChangeTotals totals, String source) => [
      if (totals.unresolvedNodeSources.contains(source))
        strings.policySourceChangeNodesUnavailable,
      if (totals.unknownQuotaSources.contains(source))
        strings.policyQuotaUnknown,
    ];
    Widget metric({
      required String title,
      required String beforeValue,
      required String afterValue,
      required List<String> unknownBefore,
      required List<String> unknownAfter,
    }) => _SourceChangeMetric(
      title: title,
      before:
          unknownBefore.isNotEmpty && unknownBefore.length >= before.sourceCount
          ? strings.policyUnknownAttribute
          : beforeValue,
      after: unknownAfter.isNotEmpty && unknownAfter.length >= after.sourceCount
          ? strings.policyUnknownAttribute
          : afterValue,
      partialBefore:
          unknownBefore.isNotEmpty && unknownBefore.length < before.sourceCount,
      partialAfter:
          unknownAfter.isNotEmpty && unknownAfter.length < after.sourceCount,
    );
    final nodeMetric = metric(
      title: strings.policySourceChangeNodeTotal,
      beforeValue: '${before.nodeCount}',
      afterValue: '${after.nodeCount}',
      unknownBefore: before.unresolvedNodeSources,
      unknownAfter: after.unresolvedNodeSources,
    );
    final quotaMetric = metric(
      title: strings.policySourceChangeRemaining,
      beforeValue: before.remainingBytes.traffic.show,
      afterValue: after.remainingBytes.traffic.show,
      unknownBefore: before.unknownQuotaSources,
      unknownAfter: after.unknownQuotaSources,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (summary.addedSources.isNotEmpty) ...[
          _SourceChangeAirports(
            title: strings.policySourceChangeAdded,
            icon: Icons.add_circle_outline,
            sources: summary.addedSources,
          ),
          const SizedBox(height: 16),
        ],
        if (summary.removedSources.isNotEmpty) ...[
          _SourceChangeAirports(
            title: strings.policySourceChangeRemoved,
            icon: Icons.remove_circle_outline,
            sources: summary.removedSources,
          ),
          const SizedBox(height: 16),
        ],
        LayoutBuilder(
          builder: (context, constraints) => constraints.maxWidth >= 460
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: nodeMetric),
                    const SizedBox(width: 12),
                    Expanded(child: quotaMetric),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    nodeMetric,
                    const SizedBox(height: 12),
                    quotaMetric,
                  ],
                ),
        ),
        if (unknownSources.isNotEmpty) ...[
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline,
                size: 18,
                color: colors.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  strings.policySourceChangeIncomplete,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          for (final source in unknownSources) ...[
            const SizedBox(height: 10),
            SelectableText(
              source,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            if (reasons(before, source).join(' · ') ==
                reasons(after, source).join(' · '))
              Text(
                reasons(after, source).join(' · '),
                style: TextStyle(color: colors.onSurfaceVariant),
              )
            else ...[
              if (reasons(before, source).isNotEmpty)
                Text(
                  '${strings.aiBefore} · ${reasons(before, source).join(' · ')}',
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
              if (reasons(after, source).isNotEmpty)
                Text(
                  '${strings.aiAfter} · ${reasons(after, source).join(' · ')}',
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
            ],
          ],
        ],
      ],
    );
  }
}

class _SourceChangeAirports extends StatelessWidget {
  const _SourceChangeAirports({
    required this.title,
    required this.icon,
    required this.sources,
  });

  final String title;
  final IconData icon;
  final List<String> sources;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: theme.textTheme.labelLarge)),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final source in sources)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(source, style: theme.textTheme.bodyMedium),
              ),
          ],
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
    required this.partialBefore,
    required this.partialAfter,
  });

  final String title;
  final String before;
  final String after;
  final bool partialBefore;
  final bool partialAfter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = context.appLocalizations;
    Widget amount(String label, String value, bool partial, bool emphasize) =>
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  maxLines: 1,
                  softWrap: false,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: emphasize ? FontWeight.w700 : FontWeight.w400,
                    color: emphasize
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (partial)
                Text(
                  strings.policySourceChangePartiallyUnknown,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        );
    return Card.filled(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: theme.textTheme.titleSmall),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                amount(strings.aiBefore, before, partialBefore, false),
                const SizedBox(width: 12),
                amount(strings.aiAfter, after, partialAfter, true),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
