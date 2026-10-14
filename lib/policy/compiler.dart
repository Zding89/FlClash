import 'dart:convert';

import 'models.dart';

final class PolicySource {
  final String id;
  final String label;
  final Map<String, Object?> raw;
  final int? expiresAt;
  final int? remainingBytes;
  final int? observedAt;
  final String? warning;

  const PolicySource({
    required this.id,
    required this.label,
    required this.raw,
    this.expiresAt,
    this.remainingBytes,
    this.observedAt,
    this.warning,
  });

  bool get expiryKnown => expiresAt != null;
  bool get unlimited => expiresAt == 0;

  Map<String, Object?> get summary => {
    'id': id,
    'label': label,
    if (expiresAt != null) 'expiresAt': expiresAt,
    if (remainingBytes != null) 'remainingBytes': remainingBytes,
    if (observedAt != null) 'observedAt': observedAt,
  };
}

final class CompiledPolicyProfile {
  final Map<String, Object?> config;
  final List<LocalNode> nodes;
  final List<String> warnings;
  final String targetId;

  const CompiledPolicyProfile({
    required this.config,
    required this.nodes,
    required this.warnings,
    required this.targetId,
  });
}

final class LocalPolicyCompiler {
  const LocalPolicyCompiler();

  List<LocalNode> extractNodes(PolicySource source) {
    final rawProxies = source.raw['proxies'] ?? <Object?>[];
    if (rawProxies is! List) {
      throw const FormatException('Invalid source proxy list');
    }
    final nodes = <LocalNode>[];
    final identities = <String>{};
    for (final value in rawProxies) {
      final raw = policyObject(value, 'proxy');
      final label = raw['name'];
      final protocol = raw['type'];
      if (label is! String ||
          label.isEmpty ||
          protocol is! String ||
          protocol.isEmpty) {
        throw const FormatException('Node needs a name and protocol');
      }
      if (raw['dialer-proxy'] != null && raw['dialer-proxy'] != '') {
        throw const FormatException(
          'Nodes with nested dialer-proxy dependencies are not supported',
        );
      }
      final identity = Map<String, Object?>.from(raw)
        ..remove('name')
        ..remove('flclash-region')
        ..remove('flclash-multiplier');
      final id = '${source.id}:${policyDigest(identity)}';
      if (!identities.add(id)) continue;
      nodes.add(
        LocalNode(
          id: id,
          sourceId: source.id,
          label: label,
          sourceLabel: source.label,
          protocol: protocol,
          raw: raw,
          attributes: NodeAttributes.infer(label, raw),
        ),
      );
    }
    return nodes;
  }

