import 'models.dart';

enum PolicyOrigin { unknown, manual, ai }

enum PolicyChoiceType { node, nodeSet }

enum NodeAttributeBasis { unknown, name, subscription, manual }

enum NodeSetStrategy { stable, latency, multiplier }

enum UnknownMultiplier { exclude, assumeOne, allow }

enum NodePreferenceType { expiry, remaining, latency, multiplier, source }

enum SortDirection { ascending, descending }

enum NodeSelectionMode { priority, loadBalance }

enum NodeBalanceStrategy { roundRobin, consistentHashing, stickySessions }

final class NodePreference {
  final NodePreferenceType type;
  final SortDirection direction;

  const NodePreference({required this.type, required this.direction});

  factory NodePreference.fromJson(Map<String, Object?> json) {
    policyKeys(json, {'type', 'direction'});
    return NodePreference(
      type: NodePreferenceType.values.byName(policyString(json, 'type')),
      direction: SortDirection.values.byName(policyString(json, 'direction')),
    );
  }

  Map<String, Object?> toJson() => {
    'type': type.name,
    'direction': direction.name,
  };
}

final class PolicyChoice {
  final PolicyChoiceType type;
  final String id;
  const PolicyChoice({required this.type, required this.id});
  factory PolicyChoice.fromJson(Map<String, Object?> json) {
    policyKeys(json, {'type', 'id'});
    final id = policyString(json, 'id', maximum: 256);
    if (id.isEmpty || id != id.trim()) {
      throw const FormatException('Invalid choice identity');
    }
    return PolicyChoice(
      type: PolicyChoiceType.values.byName(policyString(json, 'type')),
      id: id,
    );
  }
  Map<String, Object?> toJson() => {'type': type.name, 'id': id};
}

