import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

class AgentConnectionSettings {
  const AgentConnectionSettings({
    required this.provider,
    required this.model,
    this.baseUrl = '',
    this.api = 'openai-completions',
    this.proxyUrl,
    this.timeoutSeconds = 90,
    this.maxTokens = 4096,
  });

  final String provider;
  final String model;
  final String baseUrl;
  final String api;
  final String? proxyUrl;
  final int timeoutSeconds;
  final int maxTokens;

  Map<String, Object?> toJson() => {
    'provider': provider,
    'model': model,
    'baseUrl': baseUrl,
    'api': api,
    'proxyUrl': proxyUrl,
    'timeoutSeconds': timeoutSeconds,
    'maxTokens': maxTokens,
  };
}

class AgentModel {
  const AgentModel({required this.id, required this.name});
  final String id;
  final String name;
}

class AgentToolDefinition {
  const AgentToolDefinition({
    required this.name,
    required this.description,
    required this.parameters,
  });

  final String name;
  final String description;
  final Map<String, Object?> parameters;

  Map<String, Object?> toJson() => {
    'name': name,
    'description': description,
    'parameters': parameters,
  };
}

class AgentToolRequest {
  const AgentToolRequest({
    required this.requestId,
    required this.toolCallId,
    required this.name,
    required this.arguments,
    required this.isCurrent,
  });

  final String requestId;
  final String toolCallId;
  final String name;
  final Map<String, Object?> arguments;
  final bool Function() isCurrent;
}

class AgentToolResult {
  const AgentToolResult(this.value, {this.isError = false});

  final Map<String, Object?> value;
  final bool isError;
}

class AgentRuntimeException implements Exception {
  const AgentRuntimeException(this.code);
  final String code;
  @override
  String toString() => code;
}

class AgentRuntimeEvent {
  const AgentRuntimeEvent({
    required this.type,
    required this.data,
    required this.generation,
    required this.requestId,
  });

  final String type;
  final Map<String, Object?> data;
  final int generation;
  final String requestId;
}

typedef AgentToolExecutor =
    Future<AgentToolResult> Function(AgentToolRequest request);

typedef AgentTransportLauncher = Future<AgentTransport> Function();

abstract interface class AgentTransport {
  Stream<List<int>> get output;
  Stream<List<int>> get diagnostics;
  Future<int> get exitCode;
  Future<void> write(List<int> bytes);
  Future<void> close();
}

class ProcessAgentTransport implements AgentTransport {
  ProcessAgentTransport(this.process);

  final Process process;

  @override
  Stream<List<int>> get output => process.stdout;
  @override
  Stream<List<int>> get diagnostics => process.stderr;
  @override
  Future<int> get exitCode => process.exitCode;
  @override
  Future<void> write(List<int> bytes) async {
    process.stdin.add(bytes);
    await process.stdin.flush();
  }

  @override
  Future<void> close() async {
    process.kill(ProcessSignal.sigterm);
    try {
      await process.exitCode.timeout(const Duration(seconds: 2));
    } on TimeoutException {
      process.kill(ProcessSignal.sigkill);
      await process.exitCode;
    }
  }
}

class AgentRuntime {
  AgentRuntime({AgentTransportLauncher? launcher})
    : _launcher = launcher ?? _launchPackaged {
    _events = StreamController<AgentRuntimeEvent>(
      sync: true,
      onPause: () {
        _paused = true;
        cancel();
      },
      onResume: () => _paused = false,
      onCancel: cancel,
    );
  }

