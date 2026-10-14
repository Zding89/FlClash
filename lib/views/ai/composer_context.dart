import 'package:flutter_riverpod/flutter_riverpod.dart';

final aiComposerContextProvider = NotifierProvider<AiComposerContext, String?>(
  AiComposerContext.new,
);

class AiComposerContext extends Notifier<String?> {
  @override
  String? build() => null;

  void offer(String prompt) {
    if (prompt.trim().isEmpty) return;
    state = prompt;
  }

  String? consume() {
    final prompt = state;
    if (prompt != null) state = null;
    return prompt;
  }
}