final class NodeAttributes {
  final String? region;
  final double? multiplier;
  final NodeAttributeBasis regionBasis;
  final NodeAttributeBasis multiplierBasis;
  const NodeAttributes({
    this.region,
    this.multiplier,
    this.regionBasis = NodeAttributeBasis.unknown,
    this.multiplierBasis = NodeAttributeBasis.unknown,
  });
  factory NodeAttributes.fromJson(Map<String, Object?> json) {
    policyKeys(json, {
      'region',
      'multiplier',
      'regionBasis',
      'multiplierBasis',
    });
    final region = json['region'];
    final multiplier = json['multiplier'];
    if (region != null &&
        (region is! String || !RegExp(r'^[A-Z]{2}$').hasMatch(region))) {
      throw const FormatException('Region must be an ISO country code');
    }
    if (multiplier != null &&
        (multiplier is! num ||
            !multiplier.isFinite ||
            multiplier <= 0 ||
            multiplier > 1000)) {
      throw const FormatException('Invalid multiplier');
    }
    final value = NodeAttributes(
      region: region as String?,
      multiplier: (multiplier as num?)?.toDouble(),
      regionBasis: NodeAttributeBasis.values.byName(
        policyString(json, 'regionBasis', fallback: 'unknown'),
      ),
      multiplierBasis: NodeAttributeBasis.values.byName(
        policyString(json, 'multiplierBasis', fallback: 'unknown'),
      ),
    );
    if ((value.region == null) !=
            (value.regionBasis == NodeAttributeBasis.unknown) ||
        (value.multiplier == null) !=
            (value.multiplierBasis == NodeAttributeBasis.unknown)) {
      throw const FormatException('Attribute value and basis disagree');
    }
    return value;
  }
  factory NodeAttributes.infer(String label, Map<String, Object?> raw) {
    String? region;
    var regionBasis = NodeAttributeBasis.unknown;
    final declaredRegion = raw['flclash-region'];
    if (declaredRegion is String &&
        RegExp(r'^[A-Z]{2}$').hasMatch(declaredRegion)) {
      region = declaredRegion;
      regionBasis = NodeAttributeBasis.subscription;
    } else {
      for (final entry in const {
        'JP': r'日本|东京|大阪|Japan|\bJP\b|🇯🇵',
        'HK': r'香港|Hong\s*Kong|\bHK\b|🇭🇰',
        'TW': r'台湾|台灣|Taiwan|\bTW\b|🇹🇼',
        'US': r'美国|美國|United\s*States|\bUS\b|🇺🇸',
        'SG': r'新加坡|Singapore|\bSG\b|🇸🇬',
        'KR': r'韩国|韓國|Korea|\bKR\b|🇰🇷',
        'DE': r'德国|德國|Germany|\bDE\b|🇩🇪',
        'GB': r'英国|英國|United\s*Kingdom|\bUK\b|\bGB\b|🇬🇧',
        'CN': r'中国|中國|大陆|大陸|China|\bCN\b|🇨🇳',
        'MO': r'澳门|澳門|Macao|Macau|\bMO\b|🇲🇴',
        'FR': r'法国|法國|France|\bFR\b|🇫🇷',
        'CA': r'加拿大|Canada|\bCA\b|🇨🇦',
        'AU': r'澳大利亚|澳大利亞|澳洲|Australia|\bAU\b|🇦🇺',
        'NL': r'荷兰|荷蘭|Netherlands|\bNL\b|🇳🇱',
        'RU': r'俄罗斯|俄羅斯|Russia|\bRU\b|🇷🇺',
        'IN': r'印度|India\b|🇮🇳',
        'TH': r'泰国|泰國|Thailand|\bTH\b|🇹🇭',
        'VN': r'越南|Viet\s*Nam|\bVN\b|🇻🇳',
        'MY': r'马来西亚|馬來西亞|Malaysia|\bMY\b|🇲🇾',
        'TR': r'土耳其|Türkiye|Turkey|\bTR\b|🇹🇷',
        'PH': r'菲律宾|菲律賓|Philippines|\bPH\b|🇵🇭',
        'ID': r'印度尼西亚|印尼|印尼|Indonesia|🇮🇩',
      }.entries) {
        if (RegExp(entry.value, caseSensitive: false).hasMatch(label)) {
          region = entry.key;
          regionBasis = NodeAttributeBasis.name;
          break;
        }
      }
    }
    double? multiplier;
    var multiplierBasis = NodeAttributeBasis.unknown;
    final declared = raw['flclash-multiplier'];
    if (declared is num &&
        declared.isFinite &&
        declared > 0 &&
        declared <= 1000) {
      multiplier = declared.toDouble();
      multiplierBasis = NodeAttributeBasis.subscription;
    } else {
      final match = RegExp(r'(\d+(?:\.\d+)?)\s*(?:[xX×]|倍)').firstMatch(label);
      final parsed = match == null ? null : double.tryParse(match.group(1)!);
      if (parsed != null && parsed > 0 && parsed <= 1000) {
        multiplier = parsed;
        multiplierBasis = NodeAttributeBasis.name;
      }
    }
    return NodeAttributes(
      region: region,
      multiplier: multiplier,
      regionBasis: regionBasis,
      multiplierBasis: multiplierBasis,
    );
  }
  Map<String, Object?> toJson() => {
    'region': region,
    'multiplier': multiplier,
    'regionBasis': regionBasis.name,
    'multiplierBasis': multiplierBasis.name,
  };
}

