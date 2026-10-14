import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/policy/models.dart';
import 'package:flutter/material.dart';

import 'application_picker.dart';
import 'selection_fields.dart';

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
        : {
            PolicyMatchType.global,
            PolicyMatchType.processPathRegex,
          }.contains(type)
        ? const []
        : type == PolicyMatchType.destinationRegion
        ? const ['CN']
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
      PolicyMatchType.processPathRegex => s.policyInstalledApps,
      PolicyMatchType.destinationRegion => s.policyDestinationRegion,
      PolicyMatchType.ipCidr => '${s.policyIpNetworks} · IPv4',
      PolicyMatchType.ipCidr6 => '${s.policyIpNetworks} · IPv6',
      PolicyMatchType.global => s.policyGlobalScope,
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
    bool application(PolicyMatch match) =>
        {
          PolicyMatchType.processName,
          PolicyMatchType.processPath,
          PolicyMatchType.processPathRegex,
        }.contains(match.type) ||
        match.type == PolicyMatchType.any &&
            match.children.isNotEmpty &&
            match.children.every(application);
    final isApplication = application(value);
    final logical =
        !isApplication &&
        {
          PolicyMatchType.all,
          PolicyMatchType.any,
          PolicyMatchType.not,
        }.contains(value.type);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (depth == 0 && value.type != PolicyMatchType.group) ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final type in [
                PolicyMatchType.destinationRegion,
                PolicyMatchType.domainSuffix,
                PolicyMatchType.ipCidr,
                PolicyMatchType.processPathRegex,
                PolicyMatchType.global,
                PolicyMatchType.all,
              ])
                ChoiceChip(
                  label: Text(switch (type) {
                    PolicyMatchType.domainSuffix => s.policyWebsite,
                    PolicyMatchType.all => s.policyCombinedConditions,
                    _ => _label(context, type),
                  }),
                  selected:
                      (isApplication
                          ? PolicyMatchType.processPathRegex
                          : {
                              PolicyMatchType.domain,
                              PolicyMatchType.domainSuffix,
                              PolicyMatchType.domainKeyword,
                            }.contains(value.type)
                          ? PolicyMatchType.domainSuffix
                          : value.type == PolicyMatchType.ipCidr6
                          ? PolicyMatchType.ipCidr
                          : logical
                          ? PolicyMatchType.all
                          : value.type) ==
                      type,
                  onSelected: (_) => onChanged(empty(type)),
                ),
            ],
          ),
          if ({
                PolicyMatchType.domain,
                PolicyMatchType.domainSuffix,
                PolicyMatchType.domainKeyword,
                PolicyMatchType.ipCidr,
                PolicyMatchType.ipCidr6,
                PolicyMatchType.all,
                PolicyMatchType.any,
                PolicyMatchType.not,
              }.contains(value.type) &&
              !isApplication)
            DropdownButtonFormField<PolicyMatchType>(
              key: ValueKey('$path-${value.type.name}-type'),
              initialValue: value.type,
              isExpanded: true,
              items: [
                for (final type
                    in logical
                        ? [
                            PolicyMatchType.all,
                            PolicyMatchType.any,
                            PolicyMatchType.not,
                          ]
                        : {
                            PolicyMatchType.ipCidr,
                            PolicyMatchType.ipCidr6,
                          }.contains(value.type)
                        ? [PolicyMatchType.ipCidr, PolicyMatchType.ipCidr6]
                        : [
                            PolicyMatchType.domain,
                            PolicyMatchType.domainSuffix,
                            PolicyMatchType.domainKeyword,
                          ])
                  DropdownMenuItem(
                    value: type,
                    child: Text(_label(context, type)),
                  ),
              ],
              onChanged: (type) {
                if (type != null) onChanged(empty(type));
              },
            ),
        ],
        if (depth > 0 || value.type == PolicyMatchType.group)
          DropdownButtonFormField<PolicyMatchType>(
            key: ValueKey('$path-${value.type.name}-type'),
            initialValue: isApplication
                ? PolicyMatchType.processPathRegex
                : value.type,
            isExpanded: true,
            decoration: InputDecoration(labelText: s.policyScope),
            items: [
              for (final type in PolicyMatchType.values.where(
                (t) =>
                    (depth == 0 || t != PolicyMatchType.global) &&
                    (t != PolicyMatchType.group ||
                        value.type == PolicyMatchType.group) &&
                    t != PolicyMatchType.processName &&
                    t != PolicyMatchType.processPath &&
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
        const SizedBox(height: 12),
        if (isApplication)
          PolicyApplicationPicker(value: value, onChanged: onChanged)
        else if (value.type == PolicyMatchType.destinationRegion) ...[
          DropdownButtonFormField<String>(
            key: ValueKey('$path-region-mode'),
            initialValue:
                value.values.length == 1 &&
                    {'CN', '!CN'}.contains(value.values.single)
                ? value.values.single
                : 'specific',
            isExpanded: true,
            items: [
              DropdownMenuItem(value: 'CN', child: Text(s.policyDomestic)),
              DropdownMenuItem(value: '!CN', child: Text(s.policyForeign)),
              DropdownMenuItem(
                value: 'specific',
                child: Text(s.policySpecificRegions),
              ),
            ],
            onChanged: (mode) {
              if (mode != null) {
                onChanged(
                  PolicyMatch(
                    type: value.type,
                    values: mode == 'specific' ? [] : [mode],
                  ),
                );
              }
            },
          ),
          if (!(value.values.length == 1 &&
              {'CN', '!CN'}.contains(value.values.single)))
            PolicyMultiSelect(
              label: s.policySpecificRegions,
              options: policyRegionOptions(context, value.values),
              value: value.values,
              onChanged: (values) =>
                  onChanged(PolicyMatch(type: value.type, values: values)),
            ),
        ] else if (!logical && value.type != PolicyMatchType.global)
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
