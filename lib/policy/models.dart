import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';

import 'node_sets.dart';
export 'node_sets.dart';

const localPolicyProfileId = 'flclash_local';
const localPolicyTargetId = 'integration:$localPolicyProfileId';

enum PolicyMatchType {
  global,
  group,
  domain,
  domainSuffix,
  domainKeyword,
  processName,
  processPath,
  processPathRegex,
  destinationRegion,
  ipCidr,
  ipCidr6,
  all,
  any,
  not,
}

enum PolicyUnknownBehavior { allow, exclude }

enum PolicyFallback { reject, direct }

enum PolicyAction { proxy, direct, reject }

bool _applicationPattern(String value) {
  const suffix = r'/Contents/.*$';
  if (!value.startsWith('^/') || !value.endsWith(suffix)) return false;
  final path = value.substring(1, value.length - suffix.length);
  if (!path.endsWith(r'\.app')) return false;
  const escaped = r'\^$.*+?()[]{}|';
  for (var index = 0; index < path.length; index++) {
    final character = path[index];
    if (character == r'\') {
      if (index + 1 >= path.length) return false;
      if (index + 3 < path.length &&
          {
            'x28',
            'x29',
            'x2c',
          }.contains(path.substring(index + 1, index + 4))) {
        index += 3;
      } else if (escaped.contains(path[++index]) &&
          !'()'.contains(path[index])) {
        continue;
      } else {
        return false;
      }
    } else if (escaped.contains(character) ||
        ',()'.contains(character) ||
        character.codeUnitAt(0) < 32) {
      return false;
    }
  }
  return true;
}

Map<String, Object?> policyObject(Object? value, String name) {
  if (value is! Map || value.keys.any((key) => key is! String)) {
    throw FormatException('$name must be an object');
  }
  return Map<String, Object?>.from(value);
}

void policyKeys(Map<String, Object?> json, Set<String> allowed) {
  final unknown = json.keys.where((key) => !allowed.contains(key));
  if (unknown.isNotEmpty) {
    throw FormatException('Unknown fields: ${unknown.join(', ')}');
  }
}

String policyString(
  Map<String, Object?> json,
  String key, {
  String? fallback,
  int maximum = 1024,
}) {
  final value = json[key] ?? fallback;
  if (value is! String || value.length > maximum) {
    throw FormatException(
      '$key must be a string of at most $maximum characters',
    );
  }
  return value;
}

int policyInt(
  Map<String, Object?> json,
  String key, {
  int? fallback,
  int minimum = 0,
  int maximum = 9007199254740991,
}) {
  final value = json[key] ?? fallback;
  if (value is! int || value < minimum || value > maximum) {
    throw FormatException(
      '$key must be an integer between $minimum and $maximum',
    );
  }
  return value;
}

bool policyBool(
  Map<String, Object?> json,
  String key, {
  bool fallback = false,
}) {
  final value = json[key] ?? fallback;
  if (value is! bool) {
    throw FormatException('$key must be a boolean');
  }
  return value;
}

List<String> policyStrings(
  Map<String, Object?> json,
  String key, {
  int maximum = 100,
}) {
  final value = json[key] ?? <Object?>[];
  if (value is! List ||
      value.length > maximum ||
      value.any((entry) => entry is! String || entry.length > 1024)) {
    throw FormatException('$key must be a bounded string array');
  }
  return List<String>.unmodifiable(value.cast<String>());
}

List<T> policyItems<T>(
  Map<String, Object?> json,
  String key,
  T Function(Map<String, Object?>) convert, {
  int maximum = 100,
}) {
  final value = json[key] ?? <Object?>[];
  if (value is! List || value.length > maximum) {
    throw FormatException('$key must be an array of at most $maximum items');
  }
  return List<T>.unmodifiable(
    value.map((entry) => convert(policyObject(entry, key))),
  );
}

int policyIdentifier(Object? value) {
  final parsed = value is int
      ? value
      : value is String && RegExp(r'^(0|[1-9][0-9]{0,18})$').hasMatch(value)
      ? int.tryParse(value)
      : null;
  if (parsed == null || parsed <= 0 || parsed > 9223372036854775807) {
    throw const FormatException('Invalid resource identity');
  }
  return parsed;
}

String policyDigest(Object? value) {
  Object? normalize(Object? entry) {
    if (entry is Map) {
      final keys = entry.keys.map((key) => key.toString()).toList()..sort();
      return {for (final key in keys) key: normalize(entry[key])};
    }
    if (entry is List) {
      return entry.map(normalize).toList();
    }
    return entry;
  }

  return sha256.convert(utf8.encode(jsonEncode(normalize(value)))).toString();
}

final class PolicyMatch {
  final PolicyMatchType type;
  final List<String> values;
  final List<PolicyMatch> children;

  const PolicyMatch({
    this.type = PolicyMatchType.global,
    this.values = const [],
    this.children = const [],
  });

  factory PolicyMatch.fromJson(Map<String, Object?> json) {
    PolicyMatch parse(Map<String, Object?> value, int depth) {
      if (depth > 6) {
        throw const FormatException('Match conditions are too deeply nested');
      }
      policyKeys(value, {'type', 'values', 'children'});
      final type = PolicyMatchType.values.byName(
        policyString(value, 'type', fallback: 'global'),
      );
      return PolicyMatch(
        type: type,
        values: policyStrings(value, 'values', maximum: 50),
        children: policyItems(
          value,
          'children',
          (entry) => parse(entry, depth + 1),
          maximum: 20,
        ),
      );
    }

    final match = parse(json, 0);
    match.validate();
    return match;
  }

