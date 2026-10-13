import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:fl_clash/common/path.dart';
import 'package:fl_clash/common/request.dart';
import 'package:fl_clash/database/workbench_database.dart';
import 'package:fl_clash/models/profile.dart';
import 'package:path/path.dart' as paths;
import 'package:yaml/yaml.dart';

import 'compiler.dart';
import 'models.dart';

typedef PolicyReadFile = Future<String?> Function(String path);
typedef PolicyFetchFile = Future<String> Function(String url);
typedef PolicyWriteFile = Future<void> Function(String path, String content);
typedef PolicyCommitFile =
    Future<void> Function(
      String path,
      String content, {
      bool Function()? isCurrent,
    });

Object? normalizePolicyYaml(Object? value) {
  if (value is Map) {
    return value.map(
      (key, item) => MapEntry(key.toString(), normalizePolicyYaml(item)),
    );
  }
  if (value is List) return value.map(normalizePolicyYaml).toList();
  if (value == null || value is String || value is num || value is bool) {
    return value;
  }
  throw const FormatException('Unsupported YAML value');
}

final class PolicySourceLoader {
  final PolicyReadFile readFile;
  final PolicyFetchFile fetchFile;
  final PolicyWriteFile writeFile;
  final PolicyCommitFile commitFile;
  final Future<String> Function(int profileId) profilePath;
  final Future<String> Function(int profileId, String url) providerCachePath;
  final Future<String> Function() homePath;
  final WorkbenchDatabase store;

  PolicySourceLoader({
    required this.store,
    PolicyReadFile? readFile,
    PolicyFetchFile? fetchFile,
    PolicyWriteFile? writeFile,
    PolicyCommitFile? commitFile,
    Future<String> Function(int)? profilePath,
    Future<String> Function(int, String)? providerCachePath,
    Future<String> Function()? homePath,
  }) : readFile = readFile ?? _readFile,
       fetchFile = fetchFile ?? _fetchFile,
       writeFile = writeFile ?? _writeFile,
       commitFile =
           commitFile ??
           (writeFile == null
               ? _writeFileGuarded
               : (path, content, {isCurrent}) async {
                   _checkCurrent(isCurrent);
                   await writeFile(path, content);
                 }),
       profilePath = profilePath ?? ((id) => appPath.getProfilePath('$id')),
       providerCachePath =
           providerCachePath ??
           ((id, url) => appPath.getProvidersFilePath('$id', 'proxies', url)),
       homePath = homePath ?? (() => appPath.homeDirPath);

  static Future<String?> _readFile(String path) async {
    final file = File(path);
    if (!await file.exists()) return null;
    if (await file.length() > 8 * 1024 * 1024) {
      throw const FormatException('Source file exceeds 8 MiB');
    }
    return file.readAsString();
  }

  static Future<void> _writeFile(String path, String content) async {
    await _writeFileGuarded(path, content);
  }

  static void _checkCurrent(bool Function()? isCurrent) {
    if (isCurrent?.call() == false) {
      throw StateError('profile_update_superseded');
    }
  }

  static Future<void> _writeFileGuarded(
    String path,
    String content, {
    bool Function()? isCurrent,
  }) async {
    _checkCurrent(isCurrent);
    final file = File(path);
    await file.parent.create(recursive: true);
    final random = Random.secure();
    final id = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final staging = File('$path.$id.policy-pending');
    try {
      await staging.writeAsString(content, flush: true);
      _checkCurrent(isCurrent);
      staging.renameSync(path);
    } finally {
      if (await staging.exists()) await staging.delete();
    }
  }

  Future<String> fingerprint(Profile profile) async {
    final content = await readFile(await profilePath(profile.id));
    if (content == null) {
      return policyDigest(await store.readSourceCache(profile.id));
    }
    try {
      final raw = policyObject(
        normalizePolicyYaml(loadYaml(content)),
        'source',
      );
      return policyDigest(
        await _resolveProviders(profile, raw, allowNetwork: false),
      );
    } catch (_) {
      return policyDigest({
        'raw': content,
        'snapshot': await store.readSourceCache(profile.id),
      });
    }
  }

  Future<Map<String, String>> fileProviderDependencies(
    Map<String, Object?> raw,
  ) async {
    final dependencies = <String, String>{};
    final providers = policyObject(raw['proxy-providers'] ?? {}, 'providers');
    if (providers.length > 50) {
      throw const FormatException('Provider dependency limit exceeded');
    }
    for (final value in providers.values) {
      final provider = policyObject(value, 'provider');
      if (provider['type'] != 'file') continue;
      final path = provider['path'];
      if (path is! String || path.isEmpty) {
        throw const FormatException('File provider requires a path');
      }
      final home = await homePath();
      final resolved = paths.normalize(
        paths.isAbsolute(path) ? path : paths.join(home, path),
      );
      if (!paths.isWithin(home, resolved)) {
        throw const FormatException(
          'Provider file is outside application data',
        );
      }
      final file = File(resolved);
      if (await file.exists() &&
          !paths.isWithin(
            await Directory(home).resolveSymbolicLinks(),
            await file.resolveSymbolicLinks(),
          )) {
        throw const FormatException(
          'Provider file is outside application data',
        );
      }
      dependencies[resolved] = policyDigest(await readFile(resolved));
    }
    return dependencies;
  }

