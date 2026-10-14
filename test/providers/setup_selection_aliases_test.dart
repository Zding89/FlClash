import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/policy/models.dart';
import 'package:fl_clash/providers/action.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ProviderContainer container;
  late SetupAction action;
  const emptyDocument = LocalPolicyDocument();
  const managed = '''
flclash-local-policy:
  enabled: true
  policies:
    - groupName: Managed
flclash-selection-aliases:
  Original: runtime-node
''';

  setUp(() {
    container = ProviderContainer();
    action = container.read(setupActionProvider.notifier);
  });

  tearDown(() => container.dispose());

  test(
    'first launch accepts the real no-profile generated configuration',
    () async {
      final generated = await action.getProfile(
        setupState: const SetupState(
          profileId: null,
          profileLastUpdateDate: null,
          overwriteType: OverwriteType.standard,
          rules: [],
          proxyGroups: [],
          addedRules: [],
          script: null,
          overrideDns: false,
          dns: Dns(),
        ),
        patchConfig: const PatchClashConfig(),
        policyDocument: emptyDocument,
      );
      expect(generated.a, isEmpty);
      expect(
        () => action.updateSelectionAliases(generated.a, emptyDocument),
        returnsNormally,
      );
      expect(action.originalSelection('Group', 'Node'), 'Node');
    },
  );

  test(
    'returning to no profile clears prior aliases and controlled groups',
    () {
      action.updateSelectionAliases(managed, emptyDocument);
      expect(action.originalSelection('Group', 'runtime-node'), 'Original');
      expect(action.originalSelection('Managed', 'runtime-node'), isNull);

      action.updateSelectionAliases('', emptyDocument);

      expect(action.originalSelection('Group', 'runtime-node'), 'runtime-node');
      expect(
        action.originalSelection('Managed', 'runtime-node'),
        'runtime-node',
      );
    },
  );

  test(
    'leaving an integrated target restores ordinary selection ownership',
    () {
      action.updateSelectionAliases(
        managed,
        LocalPolicyDocument.fromJson({
          ...const LocalPolicyDocument().asStandalone().toJson(),
          'moduleEnabled': true,
          'integrationEnabled': true,
          'schemaVersion': 4,
        }).asStandalone(),
      );
      expect(action.originalSelection('Group', 'Node'), isNull);

      action.updateSelectionAliases('', emptyDocument);

      expect(action.originalSelection('Group', 'Node'), 'Node');
    },
  );

  test(
    'non-map configuration remains rejected without clearing prior aliases',
    () {
      action.updateSelectionAliases(managed, emptyDocument);
      expect(
        () => action.updateSelectionAliases('[]', emptyDocument),
        throwsA(isA<TypeError>()),
      );
      expect(action.originalSelection('Group', 'runtime-node'), 'Original');
      expect(action.originalSelection('Managed', 'runtime-node'), isNull);
    },
  );

  test('ordinary profile without local metadata clears aliases', () {
    action.updateSelectionAliases(managed, emptyDocument);
    action.updateSelectionAliases('rules: [MATCH,DIRECT]', emptyDocument);
    expect(action.originalSelection('Group', 'runtime-node'), 'runtime-node');
    expect(action.originalSelection('Managed', 'runtime-node'), 'runtime-node');
  });
}