  void validate({int depth = 0}) {
    if (depth > 6 || values.length > 50 || children.length > 20) {
      throw const FormatException('Match condition limit exceeded');
    }
    switch (type) {
      case PolicyMatchType.global:
        if (values.isNotEmpty || children.isNotEmpty) {
          throw const FormatException('Global scope cannot contain conditions');
        }
      case PolicyMatchType.group:
        if (values.length != 1 || children.isNotEmpty) {
          throw const FormatException('Group scope requires exactly one group');
        }
      case PolicyMatchType.all:
      case PolicyMatchType.any:
        if (children.length < 2 || values.isNotEmpty) {
          throw const FormatException(
            'Logical scope requires at least two conditions',
          );
        }
      case PolicyMatchType.not:
        if (children.length != 1 || values.isNotEmpty) {
          throw const FormatException(
            'Not scope requires exactly one condition',
          );
        }
      default:
        if (values.isEmpty || children.isNotEmpty) {
          throw const FormatException('Match scope requires values');
        }
        for (final value in values) {
          if (value.length > 1024) {
            throw const FormatException('Match value is too long');
          }
          if (type == PolicyMatchType.processPathRegex) {
            if (!_applicationPattern(value)) {
              throw const FormatException('Choose an installed application');
            }
            try {
              RegExp(value);
            } on FormatException {
              throw const FormatException('Invalid application path');
            }
            continue;
          }
          if (type == PolicyMatchType.destinationRegion &&
              !RegExp(r'^!?[A-Z]{2}$').hasMatch(value)) {
            throw const FormatException('Choose a destination region');
          }
          if (type == PolicyMatchType.ipCidr ||
              type == PolicyMatchType.ipCidr6) {
            final parts = value.split('/');
            final address = InternetAddress.tryParse(parts.first);
            final maximum = type == PolicyMatchType.ipCidr ? 32 : 128;
            final prefix = parts.length == 1
                ? maximum
                : int.tryParse(parts.last);
            if (parts.length > 2 ||
                address == null ||
                (address.type == InternetAddressType.IPv4) != (maximum == 32) ||
                prefix == null ||
                prefix < 0 ||
                prefix > maximum) {
              throw const FormatException('Invalid IP address or network');
            }
          }
          if ({
                PolicyMatchType.domain,
                PolicyMatchType.domainSuffix,
              }.contains(type) &&
              (value.contains(RegExp(r'[\s/:?#@]')) ||
                  Uri.tryParse('https://$value')?.host.isEmpty != false)) {
            throw const FormatException(
              'Enter a domain without protocol or path',
            );
          }
          if (value.trim().isEmpty ||
              value.contains(RegExp(r'[,\r\n()]')) ||
              value != value.trim()) {
            throw const FormatException('Invalid match value');
          }
        }
    }
    for (final child in children) {
      if ({
        PolicyMatchType.global,
        PolicyMatchType.group,
      }.contains(child.type)) {
        throw const FormatException('Global/group scopes cannot be nested');
      }
      child.validate(depth: depth + 1);
    }
  }

  Map<String, Object?> toJson() => {
    'type': type.name,
    'values': values,
    'children': children.map((child) => child.toJson()).toList(),
  };
}

final class PolicyProbe {
  final String url;
  final int intervalSeconds;
  final int timeoutSeconds;
  final int failureThreshold;
  final int successThreshold;
  final String expectedStatus;
  final String method;
  final bool automatic;
  final int retrySeconds;
  final int validitySeconds;

  const PolicyProbe({
    this.url = 'https://www.gstatic.com/generate_204',
    this.intervalSeconds = 30,
    this.timeoutSeconds = 5,
    this.failureThreshold = 3,
    this.successThreshold = 3,
    this.expectedStatus = '200-399',
    this.method = 'HEAD',
    this.automatic = true,
    this.retrySeconds = 180,
    this.validitySeconds = 600,
  });

