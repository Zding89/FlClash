import 'package:fl_clash/ai/history.dart';
import 'package:fl_clash/providers/workbench.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final aiHistoryStoreProvider = Provider<AiHistoryStore>(
  (ref) => AiHistoryStore(ref.watch(workbenchControllerProvider).store),
);
