import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fl_clash/common/constant.dart';
import 'package:fl_clash/common/function.dart';
import 'package:fl_clash/common/request.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
  });

  group('AuthorizedTunEnable provider', () {
    test('default is none', () {
      expect(
        container.read(authorizedTunEnableProvider),
        TunAuthorizationState.none,
      );
    });

    test('can store authorized and unauthorized results', () {
      final notifier = container.read(authorizedTunEnableProvider.notifier);
      notifier.update((_) => TunAuthorizationState.authorized);
      expect(
        container.read(authorizedTunEnableProvider),
        TunAuthorizationState.authorized,
      );
      notifier.update((_) => TunAuthorizationState.unauthorized);
      expect(
        container.read(authorizedTunEnableProvider),
        TunAuthorizationState.unauthorized,
      );
    });
  });

  group('Packages provider', () {
    test('default is empty list', () {
      expect(container.read(packagesProvider), isEmpty);
    });

    test('can update state', () {
      const pkg = Package(
        packageName: 'test.app',
        label: 'Test App',
        system: false,
        internet: true,
        lastUpdateTime: 0,
      );
      container.read(packagesProvider.notifier).update((_) => [pkg]);
      expect(container.read(packagesProvider).length, 1);
      expect(container.read(packagesProvider).first.packageName, 'test.app');
    });
  });

  group('Providers provider', () {
    test('setProvider replaces provider with matching name', () {
      final oldProvider = ExternalProvider(
        name: 'Proxy',
        type: 'Proxy',
        count: 1,
        vehicleType: 'HTTP',
        updateAt: DateTime(2026),
      );
      final newProvider = oldProvider.copyWith(count: 2);
      container.read(providersProvider.notifier).update((_) => [oldProvider]);

      container.read(providersProvider.notifier).setProvider(newProvider);

      expect(container.read(providersProvider).single.count, 2);
    });

    test('setProvider ignores null and missing provider names', () {
      final provider = ExternalProvider(
        name: 'Proxy',
        type: 'Proxy',
        count: 1,
        vehicleType: 'HTTP',
        updateAt: DateTime(2026),
      );
      container.read(providersProvider.notifier).update((_) => [provider]);

      container.read(providersProvider.notifier).setProvider(null);
      container
          .read(providersProvider.notifier)
          .setProvider(provider.copyWith(name: 'Other', count: 9));

      expect(container.read(providersProvider).single, provider);
    });
  });

  group('SystemBrightness provider', () {
    test('default is dark', () {
      expect(container.read(systemBrightnessProvider), Brightness.dark);
    });

    test('can update to light', () {
      container
          .read(systemBrightnessProvider.notifier)
          .update((_) => Brightness.light);
      expect(container.read(systemBrightnessProvider), Brightness.light);
    });
  });

  group('LocalIp provider', () {
    test('default is null', () {
      expect(container.read(localIpProvider), null);
    });

    test('can set IP', () {
      container.read(localIpProvider.notifier).update((_) => '192.168.1.1');
      expect(container.read(localIpProvider), '192.168.1.1');
    });
  });

  group('RunTime provider', () {
    test('default is null', () {
      expect(container.read(runTimeProvider), null);
    });

    test('can set runtime', () {
      container.read(runTimeProvider.notifier).update((_) => 3600);
      expect(container.read(runTimeProvider), 3600);
    });
  });

  group('ViewSize provider', () {
    test('default is zero', () {
      expect(container.read(viewSizeProvider), Size.zero);
    });

    test('can update size', () {
      container
          .read(viewSizeProvider.notifier)
          .update((_) => const Size(800, 600));
      final value = container.read(viewSizeProvider);
      expect(value.width, 800);
      expect(value.height, 600);
    });
  });

  group('SideWidth provider', () {
    test('default is 0', () {
      expect(container.read(sideWidthProvider), 0.0);
    });

    test('can update side width', () {
      container.read(sideWidthProvider.notifier).update((_) => 300.0);
      expect(container.read(sideWidthProvider), 300.0);
    });
  });

  group('viewWidth provider (derived)', () {
    test('derives from viewSize width', () {
      container
          .read(viewSizeProvider.notifier)
          .update((_) => const Size(800, 600));
      expect(container.read(viewWidthProvider), 800);
    });
  });

  group('viewHeight provider (derived)', () {
    test('derives from viewSize height', () {
      container
          .read(viewSizeProvider.notifier)
          .update((_) => const Size(800, 600));
      expect(container.read(viewHeightProvider), 600);
    });
  });

  group('Init provider', () {
    test('default is false', () {
      expect(container.read(initProvider), false);
    });

    test('can update to true', () {
      container.read(initProvider.notifier).update((_) => true);
      expect(container.read(initProvider), true);
    });
  });

  group('CurrentPageLabel provider', () {
    test('default is dashboard', () {
      expect(container.read(currentPageLabelProvider), PageLabel.dashboard);
    });

    test('toPage changes page', () {
      container
          .read(currentPageLabelProvider.notifier)
          .toPage(PageLabel.proxies);
      expect(container.read(currentPageLabelProvider), PageLabel.proxies);
    });

    test('toProfiles changes page', () {
      container.read(currentPageLabelProvider.notifier).toProfiles();
      expect(container.read(currentPageLabelProvider), PageLabel.profiles);
    });
  });

  group('SortNum provider', () {
    test('default is 0', () {
      expect(container.read(sortNumProvider), 0);
    });

    test('can update', () {
      container.read(sortNumProvider.notifier).update((_) => 5);
      expect(container.read(sortNumProvider), 5);
    });
  });

  group('Version provider', () {
    test('default is 0', () {
      expect(container.read(versionProvider), 0);
    });

    test('can set version', () {
      container.read(versionProvider.notifier).update((_) => 3);
      expect(container.read(versionProvider), 3);
    });
  });

  group('Groups provider', () {
    test('default is empty', () {
      expect(container.read(groupsProvider), isEmpty);
    });

    test('can set groups', () {
      final groups = [
        const Group(name: 'G1', type: GroupType.Selector, now: 'auto'),
      ];
      container.read(groupsProvider.notifier).update((_) => groups);
      expect(container.read(groupsProvider).length, 1);
      expect(container.read(groupsProvider).first.name, 'G1');
    });
  });

  group('TotalTraffic provider', () {
    test('default is empty Traffic', () {
      final t = container.read(totalTrafficProvider);
      expect(t.up, 0);
      expect(t.down, 0);
    });
  });

  group('CheckIpNum provider', () {
    test('default is 0', () {
      expect(container.read(checkIpNumProvider), 0);
    });

    test('increment returns previous value and updates state', () {
      final value = container.read(checkIpNumProvider.notifier).add();

      expect(value, 0);
      expect(container.read(checkIpNumProvider), 1);
    });
  });

  group('SortNum provider', () {
    test('increment returns previous value and updates state', () {
      final value = container.read(sortNumProvider.notifier).add();

      expect(value, 0);
      expect(container.read(sortNumProvider), 1);
    });
  });

  group('DelayDataSource provider', () {
    test('sets delay by url and proxy name', () {
      container
          .read(delayDataSourceProvider.notifier)
          .setDelay(
            const Delay(name: 'Proxy', url: 'https://test.example', value: 120),
          );

      expect(container.read(delayDataSourceProvider), {
        'https://test.example': {'Proxy': 120},
      });
    });

    test('keeps same state instance when delay value is unchanged', () {
      final notifier = container.read(delayDataSourceProvider.notifier);
      const delay = Delay(name: 'Proxy', url: 'https://test.example', value: 1);
      notifier.setDelay(delay);
      final state = container.read(delayDataSourceProvider);

      notifier.setDelay(delay);

      expect(identical(container.read(delayDataSourceProvider), state), isTrue);
    });
  });

  group('Loading provider', () {
    test('stop without start sets loading false immediately', () async {
      final notifier = container.read(
        loadingProvider(LoadingTag.profiles).notifier,
      );

      await notifier.stop();

      expect(container.read(loadingProvider(LoadingTag.profiles)), false);
    });

    test('stop keeps loading visible for minimum duration', () async {
      final notifier = container.read(
        loadingProvider(LoadingTag.profiles).notifier,
      );

      notifier.start();
      await notifier.stop();

      expect(container.read(loadingProvider(LoadingTag.profiles)), true);

      await Future.delayed(const Duration(milliseconds: 1100));

      expect(container.read(loadingProvider(LoadingTag.profiles)), false);
    });
  });

  group('CoreStatus provider', () {
    test('default is disconnected', () {
      expect(container.read(coreStatusProvider), CoreStatus.disconnected);
    });
  });

  group('NetworkDetection provider', () {
    late HttpClientAdapter originalAdapter;

    setUp(() {
      originalAdapter = request.dio.httpClientAdapter;
    });

    tearDown(() {
      request.dio.httpClientAdapter = originalAdapter;
    });

    testWidgets('ignores a canceled stale check after a newer check succeeds', (
      tester,
    ) async {
      final adapter = _ControlledIpAdapter();
      final interceptor = InterceptorsWrapper(
        onError: adapter.holdStaleCancellation,
      );
      request.dio.httpClientAdapter = adapter;
      request.dio.interceptors.add(interceptor);
      final container = ProviderContainer(
        overrides: [
          initProvider.overrideWithBuild((_, _) => true),
          runTimeProvider.overrideWithBuild((_, _) => 1),
        ],
      );

      try {
        final notifier = container.read(networkDetectionProvider.notifier);
        notifier.startCheck();
        await tester.pump(commonDuration);
        expect(adapter.staleRequestCount, greaterThan(0));

        notifier.startCheck();
        await tester.pump(commonDuration);
        expect(adapter.currentRequestCount, adapter.staleRequestCount);
        expect(adapter.staleCancellationCount, adapter.staleRequestCount);
        expect(adapter.releasedStaleCancellationCount, 0);
        expect(container.read(networkDetectionProvider).isLoading, isTrue);
        expect(container.read(networkDetectionProvider).ipInfo, isNull);

        adapter.completeCurrentCheck();
        await tester.pump(Duration.zero);

        expect(container.read(networkDetectionProvider).ipInfo?.ip, '2.2.2.2');
        expect(container.read(networkDetectionProvider).isLoading, isFalse);
        expect(adapter.releasedStaleCancellationCount, 0);

        adapter.releaseStaleCheck();
        await tester.pump(Duration.zero);
        expect(
          adapter.releasedStaleCancellationCount,
          adapter.staleRequestCount,
        );
        await tester.pump(const Duration(seconds: 3));

        expect(container.read(networkDetectionProvider).ipInfo?.ip, '2.2.2.2');
        expect(container.read(networkDetectionProvider).isLoading, isFalse);
      } finally {
        request.dio.interceptors.remove(interceptor);
        debouncer.cancel(FunctionTag.checkIp);
        container.dispose();
        adapter.releaseStaleCheck();
        adapter.close(force: true);
        await tester.pump(Duration.zero);
      }
    });
  });
}