  factory PolicyProbe.fromJson(Map<String, Object?> json) {
    policyKeys(json, {
      'url',
      'intervalSeconds',
      'timeoutSeconds',
      'failureThreshold',
      'successThreshold',
      'expectedStatus',
      'method',
      'automatic',
      'retrySeconds',
      'validitySeconds',
    });
    final probe = PolicyProbe(
      method: policyString(json, 'method', fallback: 'HEAD'),
      automatic: policyBool(json, 'automatic', fallback: true),
      retrySeconds: policyInt(
        json,
        'retrySeconds',
        fallback: 180,
        minimum: 5,
        maximum: 86400,
      ),
      validitySeconds: policyInt(
        json,
        'validitySeconds',
        fallback: 600,
        minimum: 5,
        maximum: 86400,
      ),
      url: policyString(
        json,
        'url',
        fallback: 'https://www.gstatic.com/generate_204',
      ),
      intervalSeconds: policyInt(
        json,
        'intervalSeconds',
        fallback: 30,
        minimum: 5,
        maximum: 3600,
      ),
      timeoutSeconds: policyInt(
        json,
        'timeoutSeconds',
        fallback: 5,
        minimum: 1,
        maximum: 30,
      ),
      failureThreshold: policyInt(
        json,
        'failureThreshold',
        fallback: 3,
        minimum: 1,
        maximum: 20,
      ),
      successThreshold: policyInt(
        json,
        'successThreshold',
        fallback: 3,
        minimum: 1,
        maximum: 20,
      ),
      expectedStatus: policyString(
        json,
        'expectedStatus',
        fallback: '200-399',
        maximum: 32,
      ),
    );
    final uri = Uri.tryParse(probe.url);
    if (uri == null ||
        !{'http', 'https'}.contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        !{'GET', 'HEAD'}.contains(probe.method) ||
        probe.validitySeconds < probe.intervalSeconds ||
        probe.timeoutSeconds >= probe.intervalSeconds) {
      throw const FormatException('Invalid probe URL or timing');
    }
    final status = RegExp(
      r'^(\d{3})(?:-(\d{3}))?$',
    ).firstMatch(probe.expectedStatus);
    if (status == null ||
        int.parse(status.group(1)!) < 100 ||
        int.parse(status.group(2) ?? status.group(1)!) > 599 ||
        int.parse(status.group(2) ?? status.group(1)!) <
            int.parse(status.group(1)!)) {
      throw const FormatException('Invalid expected HTTP status');
    }
    return probe;
  }

  Map<String, Object?> toJson() => {
    'url': url,
    'intervalSeconds': intervalSeconds,
    'timeoutSeconds': timeoutSeconds,
    'failureThreshold': failureThreshold,
    'successThreshold': successThreshold,
    'expectedStatus': expectedStatus,
    'method': method,
    'automatic': automatic,
    'retrySeconds': retrySeconds,
    'validitySeconds': validitySeconds,
  };
}

final class PolicyGuard {
  final int expiryMarginSeconds;
  final int minRemainingBytes;
  final int metadataMaxAgeSeconds;
  final PolicyUnknownBehavior unknownBehavior;

  const PolicyGuard({
    this.expiryMarginSeconds = 0,
    this.minRemainingBytes = 0,
    this.metadataMaxAgeSeconds = 86400,
    this.unknownBehavior = PolicyUnknownBehavior.exclude,
  });

  factory PolicyGuard.fromJson(Map<String, Object?> json) {
    policyKeys(json, {
      'expiryMarginSeconds',
      'minRemainingBytes',
      'metadataMaxAgeSeconds',
      'unknownBehavior',
    });
    return PolicyGuard(
      expiryMarginSeconds: policyInt(
        json,
        'expiryMarginSeconds',
        fallback: 0,
        maximum: 31536000,
      ),
      minRemainingBytes: policyInt(json, 'minRemainingBytes', fallback: 0),
      metadataMaxAgeSeconds: policyInt(
        json,
        'metadataMaxAgeSeconds',
        fallback: 86400,
        minimum: 60,
        maximum: 2592000,
      ),
      unknownBehavior: PolicyUnknownBehavior.values.byName(
        policyString(json, 'unknownBehavior', fallback: 'exclude'),
      ),
    );
  }

  Map<String, Object?> toJson() => {
    'expiryMarginSeconds': expiryMarginSeconds,
    'minRemainingBytes': minRemainingBytes,
    'metadataMaxAgeSeconds': metadataMaxAgeSeconds,
    'unknownBehavior': unknownBehavior.name,
  };
}

final class PolicyWindow {
  final List<int> weekdays;
  final int startMinute;
  final int endMinute;

  const PolicyWindow({
    this.weekdays = const [1, 2, 3, 4, 5, 6, 7],
    this.startMinute = 0,
    this.endMinute = 1440,
  });

  factory PolicyWindow.fromJson(Map<String, Object?> json) {
    policyKeys(json, {'weekdays', 'startMinute', 'endMinute'});
    final days = json['weekdays'] ?? [1, 2, 3, 4, 5, 6, 7];
    if (days is! List ||
        days.isEmpty ||
        days.length > 7 ||
        days.any((day) => day is! int || day < 1 || day > 7) ||
        days.toSet().length != days.length) {
      throw const FormatException('Invalid weekdays');
    }
    final start = policyInt(json, 'startMinute', fallback: 0, maximum: 1439);
    final end = policyInt(
      json,
      'endMinute',
      fallback: 1440,
      minimum: 0,
      maximum: 1440,
    );
    if (start == end) {
      throw const FormatException('A time window needs distinct start and end');
    }
    return PolicyWindow(
      weekdays: List<int>.unmodifiable(days.cast<int>()),
      startMinute: start,
      endMinute: end,
    );
  }

  Map<String, Object?> toJson() => {
    'weekdays': weekdays,
    'startMinute': startMinute,
    'endMinute': endMinute,
  };
}

final class PolicySchedule {
  final String timeZone;
  final List<PolicyWindow> windows;

  const PolicySchedule({
    this.timeZone = 'Asia/Shanghai',
    this.windows = const [],
  });