  static const maxFrameBytes = 1024 * 1024;
  static final _identifier = RegExp(r'^[A-Za-z0-9_-]{1,96}$');
  static bool _validId(String value) =>
      _identifier.hasMatch(value) && !value.contains('\n');
  final AgentTransportLauncher _launcher;
  final String _sessionId = _newId();
  late final StreamController<AgentRuntimeEvent> _events;
  AgentTransport? _transport;
  Future<void>? _starting;
  Future<void>? _closing;
  StreamSubscription<List<int>>? _outputSubscription;
  StreamSubscription<List<int>>? _diagnosticSubscription;
  final List<int> _frame = [];
  final Set<String> _toolRequests = {};
  final Set<String> _activeTools = {};
  int _generation = 0;
  int _queuedBytes = 0;
  int _outputBytes = 0;
  String? _requestId;
  String? _failureCode;
  List<AgentModel>? _models;
  Completer<void>? _completion;
  AgentToolExecutor? _executeTool;
  Set<String> _allowedTools = {};
  bool _closed = false;
  bool _paused = false;
  bool _cancelled = false;
  Future<void> _writes = Future<void>.value();
  Timer? _watchdog;

  Stream<AgentRuntimeEvent> get events => _events.stream;
  bool get isRunning => _completion != null;

  static String _newId() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  static Future<AgentTransport> _launchPackaged() async {
    if (!Platform.isMacOS) throw UnsupportedError('macOS required');
    final contents = File(Platform.resolvedExecutable).parent.parent.path;
    final directory = '$contents/Resources/ai';
    if (!await File('$directory/node').exists() ||
        !await File('$directory/host.mjs').exists()) {
      throw StateError('aiHostNotPackaged');
    }
    final environment = <String, String>{};
    for (final name in ['HOME', 'TMPDIR', 'LANG', 'LC_ALL']) {
      final value = Platform.environment[name];
      if (value != null) environment[name] = value;
    }
    final process = await Process.start(
      '$directory/node',
      ['$directory/host.mjs'],
      workingDirectory: directory,
      environment: environment,
      includeParentEnvironment: false,
    );
    return ProcessAgentTransport(process);
  }

  Future<void> start() {
    if (_closed) return Future.error(StateError('runtimeClosed'));
    if (_transport != null) return Future.value();
    return _starting ??= _start();
  }

  Future<void> _start() async {
    try {
      final transport = await _launcher();
      if (_closed) {
        await transport.close();
        throw StateError('runtimeClosed');
      }
      _transport = transport;
      _outputSubscription = transport.output.listen(
        _receive,
        onError: (Object error) => _fail('hostTransportFailed'),
        onDone: () => _fail('hostExited'),
      );
      _diagnosticSubscription = transport.diagnostics.listen(
        (_) {},
        onError: (Object error) {},
      );
      unawaited(
        transport.exitCode.then((_) {
          if (!_closed && identical(_transport, transport)) {
            _fail('hostExited');
          }
        }),
      );
    } finally {
      _starting = null;
    }
  }

  Future<void> prompt({
    required AgentConnectionSettings settings,
    required String key,
    required String user,
    required List<AgentToolDefinition> tools,
    required AgentToolExecutor executeTool,
    List<Map<String, Object?>> messages = const [],
  }) async {
    await start();
    if (_closed || isRunning) throw StateError('runtimeUnavailable');
    if (key.isEmpty ||
        key.length > 16384 ||
        user.trim().isEmpty ||
        user.length > 262144 ||
        tools.length > 128 ||
        messages.length > 100) {
      throw ArgumentError('invalidPrompt');
    }
    _generation++;
    _requestId = _newId();
    _cancelled = false;
    _failureCode = null;
    _outputBytes = 0;
    _toolRequests.clear();
    _activeTools.clear();
    _allowedTools = tools.map((tool) => tool.name).toSet();
    _executeTool = executeTool;
    final completion = Completer<void>();
    _completion = completion;
    _watchdog = Timer(
      Duration(seconds: settings.timeoutSeconds * 3 + 5),
      () => _fail('timeout'),
    );
    try {
      await _send('prompt', {
        'settings': settings.toJson(),
        'key': key,
        'user': user,
        'tools': tools.map((tool) => tool.toJson()).toList(),
        'messages': messages,
      });
    } catch (_) {
      _fail('hostTransportFailed');
    }
    await completion.future;
  }

