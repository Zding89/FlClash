import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/policy/models.dart';
import 'package:flutter/material.dart';

class PolicyPreferenceEditor extends StatelessWidget {
  const PolicyPreferenceEditor({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final List<NodePreference> value;
  final ValueChanged<List<NodePreference>> onChanged;
  String _label(BuildContext context, NodePreferenceType type) {
    final s = context.appLocalizations;
    return switch (type) {
      NodePreferenceType.expiry => s.policyPreferenceExpiry,
      NodePreferenceType.remaining => s.policyPreferenceRemaining,
      NodePreferenceType.latency => s.policyPreferenceLatency,
      NodePreferenceType.multiplier => s.policyPreferenceMultiplier,
      NodePreferenceType.source => s.policyPreferenceSource,
    };
  }

  @override
  Widget build(BuildContext context) {
    final s = context.appLocalizations;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          s.policyPreferences,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text(
          s.policyPreferencesHint,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (value.isEmpty) Text(s.policyStableFirst),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: value.length,
          onReorderItem: (oldIndex, newIndex) {
            final next = [...value];
            final item = next.removeAt(oldIndex);
            next.insert(newIndex, item);
            onChanged(next);
          },
          itemBuilder: (context, index) {
            final preference = value[index];
            return ListTile(
              key: ValueKey('preference-${preference.type.name}'),
              contentPadding: EdgeInsets.zero,
              leading: ReorderableDragStartListener(
                index: index,
                child: const Icon(Icons.drag_indicator),
              ),
              title: Text(_label(context, preference.type)),
              subtitle: DropdownButton<SortDirection>(
                isExpanded: true,
                value: preference.direction,
                items: [
                  DropdownMenuItem(
                    value: SortDirection.ascending,
                    child: Text(s.policyAscending),
                  ),
                  DropdownMenuItem(
                    value: SortDirection.descending,
                    child: Text(s.policyDescending),
                  ),
                ],
                onChanged: (direction) {
                  if (direction == null) return;
                  onChanged([
                    for (var i = 0; i < value.length; i++)
                      i == index
                          ? NodePreference(
                              type: preference.type,
                              direction: direction,
                            )
                          : value[i],
                  ]);
                },
              ),
              trailing: IconButton(
                tooltip: s.delete,
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: () => onChanged([...value]..removeAt(index)),
              ),
            );
          },
        ),
        if (value.length < NodePreferenceType.values.length)
          PopupMenuButton<NodePreferenceType>(
            tooltip: s.add,
            icon: const Icon(Icons.add),
            onSelected: (type) => onChanged([
              ...value,
              NodePreference(
                type: type,
                direction:
                    {
                      NodePreferenceType.expiry,
                      NodePreferenceType.remaining,
                    }.contains(type)
                    ? SortDirection.descending
                    : SortDirection.ascending,
              ),
            ]),
            itemBuilder: (context) => [
              for (final type in NodePreferenceType.values.where(
                (type) => !value.any((preference) => preference.type == type),
              ))
                PopupMenuItem(value: type, child: Text(_label(context, type))),
            ],
          ),
      ],
    );
  }
}