  factory PolicySchedule.fromJson(Map<String, Object?> json) {
    policyKeys(json, {'timeZone', 'windows'});
    final zone = policyString(json, 'timeZone', fallback: 'Asia/Shanghai');
    if (zone != 'Asia/Shanghai' && zone != 'UTC') {
      throw const FormatException('Supported time zones: Asia/Shanghai, UTC');
    }
    return PolicySchedule(
      timeZone: zone,
      windows: policyItems(json, 'windows', PolicyWindow.fromJson, maximum: 20),
    );
  }

  Map<String, Object?> toJson() => {
    'timeZone': timeZone,
    'windows': windows.map((window) => window.toJson()).toList(),
  };
}

final class LocalPolicy {
  final String id;
  final String label;
  final String targetId;
  final bool enabled;
  final int priority;
  final PolicyMatch scope;
  final PolicyAction action;
  final List<String> candidateNodeIds;
  final List<PolicyChoice> choices;
  final PolicyOrigin origin;
  final bool userModified;
  final PolicyProbe probe;
  final PolicyGuard guard;
  final PolicySchedule schedule;
  final int recoverySeconds;
  final int cooldownSeconds;
  final bool autoRecover;
  final PolicyFallback fallback;
  final bool terminateConnectionsOnExclusion;

  const LocalPolicy({
    required this.id,
    required this.label,
    required this.targetId,
    this.candidateNodeIds = const [],
    this.choices = const [],
    this.origin = PolicyOrigin.unknown,
    this.userModified = false,
    this.enabled = true,
    this.priority = 100,
    this.scope = const PolicyMatch(),
    this.action = PolicyAction.proxy,
    this.probe = const PolicyProbe(),
    this.guard = const PolicyGuard(),
    this.schedule = const PolicySchedule(),
    this.recoverySeconds = 300,
    this.cooldownSeconds = 60,
    this.autoRecover = true,
    this.fallback = PolicyFallback.reject,
    this.terminateConnectionsOnExclusion = false,
  });

  String get groupName => scope.type == PolicyMatchType.group
      ? scope.values.single
      : 'fl-policy-${policyDigest(id).substring(0, 16)}';

  factory LocalPolicy.fromJson(Map<String, Object?> json) {
    policyKeys(json, {
      'id',
      'label',
      'targetId',
      'enabled',
      'priority',
      'scope',
      'action',
      'candidateNodeIds',
      'choices',
      'origin',
      'userModified',
      'probe',
      'guard',
      'schedule',
      'recoverySeconds',
      'cooldownSeconds',
      'autoRecover',
      'fallback',
      'terminateConnectionsOnExclusion',
    });
    final id = policyString(json, 'id', maximum: 128);
    final label = policyString(json, 'label', maximum: 200);
    final target = policyString(json, 'targetId', maximum: 128);
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(id) ||
        label.trim().isEmpty ||
        !RegExp(r'^(profile|integration):[A-Za-z0-9_-]+$').hasMatch(target)) {
      throw const FormatException('Invalid policy identity or target');
    }
    final candidates = policyStrings(json, 'candidateNodeIds', maximum: 10);
    final action = PolicyAction.values.byName(
      policyString(json, 'action', fallback: 'proxy'),
    );
    final choices = policyItems(
      json,
      'choices',
      PolicyChoice.fromJson,
      maximum: 10,
    );
    if ((action == PolicyAction.proxy &&
            candidates.isEmpty &&
            choices.isEmpty) ||
        (action != PolicyAction.proxy &&
            (candidates.isNotEmpty || choices.isNotEmpty)) ||
        (candidates.isNotEmpty && choices.isNotEmpty) ||
        candidates.toSet().length != candidates.length ||
        choices.map((c) => '${c.type.name}:${c.id}').toSet().length !=
            choices.length) {
      throw const FormatException(
        'Policy requires a unique ordered candidate list',
      );
    }
    return LocalPolicy(
      id: id,
      label: label,
      targetId: target,
      enabled: policyBool(json, 'enabled', fallback: true),
      priority: policyInt(json, 'priority', fallback: 100, maximum: 1000000),
      scope: PolicyMatch.fromJson(
        policyObject(json['scope'] ?? <String, Object?>{}, 'scope'),
      ),
      action: action,
      candidateNodeIds: candidates,
      choices: choices,
      origin: PolicyOrigin.values.byName(
        policyString(json, 'origin', fallback: 'unknown'),
      ),
      userModified: policyBool(json, 'userModified'),
      probe: PolicyProbe.fromJson(
        policyObject(json['probe'] ?? <String, Object?>{}, 'probe'),
      ),
      guard: PolicyGuard.fromJson(
        policyObject(json['guard'] ?? <String, Object?>{}, 'guard'),
      ),
      schedule: PolicySchedule.fromJson(
        policyObject(json['schedule'] ?? <String, Object?>{}, 'schedule'),
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
      autoRecover: policyBool(json, 'autoRecover', fallback: true),
      fallback: PolicyFallback.values.byName(
        policyString(json, 'fallback', fallback: 'reject'),
      ),
      terminateConnectionsOnExclusion: policyBool(
        json,
        'terminateConnectionsOnExclusion',
      ),
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'label': label,
    'targetId': targetId,
    'enabled': enabled,
    'priority': priority,
    'scope': scope.toJson(),
    'action': action.name,
    'candidateNodeIds': candidateNodeIds,
    'choices': choices.map((c) => c.toJson()).toList(),
    'origin': origin.name,
    'userModified': userModified,
    'probe': probe.toJson(),
    'guard': guard.toJson(),
    'schedule': schedule.toJson(),
    'recoverySeconds': recoverySeconds,
    'cooldownSeconds': cooldownSeconds,
    'autoRecover': autoRecover,
    'fallback': fallback.name,
    'terminateConnectionsOnExclusion': terminateConnectionsOnExclusion,
  };

  Map<String, Object?> toCoreJson() => Map<String, Object?>.from(toJson())
    ..remove('scope')
    ..remove('priority')
    ..remove('targetId')
    ..remove('origin')
    ..remove('userModified')
    ..remove('fallback')
    ..['skipUnavailable'] = true
    ..['groupName'] = groupName;
}

final class SourceBudget {
  final String sourceId;
  final int limitBytes;
  final int resetDay;
  final String timeZone;

