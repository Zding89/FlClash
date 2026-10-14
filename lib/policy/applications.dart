import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as paths;

final class PolicyApplication {
  const PolicyApplication({
    required this.path,
    required this.label,
    required this.executable,
  });

  final String path;
  final String label;
  final String executable;

  String get processPathPattern =>
      '^${RegExp.escape(path).replaceAll(r'\(', r'\x28').replaceAll(r'\)', r'\x29').replaceAll(',', r'\x2c')}/Contents/.*\$';
}

String policyApplicationLabel(String value) {
  if (value.startsWith('^') && value.endsWith(r'/Contents/.*$')) {
    final root = value
        .substring(1, value.length - r'/Contents/.*$'.length)
        .replaceAll(r'\x28', '(')
        .replaceAll(r'\x29', ')')
        .replaceAll(r'\x2c', ',')
        .replaceAll(r'\.', '.');
    return paths.basenameWithoutExtension(root);
  }
  return paths.basename(value);
}

typedef ApplicationPlistReader =
    Future<Map<String, Object?>?> Function(String path);

class PolicyApplicationCatalog {
  PolicyApplicationCatalog({
    List<String>? roots,
    ApplicationPlistReader? readPlist,
    bool? supported,
    this.maximumApplications = 2000,
    this.maximumEntries = 12000,
  }) : roots =
           roots ??
           [
             '/Applications',
             if (Platform.environment['HOME'] case final String home)
               paths.join(home, 'Applications'),
             '/System/Applications',
           ],
       _readPlist = readPlist ?? _readApplicationPlist,
       supported = supported ?? Platform.isMacOS;

  final List<String> roots;
  final ApplicationPlistReader _readPlist;
  final bool supported;
  final int maximumApplications;
  final int maximumEntries;

  Future<List<PolicyApplication>> load() async {
    if (!supported) throw UnsupportedError('application_catalog_unavailable');
    final result = <String, PolicyApplication>{};
    var visited = 0;
    final clock = Stopwatch()..start();
    Future<void> visit(Directory directory, int depth) async {
      if (!await directory.exists()) return;
      await for (final entry in directory.list(followLinks: false)) {
        if (clock.elapsed > const Duration(seconds: 20)) {
          throw TimeoutException('application_catalog_timeout');
        }
        if (++visited > maximumEntries ||
            result.length >= maximumApplications) {
          throw StateError('application_catalog_limit');
        }
        if (entry is! Directory) continue;
        if (entry.path.endsWith('.app')) {
          final values = await _readPlist(
            paths.join(entry.path, 'Contents', 'Info.plist'),
          );
          final executable = values?['CFBundleExecutable'];
          if (executable is! String ||
              executable.isEmpty ||
              paths.basename(executable) != executable) {
            continue;
          }
          final executablePath = paths.join(
            entry.path,
            'Contents',
            'MacOS',
            executable,
          );
          if (!await File(executablePath).exists()) continue;
          final label =
              values?['CFBundleDisplayName'] ?? values?['CFBundleName'];
          final absolute = paths.normalize(paths.absolute(entry.path));
          result[absolute] = PolicyApplication(
            path: absolute,
            label: label is String && label.trim().isNotEmpty
                ? label
                : paths.basenameWithoutExtension(entry.path),
            executable: executablePath,
          );
        } else if (depth < 3) {
          await visit(entry, depth + 1);
        }
      }
    }

    for (final root in roots) {
      await visit(Directory(root), 0);
    }
    return result.values.toList()..sort((a, b) {
      final order = a.label.toLowerCase().compareTo(b.label.toLowerCase());
      return order == 0 ? a.path.compareTo(b.path) : order;
    });
  }

  static Future<Map<String, Object?>?> _readApplicationPlist(
    String path,
  ) async {
    final file = File(path);
    if (!await file.exists() || await file.length() > 1024 * 1024) return null;
    final process = await Process.start('/usr/bin/plutil', [
      '-convert',
      'json',
      '-o',
      '-',
      path,
    ]);
    try {
      final results = await Future.wait<Object?>([
        process.stdout.transform(utf8.decoder).join(),
        process.stderr.drain<void>(),
        process.exitCode,
      ]).timeout(const Duration(seconds: 3));
      if (results[2] != 0 || (results[0] as String).length > 4 * 1024 * 1024) {
        return null;
      }
      final value = jsonDecode(results[0] as String);
      return value is Map<String, dynamic> ? value : null;
    } on FormatException {
      return null;
    } finally {
      process.kill();
    }
  }
}