  static Future<String> _fetchFile(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !{'http', 'https'}.contains(uri.scheme) ||
        uri.host.isEmpty) {
      throw const FormatException('Invalid provider URL');
    }
    final bytes = await request.getBoundedFile(url);
    return utf8.decode(bytes);
  }

  Future<List<PolicySource>> load(
    List<Profile> profiles, {
    bool allowNetwork = false,
    bool persistCache = false,
    bool Function()? isCurrent,
  }) async {
    if (profiles.length > 20) {
      throw const FormatException(
        'At most 20 subscription sources are supported',
      );
    }
    final sources = <PolicySource>[];
    for (final profile in profiles) {
      try {
        _checkCurrent(isCurrent);
        final content = await readFile(await profilePath(profile.id));
        if (content == null) {
          final cached = await store.readSourceCache(profile.id);
          if (cached == null) {
            throw FormatException(
              'Source profile ${profile.id} has no valid snapshot',
            );
          }
          sources.add(
            await _source(profile, cached, warning: 'cached_snapshot'),
          );
          continue;
        }
        final raw = policyObject(
          normalizePolicyYaml(loadYaml(content)),
          'source',
        );
        if (raw.containsKey('flclash-local-policy')) {
          throw const FormatException(
            'Integrations cannot recursively import managed policy configurations',
          );
        }
        final resolved = await _resolveProviders(
          profile,
          raw,
          allowNetwork: allowNetwork,
          isCurrent: isCurrent,
        );
        _checkCurrent(isCurrent);
        sources.add(await _source(profile, resolved));
        if (persistCache) await store.saveSourceCache(profile.id, resolved);
      } catch (error) {
        _checkCurrent(isCurrent);
        if (error is PolicySourceException) rethrow;
        final cached = await store.readSourceCache(profile.id);
        if (cached == null) rethrow;
        sources.add(await _source(profile, cached, warning: 'cached_snapshot'));
      }
    }
    return sources;
  }

  Future<PolicySource> metadataSource(Profile profile) =>
      _source(profile, const {});

  Future<PolicySource> _source(
    Profile profile,
    Map<String, Object?> raw, {
    String? warning,
  }) =>
      store.transaction(() => _metadataSource(profile, raw, warning: warning));

  Future<PolicySource> _metadataSource(
    Profile profile,
    Map<String, Object?> raw, {
    String? warning,
  }) async {
    final info = profile.subscriptionInfo;
    final remainingKnown =
        info != null &&
        info.knownFields.containsAll({'total', 'upload', 'download'}) &&
        info.total > 0;
    final remaining = remainingKnown
        ? info.total - info.upload - info.download
        : null;
    final section = 'sourceMetadata:${profile.id}';
    final metadata = Map<String, Object?>.from(
      await store.readSection(section) ?? const {},
    );
    final previousDigest = policyDigest(metadata);
    final expireStamp =
        info?.expireObservedAt?.millisecondsSinceEpoch ??
        info?.observedAt?.millisecondsSinceEpoch;
    final remainingStamp =
        info?.remainingObservedAt?.millisecondsSinceEpoch ??
        info?.observedAt?.millisecondsSinceEpoch;
    if (info != null &&
        info.expire > 0 &&
        (info.knownFields.contains('expire') ||
            metadata['expiresAt'] == null)) {
      if (expireStamp != null &&
          (metadata['expiresObservedAt'] is! int ||
              expireStamp >= (metadata['expiresObservedAt'] as int))) {
        metadata['expiresAt'] = info.expire * 1000;
        metadata['expiresObservedAt'] = expireStamp;
      }
    }
    if (remainingKnown &&
        remainingStamp != null &&
        (metadata['remainingObservedAt'] is! int ||
            remainingStamp >= (metadata['remainingObservedAt'] as int))) {
      metadata['remainingBytes'] = remaining!.clamp(0, 9007199254740991);
      metadata['remainingObservedAt'] = remainingStamp;
    }
    if (info?.exhausted == true &&
        (metadata['remainingObservedAt'] is! int ||
            remainingStamp != null &&
                remainingStamp >= (metadata['remainingObservedAt'] as int))) {
      metadata['remainingBytes'] = 0;
      if (remainingStamp != null) {
        metadata['remainingObservedAt'] = remainingStamp;
      }
    }
    if (metadata.isNotEmpty && policyDigest(metadata) != previousDigest) {
      await store.writeSection(section, metadata);
    }
    final expires = metadata['expiresAt'] is int
        ? metadata['expiresAt'] as int
        : info != null && info.expire > 0
        ? info.expire * 1000
        : null;
    final currentRemaining = remainingKnown
        ? remainingStamp != null &&
                  metadata['remainingObservedAt'] is int &&
                  (metadata['remainingObservedAt'] as int) >= remainingStamp &&
                  metadata['remainingBytes'] is int
              ? metadata['remainingBytes'] as int
              : remaining?.clamp(0, 9007199254740991)
        : null;
    final retainedExhaustion = metadata['remainingBytes'] == 0;
    final stamps = [
      if (metadata['expiresObservedAt'] is int)
        metadata['expiresObservedAt'] as int,
      if (metadata['remainingObservedAt'] is int)
        metadata['remainingObservedAt'] as int,
    ]..sort();
    return PolicySource(
      id: '${profile.id}',
      label: profile.realLabel,
      raw: raw,
      expiresAt: expires,
      remainingBytes: retainedExhaustion ? 0 : currentRemaining,
      observedAt:
          stamps.firstOrNull ?? info?.observedAt?.millisecondsSinceEpoch,
      warning: warning,
    );
  }

  Future<Map<String, Object?>> _resolveProviders(
    Profile profile,
    Map<String, Object?> raw, {
    required bool allowNetwork,
    bool Function()? isCurrent,
  }) async {
    final result = policyObject(jsonDecode(jsonEncode(raw)), 'source');
    final proxies = List<Object?>.from(result['proxies'] as List? ?? []);
    result['flclash-inline-node-ids'] = const LocalPolicyCompiler()
        .extractNodes(
          PolicySource(
            id: '${profile.id}',
            label: profile.realLabel,
            raw: {'proxies': proxies},
          ),
        )
        .map((node) => node.id)
        .toList();
    final providersValue = result['proxy-providers'];
    if (providersValue == null) return result;
    final providers = policyObject(providersValue, 'proxy-providers');
    if (providers.length > 50) {
      throw const FormatException(
        'At most 50 providers per source are supported',
      );
    }
    final members = <String, List<String>>{};
    for (final entry in providers.entries) {
      final provider = policyObject(entry.value, 'provider');
      for (final option in [
        'filter',
        'exclude-filter',
        'exclude-type',
        'override',
        'dialer-proxy',
      ]) {
        final value = provider[option];
        if (value != null &&
            value != '' &&
            !(value is Map && value.isEmpty) &&
            !(value is List && value.isEmpty)) {
          throw PolicySourceException(option);
        }
      }
      final type = provider['type'];
      List<Object?> providerProxies;
      if (type == 'inline') {
        final payload = provider['payload'];
        if (payload is! List) {
          throw const FormatException('Inline provider requires a payload');
        }
        providerProxies = List<Object?>.from(payload);
      } else {
        String? content;
        if (type == 'http') {
          final url = provider['url'];
          if (url is! String) {
            throw const FormatException('HTTP provider requires a URL');
          }
          final cachePath = await providerCachePath(profile.id, url);
          content = await readFile(cachePath);
          if (allowNetwork) {
            _checkCurrent(isCurrent);
            final refreshed = await fetchFile(url);
            _checkCurrent(isCurrent);
            final payload = policyObject(
              normalizePolicyYaml(loadYaml(refreshed)),
              'providerPayload',
            );
            if (payload['proxies'] is! List) {
              throw const FormatException('Provider payload requires proxies');
            }
            await commitFile(cachePath, refreshed, isCurrent: isCurrent);
            content = refreshed;
          }
        } else if (type == 'file') {
          final path = provider['path'];
          if (path is! String || path.isEmpty) {
            throw const FormatException('File provider requires a path');
          }
          final home = await homePath();
          final resolved = paths.normalize(
            paths.isAbsolute(path) ? path : paths.join(home, path),
          );
          if (!paths.isWithin(home, resolved)) {
            throw const FormatException(
              'Provider file must be within FlClash application data',
            );
          }
          final file = File(resolved);
          if (await file.exists() &&
              !paths.isWithin(
                await Directory(home).resolveSymbolicLinks(),
                await file.resolveSymbolicLinks(),
              )) {
            throw const FormatException(
              'Provider file resolves outside application data',
            );
          }
          content = await readFile(resolved);
        } else {
          throw const FormatException('Unsupported proxy provider type');
        }
        if (content == null) {
          throw FormatException(
            'Provider ${entry.key} has no cached nodes; update this source first',
          );
        }
        final parsed = policyObject(
          normalizePolicyYaml(loadYaml(content)),
          'providerPayload',
        );
        if (parsed['proxies'] is! List) {
          throw const FormatException('Provider payload requires proxies');
        }
        providerProxies = List<Object?>.from(parsed['proxies'] as List);
      }
      final names = <String>[];
      for (final value in providerProxies) {
        final proxy = policyObject(value, 'providerProxy');
        final name = proxy['name'];
        if (name is! String) {
          throw const FormatException('Provider proxy requires a name');
        }
        names.add(name);
        proxies.add(proxy);
      }
      members[entry.key] = names;
      if (proxies.length > 5000) {
        throw const FormatException('Source node count exceeds 5000');
      }
    }
    result['proxies'] = proxies;
    result['flclash-provider-members'] = members;
    return result;
  }
}