  const SourceBudget({
    required this.sourceId,
    required this.limitBytes,
    this.resetDay = 1,
    this.timeZone = 'Asia/Shanghai',
  });

  factory SourceBudget.fromJson(Map<String, Object?> json) {
    policyKeys(json, {'sourceId', 'limitBytes', 'resetDay', 'timeZone'});
    final timeZone = policyString(json, 'timeZone', fallback: 'Asia/Shanghai');
    if (!{'Asia/Shanghai', 'UTC'}.contains(timeZone)) {
      throw const FormatException('Unsupported budget time zone');
    }
    return SourceBudget(
      sourceId: policyString(json, 'sourceId', maximum: 128),
      limitBytes: policyInt(json, 'limitBytes', minimum: 1),
      resetDay: policyInt(
        json,
        'resetDay',
        fallback: 1,
        minimum: 1,
        maximum: 28,
      ),
      timeZone: timeZone,
    );
  }

  Map<String, Object?> toJson() => {
    'sourceId': sourceId,
    'limitBytes': limitBytes,
    'resetDay': resetDay,
    'timeZone': timeZone,
  };
}

final class PolicyOverride {
  final String policyId;
  final String nodeId;
  final String? nodeSetId;
  final int expiresAt;

  const PolicyOverride({
    required this.policyId,
    required this.nodeId,
    this.nodeSetId,
    required this.expiresAt,
  });

  factory PolicyOverride.fromJson(Map<String, Object?> json) {
    policyKeys(json, {'policyId', 'nodeId', 'nodeSetId', 'expiresAt'});
    final setId = json['nodeSetId'];
    if (setId != null &&
        (setId is! String ||
            setId.isNotEmpty &&
                !RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(setId))) {
      throw const FormatException('Invalid temporary node set identity');
    }
    return PolicyOverride(
      policyId: policyString(json, 'policyId', maximum: 128),
      nodeId: policyString(json, 'nodeId', maximum: 256),
      nodeSetId: setId == '' ? null : setId as String?,
      expiresAt: policyInt(json, 'expiresAt', minimum: 1),
    );
  }

  String get selectionKey => policyDigest({
    'nodeId': nodeId,
    'nodeSetId': nodeSetId?.isNotEmpty == true ? nodeSetId : null,
  });

  bool references(LocalPolicy policy) =>
      policy.id == policyId &&
      (nodeSetId?.isNotEmpty == true
          ? policy.choices.any(
              (choice) =>
                  choice.type == PolicyChoiceType.nodeSet &&
                  choice.id == nodeSetId,
            )
          : policy.choices.isEmpty
          ? policy.candidateNodeIds.contains(nodeId)
          : policy.choices.any(
              (choice) =>
                  choice.type == PolicyChoiceType.node && choice.id == nodeId,
            ));

  bool allows(
    LocalPolicy policy,
    LocalNode node,
    List<PolicyNodeSet> nodeSets,
  ) {
    if (!references(policy) || node.id != nodeId) return false;
    if (nodeSetId?.isNotEmpty != true) return true;
    final set = nodeSets.firstWhereOrNull((entry) => entry.id == nodeSetId);
    return set != null &&
        set.targetId == policy.targetId &&
        set.exclusion(node) == null;
  }

  Map<String, Object?> toJson() => {
    'policyId': policyId,
    'nodeId': nodeId,
    if (nodeSetId?.isNotEmpty == true) 'nodeSetId': nodeSetId,
    'expiresAt': expiresAt,
  };
}

final class SubscriptionIntegration {
  final String id;
  final String label;
  final List<int> sourceProfileIds;
  final String? nameFilter;
  final List<String> excludedNodeIds;
  final PolicyFallback fallback;

  const SubscriptionIntegration({
    required this.id,
    required this.label,
    required this.sourceProfileIds,
    this.nameFilter,
    this.excludedNodeIds = const [],
    this.fallback = PolicyFallback.reject,
  });

  String get targetId => 'integration:$id';