final class PolicyNodeSet {
  final String id;
  final String label;
  final String targetId;
  final List<String> sourceIds;
  final List<String> regions;
  final List<String> excludedSourceIds;
  final List<String> excludedRegions;
  final List<String> nameIncludes;
  final List<String> nameExcludes;
  final List<NodePreference> preferences;
  final NodeSelectionMode selectionMode;
  final NodeBalanceStrategy balanceStrategy;
  final PolicySchedule schedule;
  final double? maxMultiplier;
  final UnknownMultiplier unknownMultiplier;
  final bool allowUnknownRegion;
  final NodeSetStrategy strategy;
  final bool hideUnavailable;
  final PolicyProbe probe;
  final int recoverySeconds;
  final int cooldownSeconds;
  final int improvementPercent;
  const PolicyNodeSet({
    required this.id,
    required this.label,
    required this.targetId,
    required this.sourceIds,
    this.regions = const [],
    this.excludedSourceIds = const [],
    this.excludedRegions = const [],
    this.nameIncludes = const [],
    this.nameExcludes = const [],
    this.preferences = const [],
    this.selectionMode = NodeSelectionMode.priority,
    this.balanceStrategy = NodeBalanceStrategy.roundRobin,
    this.schedule = const PolicySchedule(),
    this.maxMultiplier,
    this.unknownMultiplier = UnknownMultiplier.assumeOne,
    this.allowUnknownRegion = false,
    this.strategy = NodeSetStrategy.stable,
    this.hideUnavailable = true,
    this.probe = const PolicyProbe(
      intervalSeconds: 60,
      method: 'GET',
      expectedStatus: '204',
    ),
    this.recoverySeconds = 300,
    this.cooldownSeconds = 60,
    this.improvementPercent = 20,
  });
  factory PolicyNodeSet.fromJson(Map<String, Object?> json) {
    policyKeys(json, {
      'id',
      'label',
      'targetId',
      'sourceIds',
      'regions',
      'excludedSourceIds',
      'excludedRegions',
      'nameIncludes',
      'nameExcludes',
      'preferences',
      'selectionMode',
      'balanceStrategy',
      'schedule',
      'maxMultiplier',
      'unknownMultiplier',
      'allowUnknownRegion',
      'strategy',
      'hideUnavailable',
      'probe',
      'recoverySeconds',
      'cooldownSeconds',
      'improvementPercent',
    });
    final id = policyString(json, 'id', maximum: 128);
    final target = policyString(json, 'targetId', maximum: 128);
    final sources = policyStrings(json, 'sourceIds', maximum: 20);
    final regions = policyStrings(json, 'regions', maximum: 250);
    final excludedSources = policyStrings(
      json,
      'excludedSourceIds',
      maximum: 20,
    );
    final excludedRegions = policyStrings(
      json,
      'excludedRegions',
      maximum: 250,
    );
    final includes = policyStrings(json, 'nameIncludes', maximum: 20);
    final excludes = policyStrings(json, 'nameExcludes', maximum: 20);
    final preferences = policyItems(
      json,
      'preferences',
      NodePreference.fromJson,
      maximum: 5,
    );
    final cap = json['maxMultiplier'];
    final label = policyString(json, 'label', maximum: 200);
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(id) ||
        !RegExp(r'^(profile|integration):[A-Za-z0-9_-]+$').hasMatch(target) ||
        label.trim().isEmpty ||
        sources.isEmpty ||
        sources.any((s) => !RegExp(r'^[1-9][0-9]*$').hasMatch(s)) ||
        sources.toSet().length != sources.length ||
        regions.any((s) => !RegExp(r'^[A-Z]{2}$').hasMatch(s)) ||
        regions.toSet().length != regions.length ||
        excludedSources.any((s) => !RegExp(r'^[1-9][0-9]*$').hasMatch(s)) ||
        excludedSources.toSet().length != excludedSources.length ||
        excludedRegions.any((s) => !RegExp(r'^[A-Z]{2}$').hasMatch(s)) ||
        excludedRegions.toSet().length != excludedRegions.length ||
        [...includes, ...excludes].any(
          (s) =>
              s.trim().isEmpty ||
              s != s.trim() ||
              s.length > 200 ||
              s.contains(RegExp(r'[\r\n]')),
        ) ||
        includes.toSet().length != includes.length ||
        excludes.toSet().length != excludes.length ||
        preferences.map((p) => p.type).toSet().length != preferences.length ||
        cap != null &&
            (cap is! num || !cap.isFinite || cap <= 0 || cap > 1000)) {
      throw const FormatException('Invalid node set identity or filters');
    }
    return PolicyNodeSet(
      id: id,
      label: label,
      targetId: target,
      sourceIds: sources,
      regions: regions,
      excludedSourceIds: excludedSources,
      excludedRegions: excludedRegions,
      nameIncludes: includes,
      nameExcludes: excludes,
      preferences: preferences,
      selectionMode: NodeSelectionMode.values.byName(
        policyString(json, 'selectionMode', fallback: 'priority'),
      ),
      balanceStrategy: NodeBalanceStrategy.values.byName(
        policyString(json, 'balanceStrategy', fallback: 'roundRobin'),
      ),
      schedule: PolicySchedule.fromJson(
        policyObject(json['schedule'] ?? {}, 'schedule'),
      ),
      maxMultiplier: (cap as num?)?.toDouble(),
      unknownMultiplier: UnknownMultiplier.values.byName(
        policyString(json, 'unknownMultiplier', fallback: 'assumeOne'),
      ),
      allowUnknownRegion: policyBool(json, 'allowUnknownRegion'),
      strategy: NodeSetStrategy.values.byName(
        policyString(json, 'strategy', fallback: 'stable'),
      ),
      hideUnavailable: policyBool(json, 'hideUnavailable', fallback: true),
      probe: PolicyProbe.fromJson(
        policyObject(
          json['probe'] ??
              const PolicyProbe(
                intervalSeconds: 60,
                method: 'GET',
                expectedStatus: '204',
              ).toJson(),
          'probe',
        ),
      ),
      recoverySeconds: policyInt(
        json,
        'recoverySeconds',
        fallback: 300,
        maximum: 86400,
      ),
      cooldownSeconds: policyInt(
        json,
        'cooldownSeconds',
        fallback: 60,
        maximum: 3600,
      ),
      improvementPercent: policyInt(
        json,
        'improvementPercent',
        fallback: 20,
        minimum: 1,
        maximum: 100,
      ),
    );
  }
  double? effectiveMultiplier(NodeAttributes value) =>
      value.multiplier ??
      (unknownMultiplier == UnknownMultiplier.assumeOne ? 1 : null);
  String? exclusion(LocalNode node) {
    if (!sourceIds.contains(node.sourceId)) return 'outside_source';
    if (excludedSourceIds.contains(node.sourceId)) return 'excluded_source';
    final attributes = node.attributes;
    if (excludedRegions.contains(attributes.region)) return 'excluded_region';
    final name = node.label.toLowerCase();
    if (nameExcludes.any((value) => name.contains(value.toLowerCase()))) {
      return 'excluded_name';
    }
    if (nameIncludes.isNotEmpty &&
        !nameIncludes.any((value) => name.contains(value.toLowerCase()))) {
      return 'outside_name';
    }
    if (regions.isNotEmpty &&
        (attributes.region == null
            ? !allowUnknownRegion
            : !regions.contains(attributes.region))) {
      return 'outside_region';
    }
    if (maxMultiplier != null) {
      final value = effectiveMultiplier(attributes);
      if (value == null
          ? unknownMultiplier != UnknownMultiplier.allow
          : value > maxMultiplier!) {
        return 'outside_multiplier';
      }
    }
    return null;
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'label': label,
    'targetId': targetId,
    'sourceIds': sourceIds,
    'regions': regions,
    'excludedSourceIds': excludedSourceIds,
    'excludedRegions': excludedRegions,
    'nameIncludes': nameIncludes,
    'nameExcludes': nameExcludes,
    'preferences': preferences.map((value) => value.toJson()).toList(),
    'selectionMode': selectionMode.name,
    'balanceStrategy': balanceStrategy.name,
    'schedule': schedule.toJson(),
    'maxMultiplier': maxMultiplier,
    'unknownMultiplier': unknownMultiplier.name,
    'allowUnknownRegion': allowUnknownRegion,
    'strategy': strategy.name,
    'hideUnavailable': hideUnavailable,
    'probe': probe.toJson(),
    'recoverySeconds': recoverySeconds,
    'cooldownSeconds': cooldownSeconds,
    'improvementPercent': improvementPercent,
  };
  Map<String, Object?> toCoreJson() => Map<String, Object?>.from(toJson())
    ..remove('targetId')
    ..remove('hideUnavailable');
}

