import 'package:fl_clash/capabilities/runtime_events.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'only a matching later terminal resource callback proves completion',
    () async {
      final events = CapabilityRuntimeEvents();
      events.reportGeo('geoip', false, false, null);
      final revision = events.revision;
      final result = events.waitForGeo('geoip', afterRevision: revision);
      var done = false;
      result.then((_) => done = true);
      events.reportGeo('geosite', false, false, null);
      events.reportGeo('geoip', true, false, null);
      await Future<void>.delayed(Duration.zero);
      expect(done, false);
      events.reportGeo('geoip', false, false, 'credential server content');
      final complete = await result;
      expect(complete['failed'], true);
      expect(complete.toString(), isNot(contains('credential server content')));
      events.reportProxy(enabled: true, applied: false);
      expect((events.snapshot['systemProxy'] as Map)['applied'], false);
      events.reportHotkeys(applied: false, count: 0);
      expect((events.snapshot['hotkeys'] as Map)['applied'], false);
    },
  );
}