  factory SubscriptionIntegration.fromJson(Map<String, Object?> json) {
    policyKeys(json, {
      'id',
      'label',
      'sourceProfileIds',
      'nameFilter',
      'excludedNodeIds',
      'fallback',
    });
    final ids = json['sourceProfileIds'];
    if (ids is! List ||
        (ids.isEmpty && json['id'] != localPolicyProfileId) ||
        ids.length > 20 ||
        ids.map(policyIdentifier).toSet().length != ids.length) {
      throw const FormatException(
        'Integration requires 1–20 unique source profiles',
      );
    }
    final id = policyString(json, 'id', maximum: 128);
    final label = policyString(json, 'label', maximum: 200);
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(id) || label.trim().isEmpty) {
      throw const FormatException('Invalid integration identity');
    }
    final filter = json['nameFilter'];
    if (filter != null && (filter is! String || filter.length > 200)) {
      throw const FormatException('Invalid node name filter');
    }
    return SubscriptionIntegration(
      id: id,
      label: label,
      sourceProfileIds: List<int>.unmodifiable(ids.map(policyIdentifier)),
      nameFilter: filter as String?,
      excludedNodeIds: policyStrings(json, 'excludedNodeIds', maximum: 5000),
      fallback: PolicyFallback.values.byName(
        policyString(json, 'fallback', fallback: 'reject'),
      ),
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'label': label,
    'sourceProfileIds': sourceProfileIds.map((id) => '$id').toList(),
    'nameFilter': nameFilter,
    'excludedNodeIds': excludedNodeIds,
    'fallback': fallback.name,
  };
}

final class LocalNode {
  final String id;
  final String sourceId;
  final String label;
  final String sourceLabel;
  final String protocol;
  final Map<String, Object?> raw;
  final NodeAttributes attributes;

  LocalNode({
    required this.id,
    required this.sourceId,
    required this.label,
    required this.sourceLabel,
    required this.protocol,
    required Map<String, Object?> raw,
    this.attributes = const NodeAttributes(),
  }) : raw = Map.unmodifiable(raw);

  String get proxyName {
    String safe(String text) {
      final value = text.replaceAll(RegExp(r'[,\r\n()]'), ' ').trim();
      final buffer = StringBuffer();
      var bytes = 0;
      for (final rune in value.runes) {
        final character = String.fromCharCode(rune);
        bytes += utf8.encode(character).length;
        if (bytes > 100) break;
        buffer.write(character);
      }
      return buffer.toString();
    }

    return '${safe(sourceLabel)} · ${safe(label)} [${policyDigest(id).substring(0, 12)}]';
  }

  Map<String, Object?> get summary => {
    'id': id,
    'sourceId': sourceId,
    'label': label,
    'sourceLabel': sourceLabel,
    'protocol': protocol,
    'attributes': attributes.toJson(),
  };
}

enum SourceUpdateRoute { proxy, direct }

final class PolicySourceException extends FormatException {
  final String option;
  const PolicySourceException(this.option)
    : super('Unsupported source option: $option');
}

final class LocalPolicyDocument {
  final int schemaVersion;
  final int revision;
  final bool policiesEnabled;
  final bool integrationEnabled;
  final bool budgetsEnabled;
  final SourceUpdateRoute sourceUpdateRoute;
  final String? activeIntegrationId;
  final bool migrationReviewRequired;
  final List<SubscriptionIntegration> integrations;
  final List<LocalPolicy> policies;
  final List<SourceBudget> budgets;
  final List<PolicyOverride> overrides;
  final bool? _moduleEnabled;
  bool get moduleEnabled =>
      _moduleEnabled ??
      (policiesEnabled || integrationEnabled || budgetsEnabled);
  final List<PolicyNodeSet> nodeSets;
  final Map<String, NodeAttributes> nodeAttributes;

  const LocalPolicyDocument({
    this.schemaVersion = 3,
    this.revision = 0,
    this.policiesEnabled = false,
    this.integrationEnabled = false,
    this.budgetsEnabled = false,
    this.sourceUpdateRoute = SourceUpdateRoute.proxy,
    this.activeIntegrationId,
    this.migrationReviewRequired = false,
    this.integrations = const [],
    this.policies = const [],
    this.budgets = const [],
    this.overrides = const [],
    bool? moduleEnabled,
    this.nodeSets = const [],
    this.nodeAttributes = const {},
  }) : _moduleEnabled = moduleEnabled;

  SubscriptionIntegration? get activeIntegration => integrations
      .firstWhereOrNull((integration) => integration.id == activeIntegrationId);

  bool get isStandalone => schemaVersion >= 4;

  SubscriptionIntegration get localProfile =>
      integrations.firstWhereOrNull(
        (entry) => entry.id == localPolicyProfileId,
      ) ??
      const SubscriptionIntegration(
        id: localPolicyProfileId,
        label: 'Local configuration',
        sourceProfileIds: [],
      );

