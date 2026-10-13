import 'dart:convert';
import 'dart:math';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/policy/models.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

String policyNewId() {
  final random = Random.secure();
  return List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

String policyBeijingTime(int milliseconds) =>
    DateFormat('yyyy-MM-dd HH:mm:ss').format(
      DateTime.fromMillisecondsSinceEpoch(
        milliseconds,
        isUtc: true,
      ).add(const Duration(hours: 8)),
    );
String policyGiB(int bytes) =>
    (bytes / (1024 * 1024 * 1024)).toStringAsFixed(2);
int policyBytes(String text) =>
    (double.parse(text) * 1024 * 1024 * 1024).round();

class PolicyField extends StatelessWidget {
  const PolicyField({
    super.key,
    required this.controller,
    required this.label,
    this.required = false,
    this.numeric = false,
    this.maxLines = 1,
    this.onChanged,
  });
  final TextEditingController controller;
  final String label;
  final bool required;
  final bool numeric;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLines > 1 ? 65536 : 4096,
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : maxLines > 1
          ? TextInputType.multiline
          : TextInputType.text,
      decoration: InputDecoration(labelText: label, counterText: ''),
      onChanged: onChanged,
      validator: (value) =>
          required && (value == null || value.trim().isEmpty) ||
              numeric && double.tryParse(value ?? '') == null
          ? context.appLocalizations.policyInvalidData
          : null,
    ),
  );
}

class PolicyFallbackField extends StatelessWidget {
  const PolicyFallbackField({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final PolicyFallback value;
  final ValueChanged<PolicyFallback> onChanged;
  @override
  Widget build(BuildContext context) => DropdownButtonFormField<PolicyFallback>(
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(
      labelText: context.appLocalizations.policyFallback,
    ),
    items: [
      DropdownMenuItem(
        value: PolicyFallback.reject,
        child: Text(context.appLocalizations.policyFallbackReject),
      ),
      DropdownMenuItem(
        value: PolicyFallback.direct,
        child: Text(context.appLocalizations.policyFallbackDirect),
      ),
    ],
    onChanged: (value) {
      if (value != null) onChanged(value);
    },
  );
}

class PolicyJsonDialog<T> extends StatefulWidget {
  const PolicyJsonDialog({
    super.key,
    required this.initial,
    required this.parse,
  });
  final Map<String, Object?> initial;
  final T Function(Map<String, Object?>) parse;
  @override
  State<PolicyJsonDialog<T>> createState() => _PolicyJsonDialogState<T>();
}

class _PolicyJsonDialogState<T> extends State<PolicyJsonDialog<T>> {
  late final TextEditingController _text;
  bool _failed = false;
  @override
  void initState() {
    super.initState();
    _text = TextEditingController(
      text: const JsonEncoder.withIndent('  ').convert(widget.initial),
    );
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.appLocalizations.policyAdvancedJson),
    content: SizedBox(
      width: 620,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.appLocalizations.policyJsonHint),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('policy-json'),
              controller: _text,
              minLines: 10,
              maxLines: 18,
              maxLength: 262144,
              style: const TextStyle(fontFamily: 'monospace'),
              decoration: InputDecoration(
                counterText: '',
                errorText: _failed
                    ? context.appLocalizations.policyInvalidData
                    : null,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(context.appLocalizations.cancel),
      ),
      FilledButton(
        onPressed: () {
          try {
            final value = widget.parse(
              policyObject(jsonDecode(_text.text), 'document'),
            );
            Navigator.of(context).pop<T>(value);
          } catch (_) {
            setState(() => _failed = true);
          }
        },
        child: Text(context.appLocalizations.save),
      ),
    ],
  );
}

class OrderedPolicyNodes extends StatefulWidget {
  const OrderedPolicyNodes({
    super.key,
    required this.nodes,
    required this.value,
    required this.onChanged,
    this.exclusion = false,
  });
  final List<LocalNode> nodes;
  final List<String> value;
  final ValueChanged<List<String>> onChanged;
  final bool exclusion;
  @override
  State<OrderedPolicyNodes> createState() => _OrderedPolicyNodesState();
}

class _OrderedPolicyNodesState extends State<OrderedPolicyNodes> {
  String _query = '';
  void _move(int index, int delta) {
    final copy = List<String>.from(widget.value);
    final id = copy.removeAt(index);
    copy.insert(index + delta, id);
    widget.onChanged(copy);
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.appLocalizations;
    final labels = {
      for (final node in widget.nodes)
        node.id: '${node.sourceLabel} · ${node.label}',
    };
    final filtered = widget.nodes
        .where(
          (node) => '${node.sourceLabel} ${node.label}'.toLowerCase().contains(
            _query,
          ),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.exclusion
              ? strings.policyExcludedNodes
              : strings.policyCandidates,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        if (!widget.exclusion)
          Text(
            strings.policyCandidateHint,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        for (final (index, id) in widget.value.indexed)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Text('${index + 1}'),
            title: Text(
              labels[id] ?? strings.policyMissingNode,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: labels.containsKey(id)
                ? null
                : Text(id, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!widget.exclusion) ...[
                  IconButton(
                    key: ValueKey('policy-node-up-$id'),
                    onPressed: index == 0 ? null : () => _move(index, -1),
                    tooltip: strings.policyMoveUp,
                    icon: const Icon(Icons.arrow_upward, size: 18),
                  ),
                  IconButton(
                    key: ValueKey('policy-node-down-$id'),
                    onPressed: index == widget.value.length - 1
                        ? null
                        : () => _move(index, 1),
                    tooltip: strings.policyMoveDown,
                    icon: const Icon(Icons.arrow_downward, size: 18),
                  ),
                ],
                IconButton(
                  onPressed: () => widget.onChanged(
                    widget.value.where((entry) => entry != id).toList(),
                  ),
                  tooltip: strings.policyRemoveCandidate,
                  icon: const Icon(Icons.remove_circle_outline, size: 18),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        TextField(
          decoration: InputDecoration(labelText: strings.policySearchNodes),
          onChanged: (value) => setState(() => _query = value.toLowerCase()),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 200,
          child: ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final node = filtered[index];
              return CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: widget.value.contains(node.id),
                title: Text(node.label),
                subtitle: Text(node.sourceLabel),
                onChanged: (selected) {
                  if (selected == true) {
                    if (!widget.exclusion && widget.value.length >= 10) return;
                    widget.onChanged([...widget.value, node.id]);
                  } else {
                    widget.onChanged(
                      widget.value.where((id) => id != node.id).toList(),
                    );
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

String policyReasonLabel(BuildContext context, String reason) {
  final strings = context.appLocalizations;
  return switch (reason) {
    'source_expiring' || 'source_expired' => strings.policySubscriptionExpired,
    'source_remaining' => strings.policySubscriptionExhausted,
    'schedule_inactive' => strings.policyScheduleSkip,
    'missing_node' || 'outside_node_set' => strings.policySourceMissing,
    'budget_exceeded' || 'budget_limit' => strings.policyBudgetTab,
    'ledger_untrusted' => strings.policyLedgerUntrusted,
    'unhealthy' => strings.policyOperationFailed,
    _ => strings.policyCheckPending,
  };
}