class _ControlledIpAdapter implements HttpClientAdapter {
  final _staleRequests = <RequestOptions, Completer<ResponseBody>>{};
  final _currentRequests = <RequestOptions, Completer<ResponseBody>>{};
  final _releaseStaleCancellation = Completer<void>();
  CancelToken? _staleCancelToken;
  int staleCancellationCount = 0;
  int releasedStaleCancellationCount = 0;

  int get staleRequestCount => _staleRequests.length;
  int get currentRequestCount => _currentRequests.length;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    _staleCancelToken ??= options.cancelToken;
    final requests = options.cancelToken == _staleCancelToken
        ? _staleRequests
        : _currentRequests;
    final completer = Completer<ResponseBody>();
    requests[options] = completer;
    cancelFuture?.then((_) {
      if (completer.isCompleted) return;
      completer.completeError(
        DioException(
          requestOptions: options,
          type: DioExceptionType.cancel,
          error: 'cancelled',
        ),
      );
    });
    return completer.future;
  }

  void holdStaleCancellation(
    DioException error,
    ErrorInterceptorHandler handler,
  ) {
    if (error.type != DioExceptionType.cancel ||
        error.requestOptions.cancelToken != _staleCancelToken) {
      handler.next(error);
      return;
    }
    staleCancellationCount++;
    _releaseStaleCancellation.future.then((_) {
      releasedStaleCancellationCount++;
      handler.next(error);
    });
  }

  void completeCurrentCheck() {
    for (final completer in _currentRequests.values) {
      completer.complete(
        ResponseBody.fromString(
          '{"ip":"2.2.2.2","country_code":"US"}',
          200,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        ),
      );
    }
  }

  void releaseStaleCheck() {
    if (!_releaseStaleCancellation.isCompleted) {
      _releaseStaleCancellation.complete();
    }
  }

  @override
  void close({bool force = false}) {
    for (final entry in [
      ..._staleRequests.entries,
      ..._currentRequests.entries,
    ]) {
      if (entry.value.isCompleted) continue;
      entry.value.completeError(
        DioException(
          requestOptions: entry.key,
          type: DioExceptionType.cancel,
          error: 'closed',
        ),
      );
    }
  }
}