  LocalPolicyDocument asStandalone() {
    if (isStandalone) {
      validate();
      return this;
    }
    final sourceIds = <int>{
      for (final entry in integrations) ...entry.sourceProfileIds,
      for (final rule in policies)
        if (rule.targetId.startsWith('profile:'))
          ?int.tryParse(rule.targetId.split(':').last),
      for (final set in nodeSets) ...[
        if (set.targetId.startsWith('profile:'))
          ?int.tryParse(set.targetId.split(':').last),
        ...set.sourceIds.map(int.tryParse).whereType<int>(),
      ],
      for (final id in policies.expand(
        (rule) => [
          ...rule.candidateNodeIds,
          ...rule.choices
              .where((choice) => choice.type == PolicyChoiceType.node)
              .map((choice) => choice.id),
        ],
      ))
        ?int.tryParse(id.split(':').first),
    }..removeWhere((id) => id <= 0);
    final indexed = policies.indexed.toList()
      ..sort((a, b) {
        final order = a.$2.priority.compareTo(b.$2.priority);
        return order == 0 ? a.$1.compareTo(b.$1) : order;
      });
    var archivedLocalId = '${localPolicyProfileId}_legacy';
    var archiveIndex = 1;
    while (integrations.any((entry) => entry.id == archivedLocalId)) {
      archivedLocalId = '${localPolicyProfileId}_legacy_${archiveIndex++}';
    }
    return LocalPolicyDocument.fromJson({
      ...toJson(),
      'schemaVersion': 4,
      'integrationEnabled': false,
      'policiesEnabled': false,
      'activeIntegrationId': localPolicyProfileId,
      'migrationReviewRequired':
          policies.isNotEmpty || integrationEnabled || sourceIds.length > 20,
      'integrations': [
        {
          'id': localPolicyProfileId,
          'label': 'Local configuration',
          'sourceProfileIds': sourceIds.length > 20
              ? <String>[]
              : sourceIds.map((id) => '$id').toList(),
          'fallback': 'reject',
        },
        for (final entry in integrations)
          {
            ...entry.toJson(),
            'id': entry.id == localPolicyProfileId ? archivedLocalId : entry.id,
          },
      ],
      'nodeSets': [
        for (final set in nodeSets)
          {...set.toJson(), 'targetId': localPolicyTargetId},
      ],
      'policies': [
        for (var index = 0; index < indexed.length; index++)
          {
            ...indexed[index].$2.toJson(),
            'targetId': localPolicyTargetId,
            'priority': index + 1,
            'enabled': false,
          },
      ],
    });
  }

  Set<int> sourceProfileIdsForTarget(
    String targetId, {
    bool enabledOnly = true,
  }) {
    if (targetId.startsWith('integration:')) {
      return integrations
              .firstWhereOrNull((entry) => entry.targetId == targetId)
              ?.sourceProfileIds
              .toSet() ??
          {};
    }
    final profileId = int.tryParse(targetId.split(':').last);
    final rules = policies.where(
      (rule) => rule.targetId == targetId && (!enabledOnly || rule.enabled),
    );
    final referencedSets = rules
        .expand((rule) => rule.choices)
        .where((choice) => choice.type == PolicyChoiceType.nodeSet)
        .map((choice) => choice.id)
        .toSet();
    return {
      ?profileId,
      for (final set in nodeSets.where(
        (set) => referencedSets.contains(set.id),
      )) ...[
        ...set.sourceIds.map(int.parse),
        ...set.excludedSourceIds.map(int.parse),
      ],
      for (final id in rules.expand(
        (rule) => [
          ...rule.candidateNodeIds,
          ...rule.choices
              .where((choice) => choice.type == PolicyChoiceType.node)
              .map((choice) => choice.id),
        ],
      ))
        ?int.tryParse(id.split(':').first),
    };
  }

  bool referencesProfile(int id) =>
      integrations.any(
        (entry) =>
            (!isStandalone || entry.id == localPolicyProfileId) &&
            entry.sourceProfileIds.contains(id),
      ) ||
      nodeSets.any(
        (set) =>
            set.targetId == 'profile:$id' ||
            set.sourceIds.contains('$id') ||
            set.excludedSourceIds.contains('$id'),
      ) ||
      policies.any(
        (rule) =>
            rule.targetId == 'profile:$id' ||
            [
              ...rule.candidateNodeIds,
              ...rule.choices
                  .where((choice) => choice.type == PolicyChoiceType.node)
                  .map((choice) => choice.id),
            ].any((nodeId) => nodeId.startsWith('$id:')),
      ) ||
      budgets.any((budget) => budget.sourceId == '$id') ||
      overrides.any((entry) => entry.nodeId.startsWith('$id:'));

  factory LocalPolicyDocument.fromJson(Map<String, Object?> json) {
    policyKeys(json, {
      'schemaVersion',
      'revision',
      'policiesEnabled',
      'integrationEnabled',
      'activeIntegrationId',
      'migrationReviewRequired',
      'integrations',
      'policies',
      'budgets',
      'overrides',
      'budgetsEnabled',
      'sourceUpdateRoute',
      'moduleEnabled',
      'nodeSets',
      'nodeAttributes',
    });
    final version = policyInt(json, 'schemaVersion', fallback: 1, minimum: 1);
    if (version != 1 && version != 2 && version != 3 && version != 4) {
      throw const FormatException('Unsupported local policy schema version');
    }
    final activeId = json['activeIntegrationId'];
    if (activeId != null && activeId is! String) {
      throw const FormatException('Invalid active integration');
    }
    final document = LocalPolicyDocument(
      schemaVersion: version == 4 ? 4 : 3,
      migrationReviewRequired: policyBool(json, 'migrationReviewRequired'),
      moduleEnabled: policyBool(
        json,
        'moduleEnabled',
        fallback:
            policyBool(json, 'policiesEnabled') ||
            policyBool(json, 'integrationEnabled') ||
            policyBool(json, 'budgetsEnabled'),
      ),
      nodeSets: policyItems(json, 'nodeSets', PolicyNodeSet.fromJson),
      nodeAttributes:
          policyObject(json['nodeAttributes'] ?? {}, 'nodeAttributes').map(
            (key, value) => MapEntry(
              key,
              NodeAttributes.fromJson(policyObject(value, 'attributes')),
            ),
          ),
      revision: policyInt(json, 'revision', fallback: 0),
      policiesEnabled: policyBool(json, 'policiesEnabled'),
      integrationEnabled: policyBool(json, 'integrationEnabled'),
      budgetsEnabled: policyBool(json, 'budgetsEnabled'),
      sourceUpdateRoute: SourceUpdateRoute.values.byName(
        policyString(json, 'sourceUpdateRoute', fallback: 'proxy'),
      ),
      activeIntegrationId: activeId as String?,
      integrations: policyItems(
        json,
        'integrations',
        SubscriptionIntegration.fromJson,
        maximum: version == 4 ? 21 : 20,
      ),
      policies: policyItems(json, 'policies', LocalPolicy.fromJson),
      budgets: policyItems(json, 'budgets', SourceBudget.fromJson, maximum: 20),
      overrides: policyItems(json, 'overrides', PolicyOverride.fromJson),
    );
    document.validate();
    return document;
  }

