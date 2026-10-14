import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const aiVisualCapture = bool.fromEnvironment('AI_VISUAL_CAPTURE');

Future<void> loadAiVisualFonts(WidgetTester tester) async {
  if (!aiVisualCapture) return;
  await tester.runAsync(() async {
    for (final entry in {
      'AiVisualCjk': '/System/Library/Fonts/STHeiti Light.ttc',
      'AiVisualLatin': '/System/Library/Fonts/Supplemental/Arial.ttf',
    }.entries) {
      final bytes = await File(entry.value).readAsBytes();
      final loader = FontLoader(entry.key)
        ..addFont(Future.value(ByteData.sublistView(bytes)));
      await loader.load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
}

Widget aiVisualSurface(String label, Widget child) => Column(
  children: [
    if (aiVisualCapture)
      Material(
        color: const Color(0xffe2ecf8),
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Text('合成测试数据 · $label', textAlign: TextAlign.center),
          ),
        ),
      ),
    Expanded(child: child),
  ],
);

Future<void> captureAiVisual(WidgetTester tester, String filename) async {
  if (!aiVisualCapture) return;
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('ai-visual-root')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(
      '/private/tmp/flclash-visual-v3-v4',
    ).create(recursive: true);
    await File(
      '/private/tmp/flclash-visual-v3-v4/$filename.png',
    ).writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

Future<void> waitAiCondition(
  WidgetTester tester,
  bool Function() condition,
  String reason,
) async {
  for (var i = 0; i < 100 && !condition(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(condition(), true, reason: reason);
}
