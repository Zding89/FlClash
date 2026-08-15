import 'dart:io';

import 'package:test/test.dart';

void main() {
  const productName = 'FlClash Usage';
  const releaseBundleId = 'com.zding.flclash.usage';
  const debugBundleId = 'com.zding.flclash.usage.debug';

  String read(String path) => File(path).readAsStringSync();

  test('macOS app bundle has an independent identity', () {
    final appInfo = read('macos/Runner/Configs/AppInfo.xcconfig');
    final project = read('macos/Runner.xcodeproj/project.pbxproj');
    final scheme = read(
      'macos/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme',
    );

    expect(appInfo, contains('PRODUCT_NAME = $productName'));
    expect(appInfo, contains('PRODUCT_BUNDLE_IDENTIFIER = $releaseBundleId'));
    expect(project, contains('PRODUCT_BUNDLE_IDENTIFIER = $debugBundleId;'));
    expect(project, contains('path = "$productName.app";'));
    expect(
      project,
      contains('INFOPLIST_KEY_CFBundleDisplayName = "$productName";'),
    );
    expect(
      project,
      contains(
        'TEST_HOST = "\$(BUILT_PRODUCTS_DIR)/$productName.app/'
        '\$(BUNDLE_EXECUTABLE_FOLDER_PATH)/$productName";',
      ),
    );
    expect(scheme, contains('BuildableName = "$productName.app"'));
    expect(project, isNot(contains('com.follow.clash')));
    expect(scheme, isNot(contains('BuildableName = "FlClash.app"')));
  });

  test('macOS package and URL schemes do not claim the original identity', () {
    final infoPlist = read('macos/Runner/Info.plist');
    final dmgConfig = read('macos/packaging/dmg/make_config.yaml');
    final distributeOptions = read('distribute_options.yaml');

    expect(
      infoPlist,
      contains(
        '<key>CFBundleDisplayName</key>\n\t<string>\$(PRODUCT_NAME)</string>',
      ),
    );
    expect(infoPlist, contains('<string>clash-usage</string>'));
    expect(infoPlist, contains('<string>clashmeta-usage</string>'));
    expect(infoPlist, contains('<string>flclash-usage</string>'));
    expect(infoPlist, isNot(contains('<string>clash</string>')));
    expect(infoPlist, isNot(contains('<string>clashmeta</string>')));
    expect(infoPlist, isNot(contains('<string>flclash</string>')));
    expect(dmgConfig, contains('title: $productName'));
    expect(dmgConfig, contains('path: $productName.app'));
    expect(distributeOptions, contains("app_name: '$productName'"));
  });

  test('Flutter uses the distinct macOS name for local identities', () {
    final constants = read('lib/common/constant.dart');
    final launch = read('lib/common/launch.dart');
    final davClient = read('lib/common/dav_client.dart');

    expect(constants, contains("const macOSAppName = '$productName';"));
    expect(launch, contains('appName: platformAppName'));
    expect(davClient, contains("String get root => '/\$platformAppName';"));
  });

  test('manual GitHub build validates and uploads the independent app', () {
    final workflow = read('.github/workflows/build-macos-usage.yaml');

    expect(workflow, contains('workflow_dispatch:'));
    expect(workflow, contains('runs-on: macos-latest'));
    expect(workflow, contains('dart setup.dart macos --env stable -v'));
    expect(workflow, contains("test \"\$bundle_id\" = '$releaseBundleId'"));
    expect(workflow, contains("test \"\$display_name\" = '$productName'"));
    expect(workflow, contains('path: dist/*.dmg'));
    expect(workflow, isNot(contains('action-gh-release')));
  });
}