  void validate() {
    if (isStandalone &&
        (activeIntegrationId != localPolicyProfileId ||
            !integrations.any((entry) => entry.id == localPolicyProfileId) ||
            localProfile.fallback != PolicyFallback.reject ||
            policies.any((rule) => rule.targetId != localPolicyTargetId) ||
            nodeSets.any((set) => set.targetId != localPolicyTargetId))) {
      throw const FormatException('Invalid standalone local configuration');
    }
    if (integrations.map((entry) => entry.id).toSet().length !=
            integrations.length ||
        policies.map((entry) => entry.id).toSet().length != policies.length ||
        budgets.map((entry) => entry.sourceId).toSet().length !=
            budgets.length ||
        overrides.map((entry) => entry.policyId).toSet().length !=
            overrides.length) {
      throw const FormatException('Duplicate local policy identities');
    }
    if (integrationEnabled && activeIntegration == null) {
      throw const FormatException('Choose an integration before enabling it');
    }
    if (nodeSets.length > 100 ||
        nodeAttributes.length > 5000 ||
        nodeSets.map((s) => s.id).toSet().length != nodeSets.length) {
      throw const FormatException('Invalid node set capacity or identity');
    }
    for (final set in nodeSets) {
      PolicyNodeSet.fromJson(set.toJson());
      if (set.targetId.startsWith('integration:') &&
          !integrations.any((i) => i.targetId == set.targetId)) {
        throw const FormatException('Node set target is missing');
      }
    }
    final scopes = <String>{};
    for (final policy in policies) {
      LocalPolicy.fromJson(policy.toJson());
      if (policy.targetId.startsWith('integration:') &&
          !integrations.any((entry) => entry.targetId == policy.targetId)) {
        throw const FormatException('Policy refers to a missing integration');
      }
      for (final choice in policy.choices.where(
        (c) => c.type == PolicyChoiceType.nodeSet,
      )) {
        final set = nodeSets.firstWhereOrNull((s) => s.id == choice.id);
        if (set == null || set.targetId != policy.targetId) {
          throw const FormatException(
            'Node set reference is missing or belongs to another target',
          );
        }
      }
      if (!policy.enabled) continue;
      final scopeKey = '${policy.targetId}/${policy.priority}';
      if (!scopes.add(scopeKey)) {
        throw const FormatException(
          'Enabled policies for one target need unique priorities',
        );
      }
    }
    for (final override in overrides) {
      final policy = policies.firstWhereOrNull(
        (entry) => entry.id == override.policyId,
      );
      if (policy == null || !override.references(policy)) {
        throw const FormatException(
          'Temporary override must reference an allowed candidate',
        );
      }
    }
  }

  LocalPolicyDocument withRevision(int value) => LocalPolicyDocument(
    schemaVersion: schemaVersion,
    moduleEnabled: moduleEnabled,
    nodeSets: nodeSets,
    nodeAttributes: nodeAttributes,
    revision: value,
    policiesEnabled: policiesEnabled,
    integrationEnabled: integrationEnabled,
    budgetsEnabled: budgetsEnabled,
    sourceUpdateRoute: sourceUpdateRoute,
    activeIntegrationId: activeIntegrationId,
    migrationReviewRequired: migrationReviewRequired,
    integrations: integrations,
    policies: policies,
    budgets: budgets,
    overrides: overrides,
  );

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'moduleEnabled': moduleEnabled,
    'nodeSets': nodeSets.map((s) => s.toJson()).toList(),
    'nodeAttributes': nodeAttributes.map(
      (key, value) => MapEntry(key, value.toJson()),
    ),
    'revision': revision,
    'policiesEnabled': policiesEnabled,
    'integrationEnabled': integrationEnabled,
    'budgetsEnabled': budgetsEnabled,
    'sourceUpdateRoute': sourceUpdateRoute.name,
    'activeIntegrationId': activeIntegrationId,
    'migrationReviewRequired': migrationReviewRequired,
    'integrations': integrations.map((entry) => entry.toJson()).toList(),
    'policies': policies.map((entry) => entry.toJson()).toList(),
    'budgets': budgets.map((entry) => entry.toJson()).toList(),
    'overrides': overrides.map((entry) => entry.toJson()).toList(),
  };
}
