import 'package:fl_clash/views/ai/composer_context.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'unmounted context retains only latest request and can be consumed once',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(aiComposerContextProvider.notifier);
      expect(container.read(aiComposerContextProvider), isNull);
      notifier.offer('Earlier request');
      notifier.offer('Latest request');
      notifier.offer('   ');
      await container.pump();
      expect(container.read(aiComposerContextProvider), 'Latest request');
      expect(notifier.consume(), 'Latest request');
      expect(notifier.consume(), isNull);
      notifier.offer('Latest request');
      expect(notifier.consume(), 'Latest request');
      expect(container.read(aiComposerContextProvider), isNull);
    },
  );

  test(
    'composer context is transient and isolated to its application container',
    () {
      final first = ProviderContainer();
      final second = ProviderContainer();
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      first
          .read(aiComposerContextProvider.notifier)
          .offer('First application request');
      expect(second.read(aiComposerContextProvider), isNull);
      expect(
        first.read(aiComposerContextProvider.notifier).consume(),
        'First application request',
      );
      expect(second.read(aiComposerContextProvider.notifier).consume(), isNull);
    },
  );
}