  Future<List<AgentModel>> listModels({
    required AgentConnectionSettings settings,
    required String key,
  }) async {
    await start();
    if (_closed || isRunning) throw StateError('runtimeUnavailable');
    if (key.isEmpty || key.length > 16384) throw ArgumentError('invalidKey');
    _generation++;
    _requestId = _newId();
    _cancelled = false;
    _failureCode = null;
    _models = null;
    _allowedTools = {};
    final completion = Completer<void>();
    _completion = completion;
    _watchdog = Timer(
      Duration(seconds: settings.timeoutSeconds + 5),
      () => _fail('timeout'),
    );
    try {
      await _send('listModels', {'settings': settings.toJson(), 'key': key});
    } catch (_) {
      _fail('hostTransportFailed');
    }
    await completion.future;
    if (_cancelled) throw const AgentRuntimeException('cancelled');
    return _models ?? (throw const AgentRuntimeException('invalidModelList'));
  }

  Future<void> _send(
    String type,
    Map<String, Object?> data, {
    String? requestId,
  }) {
    final encoded = jsonEncode({
      'version': 1,
      'sessionId': _sessionId,
      'generation': _generation,
      'requestId': requestId ?? _requestId,
      'type': type,
      'data': data,
    });
    final bytes = utf8.encode('$encoded\n');
    if (bytes.length > maxFrameBytes ||
        _queuedBytes + bytes.length > 4 * maxFrameBytes) {
      return Future.error(StateError('frameLimit'));
    }
    _queuedBytes += bytes.length;
    final transport = _transport;
    final operation = _writes
        .then((_) async {
          if (_closed ||
              transport == null ||
              !identical(_transport, transport)) {
            throw StateError('runtimeClosed');
          }
          await transport.write(bytes).timeout(const Duration(seconds: 5));
        })
        .whenComplete(() => _queuedBytes -= bytes.length);
    _writes = operation.catchError((Object _) {});
    return operation;
  }

  void _receive(List<int> bytes) {
    if (_closed) return;
    for (final byte in bytes) {
      if (byte == 10) {
        try {
          final value = jsonDecode(utf8.decode(_frame));
          _frame.clear();
          if (value is! Map<String, dynamic>) throw const FormatException();
          _handle(value);
        } catch (_) {
          _fail('invalidFrame');
          return;
        }
      } else {
        if (_frame.length >= maxFrameBytes) {
          _fail('frameLimit');
          return;
        }
        _frame.add(byte);
      }
    }
  }

  void _handle(Map<String, dynamic> frame) {
    if (frame['version'] != 1 ||
        frame['sessionId'] is! String ||
        !_validId(frame['sessionId'] as String) ||
        frame['requestId'] is! String ||
        !_validId(frame['requestId'] as String) ||
        frame['generation'] is! int ||
        (frame['generation'] as int) < 1 ||
        frame['type'] is! String ||
        frame['data'] is! Map<String, dynamic>) {
      throw const FormatException();
    }
    if (frame['sessionId'] != _sessionId ||
        frame['generation'] != _generation ||
        frame['requestId'] != _requestId ||
        _completion == null) {
      return;
    }
    final type = frame['type'] as String;
    final data = Map<String, Object?>.from(frame['data'] as Map);
    if (![
      'text',
      'models',
      'status',
      'error',
      'done',
      'toolRequest',
    ].contains(type)) {
      throw const FormatException();
    }
    if (type == 'status' && data['status'] is! String ||
        type == 'error' &&
            (data['code'] is! String || !_validId(data['code'] as String)) ||
        type == 'done' &&
            (data['cancelled'] is! bool || data['failed'] is! bool)) {
      throw const FormatException();
    }
    if (type == 'models') {
      final models = data['models'];
      if (models is! List || models.length > 1000) {
        throw const FormatException();
      }
      _models = [
        for (final model in models)
          if (model is Map &&
              model['id'] is String &&
              (model['id'] as String).isNotEmpty &&
              (model['id'] as String).length <= 200 &&
              model['name'] is String &&
              (model['name'] as String).length <= 200)
            AgentModel(id: model['id'] as String, name: model['name'] as String)
          else
            throw const FormatException(),
      ];
    }
    if (type == 'text') {
      if (data['text'] is! String) throw const FormatException();
      _outputBytes += utf8.encode(data['text'] as String).length;
      if (_outputBytes > 4 * maxFrameBytes) {
        _fail('outputLimit');
        return;
      }
    }
    if (type == 'error') _failureCode = data['code'] as String;
    if (type == 'toolRequest') {
      if (!_cancelled) unawaited(_execute(data));
      return;
    }
    if (!_paused && !_events.isClosed && (!_cancelled || type == 'done')) {
      _events.add(
        AgentRuntimeEvent(
          type: type,
          data: data,
          generation: _generation,
          requestId: _requestId!,
        ),
      );
    }
    if (type == 'done' ||
        (type == 'error' && data['code'] == 'invalidPrompt')) {
      _finish(
        error: _cancelled
            ? null
            : _failureCode ?? (data['failed'] == true ? 'agentFailed' : null),
      );
    }
  }

