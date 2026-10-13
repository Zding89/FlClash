import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_js/flutter_js.dart';

class ScriptExecutionException implements Exception {
  final String code;

  const ScriptExecutionException(this.code);

  @override
  String toString() => code;
}

typedef ScriptProcessLauncher = Future<Process> Function();

Future<Process> _launchPackagedScript() async {
  final contents = File(Platform.resolvedExecutable).parent.parent.path;
  final directory = '$contents/Resources/ai';
  if (!await File('$directory/node').exists() ||
      !await File('$directory/script_runner.mjs').exists()) {
    throw const ScriptExecutionException('script_runtime_unavailable');
  }
  return launchScriptProcess(
    executablePath: '$directory/node',
    runnerPath: '$directory/script_runner.mjs',
  );
}

Future<Process> launchScriptProcess({
  required String executablePath,
  required String runnerPath,
}) async {
  final executable = await File(executablePath).resolveSymbolicLinks();
  final runner = await File(runnerPath).resolveSymbolicLinks();
  final permissions = [
    '(version 1)',
    '(deny default)',
    '(allow process-exec (literal ${jsonEncode(executable)}))',
    '(allow sysctl-read)',
    '(allow file-read-metadata)',
    '(allow file-read* (literal "/") (literal ${jsonEncode(executable)}) (literal ${jsonEncode(runner)}) (subpath "/usr/lib") (subpath "/System/Library"))',
  ].join('\n');
  return Process.start(
    '/usr/bin/sandbox-exec',
    [
      '-p',
      permissions,
      executable,
      '--max-old-space-size=64',
      '--max-semi-space-size=4',
      runner,
    ],
    workingDirectory: '/',
    environment: const {},
    includeParentEnvironment: false,
  );
}

Future<String> _readScriptOutput(Stream<List<int>> stream) async {
  final bytes = BytesBuilder(copy: false);
  await for (final chunk in stream) {
    if (bytes.length + chunk.length > 8 * 1024 * 1024) {
      throw const ScriptExecutionException('script_output_limit');
    }
    bytes.add(chunk);
  }
  return utf8.decode(bytes.takeBytes());
}

Future<Map<String, dynamic>> handleEvaluate(
  String scriptContent,
  Map<String, dynamic> config, {
  Duration timeout = const Duration(seconds: 2),
  ScriptProcessLauncher? launcher,
}) async {
  final candidate = {
    ...config,
    'proxy-providers': config['proxy-providers'] ?? <String, Object?>{},
  };
  final input = jsonEncode(candidate);
  if (utf8.encode(scriptContent).length > 512 * 1024 ||
      utf8.encode(input).length > 8 * 1024 * 1024 ||
      timeout <= Duration.zero ||
      timeout > const Duration(seconds: 2)) {
    throw const ScriptExecutionException('script_input_limit');
  }
  if (!Platform.isMacOS && launcher == null) {
    final runtime = getJavascriptRuntime(xhr: false);
    try {
      final result = await runtime.evaluateAsync(
        'JSON.stringify((function(){ $scriptContent; return main($input); })())',
      );
      if (result.isError) {
        throw const ScriptExecutionException('script_evaluation_failed');
      }
      return _scriptResult(result.stringResult);
    } finally {
      JavascriptRuntime.channelFunctionsRegistered.remove(
        runtime.getEngineInstanceId(),
      );
      runtime.dispose();
    }
  }
  Process? process;
  var exited = false;
  var acceptingLaunch = true;
  StreamSubscription<List<int>>? diagnostics;
  final elapsed = Stopwatch()..start();
  final deadline = timeout + const Duration(seconds: 1);
  Duration remaining() {
    final duration = deadline - elapsed.elapsed;
    if (duration <= Duration.zero) {
      throw const ScriptExecutionException('script_timeout');
    }
    return duration;
  }

  try {
    final launched = (launcher ?? _launchPackagedScript)();
    unawaited(
      launched.then((value) async {
        if (!acceptingLaunch) {
          value.kill(ProcessSignal.sigkill);
          await value.exitCode;
        }
      }, onError: (Object _) {}),
    );
    process = await launched.timeout(remaining());
    unawaited(process.exitCode.then((_) => exited = true));
    diagnostics = process.stderr.listen((_) {}, onError: (Object _) {});
    final output = _readScriptOutput(process.stdout);
    unawaited(output.catchError((Object _) => ''));
    process.stdin.add(
      utf8.encode(
        jsonEncode({
          'script': scriptContent,
          'config': candidate,
          'timeoutMillis': timeout.inMilliseconds.clamp(1, 2000),
        }),
      ),
    );
    await process.stdin.flush().timeout(remaining());
    await process.stdin.close().timeout(remaining());
    final result = await output.timeout(remaining());
    final exit = await process.exitCode.timeout(remaining());
    final response = jsonDecode(result);
    if (response is! Map<String, dynamic>) {
      throw const ScriptExecutionException('script_worker_failed');
    }
    if (exit != 0 || response['code'] != null) {
      final code = response['code'];
      throw ScriptExecutionException(
        code is String &&
                {
                  'script_timeout',
                  'script_input_limit',
                  'script_output_limit',
                  'script_result_not_object',
                  'script_evaluation_failed',
                }.contains(code)
            ? code
            : 'script_worker_failed',
      );
    }
    return _scriptResult(jsonEncode(response['value']));
  } on TimeoutException {
    throw const ScriptExecutionException('script_timeout');
  } on ScriptExecutionException {
    rethrow;
  } catch (_) {
    throw const ScriptExecutionException('script_worker_failed');
  } finally {
    acceptingLaunch = false;
    if (process != null) {
      if (!exited) process.kill(ProcessSignal.sigkill);
      await process.exitCode;
    }
    await diagnostics?.cancel();
  }
}

Map<String, dynamic> _scriptResult(String value) {
  if (value.length > 8 * 1024 * 1024) {
    throw const ScriptExecutionException('script_output_limit');
  }
  final result = jsonDecode(value);
  if (result is! Map<String, dynamic>) {
    throw const ScriptExecutionException('script_result_not_object');
  }
  return result;
}
