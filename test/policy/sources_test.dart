import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:fl_clash/database/workbench_database.dart';
import 'package:fl_clash/models/profile.dart';
import 'package:fl_clash/policy/models.dart';
import 'package:fl_clash/policy/sources.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late WorkbenchDatabase store;
  late Map<String, String> files;
  late PolicySourceLoader loader;
  var downloads = 0;
  const profile = Profile(
    id: 7,
    label: 'A',
    autoUpdateDuration: Duration(hours: 1),
  );
  const first =
      'proxies: [{name: A1, type: ss, server: a.example, port: 443, cipher: aes-128-gcm, password: fixture}]';
  const second =
      'proxies: [{name: B2, type: ss, server: b.example, port: 443, cipher: aes-128-gcm, password: fixture}]';

  setUp(() {
    store = WorkbenchDatabase(NativeDatabase.memory());
    files = {
      '/profile/7':
          'proxy-providers: {remote: {type: http, url: "https://example.invalid/nodes"}}',
      '/cache/7': first,
    };
    downloads = 0;
    loader = PolicySourceLoader(
      store: store,
      profilePath: (id) async => '/profile/$id',
      providerCachePath: (id, url) async => '/cache/$id',
      readFile: (path) async => files[path],
      writeFile: (path, content) async => files[path] = content,
      fetchFile: (url) async {
        downloads++;
        return second;
      },
    );
  });
  tearDown(() => store.close());

  test(
    'refresh fetches an existing provider cache and changes its fingerprint',
    () async {
      final before = await loader.fingerprint(profile);
      final cached = await loader.load([profile]);
      expect(downloads, 0);
      expect((cached.single.raw['proxies'] as List).single['name'], 'A1');
      final refreshed = await loader.load(
        [profile],
        allowNetwork: true,
        persistCache: true,
      );
      expect(downloads, 1);
      expect((refreshed.single.raw['proxies'] as List).single['name'], 'B2');
      expect(await loader.fingerprint(profile), isNot(before));
    },
  );

  test(
    'unsupported provider options cannot fall back to an old unfiltered snapshot',
    () async {
      await loader.load([profile], persistCache: true);
      files['/profile/7'] =
          'proxy-providers: {remote: {type: http, url: "https://example.invalid/nodes", exclude-filter: C3}}';
      await expectLater(
        loader.load([profile]),
        throwsA(isA<PolicySourceException>()),
      );
    },
  );

  test(
    'unavailable provider preserves the last valid graph and current known expiry',
    () async {
      await loader.load([profile], persistCache: true);
      files.remove('/cache/7');
      final expired = profile.copyWith(
        subscriptionInfo: SubscriptionInfo(
          expire: 100,
          knownFields: const {'expire'},
          observedAt: DateTime.fromMillisecondsSinceEpoch(200000),
        ),
      );
      final fallback = (await loader.load([expired])).single;
      expect(fallback.warning, 'cached_snapshot');
      expect(fallback.expiresAt, 100000);
      expect(fallback.remainingBytes, null);
      expect((fallback.raw['proxies'] as List).single['name'], 'A1');
    },
  );

  test(
    'missing total and zero total remain unknown rather than unlimited',
    () async {
      for (final header in [
        'upload=1; download=2',
        'upload=1; download=2; total=0',
      ]) {
        final value = (await loader.load([
          profile.copyWith(
            subscriptionInfo: SubscriptionInfo.formHString(header),
          ),
        ])).single;
        expect(value.remainingBytes, null);
      }
    },
  );

  test(
    'file provider fingerprints change with content and reject symlink escape',
    () async {
      final home = await Directory.systemTemp.createTemp('flclash-source-deps');
      final outside = await Directory.systemTemp.createTemp(
        'flclash-source-outside',
      );
      addTearDown(() => home.delete(recursive: true));
      addTearDown(() => outside.delete(recursive: true));
      final file = File('${home.path}/nodes.yaml');
      await file.writeAsString(first);
      final disk = PolicySourceLoader(
        store: store,
        homePath: () async => home.path,
      );
      final raw = <String, Object?>{
        'proxy-providers': {
          'file': {'type': 'file', 'path': 'nodes.yaml'},
        },
      };
      final before = await disk.fileProviderDependencies(raw);
      await file.writeAsString(second);
      expect(await disk.fileProviderDependencies(raw), isNot(before));
      await File('${outside.path}/nodes.yaml').writeAsString(first);
      await Link(
        '${home.path}/escape.yaml',
      ).create('${outside.path}/nodes.yaml');
      await expectLater(
        disk.fileProviderDependencies({
          'proxy-providers': {
            'file': {'type': 'file', 'path': 'escape.yaml'},
          },
        }),
        throwsFormatException,
      );
    },
  );

  test('late provider fetch cannot overwrite a newer source cache', () async {
    final directory = await Directory.systemTemp.createTemp(
      'flclash-source-order',
    );
    addTearDown(() => directory.delete(recursive: true));
    final cache = File('${directory.path}/provider.yaml');
    await cache.writeAsString(first);
    final oldResponse = Completer<String>();
    final oldStarted = Completer<void>();
    var epoch = 1;
    var calls = 0;
    final ordered = PolicySourceLoader(
      store: store,
      profilePath: (id) async => '/profile/$id',
      providerCachePath: (id, url) async => cache.path,
      readFile: (path) async =>
          path == '/profile/7' ? files[path] : await File(path).readAsString(),
      fetchFile: (url) async {
        calls++;
        if (calls == 1) {
          oldStarted.complete();
          return oldResponse.future;
        }
        return second;
      },
    );
    final old = ordered.load(
      [profile],
      allowNetwork: true,
      isCurrent: () => epoch == 1,
    );
    final oldFails = expectLater(old, throwsStateError);
    await oldStarted.future;
    epoch = 2;
    final fresh = await ordered.load(
      [profile],
      allowNetwork: true,
      isCurrent: () => epoch == 2,
    );
    expect((fresh.single.raw['proxies'] as List).single['name'], 'B2');
    oldResponse.complete(first);
    await oldFails;
    expect(await cache.readAsString(), second);
    expect(await directory.list().length, 1);
  });

  test(
    'provider commit checks latest intent immediately before atomic rename',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'flclash-source-commit',
      );
      addTearDown(() => directory.delete(recursive: true));
      final cache = File('${directory.path}/provider.yaml');
      await cache.writeAsString(second);
      final disk = PolicySourceLoader(store: store);
      var checks = 0;
      await expectLater(
        disk.commitFile(cache.path, first, isCurrent: () => ++checks == 1),
        throwsStateError,
      );
      expect(checks, 2);
      expect(await cache.readAsString(), second);
      expect(await directory.list().length, 1);
    },
  );
}