List<LocalPolicy> orderedPolicies(Iterable<LocalPolicy> entries) {
  final rules = entries.toList()
    ..sort((a, b) => a.priority.compareTo(b.priority));
  return rules;
}

List<LocalPolicy> insertPolicy(
  List<LocalPolicy> entries,
  LocalPolicy value, {
  bool generated = false,
}) {
  if (value.scope.type == PolicyMatchType.group) {
    return [
      for (final rule in entries) rule.id == value.id ? value : rule,
      if (!entries.any((r) => r.id == value.id)) value,
    ];
  }
  final target = orderedPolicies(
    entries.where(
      (r) =>
          r.targetId == value.targetId && r.scope.type != PolicyMatchType.group,
    ),
  );
  final existing = target.indexWhere((r) => r.id == value.id);
  if (existing >= 0) {
    target[existing] = value;
  } else {
    final index = target.indexWhere(
      (r) => !generated && r.origin == PolicyOrigin.ai,
    );
    target.insert(index < 0 ? target.length : index, value);
  }
  return [
    ...entries.where(
      (r) =>
          r.targetId != value.targetId || r.scope.type == PolicyMatchType.group,
    ),
    for (var i = 0; i < target.length; i++)
      LocalPolicy.fromJson({...target[i].toJson(), 'priority': i + 1}),
  ];
}