  CompiledPolicyProfile compile({
    required LocalPolicyDocument document,
    required int? profileId,
    required Map<String, Object?> baseConfig,
    required List<PolicySource> sources,
    bool enforceCandidateReferences = true,
  }) {
    document.validate();
    if (document.isStandalone &&
        !(document.moduleEnabled && document.integrationEnabled)) {
      final raw = policyObject(jsonDecode(jsonEncode(baseConfig)), 'baseConfig')
        ..remove('flclash-local-policy')
        ..remove('flclash-selection-aliases');
      return CompiledPolicyProfile(
        config: raw,
        nodes: const [],
        warnings: const [],
        targetId: 'profile:$profileId',
      );
    }
    final integration = document.moduleEnabled && document.integrationEnabled
        ? document.activeIntegration
        : null;
    final targetId = integration?.targetId ?? 'profile:$profileId';
    final policies = document.moduleEnabled && document.policiesEnabled
        ? orderedPolicies(
            document.policies.where(
              (policy) => policy.enabled && policy.targetId == targetId,
            ),
          )
        : <LocalPolicy>[];
    final referencedSets = policies
        .expand((policy) => policy.choices)
        .where((choice) => choice.type == PolicyChoiceType.nodeSet)
        .map((choice) => choice.id)
        .toSet();
    final sets = document.nodeSets
        .where((set) => referencedSets.contains(set.id))
        .toList();
    final sourceIds = integration == null
        ? {
            '$profileId',
            ...sets.expand(
              (set) => [...set.sourceIds, ...set.excludedSourceIds],
            ),
            ...policies
                .expand(
                  (policy) => [
                    ...policy.candidateNodeIds,
                    ...policy.choices
                        .where((choice) => choice.type == PolicyChoiceType.node)
                        .map((choice) => choice.id),
                  ],
                )
                .map((id) => id.split(':').first),
          }
        : integration.sourceProfileIds.map((id) => '$id').toSet();
    final selectedSources = integration == null
        ? sources.where((source) => sourceIds.contains(source.id)).toList()
        : sources
              .where(
                (source) => integration.sourceProfileIds
                    .map((id) => '$id')
                    .contains(source.id),
              )
              .toList();
    if (integration != null &&
        selectedSources.length != integration.sourceProfileIds.length) {
      throw const FormatException('An integration source is missing');
    }
    if (policies.isNotEmpty && selectedSources.length != sourceIds.length) {
      throw const FormatException('A rule source profile is missing');
    }
    final nodes = selectedSources
        .expand(extractNodes)
        .map(
          (node) => LocalNode(
            id: node.id,
            sourceId: node.sourceId,
            label: node.label,
            sourceLabel: node.sourceLabel,
            protocol: node.protocol,
            raw: node.raw,
            attributes: document.nodeAttributes[node.id] ?? node.attributes,
          ),
        )
        .where((node) {
          if (integration == null) return true;
          if (integration.excludedNodeIds.contains(node.id)) return false;
          final filter = integration.nameFilter;
          return filter == null ||
              filter.isEmpty ||
              node.label.toLowerCase().contains(filter.toLowerCase());
        })
        .toList();
    if (nodes.length > 5000) {
      throw const FormatException('At most 5000 nodes are supported');
    }
    final usedSourceIds = selectedSources.map((source) => source.id).toSet();
    final budgets = document.moduleEnabled && document.budgetsEnabled
        ? document.budgets
              .where((budget) => usedSourceIds.contains(budget.sourceId))
              .toList()
        : <SourceBudget>[];
    for (final set in sets) {
      if (!document.isStandalone && !usedSourceIds.containsAll(set.sourceIds)) {
        throw const FormatException('Node set sources are outside the target');
      }
    }
    final managed =
        policies.isNotEmpty || budgets.isNotEmpty || integration != null;
    if ((policies.isNotEmpty || integration != null) &&
        baseConfig['mode'] != null &&
        baseConfig['mode'] != 'rule') {
      throw const FormatException('Local policies require rule mode');
    }
    final raw = policyObject(jsonDecode(jsonEncode(baseConfig)), 'baseConfig');
    final warnings = <String>[
      for (final source in selectedSources)
        if (source.warning != null) '${source.warning}:${source.id}',
    ];
    final configuredIds = nodes.map((node) => node.id).toSet();
    for (final policy in policies) {
      final missing = [
        ...policy.candidateNodeIds,
        ...policy.choices
            .where((c) => c.type == PolicyChoiceType.node)
            .map((c) => c.id),
      ].where((id) => !configuredIds.contains(id)).toList();
      if (missing.isNotEmpty &&
          enforceCandidateReferences &&
          !document.isStandalone) {
        throw FormatException(
          'Policy ${policy.label} has missing candidates: ${missing.join(', ')}',
        );
      }
      if (missing.isNotEmpty) warnings.add('missing_candidates:${policy.id}');
    }
    if (integration != null) {
      final preserved = <String, Object?>{};
      for (final key in {
        'mixed-port',
        'port',
        'socks-port',
        'redir-port',
        'tproxy-port',
        'mode',
        'allow-lan',
        'log-level',
        'ipv6',
        'find-process-mode',
        'keep-alive-interval',
        'unified-delay',
        'tcp-concurrent',
        'tun',
        'dns',
        'hosts',
        'geox-url',
        'geodata-loader',
        'global-ua',
        'geo-auto-update',
        'geo-update-interval',
        'external-controller',
        'external-ui',
        'external-ui-url',
      }) {
        if (raw.containsKey(key)) preserved[key] = raw[key];
      }
      raw
        ..clear()
        ..addAll(preserved)
        ..['proxies'] = <Object?>[]
        ..['proxy-groups'] = <Object?>[]
        ..['rules'] = <String>[
          'MATCH,${integration.fallback == PolicyFallback.reject ? 'REJECT' : 'DIRECT'}',
        ]
        ..['profile'] = <String, Object?>{'store-selected': false};
    }
    if (!managed && integration == null) {
      return CompiledPolicyProfile(
        config: raw,
        nodes: nodes,
        warnings: warnings,
        targetId: targetId,
      );
    }
    final existingProxies = (raw['proxies'] as List? ?? [])
        .map((entry) => policyObject(entry, 'proxy'))
        .toList();
    final existingGroups = (raw['proxy-groups'] as List? ?? [])
        .map((entry) => policyObject(entry, 'group'))
        .toList();
    final existingNames = <String>{
      ...existingProxies.map((entry) => entry['name']).whereType<String>(),
      ...existingGroups.map((entry) => entry['name']).whereType<String>(),
    };
    final aliasNodes = nodes;
    final originalAliases = <String, String>{};
    if (integration == null) {
      final source = selectedSources.firstWhere(
        (source) => source.id == '$profileId',
      );
      final aliasesById = {
        for (final node in aliasNodes.where(
          (node) => node.sourceId == source.id,
        ))
          node.id: node.proxyName,
      };
      void addAlias(Map<String, Object?> proxy) {
        final label = proxy['name'];
        if (label is! String) {
          throw const FormatException('Invalid generated node name');
        }
        final identity = Map<String, Object?>.from(proxy)
          ..remove('name')
          ..remove('flclash-region')
          ..remove('flclash-multiplier');
        final alias = aliasesById['${source.id}:${policyDigest(identity)}'];
        if (alias == null) {
          throw const FormatException(
            'Source accounting requires unchanged independent node endpoints',
          );
        }
        final prior = originalAliases[label];
        if (prior != null && prior != alias) {
          throw const FormatException(
            'Ambiguous same-name nodes within one source',
          );
        }
        originalAliases[label] = alias;
      }

      for (final value in source.raw['proxies'] as List? ?? <Object?>[]) {
        addAlias(policyObject(value, 'source proxy'));
      }
      final effectiveIds = <String>{};
      for (final proxy in existingProxies) {
        addAlias(proxy);
        effectiveIds.add(
          '${source.id}:${policyDigest(Map<String, Object?>.from(proxy)
            ..remove('name')
            ..remove('flclash-region')
            ..remove('flclash-multiplier'))}',
        );
      }
      final inline = source.raw['flclash-inline-node-ids'];
      final expected = inline is List
          ? inline.cast<String>().toSet()
          : source.raw['flclash-provider-members'] == null
          ? aliasesById.keys.toSet()
          : null;
      if (expected != null &&
          (expected.length != effectiveIds.length ||
              !expected.containsAll(effectiveIds))) {
        throw const FormatException(
          'Source accounting does not support script changes to the node inventory',
        );
      }
      if (policyDigest(raw['proxy-providers']) !=
          policyDigest(source.raw['proxy-providers'])) {
        throw const FormatException(
          'Source accounting does not support script changes to provider definitions',
        );
      }
      final originalInlineNames =
          existingProxies
              .map((proxy) => proxy['name'])
              .whereType<String>()
              .toList()
            ..sort();
      existingProxies.clear();
      final members = policyObject(
        source.raw['flclash-provider-members'] ?? <String, Object?>{},
        'providerMembers',
      );
      for (final group in existingGroups) {
        for (final option in ['filter', 'exclude-filter', 'exclude-type']) {
          final value = group[option];
          if (value != null && value != '') {
            throw PolicySourceException('proxy-groups.$option');
          }
        }
        final groupProxies = List<String>.from(group['proxies'] as List? ?? []);
        if (group['include-all'] == true ||
            group['include-all-proxies'] == true) {
          groupProxies.addAll(originalInlineNames);
        }
        final uses =
            group['include-all'] == true ||
                group['include-all-providers'] == true
            ? (members.keys.toList()..sort())
            : List<String>.from(group['use'] as List? ?? []);
        for (final provider in uses) {
          final providerMembers = members[provider];
          if (providerMembers is! List) {
            throw const FormatException('Provider group could not be expanded');
          }
          groupProxies.addAll(providerMembers.cast<String>());
        }
        group['proxies'] = groupProxies
            .map((name) => originalAliases[name] ?? name)
            .toSet()
            .toList();
        group.remove('use');
        group.remove('include-all');
        group.remove('include-all-proxies');
        group.remove('include-all-providers');
      }
      raw['flclash-selection-aliases'] = originalAliases;
      raw.remove('proxy-providers');
      raw['rules'] = List<String>.from(
        raw['rules'] as List? ?? [],
      ).map((rule) => _rewriteRuleTarget(rule, originalAliases)).toList();
      final subRules = raw['sub-rules'];
      if (subRules is Map) {
        raw['sub-rules'] = subRules.map(
          (key, value) => MapEntry(
            key,
            List<String>.from(
              value as List,
            ).map((rule) => _rewriteRuleTarget(rule, originalAliases)).toList(),
          ),
        );
      }
    }
    for (final node in aliasNodes) {
      if (existingNames.contains(node.proxyName)) {
        throw const FormatException(
          'Reserved policy node name conflicts with source',
        );
      }
      existingProxies.add(
        Map<String, Object?>.from(node.raw)
          ..remove('flclash-region')
          ..remove('flclash-multiplier')
          ..['name'] = node.proxyName,
      );
    }
    final aliasById = {for (final node in aliasNodes) node.id: node.proxyName};
    final managedGroups = <String>{};
    for (final policy in policies) {
      if (!managedGroups.add(policy.groupName)) {
        throw const FormatException(
          'Multiple policies cannot own the same group',
        );
      }
      if (policy.scope.type == PolicyMatchType.group) {
        if (integration != null ||
            !existingGroups.any((group) => group['name'] == policy.groupName)) {
          throw FormatException('Unknown original group: ${policy.groupName}');
        }
        existingGroups.removeWhere(
          (group) => group['name'] == policy.groupName,
        );
      } else if (existingNames.contains(policy.groupName)) {
        throw const FormatException(
          'Reserved policy group name conflicts with source',
        );
      }
      existingGroups.add({
        'name': policy.groupName,
        'type': 'select',
        'proxies': [
          'REJECT',
          ...{
            ...policy.candidateNodeIds,
            ...policy.choices
                .where((c) => c.type == PolicyChoiceType.node)
                .map((c) => c.id),
            for (final choice in policy.choices.where(
              (c) => c.type == PolicyChoiceType.nodeSet,
            ))
              ...nodes
                  .where(
                    (n) =>
                        sets
                            .firstWhere((s) => s.id == choice.id)
                            .exclusion(n) ==
                        null,
                  )
                  .map((n) => n.id),
          }.map((id) => aliasById[id]).whereType<String>(),
        ],
      });
    }
    final originalRules = List<String>.from(raw['rules'] as List? ?? []);
    final generatedRules = <String>[];
    for (final policy in policies) {
      generatedRules.addAll(_rules(policy.scope, policy.groupName));
    }
    bool matchesApplication(PolicyMatch match) =>
        {
          PolicyMatchType.processName,
          PolicyMatchType.processPath,
          PolicyMatchType.processPathRegex,
        }.contains(match.type) ||
        match.children.any(matchesApplication);
    if (policies.any((policy) => matchesApplication(policy.scope))) {
      raw['find-process-mode'] = 'strict';
    }
    raw['proxies'] = existingProxies;
    raw['proxy-groups'] = existingGroups;
    raw['rules'] = [...generatedRules, ...originalRules];
    if (managed) {
      final usedSources = selectedSources.map((source) => source.id).toSet();
      final relevantIds = policies.map((policy) => policy.id).toSet();
      raw['flclash-local-policy'] = {
        'schemaVersion': 3,
        'targetId': targetId,
        'nodeSets': sets.map((s) => s.toCoreJson()).toList(),
        'revision': document.revision,
        'enabled': true,
        'sources': selectedSources
            .where((source) => usedSources.contains(source.id))
            .map((source) => source.summary)
            .toList(),
        'nodes': aliasNodes
            .map(
              (node) => {
                'id': node.id,
                'sourceId': node.sourceId,
                'proxyName': node.proxyName,
                'label': node.label,
                ...node.attributes.toJson(),
              },
            )
            .toList(),
        'policies': policies.map((policy) => policy.toCoreJson()).toList(),
        'budgets': budgets
            .where((budget) => usedSources.contains(budget.sourceId))
            .map((budget) => budget.toJson())
            .toList(),
        'overrides': document.overrides
            .where((override) => relevantIds.contains(override.policyId))
            .map((override) => override.toJson())
            .toList(),
      };
    }
    return CompiledPolicyProfile(
      config: raw,
      nodes: nodes,
      warnings: warnings,
      targetId: targetId,
    );
  }

  String _rewriteRuleTarget(String rule, Map<String, String> aliases) {
    final parts = rule.split(',');
    var targetIndex = parts.length - 1;
    while (targetIndex > 0 &&
        {'no-resolve', 'src'}.contains(parts[targetIndex].trim())) {
      targetIndex--;
    }
    final replacement = aliases[parts[targetIndex].trim()];
    if (replacement != null) parts[targetIndex] = replacement;
    return parts.join(',');
  }

  List<String> _rules(PolicyMatch scope, String group) {
    if (scope.type == PolicyMatchType.group) return [];
    if (scope.type == PolicyMatchType.global) return ['MATCH,$group'];
    return ['${_expression(scope)},$group'];
  }

  String _expression(PolicyMatch match) {
    if ({
      PolicyMatchType.all,
      PolicyMatchType.any,
      PolicyMatchType.not,
    }.contains(match.type)) {
      final operation = switch (match.type) {
        PolicyMatchType.all => 'AND',
        PolicyMatchType.any => 'OR',
        _ => 'NOT',
      };
      return '$operation,(${match.children.map((child) => '(${_expression(child)})').join(',')})';
    }
    String condition(String value) {
      if (match.type == PolicyMatchType.destinationRegion) {
        return value.startsWith('!')
            ? 'NOT,((GEOIP,${value.substring(1)}))'
            : 'GEOIP,$value';
      }
      if ((match.type == PolicyMatchType.ipCidr ||
              match.type == PolicyMatchType.ipCidr6) &&
          !value.contains('/')) {
        value = '$value/${match.type == PolicyMatchType.ipCidr ? 32 : 128}';
      }
      return '${_keyword(match.type)},$value';
    }

    if (match.values.length == 1) return condition(match.values.single);
    return 'OR,(${match.values.map((value) => '(${condition(value)})').join(',')})';
  }

  String _keyword(PolicyMatchType type) => switch (type) {
    PolicyMatchType.domain => 'DOMAIN',
    PolicyMatchType.domainSuffix => 'DOMAIN-SUFFIX',
    PolicyMatchType.domainKeyword => 'DOMAIN-KEYWORD',
    PolicyMatchType.processName => 'PROCESS-NAME',
    PolicyMatchType.processPath => 'PROCESS-PATH',
    PolicyMatchType.processPathRegex => 'PROCESS-PATH-REGEX',
    PolicyMatchType.ipCidr => 'IP-CIDR',
    PolicyMatchType.ipCidr6 => 'IP-CIDR6',
    _ => throw const FormatException('Unsupported rule match type'),
  };
}
