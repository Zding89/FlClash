import 'dart:async';

class CapabilityRuntimeEvents {
  final _events = StreamController<Map<String, Object?>>.broadcast(sync: true);
  final Map<String, Map<String, Object?>> _geo = {};
  Map<String, Object?>? _proxy;
  Map<String, Object?>? _hotkeys;
  int _revision = 0;

  int get revision => _revision;
  Map<String, Object?> get snapshot => {
    'revision': _revision,
    'geo': Map<String, Map<String, Object?>>.from(_geo),
    'systemProxy': _proxy,
    'hotkeys': _hotkeys,
  };

  void reportGeo(String type, bool updating, bool skipped, String? error) {
    final event = <String, Object?>{
      'kind': 'geo',
      'type': type.toLowerCase(),
      'updating': updating,
      'skipped': skipped,
      'failed': error != null && error.isNotEmpty,
      'revision': ++_revision,
      'observedAt': DateTime.now().millisecondsSinceEpoch,
    };
    _geo[type.toLowerCase()] = event;
    _events.add(event);
  }

  void reportProxy({required bool enabled, required bool applied}) {
    final event = <String, Object?>{
      'kind': 'proxy',
      'enabled': enabled,
      'applied': applied,
      'revision': ++_revision,
      'observedAt': DateTime.now().millisecondsSinceEpoch,
    };
    _proxy = event;
    _events.add(event);
  }

  void reportHotkeys({required bool applied, required int? count}) {
    _hotkeys = {
      'applied': applied,
      'count': count,
      'revision': ++_revision,
      'observedAt': DateTime.now().millisecondsSinceEpoch,
    };
  }

  Future<Map<String, Object?>> waitForGeo(
    String type, {
    required int afterRevision,
    Duration timeout = const Duration(minutes: 5),
  }) async {
    bool completed(Map<String, Object?> event) =>
        event['kind'] == 'geo' &&
        event['type'] == type.toLowerCase() &&
        (event['revision'] as int) > afterRevision &&
        event['updating'] == false;
    final latest = _geo[type.toLowerCase()];
    if (latest != null && completed(latest)) return latest;
    return _events.stream.firstWhere(completed).timeout(timeout);
  }
}

final capabilityRuntimeEvents = CapabilityRuntimeEvents();
