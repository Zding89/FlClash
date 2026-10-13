import 'dart:io';

import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

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
    expect(
      project,
      contains(
        r'/bin/sh \"$PROJECT_DIR/../services/control/scripts/package_macos.sh\"',
      ),
    );
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

  test(
    'GitHub builds only the development branch and preserves read access',
    () {
      final workflow =
          loadYaml(read('.github/workflows/build-macos-usage.yaml')) as YamlMap;
      final triggers = workflow['on'] as YamlMap;

      expect(triggers.keys, unorderedEquals(['workflow_dispatch', 'push']));
      expect(triggers['push'], {
        'branches': ['codex/macos-usage-cloud-build'],
      });
      expect(workflow['permissions'], {'contents': 'read'});
      expect(workflow['env']['FLUTTER_VERSION'], '3.44.4');
      expect(workflow['env']['FLUTTER_SWIFT_PACKAGE_MANAGER'], 'true');
    },
  );

  test(
    'GitHub build tests packaged runtime before uploading independent app',
    () {
      final workflowText = read('.github/workflows/build-macos-usage.yaml');
      final workflow = loadYaml(workflowText) as YamlMap;
      final job = workflow['jobs']['build'] as YamlMap;
      final steps = (job['steps'] as YamlList).cast<YamlMap>();
      YamlMap step(String name) =>
          steps.singleWhere((step) => step['name'] == name);
      int index(String name) =>
          steps.indexWhere((step) => step['name'] == name);

      expect(job['runs-on'], r'${{ matrix.runner }}');
      expect(job['strategy']['matrix']['include'], [
        {'runner': 'macos-latest', 'arch': 'arm64', 'machine': 'arm64'},
        {'runner': 'macos-15-intel', 'arch': 'x64', 'machine': 'x86_64'},
      ]);
      expect(step('Setup Node')['with']['node-version'], '22.23.3');
      expect(step('Setup pnpm')['with']['version'], '11.21.0');
      expect(step('Setup Go')['with']['go-version'], '1.26.4');
      expect(
        step('Build and test AI agent host')['run'],
        contains(
          'pnpm install --frozen-lockfile --ignore-scripts\npnpm build\npnpm test',
        ),
      );
      expect(
        step('Prepare isolated macOS script test runtime')['run'],
        r'node scripts/package.mjs --arch ${{ matrix.arch }} --resources '
        r'/private/tmp/flclash-ai-host-node22-${{ matrix.arch }}/Resources',
      );
      expect(
        index('Prepare isolated macOS script test runtime'),
        lessThan(index('Test Flutter application')),
      );
      expect(
        step('Analyze Flutter application')['run'],
        'flutter analyze --no-fatal-infos',
      );
      expect(
        step('Test Flutter application')['run'],
        'flutter test --no-pub --reporter expanded',
      );
      expect(
        step('Build and test local control runtime')['run'],
        contains('cargo test --locked'),
      );
      expect(step('Validate Go core wrapper')['env']['CGO_ENABLED'], '0');
      expect(step('Validate Go core wrapper')['run'], 'go test .\ngo vet .\n');
      expect(
        step('Build macOS DMG')['run'],
        contains('dart setup.dart macos --env stable -v'),
      );
      final verification =
          step('Verify built application and packaged AI runtime')['run']
              as String;
      expect(
        verification,
        contains("test \"\$bundle_id\" = '$releaseBundleId'"),
      );
      expect(
        verification,
        contains("test \"\$display_name\" = '$productName'"),
      );
      for (final resource in [
        'node',
        'host.mjs',
        'script_runner.mjs',
        'manifest.json',
        'NODE-LICENSE',
      ]) {
        expect(verification, contains('\$resources/ai/$resource'));
      }
      expect(
        verification,
        contains('/usr/bin/codesign --verify --deep --strict'),
      );
      expect(
        verification,
        contains('node packages/ai_agent_host/scripts/verify.mjs --resources'),
      );
      expect(
        index('Verify built application and packaged AI runtime'),
        lessThan(index('Upload installer')),
      );
      expect(verification, contains(r'$resources/control/flclashctl'));
      expect(
        verification,
        contains(r'$resources/control/libflclash_control.dylib'),
      );
      expect(step('Upload installer')['with']['path'], 'dist/*.dmg');
      expect(step('Upload installer')['with']['retention-days'], 14);
      expect(workflowText, isNot(contains('action-gh-release')));
    },
  );
}
