import 'dart:async';

import 'package:drift/native.dart';
import 'package:fl_clash/capabilities/gateway.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/database/database.dart' as db;
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/action.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/database.dart';
import 'package:fl_clash/providers/state.dart';
import 'package:fl_clash/providers/workbench.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Controller extends Mock implements WorkbenchController {}

class _Core extends Mock implements CoreController {
  String selected = 'Old';
  int changes = 0;
  @override
  Future<String> changeProxy(ChangeProxyParams params) async {
    selected = params.proxyName;
    changes++;
    return '';
  }

  @override
  Future<void> closeConnections() async {}
  @override
  Future<void> resetConnections() async {}
  @override
  Future<List<Group>> getProxiesGroups({
    required ProxiesSortType sortType,
    required DelayMap delayMap,
    required Map<String, String> selectedMap,
    required String defaultTestUrl,
  }) async => [
    Group(
      type: GroupType.Selector,
      name: 'Group',
      now: selected,
      all: const [
        Proxy(name: 'Old', type: 'ss'),
        Proxy(name: 'New', type: 'ss'),
      ],
    ),
  ];
}

class _Profiles extends Profiles {
  _Profiles(this.initial);
  final Profile initial;
  @override
  List<Profile> build() => [initial];
}

void main() {
  for (final fail in [false, true]) {
    test(
      'R06 proxy_select awaits storage and refreshes groups, write failure=$fail',
      () async {
        final memory = db.Database(NativeDatabase.memory());
        final profile = Profile.normal(
          label: 'fixture',
        ).copyWith(selectedMap: {'Group': 'Old'});
        await memory.profiles.put(profile.toCompanion());
        final core = _Core();
        final storing = Completer<void>();
        late ProviderContainer container;
        late FlutterApplicationCapabilityGateway gateway;
        final provider = Provider(
          (ref) => FlutterApplicationCapabilityGateway(
            ref: ref,
            controller: _Controller(),
            core: core,
          ),
        );
        container = ProviderContainer(
          overrides: [
            profilesProvider.overrideWith(() => _Profiles(profile)),
            currentProfileIdProvider.overrideWithBuild((_, _) => profile.id),
            proxiesCoreProvider.overrideWithValue(core),
            profileWriterProvider.overrideWithValue((value) async {
              await storing.future;
              if (fail) throw StateError('fixture-storage-failed');
              await memory.profiles.put(value.toCompanion());
            }),
          ],
        );
        gateway = container.read(provider);
        addTearDown(() async {
          if (!storing.isCompleted) storing.complete();
          container.dispose();
          await memory.close();
        });
        var completed = false;
        final result = gateway
            .execute('proxy_select', {
              'group': 'Group',
              'node': 'New',
            }, origin: 'cli')
            .then((value) {
              completed = true;
              return value;
            });
        if (fail) {
          unawaited(result.catchError((Object _) => <String, Object?>{}));
        }
        await pumpEventQueue();
        expect(core.selected, 'New');
        expect(completed, false);
        expect(
          (await memory.profilesDao.query().get()).single.selectedMap['Group'],
          'Old',
        );
        storing.complete();
        if (fail) {
          await expectLater(result, throwsStateError);
          expect(
            container.read(currentProfileProvider)?.selectedMap['Group'],
            'Old',
          );
        } else {
          expect((await result)['status'], 'completed');
          expect(
            container.read(currentProfileProvider)?.selectedMap['Group'],
            'New',
          );
        }
        expect(container.read(groupsProvider).single.now, 'New');
        final reloaded = (await memory.profilesDao.query().get()).single;
        expect(reloaded.selectedMap['Group'], fail ? 'Old' : 'New');
        expect(core.changes, 1);
      },
    );
  }
}
