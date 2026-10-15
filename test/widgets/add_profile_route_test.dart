import 'dart:async';

import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/profile.dart';
import 'package:fl_clash/providers/action.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/profiles/add.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeProfilesAction extends ProfilesAction {
  Profile? imported;
  bool? fileNavigateToProfiles;
  bool? urlNavigateToProfiles;
  bool? qrNavigateToProfiles;
  String? url;

  @override
  Future<Profile?> addProfileFormFile({bool navigateToProfiles = true}) async {
    fileNavigateToProfiles = navigateToProfiles;
    return imported;
  }

  @override
  Future<Profile?> addProfileFormURL(
    String value, {
    bool navigateToProfiles = true,
  }) async {
    url = value;
    urlNavigateToProfiles = navigateToProfiles;
    return imported;
  }

  @override
  Future<Profile?> addProfileFormQrCode({
    bool navigateToProfiles = true,
  }) async {
    qrNavigateToProfiles = navigateToProfiles;
    return imported;
  }
}

late ProviderContainer _container;
late _FakeProfilesAction _action;

Future<void> _mountAddProfile(
  WidgetTester tester, {
  required bool navigateToProfiles,
}) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: _container,
      child: MaterialApp(
        navigatorKey: globalState.navigatorKey,
        locale: const Locale('zh', 'CN'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        home: const Scaffold(body: Text('规则草稿')),
      ),
    ),
  );
  await tester.pumpAndSettle();
  unawaited(
    globalState.navigatorKey.currentState!.push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          body: AddProfileView(
            context: context,
            navigateToProfiles: navigateToProfiles,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    _container = ProviderContainer(
      overrides: [
        profilesActionProvider.overrideWith(_FakeProfilesAction.new),
        viewSizeProvider.overrideWithBuild((_, _) => const Size(800, 600)),
      ],
    );
    _action =
        _container.read(profilesActionProvider.notifier) as _FakeProfilesAction;
    globalState.container = _container;
  });

  tearDownAll(() => _container.dispose());

  setUp(() {
    _action.imported = Profile.normal(label: '导入成功');
    _action.fileNavigateToProfiles = null;
    _action.urlNavigateToProfiles = null;
    _action.qrNavigateToProfiles = null;
    _action.url = null;
  });

  testWidgets('局部导入成功只关闭添加页并保留底层规则草稿', (tester) async {
    await _mountAddProfile(tester, navigateToProfiles: false);
    await tester.tap(find.text(AppLocalizations.current.file));
    await tester.pumpAndSettle();

    expect(_action.fileNavigateToProfiles, isFalse);
    expect(find.text('规则草稿', skipOffstage: false), findsOneWidget);
    expect(find.text(AppLocalizations.current.file), findsNothing);
  });

  testWidgets('局部导入失败留在添加页，取消 URL 也不销毁草稿', (tester) async {
    _action.imported = null;
    await _mountAddProfile(tester, navigateToProfiles: false);
    await tester.tap(find.text(AppLocalizations.current.file));
    await tester.pumpAndSettle();
    expect(find.text(AppLocalizations.current.file), findsOneWidget);
    expect(find.text('规则草稿', skipOffstage: false), findsOneWidget);

    await tester.tap(find.text(AppLocalizations.current.url));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppLocalizations.current.cancel));
    await tester.pumpAndSettle();
    expect(find.text(AppLocalizations.current.url), findsOneWidget);
    expect(_action.url, isNull);
    expect(find.text('规则草稿', skipOffstage: false), findsOneWidget);
  });

  testWidgets('URL 与二维码局部导入传递保留路由参数', (tester) async {
    await _mountAddProfile(tester, navigateToProfiles: false);
    await tester.tap(find.text(AppLocalizations.current.url));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      'https://example.com/sub.yaml',
    );
    await tester.tap(find.text(AppLocalizations.current.submit));
    await tester.pumpAndSettle();
    expect(_action.urlNavigateToProfiles, isFalse);
    expect(_action.url, 'https://example.com/sub.yaml');
    expect(find.text('规则草稿'), findsOneWidget);

    await _mountAddProfile(tester, navigateToProfiles: false);
    await tester.tap(find.text(AppLocalizations.current.qrcode));
    await tester.pumpAndSettle();
    expect(_action.qrNavigateToProfiles, isFalse);
  });

  testWidgets('默认导入仍传递跳转配置页参数', (tester) async {
    await _mountAddProfile(tester, navigateToProfiles: true);
    await tester.tap(find.text(AppLocalizations.current.file));
    await tester.pumpAndSettle();
    expect(_action.fileNavigateToProfiles, isTrue);
  });
}