  Future<void> _execute(Map<String, Object?> data) async {
    final toolRequestId = data['requestId'];
    final toolCallId = data['toolCallId'];
    final name = data['name'];
    final arguments = data['arguments'];
    if (toolRequestId is! String ||
        !_validId(toolRequestId) ||
        toolCallId is! String ||
        toolCallId.isEmpty ||
        toolCallId.length > 200 ||
        name is! String ||
        !_allowedTools.contains(name) ||
        arguments is! Map<String, dynamic> ||
        _toolRequests.length >= 4096 ||
        _activeTools.length >= 32 ||
        !_toolRequests.add(toolRequestId)) {
      _fail('invalidToolRequest');
      return;
    }
    _activeTools.add(toolRequestId);
    final generation = _generation;
    bool isCurrent() =>
        !_closed &&
        !_cancelled &&
        _completion != null &&
        _generation == generation;
    try {
      if (!isCurrent()) return;
      final result = await _executeTool!(
        AgentToolRequest(
          requestId: toolRequestId,
          toolCallId: toolCallId,
          name: name,
          arguments: Map<String, Object?>.from(arguments),
          isCurrent: isCurrent,
        ),
      );
      if (!isCurrent()) return;
      await _send('toolResult', {
        'toolCallId': toolCallId,
        'isError': result.isError,
        'value': result.value,
      }, requestId: toolRequestId);
    } catch (_) {
      if (isCurrent()) {
        try {
          await _send('toolResult', {
            'toolCallId': toolCallId,
            'isError': true,
            'value': {'code': 'commandFailed'},
          }, requestId: toolRequestId);
        } catch (_) {
          _fail('hostTransportFailed');
        }
      }
    } finally {
      _activeTools.remove(toolRequestId);
    }
  }

  void cancel() {
    if (_closed || _completion == null || _cancelled) return;
    _cancelled = true;
    unawaited(
      _send('cancel', {}).catchError((Object _) {
        _fail('hostTransportFailed');
      }),
    );
  }

  void _finish({String? error}) {
    _watchdog?.cancel();
    _watchdog = null;
    final completion = _completion;
    if (completion != null) {
      if (error == null) {
        completion.complete();
      } else {
        completion.completeError(AgentRuntimeException(error));
      }
    }
    _completion = null;
    _executeTool = null;
    _toolRequests.clear();
    _activeTools.clear();
  }

  void _fail(String code) {
    if (_closed) return;
    if (!_paused && !_events.isClosed && _completion != null) {
      _events.add(
        AgentRuntimeEvent(
          type: 'error',
          data: {'code': code},
          generation: _generation,
          requestId: _requestId!,
        ),
      );
    }
    _cancelled = true;
    _finish(error: code);
    unawaited(close());
  }

  Future<void> close() => _closing ??= _close();

  Future<void> _close() async {
    _closed = true;
    _cancelled = true;
    _finish();
    final starting = _starting;
    if (starting != null) {
      try {
        await starting;
      } catch (_) {}
    }
    await _outputSubscription?.cancel();
    await _diagnosticSubscription?.cancel();
    final transport = _transport;
    _transport = null;
    _frame.clear();
    if (transport != null) await transport.close();
    unawaited(_events.close());
  }
}
