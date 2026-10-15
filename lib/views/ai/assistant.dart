import 'dart:async';
import 'dart:convert';

import 'package:fl_clash/ai/runtime.dart';
import 'package:fl_clash/ai/history.dart';
import 'package:fl_clash/ai/context.dart';
import 'package:fl_clash/ai/settings.dart';
import 'package:fl_clash/ai/tools.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/capabilities/service.dart';
import 'package:fl_clash/capabilities/manifest.dart';
import 'package:fl_clash/configuration/changes.dart';
import 'package:fl_clash/configuration/settings.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/ai_history.dart';
import 'package:fl_clash/providers/state.dart';
import 'package:fl_clash/providers/workbench.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'approval.dart';
import 'change_record.dart';
import 'composer_context.dart';
import 'errors.dart';
import 'settings.dart';
import 'presentation.dart';
import 'history.dart';
import 'message.dart';

class AiAssistantView extends ConsumerStatefulWidget {
  const AiAssistantView({super.key, this.initialPrompt, this.inputController});
  final String? initialPrompt;
  final TextEditingController? inputController;

  @override
  ConsumerState<AiAssistantView> createState() => _AiAssistantViewState();
}

class _ConversationMessage {
  _ConversationMessage(this.role, this.text);
  final String role;
  final viewKey = GlobalKey();
  String text;
  String? streamMessageId;
  String? changeId;
  String? operationSummary;
  Map<String, Object?>? result;
  ConfigurationProposal? proposal;
  bool failed = false;
  Completer<bool>? approval;
}

class _AiAssistantViewState extends ConsumerState<AiAssistantView> {
  late final _input = widget.inputController ?? TextEditingController();
  final _scroll = ScrollController();
  final _messages = <_ConversationMessage>[];
  late final WorkbenchController _controller;
  late final AiHistoryStore _historyStore;
  int _historyGeneration = 0;
  StreamSubscription<int>? _historyRestores;
  Timer? _changeTimer;
  int _cardGeneration = 0;
  int? _cardRefreshEpoch;
  bool _linkedChangesPending = false;
  String _conversationId = aiConversationId();
  String? _targetLabel;
  final _changeIds = <String>{};
  final _changeReferences = <String, int>{};
  final _historySecrets = <String>{};
  List<Map<String, Object?>> _context = [];
  final _diagnostics = <Map<String, Object?>>[];
  int _contextMessageCount = 0;
  bool _recoveryRequired = false;
  Timer? _historyTimer;
  bool _helpExpanded = false;
  AgentRuntime? _runtime;
  StreamSubscription<AgentRuntimeEvent>? _subscription;
  bool _busy = false;
  bool _contextScheduled = false;
  bool _followLatest = true;
  bool _scrollingToLatest = false;
  bool _seekingLatest = false;
  bool _userScrolling = false;
  int _followGeneration = 0;
  String? _error;
  String? _status;
  _ConversationMessage? _assistantMessage;
  int _responseBytes = 0;
  int _epoch = 0;

