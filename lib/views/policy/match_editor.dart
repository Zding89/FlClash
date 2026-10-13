import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/policy/models.dart';
import 'package:flutter/material.dart';

class PolicyMatchEditor extends StatelessWidget {
  const PolicyMatchEditor({
    super.key,
    required this.value,
    required this.onChanged,
    this.depth = 0,
    this.path = 'root',
  });
  final PolicyMatch value;
  final ValueChanged<PolicyMatch> onChanged;
  final int depth;
  final String path;

  static PolicyMatch empty(PolicyMatchType type) => PolicyMatch(
    type: type,
    values:
        const {
          PolicyMatchType.all,
          PolicyMatchType.any,
          PolicyMatchType.not,
        }.contains(type)
        ? const []
        : const [''],
    children:
        const {
          PolicyMatchType.all,
          PolicyMatchType.any,
          PolicyMatchType.not,
        }.contains(type)
        ? List.generate(
            type == PolicyMatchType.not ? 1 : 2,
            (_) => const PolicyMatch(
              type: PolicyMatchType.domainSuffix,
              values: [''],
            ),
          )
        : const [],
  );

  String _label(BuildContext context, PolicyMatchType type) {
    final s = context.appLocalizations;
    return switch (type) {
      PolicyMatchType.domain => s.policyDomainScope,
      PolicyMatchType.domainSuffix => s.policyDomainSuffix,
      PolicyMatchType.domainKeyword => s.policyDomainKeyword,
      PolicyMatchType.processName => s.policyProcessName,
      PolicyMatchType.processPath => s.policyProcessPath,
      PolicyMatchType.all => s.policyMatchAll,
      PolicyMatchType.any => s.policyMatchAny,
      PolicyMatchType.not => s.policyMatchNot,
      _ => s.policyScope,
    };
  }

  void _child(int index, PolicyMatch next) => onChanged(
    PolicyMatch(
      type: value.type,
      children: [
        for (var i = 0; i < value.children.length; i++)
          i == index ? next : value.children[i],
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final s = context.appLocalizations;
    final logical = {
      PolicyMatchType.all,
      PolicyMatchType.any,
      PolicyMatchType.not,
    }.contains(value.type);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (depth > 0)
          DropdownButtonFormField<PolicyMatchType>(
            key: ValueKey('$path-${value.type.name}-type'),
            initialValue: value.type,
            isExpanded: true,
            decoration: InputDecoration(labelText: s.policyScope),
            items: [
              for (final type in PolicyMatchType.values.where(
                (t) =>
                    t != PolicyMatchType.global &&
                    t != PolicyMatchType.group &&
                    (depth < 5 ||
                        !{
                          PolicyMatchType.all,
                          PolicyMatchType.any,
                          PolicyMatchType.not,
                        }.contains(t)),
              ))
                DropdownMenuItem(
                  value: type,
                  child: Text(_label(context, type)),
                ),
            ],
            onChanged: (type) {
              if (type != null) onChanged(empty(type));
            },
          ),
        if (!logical)
          TextFormField(
            key: ValueKey('$path-${value.type.name}-values'),
            initialValue: value.values.join('\n'),
            maxLines: 2,
            decoration: InputDecoration(labelText: s.policyScopeValues),
            onChanged: (text) => onChanged(
              PolicyMatch(
                type: value.type,
                values: text.split('\n').map((v) => v.trim()).toList(),
              ),
            ),
          ),
        if (logical) ...[
          for (var i = 0; i < value.children.length; i++)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PolicyMatchEditor(
                      value: value.children[i],
                      depth: depth + 1,
                      path: '$path-$i',
                      onChanged: (next) => _child(i, next),
                    ),
                    if (value.type != PolicyMatchType.not &&
                        value.children.length > 2)
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          tooltip: s.delete,
                          onPressed: () => onChanged(
                            PolicyMatch(
                              type: value.type,
                              children: [
                                for (var j = 0; j < value.children.length; j++)
                                  if (j != i) value.children[j],
                              ],
                            ),
                          ),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          if (value.type != PolicyMatchType.not && value.children.length < 20)
            TextButton.icon(
              onPressed: () => onChanged(
                PolicyMatch(
                  type: value.type,
                  children: [
                    ...value.children,
                    empty(PolicyMatchType.domainSuffix),
                  ],
                ),
              ),
              icon: const Icon(Icons.add),
              label: Text(s.add),
            ),
        ],
      ],
    );
  }
}
