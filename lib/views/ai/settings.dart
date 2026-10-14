import 'dart:async';
import 'dart:math';

import 'package:fl_clash/ai/credentials.dart';
import 'package:fl_clash/ai/runtime.dart';
import 'package:fl_clash/ai/settings.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/configuration/changes.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/workbench.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'approval.dart';
import 'errors.dart';

AgentRuntime createAiTestRuntime() => AgentRuntime();

class AiSettingsView extends ConsumerStatefulWidget {
  const AiSettingsView({super.key, this.runtimeFactory = createAiTestRuntime});
  final AgentRuntime Function() runtimeFactory;

  @override
  ConsumerState<AiSettingsView> createState() => _AiSettingsViewState();
}

class _AiSettingsViewState extends ConsumerState<AiSettingsView> {
  bool _busy = false;
  bool _initialized = false;
  int _editorEpoch = 0;
  bool _editorLoading = false;
  bool _editorOpen = false;
  AgentConnection? _editingConnection;
  bool _editorHasKey = false;
  GlobalKey<_AiConnectionEditorState> _editorKey = GlobalKey();
  String? _message;
  bool _failed = false;

  Future<void> _perform(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
      _failed = false;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) {
        setState(() {
          _failed = true;
          _message = aiErrorText(context, error);
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  ConfigurationApproval _afterInitialApproval(ConfigurationProposal original) =>
      (proposal) async {
        if (!mounted) return false;
        if (proposal.validation['finalConfigValidated'] == true &&
            original.validation['finalConfigValidated'] != true) {
          return showAiConfigurationApproval(context, proposal);
        }
        return true;
      };

  Future<bool> _commitSettings(AgentSettings next) async {
    final controller = ref.read(workbenchControllerProvider);
    final proposal = await controller.proposeAgentSettings(next);
    if (!mounted) return false;
    final result = await controller.commit(
      proposal,
      approve: (proposal) => mounted
          ? showAiConfigurationApproval(context, proposal)
          : Future.value(false),
      isCurrent: () => mounted,
    );
    return result['status'] == 'applied';
  }

  Future<void> _edit(AgentConnection? existing, {bool protect = true}) async {
    final epoch = ++_editorEpoch;
    if (_busy ||
        (protect && !_editorLoading && !await _canLeaveEditor()) ||
        !mounted ||
        epoch != _editorEpoch) {
      return;
    }
    setState(() => _editorLoading = true);
    final controller = ref.read(workbenchControllerProvider);
    bool hasKey = false;
    try {
      hasKey =
          existing != null &&
          (await controller.credentials.read(
                existing.credentialId,
              ))?.isNotEmpty ==
              true;
    } on LegacyCredentialMigrationException {
      if (mounted && epoch == _editorEpoch) {
        setState(() {
          _failed = true;
          _message = context.appLocalizations.aiCredentialMigrationRequired;
        });
      }
    } catch (error) {
      if (mounted && epoch == _editorEpoch) {
        setState(() {
          _editorLoading = false;
          _failed = true;
          _message = aiErrorText(context, error);
        });
      }
      return;
    }
    if (!mounted || epoch != _editorEpoch) return;
    setState(() {
      _editorLoading = false;
      _editingConnection = existing;
      _editorHasKey = hasKey;
      _editorKey = GlobalKey();
      _editorOpen = true;
    });
  }

  Future<bool> _canLeaveEditor() async =>
      await _editorKey.currentState?.confirmDiscard() ?? true;

  Future<void> _saveDraft(AiConnectionDraft draft) async {
    final existing = _editingConnection;
    final controller = ref.read(workbenchControllerProvider);
    await _perform(() async {
      final before = await controller.readAgentSettings();
      final current = existing == null
          ? null
          : before.connections
                .where((entry) => entry.id == existing.id)
                .firstOrNull;
      if (existing != null &&
          (current == null ||
              current.toJson().toString() != existing.toJson().toString())) {
        throw const ConfigurationChangeException(
          'configuration_version_conflict',
        );
      }
      final connections = [
        for (final entry in before.connections)
          entry.id == existing?.id ? draft.connection : entry,
        if (existing == null) draft.connection,
      ];
      final next = AgentSettings(
        enabled: true,
        selectedConnectionId: draft.connection.id,
        connections: connections,
      );
      ConfigurationProposal? proposal;
      try {
        proposal = await controller.proposeAgentSettings(next);
      } on ConfigurationChangeException catch (error) {
        if (error.code != 'configuration_unchanged' || draft.secret == null) {
          rethrow;
        }
      }
      if (!mounted) return;
      if (proposal != null &&
          proposal.highRisk &&
          !await showAiConfigurationApproval(context, proposal)) {
        return;
      }
      if (!mounted) return;
      String? previousSecret;
      bool touched = false;
      try {
        await controller.closeAgent();
        if (!mounted) return;
        if (draft.secret != null) {
          previousSecret = await controller.credentials.read(
            draft.connection.credentialId,
          );
          if (!mounted) return;
          touched = true;
          await controller.credentials.write(
            draft.connection.credentialId,
            draft.secret!,
          );
        }
        if (proposal != null) {
          final result = await controller.commit(
            proposal,
            approve: _afterInitialApproval(proposal),
            isCurrent: () => mounted,
          );
          if (result['status'] != 'applied') {
            throw const ConfigurationChangeException(
              'configuration_apply_failed',
            );
          }
        }
        if (mounted) {
          setState(() => _message = context.appLocalizations.aiSaved);
        }
      } catch (_) {
        if (touched) {
          try {
            if (previousSecret == null) {
              await controller.credentials.delete(
                draft.connection.credentialId,
              );
            } else {
              await controller.credentials.write(
                draft.connection.credentialId,
                previousSecret,
              );
            }
          } catch (_) {
            if (mounted) {
              setState(() {
                _failed = true;
                _message = context.appLocalizations.aiCredentialRecoveryFailed;
              });
            }
            return;
          }
        }
        if (mounted) {
          setState(() {
            _failed = true;
            _message = context.appLocalizations.aiSaveFailed;
          });
        }
      }
    });
    if (mounted && !_failed && _message == context.appLocalizations.aiSaved) {
      setState(() {
        _editingConnection = draft.connection;
        _editorHasKey = true;
        _editorKey = GlobalKey();
      });
    }
  }

  Future<void> _deleteKey(AgentConnection connection) async {
    final strings = context.appLocalizations;
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.aiDeleteKey),
        content: Text(strings.aiDeleteKeyHint),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(strings.delete),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    var deleted = false;
    await _perform(() async {
      final controller = ref.read(workbenchControllerProvider);
      await controller.closeAgent();
      await controller.credentials.delete(connection.credentialId);
      deleted = true;
    });
    if (deleted && mounted && _editingConnection?.id == connection.id) {
      setState(() {
        _editorHasKey = false;
        _editorKey = GlobalKey();
      });
    }
  }

  Future<void> _deleteConnection(
    AgentConnection connection,
  ) => _perform(() async {
    final controller = ref.read(workbenchControllerProvider);
    final before = await controller.readAgentSettings();
    final remaining = before.connections
        .where((entry) => entry.id != connection.id)
        .toList();
    final selected = before.selectedConnectionId == connection.id
        ? remaining.firstOrNull?.id
        : before.selectedConnectionId;
    final next = AgentSettings(
      enabled: before.enabled && selected != null,
      selectedConnectionId: selected,
      connections: remaining,
    );
    final proposal = await controller.proposeAgentSettings(next);
    if (!mounted || !await showAiConfigurationApproval(context, proposal)) {
      return;
    }
    final secret = await controller.credentials.read(connection.credentialId);
    await controller.closeAgent();
    bool touched = false;
    try {
      if (!mounted) return;
      touched = true;
      await controller.credentials.delete(connection.credentialId);
      final result = await controller.commit(
        proposal,
        approve: _afterInitialApproval(proposal),
        isCurrent: () => mounted,
      );
      if (result['status'] != 'applied') {
        throw const ConfigurationChangeException('configuration_apply_failed');
      }
    } catch (_) {
      if (touched && secret != null) {
        try {
          await controller.credentials.write(connection.credentialId, secret);
        } catch (_) {
          if (mounted) {
            setState(() {
              _failed = true;
              _message = context.appLocalizations.aiCredentialRecoveryFailed;
            });
          }
          return;
        }
      }
      rethrow;
    }
  });

  Widget _connectionList(AgentSettings settings) {
    final strings = context.appLocalizations;
    return Card(
      margin: EdgeInsets.zero,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          for (final connection in settings.connections)
            ListTile(
              key: ValueKey('ai-edit-${connection.id}'),
              minLeadingWidth: 24,
              horizontalTitleGap: 8,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              selected: _editorOpen && _editingConnection?.id == connection.id,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              leading: const Icon(Icons.link),
              title: Tooltip(
                message: connection.label,
                child: Text(
                  connection.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              subtitle: Text(
                connection.model,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: _busy ? null : () => _edit(connection),
              trailing: PopupMenuButton<String>(
                enabled: !_busy && !_editorLoading,
                onSelected: (action) async {
                  if (!await _canLeaveEditor() || !mounted) return;
                  switch (action) {
                    case 'select':
                      await _perform(() async {
                        await ref
                            .read(workbenchControllerProvider)
                            .closeAgent();
                        await _commitSettings(
                          AgentSettings(
                            enabled: settings.enabled,
                            selectedConnectionId: connection.id,
                            connections: settings.connections,
                          ),
                        );
                      });
                      if (mounted) await _edit(connection, protect: false);
                    case 'key':
                      await _deleteKey(connection);
                    case 'delete':
                      await _deleteConnection(connection);
                      final latest = await ref
                          .read(workbenchControllerProvider)
                          .readAgentSettings();
                      if (mounted &&
                          _editingConnection?.id == connection.id &&
                          !latest.connections.any(
                            (entry) => entry.id == connection.id,
                          )) {
                        _editorEpoch++;
                        setState(() => _editorOpen = false);
                      }
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'select',
                    child: Text(strings.aiSelectConnection),
                  ),
                  PopupMenuItem(value: 'key', child: Text(strings.aiDeleteKey)),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(strings.aiDeleteConnection),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _busy || settings.connections.length >= 20
                ? null
                : () => _edit(null),
            icon: const Icon(Icons.add),
            label: Text(strings.aiAddConnection),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.appLocalizations;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop && !_busy && await _canLeaveEditor() && context.mounted) {
          Navigator.of(context).pop(result);
        }
      },
      child: CommonScaffold(
        title: strings.aiSettingsTitle,
        body: ref
            .watch(agentSettingsProvider)
            .when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Center(child: Text(strings.aiRequestFailed)),
              data: (settings) {
                if (!_initialized) {
                  _initialized = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && settings.selected != null) {
                      unawaited(_edit(settings.selected));
                    }
                  });
                }
                return Column(
                  children: [
                    SwitchListTile(
                      title: Text(strings.aiEnable),
                      subtitle: Text(strings.aiEnableHint),
                      value: settings.enabled,
                      onChanged: _busy || settings.selected == null
                          ? null
                          : (enabled) => _perform(() async {
                              if (!enabled) {
                                await ref
                                    .read(workbenchControllerProvider)
                                    .closeAgent();
                              }
                              await _commitSettings(
                                AgentSettings(
                                  enabled: enabled,
                                  selectedConnectionId:
                                      settings.selectedConnectionId,
                                  connections: settings.connections,
                                ),
                              );
                            }),
                    ),
                    if (_busy || _editorLoading)
                      const LinearProgressIndicator(),
                    if (_message != null)
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          _message!,
                          style: TextStyle(
                            color: _failed
                                ? Theme.of(context).colorScheme.error
                                : null,
                          ),
                        ),
                      ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final list = _connectionList(settings);
                          final editor = _editorOpen
                              ? AiConnectionEditor(
                                  key: _editorKey,
                                  existing: _editingConnection,
                                  hasKey: _editorHasKey,
                                  embedded: true,
                                  saving: _busy || _editorLoading,
                                  onSave: _saveDraft,
                                  onCancel: () async {
                                    if (await _canLeaveEditor() && mounted) {
                                      _editorEpoch++;
                                      setState(() => _editorOpen = false);
                                    }
                                  },
                                  runtimeFactory: widget.runtimeFactory,
                                )
                              : Center(child: Text(strings.aiNoConnection));
                          if (constraints.maxWidth >= 760) {
                            return Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  SizedBox(
                                    width: constraints.maxWidth < 1000
                                        ? 210
                                        : 250,
                                    child: list,
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(child: editor),
                                ],
                              ),
                            );
                          }
                          return Column(
                            children: [
                              SizedBox(height: 170, child: list),
                              Expanded(child: editor),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
      ),
    );
  }
}

class AiConnectionDraft {
  const AiConnectionDraft({required this.connection, this.secret});
  final AgentConnection connection;
  final String? secret;
}

class AiConnectionEditor extends ConsumerStatefulWidget {
  const AiConnectionEditor({
    super.key,
    this.existing,
    required this.hasKey,
    this.runtimeFactory = createAiTestRuntime,
    this.embedded = false,
    this.saving = false,
    this.onSave,
    this.onCancel,
  });
  final bool embedded;
  final bool saving;
  final Future<void> Function(AiConnectionDraft)? onSave;
  final VoidCallback? onCancel;
  final AgentConnection? existing;
  final bool hasKey;
  final AgentRuntime Function() runtimeFactory;

  @override
  ConsumerState<AiConnectionEditor> createState() => _AiConnectionEditorState();
}

class _AiConnectionEditorState extends ConsumerState<AiConnectionEditor> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _label;
  late final TextEditingController _model;
  late final TextEditingController _url;
  late final TextEditingController _timeout;
  late final TextEditingController _tokens;
  final _secret = TextEditingController();
  late String _provider;
  late String _api;
  late bool _useProxy;
  bool _testing = false;
  bool _showKey = false;
  bool? _testPassed;
  String? _testMessage;
  AgentRuntime? _testRuntime;
  int _testEpoch = 0;
  int _modelEpoch = 0;
  bool _fetching = false;
  List<AgentModel> _models = const [];
  String? _modelMessage;
  String _modelSearch = '';
  AgentRuntime? _modelRuntime;

  @override
  void initState() {
    super.initState();
    final connection = widget.existing;
    _provider = connection?.provider ?? 'deepseek';
    _api = connection?.api ?? 'openai-completions';
    _useProxy = connection?.useProxy ?? false;
    _label = TextEditingController(text: connection?.label ?? '');
    _model = TextEditingController(text: connection?.model ?? '');
    _url = TextEditingController(text: connection?.baseUrl ?? '');
    _timeout = TextEditingController(
      text: '${connection?.timeoutSeconds ?? 90}',
    );
    _tokens = TextEditingController(text: '${connection?.maxTokens ?? 4096}');
  }

  bool get _dirty {
    final original = widget.existing;
    return _label.text.trim() != (original?.label ?? '') ||
        _model.text.trim() != (original?.model ?? '') ||
        _url.text.trim() != (original?.baseUrl ?? '') ||
        _provider != (original?.provider ?? 'deepseek') ||
        _api != (original?.api ?? 'openai-completions') ||
        _useProxy != (original?.useProxy ?? false) ||
        _timeout.text != '${original?.timeoutSeconds ?? 90}' ||
        _tokens.text != '${original?.maxTokens ?? 4096}' ||
        _secret.text.isNotEmpty;
  }

  Future<bool> confirmDiscard() async {
    if (!_dirty && !_testing && !_fetching) return true;
    final strings = context.appLocalizations;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(strings.aiUnsavedChanges),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(strings.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(strings.aiDiscardChanges),
              ),
            ],
          ),
        ) ??
        false;
  }

  bool get _targetChanged =>
      widget.existing != null &&
      (_provider != widget.existing!.provider ||
          _url.text.trim() != widget.existing!.baseUrl ||
          _api != widget.existing!.api);

  @override
  void dispose() {
    _testEpoch++;
    _modelEpoch++;
    _modelRuntime?.cancel();
    unawaited(_modelRuntime?.close() ?? Future<void>.value());
    _testRuntime?.cancel();
    unawaited(_testRuntime?.close() ?? Future<void>.value());
    for (final controller in [
      _label,
      _model,
      _url,
      _timeout,
      _tokens,
      _secret,
    ]) {
      controller.clear();
      controller.dispose();
    }
    super.dispose();
  }

  AgentConnection? _connection() {
    if (!_form.currentState!.validate()) return null;
    try {
      final random = Random.secure();
      final id =
          widget.existing?.id ??
          List.generate(
            16,
            (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
          ).join();
      return AgentConnection.fromJson({
        'id': id,
        'label': _label.text.trim(),
        'provider': _provider,
        'model': _model.text.trim(),
        'baseUrl': _url.text.trim(),
        'api': _api,
        'useProxy': _useProxy,
        'timeoutSeconds': int.parse(_timeout.text),
        'maxTokens': int.parse(_tokens.text),
      });
    } catch (_) {
      setState(() {
        _testPassed = false;
        _testMessage = context.appLocalizations.aiInvalidConnection;
      });
      return null;
    }
  }

  void _invalidateModels({bool clearKey = false}) {
    _modelEpoch++;
    _modelRuntime?.cancel();
    unawaited(_modelRuntime?.close() ?? Future<void>.value());
    _modelRuntime = null;
    setState(() {
      _fetching = false;
      _models = const [];
      _modelMessage = null;
      if (clearKey) {
        _secret.clear();
        _model.clear();
      }
      _testPassed = null;
      _testMessage = null;
    });
  }

  Future<void> _fetchModels() async {
    if (_fetching || _testing) return;
    final epoch = ++_modelEpoch;
    setState(() {
      _fetching = true;
      _models = const [];
      _modelMessage = null;
    });
    AgentRuntime? runtime;
    try {
      final secret = _secret.text.trim().isNotEmpty
          ? _secret.text.trim()
          : !_targetChanged && widget.existing != null
          ? await ref
                .read(workbenchControllerProvider)
                .credentials
                .read(widget.existing!.credentialId)
          : null;
      if (!mounted || epoch != _modelEpoch) return;
      if (secret == null || secret.isEmpty) {
        throw const AgentRuntimeException('keyMissing');
      }
      runtime = widget.runtimeFactory();
      _modelRuntime = runtime;
      final settings = AgentConnectionSettings(
        provider: _provider,
        model: '',
        baseUrl: _url.text.trim(),
        api: _api,
        proxyUrl: _useProxy
            ? 'http://127.0.0.1:${ref.read(patchClashConfigProvider).mixedPort}'
            : null,
        timeoutSeconds: int.parse(_timeout.text),
        maxTokens: int.parse(_tokens.text),
      );
      final models = await runtime.listModels(settings: settings, key: secret);
      if (!mounted || epoch != _modelEpoch) return;
      setState(() {
        _models = models;
        _modelMessage = models.isEmpty
            ? context.appLocalizations.aiModelsEmpty
            : context.appLocalizations.aiModelsFetched(models.length);
      });
    } catch (error) {
      if (mounted && epoch == _modelEpoch) {
        setState(() {
          _modelMessage =
              error is AgentRuntimeException &&
                  error.code == 'modelsUnsupported'
              ? context.appLocalizations.aiModelsUnsupported
              : aiErrorText(context, error);
        });
      }
    } finally {
      await runtime?.close();
      if (identical(_modelRuntime, runtime)) _modelRuntime = null;
      if (mounted && epoch == _modelEpoch) setState(() => _fetching = false);
    }
  }

  Future<void> _test() async {
    final connection = _connection();
    if (_testing || connection == null) return;
    final epoch = ++_testEpoch;
    setState(() {
      _testing = true;
      _testPassed = null;
      _testMessage = context.appLocalizations.aiTesting;
    });
    AgentRuntime? runtime;
    StreamSubscription<AgentRuntimeEvent>? subscription;
    try {
      final secret = _secret.text.trim().isNotEmpty
          ? _secret.text.trim()
          : await ref
                .read(workbenchControllerProvider)
                .credentials
                .read(connection.credentialId);
      if (!mounted || epoch != _testEpoch) return;
      if (secret == null || secret.isEmpty) {
        throw const AgentRuntimeException('keyMissing');
      }
      runtime = widget.runtimeFactory();
      _testRuntime = runtime;
      bool streamed = false;
      bool toolCalled = false;
      bool failed = false;
      subscription = runtime.events.listen((event) {
        if (event.type == 'text' && (event.data['text'] as String).isNotEmpty) {
          streamed = true;
        }
        if (event.type == 'error' ||
            event.type == 'done' && event.data['cancelled'] == true) {
          failed = true;
        }
      });
      final challenge = 'echo-${DateTime.now().microsecondsSinceEpoch}';
      await runtime.prompt(
        settings: connection.runtimeSettings(
          mixedPort: ref.read(patchClashConfigProvider).mixedPort,
        ),
        key: secret,
        user:
            'Call tool_echo with value "$challenge" exactly once, then return that value as text. Do not use any other tool.',
        tools: const [
          AgentToolDefinition(
            name: 'tool_echo',
            description:
                'Echo a connection-test value; does not change app state.',
            parameters: {
              'type': 'object',
              'properties': {
                'value': {'type': 'string'},
              },
              'required': ['value'],
              'additionalProperties': false,
            },
          ),
        ],
        executeTool: (request) async {
          if (!mounted ||
              epoch != _testEpoch ||
              !request.isCurrent() ||
              request.arguments['value'] != challenge) {
            return const AgentToolResult({
              'code': 'invalidEcho',
            }, isError: true);
          }
          toolCalled = true;
          return AgentToolResult({'value': challenge});
        },
      );
      if (mounted && epoch == _testEpoch) {
        setState(() {
          _testPassed = streamed && toolCalled && !failed;
          _testMessage = _testPassed!
              ? context.appLocalizations.aiTestPassed
              : context.appLocalizations.aiTestPartial;
        });
      }
    } catch (error) {
      if (mounted && epoch == _testEpoch) {
        setState(() {
          _testPassed = false;
          _testMessage = aiErrorText(context, error);
        });
      }
    } finally {
      await subscription?.cancel();
      await runtime?.close();
      if (identical(_testRuntime, runtime)) _testRuntime = null;
      if (mounted && epoch == _testEpoch) setState(() => _testing = false);
    }
  }

  Future<void> _stopTest() async {
    final epoch = ++_testEpoch;
    final runtime = _testRuntime;
    runtime?.cancel();
    await runtime?.close();
    if (mounted && epoch == _testEpoch) {
      setState(() {
        _testing = false;
        _testPassed = false;
        _testMessage = context.appLocalizations.aiCancelled;
      });
    }
  }

  String _providerLabel(String id) {
    final strings = context.appLocalizations;
    return switch (id) {
      'glm-cn' => 'GLM · ${strings.aiChinaApi}',
      'glm-coding-cn' => 'GLM · ${strings.aiChinaCoding}',
      'glm-global' => 'GLM · ${strings.aiGlobalApi}',
      'glm-coding-global' => 'GLM · ${strings.aiGlobalCoding}',
      'kimi-cn' => 'Kimi · ${strings.aiChinaApi}',
      'kimi-global' => 'Kimi · ${strings.aiGlobalApi}',
      'kimi-coding' => 'Kimi · ${strings.aiCodingPlan}',
      'custom' => strings.aiCustomProvider,
      _ => agentProviderPresets[id]!,
    };
  }

  void _invalidateTest() {
    setState(() {
      _testPassed = null;
      _testMessage = null;
    });
  }

  Widget _group(List<Widget> children) => SizedBox(
    width: double.infinity,
    child: Material(
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    ),
  );

  Widget _sectionTitle(IconData icon, String title) => Row(
    children: [
      Icon(icon, color: Theme.of(context).colorScheme.primary),
      const SizedBox(width: 12),
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final strings = context.appLocalizations;
    String? requiredText(String? value) => value == null || value.trim().isEmpty
        ? strings.aiInvalidConnection
        : null;
    final content = SizedBox(
      width: 720,
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _group([
                _sectionTitle(Icons.dns_outlined, strings.aiServiceCredentials),
                const SizedBox(height: 16),
                TextFormField(
                  key: const ValueKey('ai-connection-name'),
                  controller: _label,
                  enabled: !_testing && !widget.saving,
                  maxLength: 200,
                  decoration: InputDecoration(
                    labelText: strings.name,
                    counterText: '',
                  ),
                  validator: requiredText,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _provider,
                  isExpanded: true,
                  key: const ValueKey('ai-connection-provider'),
                  decoration: InputDecoration(labelText: strings.aiProvider),
                  items: [
                    for (final id in agentProviderPresets.keys)
                      DropdownMenuItem(
                        value: id,
                        child: Text(
                          _providerLabel(id),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: _testing || widget.saving
                      ? null
                      : (value) {
                          if (value == null) return;
                          _invalidateModels(clearKey: true);
                          setState(() {
                            _provider = value;
                            _model.clear();
                            _url.clear();
                            _secret.clear();
                            _testMessage = null;
                            _testPassed = null;
                            _api = value == 'openai'
                                ? 'openai-responses'
                                : value == 'anthropic' || value == 'kimi-coding'
                                ? 'anthropic-messages'
                                : 'openai-completions';
                          });
                        },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('ai-connection-url'),
                  controller: _url,
                  enabled: !_testing && !widget.saving,
                  maxLength: 4096,
                  decoration: InputDecoration(
                    labelText: strings.aiBaseUrl,
                    helperText: _provider == 'custom'
                        ? null
                        : strings.aiPresetDefault,
                    counterText: '',
                  ),
                  validator: (value) =>
                      _provider == 'custom' ? requiredText(value) : null,
                  onChanged: (_) => _invalidateModels(clearKey: true),
                ),
                if (_provider == 'custom') ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _api,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: strings.aiApiProtocol,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'openai-completions',
                        child: Text('OpenAI Chat Completions'),
                      ),
                      DropdownMenuItem(
                        value: 'openai-responses',
                        child: Text('OpenAI Responses'),
                      ),
                      DropdownMenuItem(
                        value: 'anthropic-messages',
                        child: Text('Anthropic Messages'),
                      ),
                    ],
                    onChanged: _testing || widget.saving
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() {
                                _invalidateModels(clearKey: true);
                                _api = value;
                                _testPassed = null;
                                _testMessage = null;
                              });
                            }
                          },
                  ),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('ai-connection-key'),
                  controller: _secret,
                  enabled: !_testing && !widget.saving,
                  obscureText: !_showKey,
                  autocorrect: false,
                  enableSuggestions: false,
                  maxLength: 16384,
                  decoration: InputDecoration(
                    labelText: strings.aiKey,
                    counterText: '',
                    helperText: _targetChanged
                        ? strings.aiTargetChanged
                        : widget.hasKey
                        ? strings.aiKeyStored
                        : strings.aiKeyRequired,
                    helperMaxLines: 3,
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _showKey = !_showKey),
                      tooltip: _showKey ? strings.aiKeyHide : strings.aiKeyShow,
                      icon: Icon(
                        _showKey ? Icons.visibility_off : Icons.visibility,
                      ),
                    ),
                  ),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty) &&
                          (!widget.hasKey || _targetChanged)
                      ? strings.aiKeyRequired
                      : null,
                  onChanged: (_) => _invalidateModels(),
                ),
                if (_targetChanged) Text(strings.aiTargetChanged),
              ]),
              const SizedBox(height: 12),
              _group([
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        strings.aiModel,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    FilledButton.tonalIcon(
                      key: const ValueKey('ai-fetch-models'),
                      onPressed: _testing || _fetching || widget.saving
                          ? null
                          : _fetchModels,
                      icon: const Icon(Icons.refresh),
                      label: Text(strings.aiFetchModels),
                    ),
                  ],
                ),
                if (_fetching) ...[
                  const SizedBox(height: 8),
                  const LinearProgressIndicator(),
                  TextButton(
                    onPressed: () {
                      _invalidateModels();
                      setState(() => _modelMessage = strings.aiCancelled);
                    },
                    child: Text(strings.aiStop),
                  ),
                ],
                if (_modelMessage != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(_modelMessage!),
                  ),
                if (_models.isNotEmpty) ...[
                  TextField(
                    key: const ValueKey('ai-search-models'),
                    enabled: !_testing && !widget.saving,
                    decoration: InputDecoration(
                      hintText: strings.aiSearchModels,
                      prefixIcon: const Icon(Icons.search),
                    ),
                    onChanged: (value) =>
                        setState(() => _modelSearch = value.toLowerCase()),
                  ),
                  SizedBox(
                    key: const ValueKey('ai-model-options'),
                    height: 160,
                    child: ListView(
                      children: [
                        for (final model in _models)
                          if ('${model.id} ${model.name}'
                              .toLowerCase()
                              .contains(_modelSearch))
                            ListTile(
                              selected: model.id == _model.text,
                              leading: Icon(
                                model.id == _model.text
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_unchecked,
                              ),
                              title: Text(model.id),
                              subtitle: model.name == model.id
                                  ? null
                                  : Text(model.name),
                              onTap: _testing || widget.saving
                                  ? null
                                  : () {
                                      _model.text = model.id;
                                      _invalidateTest();
                                    },
                            ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                TextFormField(
                  key: const ValueKey('ai-connection-model'),
                  controller: _model,
                  enabled: !_testing && !widget.saving,
                  maxLength: 200,
                  decoration: InputDecoration(
                    labelText: strings.aiManualModel,
                    counterText: '',
                  ),
                  validator: requiredText,
                  onChanged: (_) => _invalidateTest(),
                ),
                const SizedBox(height: 12),
                Text(
                  strings.aiModelFetchHint,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ]),
              const SizedBox(height: 12),
              _group([
                OutlinedButton.icon(
                  onPressed: _testing || _fetching || widget.saving
                      ? null
                      : _test,
                  icon: const Icon(Icons.fact_check_outlined),
                  label: Text(strings.aiTestConnection),
                ),
                Text(
                  strings.aiTestingCharges,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (_testing) ...[
                  const SizedBox(height: 8),
                  const LinearProgressIndicator(),
                  TextButton(onPressed: _stopTest, child: Text(strings.aiStop)),
                ],
                if (_testMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _testMessage!,
                      style: TextStyle(
                        color: _testPassed == false
                            ? Theme.of(context).colorScheme.error
                            : null,
                      ),
                    ),
                  ),
              ]),
              const SizedBox(height: 12),
              _group([
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(strings.aiUseProxy),
                  value: _useProxy,
                  onChanged: _testing || widget.saving
                      ? null
                      : (value) => setState(() {
                          _invalidateModels();
                          _useProxy = value;
                          _testPassed = null;
                          _testMessage = null;
                        }),
                ),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text(strings.aiAdvanced),
                  children: [
                    TextFormField(
                      controller: _timeout,
                      enabled: !_testing && !widget.saving,
                      decoration: InputDecoration(labelText: strings.aiTimeout),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        final number = int.tryParse(value ?? '');
                        return number == null || number < 5 || number > 300
                            ? strings.aiInvalidConnection
                            : null;
                      },
                      onChanged: (_) => _invalidateTest(),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _tokens,
                      enabled: !_testing && !widget.saving,
                      decoration: InputDecoration(
                        labelText: strings.aiMaxTokens,
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        final number = int.tryParse(value ?? '');
                        return number == null || number < 64 || number > 32768
                            ? strings.aiInvalidConnection
                            : null;
                      },
                      onChanged: (_) => _invalidateTest(),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ]),
            ],
          ),
        ),
      ),
    );
    final actions = <Widget>[
      TextButton(
        onPressed: widget.saving
            ? null
            : () async {
                if (widget.embedded) {
                  widget.onCancel?.call();
                  return;
                }
                if (await confirmDiscard() && context.mounted) {
                  Navigator.of(context).pop();
                }
              },
        child: Text(strings.cancel),
      ),
      FilledButton(
        onPressed: _testing || _fetching || widget.saving
            ? null
            : () {
                final connection = _connection();
                if (connection != null) {
                  final draft = AiConnectionDraft(
                    connection: connection,
                    secret: _secret.text.trim().isEmpty
                        ? null
                        : _secret.text.trim(),
                  );
                  if (widget.embedded) {
                    unawaited(
                      widget.onSave?.call(draft) ?? Future<void>.value(),
                    );
                  } else {
                    Navigator.of(context).pop(draft);
                  }
                }
              },
        child: Text(strings.aiSaveAndUse),
      ),
    ];
    if (widget.embedded) {
      return Card(
        margin: EdgeInsets.zero,
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.existing == null
                    ? strings.aiAddConnection
                    : strings.aiEditConnection,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Expanded(child: content),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 12,
                children: actions,
              ),
            ],
          ),
        ),
      );
    }
    return AlertDialog(
      title: Text(
        widget.existing == null
            ? strings.aiAddConnection
            : strings.aiEditConnection,
      ),
      content: content,
      actions: actions,
    );
  }
}