  @override
  void initState() {
    super.initState();
    _controller = ref.read(workbenchControllerProvider);
    _historyStore = ref.read(aiHistoryStoreProvider);
    _historyGeneration = _historyStore.generation;
    _historyRestores = _historyStore.restores.listen((generation) {
      if (!mounted) return;
      _historyGeneration = generation;
      unawaited(_clear(persist: false));
    });
    _scroll.addListener(_readingPositionChanged);
    _changeTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted && _linkedChangesPending && _changeIds.isNotEmpty) {
        unawaited(_refreshLinkedCards());
      }
    });
    _input.text = widget.initialPrompt ?? '';
    if (widget.inputController != null) _input.addListener(_composerChanged);
    ref.listenManual(aiComposerContextProvider, (_, next) {
      if (next != null) _scheduleComposerContext();
    }, fireImmediately: true);
  }

  void _scheduleComposerContext() {
    if (!mounted ||
        _busy ||
        _contextScheduled ||
        ref.read(aiComposerContextProvider) == null) {
      return;
    }
    _contextScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _contextScheduled = false;
      if (!mounted || _busy) return;
      final prompt = ref.read(aiComposerContextProvider.notifier).consume();
      if (prompt == null) return;
      setState(() {
        final text = _input.text.isEmpty ? prompt : '${_input.text}\n\n$prompt';
        _input.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
      });
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    if (_busy) _recoveryRequired = true;
    _epoch++;
    _followGeneration++;
    _cancelApprovals();
    _runtime?.cancel();
    _historyTimer?.cancel();
    _changeTimer?.cancel();
    unawaited(_historyRestores?.cancel() ?? Future<void>.value());
    unawaited(_persistConversation());
    unawaited(_subscription?.cancel() ?? Future<void>.value());
    unawaited(_controller.closeAgent());
    _input.removeListener(_composerChanged);
    if (widget.inputController == null) _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _composerChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _persistConversation() async {
    _historyTimer?.cancel();
    if (_historyGeneration != _historyStore.generation) return;
    final messages = <Map<String, String>>[
      for (final message in _messages)
        if (message.role != 'tool' && message.text.isNotEmpty)
          {
            'role': message.role,
            'content': aiHistoryText(message.text, _historySecrets),
          },
    ];
    if (messages.isEmpty) return;
    final entry = AiConversation(
      id: _conversationId,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      messages: messages,
      targetLabel: _targetLabel == null
          ? null
          : aiHistoryText(_targetLabel!, _historySecrets),
      changeIds: _changeIds.toList(),
      changeReferences: {..._changeReferences},
      context: aiContextMessages(
        _context,
        sanitize: (text) => aiHistoryText(text, _historySecrets),
      ),
      diagnostics: aiDiagnosticEvents(_diagnostics),
      recoveryRequired: _recoveryRequired,
    );
    try {
      await _historyStore.save(entry);
    } catch (_) {
      if (mounted) {
        setState(() => _error = context.appLocalizations.aiHistorySaveFailed);
      }
    }
  }

  void _scheduleHistory() {
    _historyTimer?.cancel();
    _historyTimer = Timer(const Duration(milliseconds: 500), () {
      unawaited(_persistConversation());
    });
  }

  Future<void> _openHistory() async {
    if (_busy) return;
    await _persistConversation();
    if (!mounted) return;
    final entry = await Navigator.of(context).push<AiConversation>(
      MaterialPageRoute(
        builder: (_) => AiConversationHistoryView(store: _historyStore),
      ),
    );
    if (!mounted) return;
    if (entry == null) {
      try {
        final entries = await _historyStore.list();
        if (mounted &&
            _messages.isNotEmpty &&
            !entries.any((entry) => entry.id == _conversationId)) {
          await _clear();
        }
      } catch (_) {
        if (mounted) {
          setState(() => _error = context.appLocalizations.aiHistorySaveFailed);
        }
      }
      return;
    }
    await _clear();
    if (!mounted) return;
    setState(() {
      _conversationId = entry.id;
      _targetLabel = entry.targetLabel;
      _changeIds.addAll(entry.changeIds);
      _linkedChangesPending = entry.changeIds.isNotEmpty;
      _changeReferences.addAll(entry.changeReferences);
      _context = entry.context;
      _recoveryRequired = entry.recoveryRequired;
      _diagnostics.addAll(entry.diagnostics);
      _contextMessageCount = entry.messages.length;
      _messages.addAll(
        entry.messages.map(
          (message) =>
              _ConversationMessage(message['role']!, message['content']!),
        ),
      );
    });
    await _refreshLinkedCards(restoring: true);
    if (mounted) _followOutput(force: true);
  }

  bool _showToolResult(AgentToolResult result) =>
      result.isError ||
      result.value['errorCode'] != null ||
      result.value['error'] != null ||
      aiResultProposal(result.value) != null ||
      const {
        'failed',
        'conflict',
        'unsupported',
        'cancelled',
        'rejected',
        'pending_confirmation',
        'pending_user_input',
        'requires_user_action',
        'recovery_required',
      }.contains(result.value['status']);

  void _linkResult(AgentToolRequest request, Map<String, Object?> value) {
    if (request.name == 'changes_status' ||
        request.name == 'application_operation') {
      return;
    }
    if (request.name == 'application_invoke') {
      final command = request.arguments['command'];
      final mutating =
          command is String &&
          (command.endsWith('_propose') ||
              const {
                'changes_commit',
                'changes_undo',
                'rule_set_disabled',
                'script_select',
                'resource_update',
              }.contains(command) ||
              applicationCapabilities.any(
                (capability) =>
                    capability.command == command && capability.mutating,
              ));
      if (!mutating) return;
    }
    final proposal = aiResultProposal(value);
    if (proposal != null) _linkChange(proposal.id);
    final operation = value['operationId'];
    if (operation is String) _linkChange(operation);
    final nested = value['result'];
    if (nested is Map<String, Object?>) {
      final nestedProposal = aiResultProposal({'proposal': nested['proposal']});
      if (nestedProposal != null) _linkChange(nestedProposal.id);
    }
  }

  void _linkChange(String id) {
    _changeIds.add(id);
    _linkedChangesPending = true;
    _changeReferences.putIfAbsent(
      id,
      () => _messages.where((message) => message.role != 'tool').length,
    );
  }

  Future<void> _refreshLinkedCards({bool restoring = false}) async {
    if (_cardRefreshEpoch == _epoch) return;
    final generation = ++_cardGeneration;
    final epoch = _epoch;
    _cardRefreshEpoch = epoch;
    final ids = _changeIds.toList();
    try {
      final rows = await Future.wait(ids.map(_controller.store.readChange));
      final operationResults = <String, Map<String, Object?>>{};
      final unavailableOperations = <String>{};
      await Future.wait([
        for (final row in rows)
          if (row != null && row.category.startsWith('capability:'))
            () async {
              try {
                final result = await ref
                    .read(applicationCapabilityServiceProvider)
                    .execute('operation_query', {
                      'operationId': row.id,
                    }, origin: 'agent')
                    .timeout(const Duration(seconds: 5));
                if (result['operationId'] == row.id &&
                    result['status'] is String) {
                  operationResults[row.id] = result;
                } else {
                  unavailableOperations.add(row.id);
                }
              } catch (_) {
                unavailableOperations.add(row.id);
              }
            }(),
      ]);
      Map<String, Object?>? currentState;
      if (rows.any(
        (row) =>
            row?.status == 'draft' &&
            row!.expiresAt > DateTime.now().millisecondsSinceEpoch &&
            !row.category.startsWith('resource:') &&
            !row.category.startsWith('capability:'),
      )) {
        try {
          currentState = await _controller.backend.readState().timeout(
            const Duration(seconds: 5),
          );
        } catch (_) {}
      }
      if (!mounted || epoch != _epoch || generation != _cardGeneration) return;
      setState(() {
        _linkedChangesPending =
            unavailableOperations.isNotEmpty ||
            rows.any(
              (row) =>
                  const {
                    'draft',
                    'committing',
                    'persisted',
                    'restoring',
                    'running',
                    'accepted',
                    'queued',
                  }.contains(
                    row == null
                        ? null
                        : operationResults[row.id]?['status'] ??
                              aiStoredChangeStatus(row),
                  ),
            );
        for (var index = 0; index < rows.length; index++) {
          final row = rows[index];
          if (row == null) continue;
          final existing = _messages
              .where(
                (message) =>
                    (message.changeId ?? message.proposal?.id) == row.id,
              )
              .firstOrNull;
          if (existing?.approval?.isCompleted == false) continue;
          if (row.status == 'superseded') {
            _messages.removeWhere((message) => message.proposal?.id == row.id);
            continue;
          }
          if (unavailableOperations.contains(row.id) && existing != null) {
            continue;
          }
          var status =
              operationResults[row.id]?['status'] as String? ??
              aiStoredChangeStatus(row);
          if (status == 'draft' &&
              !row.category.startsWith('resource:') &&
              !row.category.startsWith('capability:') &&
              currentState != null &&
              configurationDigest(currentState) != row.fingerprint) {
            status = 'conflict';
          }
          if (status == 'draft' &&
              !row.category.startsWith('resource:') &&
              !row.category.startsWith('capability:') &&
              currentState == null) {
            status = 'unverified';
          }
          if (existing != null) {
            existing.result = operationResults[row.id] ?? {'status': status};
            existing.failed = const {'failed', 'interrupted'}.contains(status);
            continue;
          }
          final operation = row.category.startsWith('capability:');
          final message = _ConversationMessage('tool', '')
            ..changeId = row.id
            ..operationSummary = operation ? row.summary : null
            ..proposal = operation ? null : aiStoredProposal(row)
            ..result = operationResults[row.id] ?? {'status': status};
          if (restoring && status == 'requires_recovery') {
            _recoveryRequired = true;
          }
          final anchor =
              _changeReferences[row.id] ??
              _messages.where((message) => message.role != 'tool').length;
          var textCount = 0;
          var position = _messages.length;
          for (var offset = 0; offset < _messages.length; offset++) {
            if (_messages[offset].role == 'tool') continue;
            if (textCount++ >= anchor) {
              position = offset;
              break;
            }
          }
          _messages.insert(position, message);
        }
        if (restoring && rows.whereType<Object>().length < ids.length) {
          _error = context.appLocalizations.aiChangesUnavailable;
        }
      });
      _followOutput();
    } catch (_) {
      if (mounted && epoch == _epoch && generation == _cardGeneration) {
        setState(() => _linkedChangesPending = ids.isNotEmpty);
      }
    } finally {
      if (_cardRefreshEpoch == epoch) _cardRefreshEpoch = null;
    }
  }

  void _cancelApprovals() {
    for (final message in _messages) {
      if (message.approval != null && !message.approval!.isCompleted) {
        message.result = const {'status': 'cancelled'};
        message.approval!.complete(false);
      }
    }
  }

  void _appendToolMessage(_ConversationMessage message) {
    _assistantMessage = null;
    final proposalId = message.proposal?.id;
    final result = message.result;
    final nested = result?['result'];
    final supersedesId =
        result?['supersedesId'] ??
        (nested is Map ? nested['supersedesId'] : null);
    if (proposalId != null) {
      _messages.removeWhere(
        (entry) =>
            entry.role == 'tool' &&
            entry.proposal != null &&
            (entry.approval == null || entry.approval!.isCompleted) &&
            (entry.proposal!.id == proposalId ||
                entry.proposal!.id == supersedesId),
      );
    }
    _messages.add(message);
    while (_messages.where((entry) => entry.role == 'tool').length > 32) {
      final index = _messages.indexWhere(
        (entry) =>
            entry.role == 'tool' &&
            (entry.approval == null || entry.approval!.isCompleted),
      );
      if (index < 0) break;
      _messages.removeAt(index);
    }
  }

  Future<bool> _approve(ConfigurationProposal proposal, int epoch) async {
    if (!mounted || epoch != _epoch || !_busy || _runtime?.isClosed != false) {
      return false;
    }
    _linkChange(proposal.id);
    await _persistConversation();
    if (!mounted || epoch != _epoch || !_busy || _runtime?.isClosed != false) {
      return false;
    }
    final message = _ConversationMessage('tool', '')
      ..proposal = proposal
      ..approval = Completer<bool>();
    setState(() => _appendToolMessage(message));
    _followOutput();
    final runtime = _runtime;
    await runtime?.setApprovalPending(true);
    try {
      final approved = await message.approval!.future;
      if (mounted) setState(() {});
      return approved &&
          mounted &&
          epoch == _epoch &&
          _runtime?.isClosed == false;
    } finally {
      await runtime?.setApprovalPending(false);
    }
  }

  void _readingPositionChanged() {
    if (!_scroll.hasClients || _scrollingToLatest || _userScrolling) return;
    final following = _scroll.position.extentAfter <= 96;
    if (following != _followLatest && mounted) {
      setState(() => _followLatest = following);
    }
  }

  bool _readingScroll(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    if (notification is ScrollStartNotification &&
            notification.dragDetails != null ||
        notification is UserScrollNotification &&
            notification.direction != ScrollDirection.idle) {
      _followGeneration++;
      setState(() {
        _userScrolling = true;
        _scrollingToLatest = false;
        _seekingLatest = false;
        _followLatest = false;
      });
    } else if (_userScrolling &&
        (notification is ScrollEndNotification ||
            notification is UserScrollNotification &&
                notification.direction == ScrollDirection.idle)) {
      _userScrolling = false;
      _readingPositionChanged();
    }
    return false;
  }

  void _followOutput({bool force = false}) {
    if (force) {
      setState(() {
        _followLatest = true;
        _seekingLatest = true;
        _userScrolling = false;
      });
    }
    if (!_followLatest || _scrollingToLatest) return;
    _scrollingToLatest = true;
    final generation = ++_followGeneration;
    var attempts = 0;
    double? previousExtent;
    void settle(Duration _) {
      if (!mounted || generation != _followGeneration) return;
      if (!_followLatest || !_scroll.hasClients || _messages.isEmpty) {
        setState(() {
          _scrollingToLatest = false;
          _seekingLatest = false;
        });
        return;
      }
      final position = _scroll.position;
      final extent = position.maxScrollExtent;
      final reachedTail =
          _messages.last.viewKey.currentContext != null &&
          position.extentAfter <= 1;
      if (reachedTail &&
          previousExtent != null &&
          (extent - previousExtent!).abs() <= 1) {
        setState(() {
          _scrollingToLatest = false;
          _seekingLatest = false;
        });
        return;
      }
      if (++attempts >= 16) {
        setState(() {
          _scrollingToLatest = false;
          _seekingLatest = false;
          _followLatest = false;
        });
        return;
      }
      previousExtent = extent;
      _scroll.jumpTo(extent);
      WidgetsBinding.instance.addPostFrameCallback(settle);
      WidgetsBinding.instance.ensureVisualUpdate();
    }

    WidgetsBinding.instance.addPostFrameCallback(settle);
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _recordDiagnostic(
    String kind, {
    String? name,
    String? status,
    String? code,
    int? turn,
  }) {
    _diagnostics.add({
      'kind': kind,
      'name': ?name,
      'status': ?status,
      'code': ?code,
      'turn': ?turn,
      'at': DateTime.now().millisecondsSinceEpoch,
    });
    if (_diagnostics.length > 64) _diagnostics.removeAt(0);
  }

  void _event(AgentRuntimeEvent event) {
    if (!mounted || !_busy) return;
    setState(() {
      switch (event.type) {
        case 'context':
          _context = aiContextMessages(
            event.data['messages'],
            sanitize: (text) => aiHistoryText(text, _historySecrets),
          );
          _contextMessageCount = _messages
              .where((message) => message.role != 'tool')
              .length;
        case 'task':
          _recordDiagnostic('task', status: event.data['status'] as String?);
        case 'text':
          if (event.data['phase'] == 'progress') break;
          final text = event.data['text'] as String;
          _responseBytes += utf8.encode(text).length;
          if (_responseBytes > 256 * 1024) {
            _runtime?.cancel();
            _error = context.appLocalizations.aiHistoryLimit;
          } else if (text.isNotEmpty) {
            final messageId = event.data['messageId'] as String?;
            if (_assistantMessage == null ||
                (messageId != null &&
                    _assistantMessage!.streamMessageId != messageId)) {
              _assistantMessage = _ConversationMessage('assistant', '')
                ..streamMessageId = messageId;
              _messages.add(_assistantMessage!);
            }
            _assistantMessage!.text += text;
          }
        case 'status':
          _recordDiagnostic(
            'run',
            status: event.data['status'] as String?,
            turn: event.data['turn'] as int?,
          );
          _status = context.appLocalizations.aiThinking;
        case 'error':
          _recoveryRequired = true;
          _recordDiagnostic('error', code: event.data['code'] as String?);
          _error = aiErrorText(context, event.data['code']);
          _cancelApprovals();
        case 'done':
          _recoveryRequired =
              event.data['cancelled'] == true || event.data['failed'] == true;
          if (event.data['taskStatus'] is String) {
            _recordDiagnostic(
              'task',
              status: event.data['taskStatus'] as String,
            );
          }
          _recordDiagnostic(
            'run',
            status: event.data['cancelled'] == true
                ? 'cancelled'
                : event.data['failed'] == true
                ? 'failed'
                : 'finished',
          );
          if (event.data['cancelled'] == true) {
            _status = context.appLocalizations.aiCancelled;
          } else {
            _status = null;
          }
      }
    });
    _followOutput();
    _scheduleHistory();
  }

  List<Map<String, Object?>> _history() {
    final result = <Map<String, Object?>>[];
    var bytes = 0;
    for (final message in _messages.reversed) {
      if (message.text.isEmpty || message.role == 'tool') continue;
      final size = utf8.encode(message.text).length;
      if (bytes + size > 256 * 1024) break;
      bytes += size;
      result.insert(0, {'role': message.role, 'content': message.text});
      if (result.length == 80) break;
    }
    return result;
  }

  List<Map<String, Object?>>? _promptContext() {
    if (_context.isEmpty) return null;
    final trailing = _messages
        .where((message) => message.role != 'tool')
        .skip(_contextMessageCount)
        .where((message) => message.text.isNotEmpty);
    return aiContextMessages([
      ..._context,
      for (final message in trailing)
        {
          'role': message.role,
          'content': message.role == 'user'
              ? message.text
              : [
                  {'type': 'text', 'text': message.text},
                ],
        },
    ]);
  }

  Future<void> _send(AgentSettings settings) async {
    final user = _input.text.trim();
    final connection = settings.selected;
    if (_busy || !settings.enabled || connection == null || user.isEmpty) {
      return;
    }
    if (_messages.where((message) => message.role != 'tool').length >= 79) {
      setState(() => _error = context.appLocalizations.aiHistoryLimit);
      return;
    }
    final epoch = ++_epoch;
    final controller = _controller;
    final history = _history();
    final modelContext = _promptContext();
    final recoveryRequired = _recoveryRequired;
    setState(() {
      _busy = true;
      _error = null;
      _status = context.appLocalizations.aiThinking;
    });
    try {
      final key = await controller.credentials.read(connection.credentialId);
      if (!mounted || _epoch != epoch) return;
      if (key == null || key.isEmpty) {
        throw const AgentRuntimeException('keyMissing');
      }
      _historySecrets.add(key);
      final runtime = controller.runtime;
      if (!identical(_runtime, runtime)) {
        await _subscription?.cancel();
        _runtime = runtime;
        _subscription = runtime.events.listen((event) {
          if (identical(_runtime, runtime)) _event(event);
        });
      }
      if (!mounted || _epoch != epoch) return;
      final tools = AgentTools(
        controller: controller,
        approve: (proposal) async {
          if (!mounted || _epoch != epoch) return false;
          return _approve(proposal, epoch);
        },
      );
      setState(() {
        _recoveryRequired = true;
        _helpExpanded = false;
        if (_messages.isEmpty) {
          _targetLabel = ref.read(currentProfileProvider)?.label;
        }
        _messages.add(_ConversationMessage('user', user));
        _assistantMessage = null;
        _responseBytes = 0;
        _input.clear();
      });
      await _persistConversation();
      if (!mounted || epoch != _epoch) return;
      final mixedPort = ref.read(patchClashConfigProvider).mixedPort;
      await runtime.prompt(
        settings: connection.runtimeSettings(mixedPort: mixedPort),
        key: key,
        user: user,
        messages: history,
        context: modelContext,
        recoveryRequired: recoveryRequired,
        tools: tools.definitions,
        executeTool: (request) async {
          if (!mounted || _epoch != epoch || !request.isCurrent()) {
            return const AgentToolResult({'code': 'cancelled'}, isError: true);
          }
          setState(() => _status = context.appLocalizations.aiToolWorking);
          final result = await tools.execute(request);
          if (mounted && _epoch == epoch && request.isCurrent()) {
            _recordDiagnostic(
              'tool',
              name: request.name == 'application_invoke'
                  ? request.arguments['command'] as String?
                  : request.name,
              status: result.isError
                  ? 'failed'
                  : result.value['status'] as String? ?? 'returned',
              code:
                  (result.value['code'] ?? result.value['errorCode'])
                      as String?,
            );
            _linkResult(request, result.value);
            setState(() {
              _status = context.appLocalizations.aiThinking;
              if (_showToolResult(result)) {
                _appendToolMessage(
                  _ConversationMessage('tool', '')
                    ..result = result.value
                    ..changeId = result.value['operationId'] as String?
                    ..proposal = aiResultProposal(result.value)
                    ..failed = result.isError,
                );
              }
            });
            _followOutput();
            await _refreshLinkedCards();
            await _persistConversation();
          }
          return result;
        },
      );
    } catch (error) {
      if (mounted && _epoch == epoch) {
        _recoveryRequired = true;
        setState(() => _error = aiErrorText(context, error));
      }
    } finally {
      if (mounted && _epoch == epoch) {
        await _persistConversation();
        if (mounted && _epoch == epoch) {
          setState(() {
            _busy = false;
            _assistantMessage = null;
            if (_status != context.appLocalizations.aiCancelled) _status = null;
          });
          _scheduleComposerContext();
        }
      }
    }
  }

  Future<void> _stop() async {
    _recoveryRequired = true;
    final epoch = ++_epoch;
    final runtime = _runtime;
    _runtime = null;
    _cancelApprovals();
    runtime?.cancel();
    setState(() => _status = context.appLocalizations.aiCancelled);
    await _subscription?.cancel();
    _subscription = null;
    await _controller.closeAgent();
    await _persistConversation();
    if (mounted && _epoch == epoch) {
      setState(() {
        _busy = false;
        _assistantMessage = null;
      });
      _scheduleComposerContext();
    }
  }

  Future<void> _openSettings() async {
    if (_busy) _recoveryRequired = true;
    _epoch++;
    final runtime = _runtime;
    _runtime = null;
    _cancelApprovals();
    runtime?.cancel();
    await _subscription?.cancel();
    _subscription = null;
    await _controller.closeAgent();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _status = null;
    });
    _scheduleComposerContext();
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => const AiSettingsView()));
  }

  Future<void> _selectConnection(AgentSettings settings, String id) async {
    if (_busy || id == settings.selectedConnectionId) return;
    final epoch = _epoch;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _controller.closeAgent();
      if (!mounted) return;
      final proposal = await _controller.proposeAgentSettings(
        AgentSettings(
          enabled: settings.enabled,
          selectedConnectionId: id,
          connections: settings.connections,
        ),
      );
      if (!mounted) return;
      final result = await _controller.commit(
        proposal,
        approve: (proposal) => mounted
            ? showAiConfigurationApproval(context, proposal)
            : Future.value(false),
        isCurrent: () => mounted,
      );
      if (mounted && result['status'] != 'applied') {
        setState(
          () => _error = aiErrorText(
            context,
            result['code'] ?? 'configuration_apply_failed',
          ),
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = aiErrorText(context, error));
    } finally {
      if (mounted && _epoch == epoch) {
        setState(() => _busy = false);
        _scheduleComposerContext();
      }
    }
  }

  Future<void> _clear({bool persist = true}) async {
    if (_busy) _recoveryRequired = true;
    final epoch = ++_epoch;
    final runtime = _runtime;
    _runtime = null;
    _cancelApprovals();
    runtime?.cancel();
    final saved = persist ? _persistConversation() : Future<void>.value();
    _historyTimer?.cancel();
    _historyGeneration = _historyStore.generation;
    setState(() {
      _followLatest = true;
      _scrollingToLatest = false;
      _seekingLatest = false;
      _userScrolling = false;
      _followGeneration++;
      _messages.clear();
      _input.clear();
      _conversationId = aiConversationId();
      _targetLabel = null;
      _changeIds.clear();
      _linkedChangesPending = false;
      _changeReferences.clear();
      _cardGeneration++;
      _historySecrets.clear();
      _context = [];
      _contextMessageCount = 0;
      _recoveryRequired = false;
      _diagnostics.clear();
      _busy = true;
      _error = null;
      _status = null;
      _assistantMessage = null;
    });
    await _subscription?.cancel();
    _subscription = null;
    await _controller.closeAgent();
    await saved;
    if (mounted && _epoch == epoch) {
      setState(() => _busy = false);
      _scheduleComposerContext();
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.appLocalizations;
    final value = ref.watch(agentSettingsProvider);
    ref.listen(agentSettingsProvider, (previous, next) {
      final before = previous?.asData?.value;
      final after = next.asData?.value;
      if (before != null &&
          after != null &&
          (before.enabled != after.enabled ||
              jsonEncode(before.selected?.toJson()) !=
                  jsonEncode(after.selected?.toJson()))) {
        unawaited(_clear());
      }
    });
    return CommonScaffold(
      title: strings.aiAssistantTitle,
      actions: [
        IconButton(
          tooltip: strings.aiConversationHistory,
          icon: const Icon(Icons.history),
          onPressed: _busy ? null : _openHistory,
        ),
        IconButton(
          onPressed: _busy ? null : _clear,
          tooltip: strings.aiNewConversation,
          icon: const Icon(Icons.add_comment_outlined),
        ),
        IconButton(
          onPressed: _openSettings,
          tooltip: strings.aiSettingsTitle,
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
      body: value.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(child: Text(strings.aiRequestFailed)),
        data: (settings) => LayoutBuilder(
          builder: (context, constraints) {
            final conversation = Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Row(
                        children: [
                          const Icon(Icons.auto_awesome_outlined, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: settings.connections.isEmpty
                                ? Text(strings.aiNoConnection)
                                : DropdownButtonFormField<String>(
                                    key: ValueKey(
                                      'ai-current-connection-${settings.selectedConnectionId}',
                                    ),
                                    initialValue: settings.selectedConnectionId,
                                    isExpanded: true,
                                    decoration: InputDecoration(
                                      labelText: strings.aiCurrentConnection,
                                      border: const OutlineInputBorder(),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                    ),
                                    items: [
                                      for (final connection
                                          in settings.connections)
                                        DropdownMenuItem(
                                          value: connection.id,
                                          child: Text(
                                            '${connection.label} · ${connection.model}',
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                    ],
                                    onChanged: _busy
                                        ? null
                                        : (id) {
                                            if (id != null) {
                                              unawaited(
                                                _selectConnection(settings, id),
                                              );
                                            }
                                          },
                                  ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: () => setState(
                                  () => _helpExpanded = !_helpExpanded,
                                ),
                                icon: Icon(
                                  _helpExpanded
                                      ? Icons.expand_less
                                      : Icons.expand_more,
                                ),
                                label: Text(strings.aiCanHelp),
                              ),
                            ),
                          ),
                          if (_changeIds.isNotEmpty)
                            IconButton(
                              tooltip: strings.aiLinkedChanges,
                              onPressed: _busy
                                  ? null
                                  : () => Navigator.of(context).push<void>(
                                      MaterialPageRoute(
                                        builder: (_) => AiLinkedChangesView(
                                          store: _controller.store,
                                          ids: _changeIds.toList(),
                                        ),
                                      ),
                                    ),
                              icon: const Icon(Icons.receipt_long_outlined),
                            ),
                        ],
                      ),
                    ),
                    if (_helpExpanded)
                      SizedBox(
                        height: constraints.maxHeight * .35,
                        child: AiCapabilityPanel(
                          catalog: ref
                              .read(applicationCapabilityServiceProvider)
                              .manifest,
                        ),
                      ),
                    Expanded(
                      child: _messages.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  !settings.enabled
                                      ? strings.aiDisabled
                                      : strings.aiEmptyConversation,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            )
                          : NotificationListener<ScrollNotification>(
                              onNotification: _readingScroll,
                              child: ListView.builder(
                                key: const ValueKey('ai-conversation-list'),
                                controller: _scroll,
                                padding: const EdgeInsets.all(16),
                                itemCount: _messages.length,
                                itemBuilder: (context, index) => KeyedSubtree(
                                  key: _messages[index].viewKey,
                                  child: _message(_messages[index]),
                                ),
                              ),
                            ),
                    ),
                    if ((!_followLatest || _seekingLatest) &&
                        _messages.isNotEmpty)
                      TextButton.icon(
                        key: const ValueKey('ai-latest-message'),
                        onPressed: _scrollingToLatest
                            ? null
                            : () => _followOutput(force: true),
                        icon: const Icon(Icons.arrow_downward),
                        label: Text(strings.aiLatestMessage),
                      ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    if (_status != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: Row(
                          children: [
                            if (_busy)
                              const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _status!,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Focus(
                              canRequestFocus: false,
                              onKeyEvent: (_, event) {
                                final platform = Theme.of(context).platform;
                                final composing = _input.value.composing;
                                if (![
                                      TargetPlatform.macOS,
                                      TargetPlatform.windows,
                                      TargetPlatform.linux,
                                    ].contains(platform) ||
                                    (event.logicalKey !=
                                            LogicalKeyboardKey.enter &&
                                        event.logicalKey !=
                                            LogicalKeyboardKey.numpadEnter) ||
                                    HardwareKeyboard.instance.isShiftPressed ||
                                    (composing.isValid &&
                                        !composing.isCollapsed)) {
                                  return KeyEventResult.ignored;
                                }
                                if (event is KeyDownEvent) _send(settings);
                                return KeyEventResult.handled;
                              },
                              child: TextField(
                                key: const ValueKey('ai-prompt'),
                                controller: _input,
                                enabled:
                                    settings.enabled &&
                                    settings.selected != null &&
                                    !_busy,
                                onChanged: (_) => setState(() {}),
                                minLines: 1,
                                maxLines: 4,
                                keyboardType: TextInputType.multiline,
                                textInputAction: TextInputAction.newline,
                                maxLength: 16384,
                                decoration: InputDecoration(
                                  hintText: strings.aiPromptHint,
                                  counterText: '',
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (_busy)
                            IconButton.filledTonal(
                              onPressed: _stop,
                              tooltip: strings.aiStop,
                              icon: const Icon(Icons.stop),
                            )
                          else
                            IconButton.filled(
                              key: const ValueKey('ai-send'),
                              onPressed:
                                  settings.enabled &&
                                      settings.selected != null &&
                                      _input.text.trim().isNotEmpty
                                  ? () => _send(settings)
                                  : null,
                              tooltip: strings.aiSend,
                              icon: const Icon(Icons.arrow_upward),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
            return conversation;
          },
        ),
      ),
    );
  }

  Widget _message(_ConversationMessage message) {
    if (message.role != 'tool') return _MessageCard(message: message);
    final pending = message.approval != null && !message.approval!.isCompleted;
    void resolve(bool approved) {
      if (!pending) return;
      if (message.approval!.isCompleted) return;
      setState(() {
        message.result = {'status': approved ? 'approved' : 'rejected'};
        message.approval!.complete(approved);
      });
    }

    return AiToolResultCard(
      result: message.result,
      summary: message.operationSummary,
      proposal: message.proposal,
      failed: message.failed,
      awaitingApproval: pending,
      onReview: message.proposal == null
          ? null
          : () => showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(context.appLocalizations.aiReviewPlan),
                content: SizedBox(
                  width: 560,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AiToolResultCard(
                          proposal: message.proposal,
                          expanded: true,
                          result: message.result,
                          awaitingApproval: pending,
                        ),
                        if (message.proposal!.highRisk)
                          Text(context.appLocalizations.aiHighRisk),
                        if (message
                                .proposal!
                                .validation['requiresScriptExecutionApproval'] ==
                            true)
                          Text(context.appLocalizations.aiScriptExecutionOnly),
                        if (message
                                .proposal!
                                .validation['finalConfigDifferences'] !=
                            null) ...[
                          Text(
                            context.appLocalizations.aiFinalConfigDifferences,
                          ),
                          if (message
                                  .proposal!
                                  .validation['finalConfigDifferences']
                              is List)
                            for (final difference
                                in message
                                        .proposal!
                                        .validation['finalConfigDifferences']
                                    as List)
                              if (difference is Map &&
                                  difference['path'] is String)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('${difference['path']}'),
                                      Text(context.appLocalizations.aiBefore),
                                      SelectableText(
                                        aiDisplayValue({
                                          '${difference['path']}':
                                              difference['before'],
                                        }),
                                      ),
                                      Text(context.appLocalizations.aiAfter),
                                      SelectableText(
                                        aiDisplayValue({
                                          '${difference['path']}':
                                              difference['after'],
                                        }),
                                      ),
                                    ],
                                  ),
                                ),
                        ],
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(context.appLocalizations.cancel),
                  ),
                ],
              ),
            ),
      onApprove: pending
          ? () async {
              final approved = await showAiConfigurationApproval(
                context,
                message.proposal!,
              );
              if (mounted && !message.approval!.isCompleted) resolve(approved);
            }
          : null,
      onCancel: pending ? () => resolve(false) : null,
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message});
  final _ConversationMessage message;

  @override
  Widget build(BuildContext context) {
    final user = message.role == 'user';
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        color: user ? colors.secondaryContainer : colors.surfaceContainerLow,
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user
                    ? context.appLocalizations.aiYou
                    : context.appLocalizations.aiAssistantRole,
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 6),
              if (user)
                SelectableText(message.text)
              else
                AiAssistantMarkdown(
                  text: message.text.isEmpty ? '…' : message.text,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
