import 'dart:async';
import 'dart:convert';

import 'package:fl_clash/ai/runtime.dart';
import 'package:fl_clash/ai/history.dart';
import 'package:fl_clash/ai/settings.dart';
import 'package:fl_clash/ai/tools.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/capabilities/service.dart';
import 'package:fl_clash/capabilities/manifest.dart';
import 'package:fl_clash/configuration/changes.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/ai_history.dart';
import 'package:fl_clash/providers/state.dart';
import 'package:fl_clash/providers/workbench.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'approval.dart';
import 'composer_context.dart';
import 'errors.dart';
import 'settings.dart';
import 'presentation.dart';
import 'history.dart';
import 'message.dart';

class AiAssistantView extends ConsumerStatefulWidget {
  const AiAssistantView({super.key, this.initialPrompt});
  final String? initialPrompt;

  @override
  ConsumerState<AiAssistantView> createState() => _AiAssistantViewState();
}

class _ConversationMessage {
  _ConversationMessage(this.role, this.text);
  final String role;
  String text;
  Map<String, Object?>? result;
  ConfigurationProposal? proposal;
  bool failed = false;
  Completer<bool>? approval;
}

class _AiAssistantViewState extends ConsumerState<AiAssistantView> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <_ConversationMessage>[];
  late final WorkbenchController _controller;
  late final AiHistoryStore _historyStore;
  String _conversationId = aiConversationId();
  String? _targetLabel;
  final _changeIds = <String>{};
  final _historySecrets = <String>{};
  Timer? _historyTimer;
  bool _helpExpanded = false;
  AgentRuntime? _runtime;
  StreamSubscription<AgentRuntimeEvent>? _subscription;
  bool _busy = false;
  bool _contextScheduled = false;
  String? _error;
  String? _status;
  int _assistantIndex = -1;
  int _responseBytes = 0;
  int _epoch = 0;

  @override
  void initState() {
    super.initState();
    _controller = ref.read(workbenchControllerProvider);
    _historyStore = ref.read(aiHistoryStoreProvider);
    _input.text = widget.initialPrompt ?? '';
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
    _epoch++;
    _cancelApprovals();
    _runtime?.cancel();
    _historyTimer?.cancel();
    unawaited(_persistConversation());
    unawaited(_subscription?.cancel() ?? Future<void>.value());
    unawaited(_controller.closeAgent());
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _persistConversation() async {
    _historyTimer?.cancel();
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
      _messages.addAll(
        entry.messages.map(
          (message) =>
              _ConversationMessage(message['role']!, message['content']!),
        ),
      );
    });
    _followOutput();
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
    if (request.name == 'application_invoke' &&
        !applicationCapabilities.any(
          (capability) =>
              capability.command == request.arguments['command'] &&
              capability.mutating,
        )) {
      return;
    }
    final proposal = aiResultProposal(value);
    if (proposal != null) _changeIds.add(proposal.id);
    final operation = value['operationId'];
    if (operation is String) _changeIds.add(operation);
    final nested = value['result'];
    if (nested is Map<String, Object?>) {
      final nestedProposal = aiResultProposal({'proposal': nested['proposal']});
      if (nestedProposal != null) _changeIds.add(nestedProposal.id);
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
    _messages.add(message);
    while (_messages.where((entry) => entry.role == 'tool').length > 32) {
      final index = _messages.indexWhere(
        (entry) =>
            entry.role == 'tool' &&
            (entry.approval == null || entry.approval!.isCompleted),
      );
      if (index < 0) break;
      _messages.removeAt(index);
      if (_assistantIndex > index) _assistantIndex--;
    }
  }

  Future<bool> _approve(ConfigurationProposal proposal, int epoch) async {
    if (!mounted || epoch != _epoch || !_busy || _runtime?.isClosed != false) {
      return false;
    }
    _changeIds.add(proposal.id);
    await _persistConversation();
    if (!mounted || epoch != _epoch || !_busy || _runtime?.isClosed != false) {
      return false;
    }
    final message = _ConversationMessage('tool', '')
      ..proposal = proposal
      ..approval = Completer<bool>();
    setState(() => _appendToolMessage(message));
    _followOutput();
    final approved = await message.approval!.future;
    if (mounted) setState(() {});
    return approved &&
        mounted &&
        epoch == _epoch &&
        _runtime?.isClosed == false;
  }

  void _followOutput() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  void _event(AgentRuntimeEvent event) {
    if (!mounted || !_busy) return;
    setState(() {
      switch (event.type) {
        case 'text':
          final text = event.data['text'] as String;
          _responseBytes += utf8.encode(text).length;
          if (_responseBytes > 256 * 1024) {
            _runtime?.cancel();
            _error = context.appLocalizations.aiHistoryLimit;
          } else if (_assistantIndex >= 0 &&
              _assistantIndex < _messages.length) {
            _messages[_assistantIndex].text += text;
          }
        case 'status':
          _status = context.appLocalizations.aiThinking;
        case 'error':
          _error = aiErrorText(context, event.data['code']);
          _cancelApprovals();
        case 'done':
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
        _helpExpanded = false;
        if (_messages.isEmpty) {
          _targetLabel = ref.read(currentProfileProvider)?.label;
        }
        _messages.add(_ConversationMessage('user', user));
        _messages.add(_ConversationMessage('assistant', ''));
        _assistantIndex = _messages.length - 1;
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
        tools: tools.definitions,
        executeTool: (request) async {
          if (!mounted || _epoch != epoch || !request.isCurrent()) {
            return const AgentToolResult({'code': 'cancelled'}, isError: true);
          }
          setState(() => _status = context.appLocalizations.aiToolWorking);
          final result = await tools.execute(request);
          if (mounted && _epoch == epoch && request.isCurrent()) {
            _linkResult(request, result.value);
            setState(() {
              _status = context.appLocalizations.aiThinking;
              if (_showToolResult(result)) {
                _appendToolMessage(
                  _ConversationMessage('tool', '')
                    ..result = result.value
                    ..proposal = aiResultProposal(result.value)
                    ..failed = result.isError,
                );
              }
            });
            _followOutput();
            await _persistConversation();
          }
          return result;
        },
      );
    } catch (error) {
      if (mounted && _epoch == epoch) {
        setState(() => _error = aiErrorText(context, error));
      }
    } finally {
      if (mounted && _epoch == epoch) {
        await _persistConversation();
        if (mounted && _epoch == epoch) {
          setState(() {
            _busy = false;
            _assistantIndex = -1;
            if (_status != context.appLocalizations.aiCancelled) _status = null;
          });
          _scheduleComposerContext();
        }
      }
    }
  }

  Future<void> _stop() async {
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
        _assistantIndex = -1;
      });
      _scheduleComposerContext();
    }
  }

  Future<void> _openSettings() async {
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

  Future<void> _clear() async {
    final epoch = ++_epoch;
    final runtime = _runtime;
    _runtime = null;
    _cancelApprovals();
    runtime?.cancel();
    final saved = _persistConversation();
    setState(() {
      _messages.clear();
      _input.clear();
      _conversationId = aiConversationId();
      _targetLabel = null;
      _changeIds.clear();
      _historySecrets.clear();
      _busy = true;
      _error = null;
      _status = null;
      _assistantIndex = -1;
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
                          : ListView.builder(
                              key: const ValueKey('ai-conversation-list'),
                              controller: _scroll,
                              padding: const EdgeInsets.all(16),
                              itemCount: _messages.length,
                              itemBuilder: (context, index) =>
                                  _message(_messages[index]),
                            ),
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
