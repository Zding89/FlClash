import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/cupertino.dart';

final class SourceDownloadException implements Exception {
  final String code;
  const SourceDownloadException(this.code);
  @override
  String toString() => code;
}

class Request {
  late final Dio dio;
  late final Dio _clashDio;
  String? userAgent;

  Request({Dio? profileClient}) {
    dio = Dio(BaseOptions(headers: {'User-Agent': browserUa}));
    _clashDio = profileClient ?? Dio();
    if (profileClient == null) {
      _clashDio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final client = HttpClient();
          client.findProxy = (Uri uri) {
            client.userAgent = globalState.ua;
            return FlClashHttpOverrides.handleFindProxy(uri);
          };
          return client;
        },
      );
    }
  }

  Future<Response<Uint8List>> getFileResponseForUrl(String url) async {
    try {
      return await _clashDio.get<Uint8List>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
    } catch (e) {
      commonPrint.log('getFileResponseForUrl error ${e.toString()}');
      if (e is DioException) {
        if (e.type == DioExceptionType.unknown) {
          throw currentAppLocalizations.unknownNetworkError;
        } else if (e.type == DioExceptionType.badResponse) {
          throw currentAppLocalizations.networkException;
        }
        rethrow;
      }
      throw currentAppLocalizations.unknownNetworkError;
    }
  }

  Future<Uint8List> getBoundedFile(
    String url, {
    int maximumBytes = 8 * 1024 * 1024,
    String? proxyDirective,
  }) async => (await getBoundedFileResponse(
    url,
    maximumBytes: maximumBytes,
    proxyDirective: proxyDirective,
  )).data!;

  Future<Response<Uint8List>> getBoundedFileResponse(
    String url, {
    int maximumBytes = 8 * 1024 * 1024,
    Duration timeout = const Duration(seconds: 15),
    String? proxyDirective,
  }) async {
    if (maximumBytes < 1 ||
        maximumBytes > 8 * 1024 * 1024 ||
        timeout <= Duration.zero ||
        timeout > const Duration(seconds: 15)) {
      throw const FormatException('Invalid source download limits');
    }
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !{'http', 'https'}.contains(uri.scheme) ||
        uri.host.isEmpty) {
      throw const FormatException('Invalid source URL');
    }
    if (proxyDirective != null &&
        proxyDirective != 'DIRECT' &&
        !RegExp(r'^PROXY 127\.0\.0\.1:[0-9]{1,5}$').hasMatch(proxyDirective)) {
      throw const FormatException('Invalid source update route');
    }
    final client = proxyDirective == null ? _clashDio : Dio();
    if (proxyDirective != null) {
      client.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () => HttpClient()
          ..badCertificateCallback = null
          ..userAgent = globalState.ua
          ..findProxy = (_) => proxyDirective,
      );
    }
    final token = CancelToken();
    final elapsed = Stopwatch()..start();
    Timer? deadline;
    StreamSubscription<Uint8List>? subscription;
    try {
      final response = await client
          .get<ResponseBody>(
            url,
            options: Options(responseType: ResponseType.stream),
            cancelToken: token,
          )
          .timeout(timeout);
      final body = response.data;
      if (body == null) throw const FormatException('Empty source response');
      final bytes = BytesBuilder(copy: false);
      final result = Completer<Uint8List>();
      void fail(Object error, [StackTrace? stack]) {
        if (result.isCompleted) return;
        result.completeError(error, stack);
        token.cancel('bounded source download stopped');
      }

      subscription = body.stream.listen(
        (chunk) {
          if (result.isCompleted) return;
          if (bytes.length + chunk.length > maximumBytes) {
            fail(const FormatException('Source response exceeds size limit'));
          } else {
            bytes.add(chunk);
          }
        },
        onError: fail,
        onDone: () {
          if (!result.isCompleted) result.complete(bytes.takeBytes());
        },
        cancelOnError: true,
      );
      final remaining = timeout - elapsed.elapsed;
      deadline = Timer(
        remaining <= Duration.zero ? Duration.zero : remaining,
        () => fail(TimeoutException('Source download timed out')),
      );
      return Response<Uint8List>(
        data: await result.future,
        requestOptions: response.requestOptions,
        headers: response.headers,
        statusCode: response.statusCode,
        statusMessage: response.statusMessage,
        isRedirect: response.isRedirect,
        redirects: response.redirects,
        extra: response.extra,
      );
    } on DioException {
      throw const SourceDownloadException('source_download_network_failed');
    } on SocketException {
      throw const SourceDownloadException('source_download_network_failed');
    } finally {
      deadline?.cancel();
      token.cancel();
      await subscription?.cancel();
      if (proxyDirective != null) client.close(force: true);
    }
  }

  Future<Response<String>> getTextResponseForUrl(String url) async {
    final response = await _clashDio.get<String>(
      url,
      options: Options(responseType: ResponseType.plain),
    );
    return response;
  }

  Future<MemoryImage?> getImage(String url) async {
    if (url.isEmpty) return null;
    final response = await dio.get<Uint8List>(
      url,
      options: Options(responseType: ResponseType.bytes),
    );
    final data = response.data;
    if (data == null) return null;
    return MemoryImage(data);
  }

  Future<Map<String, dynamic>?> checkForUpdate() async {
    try {
      final response = await dio.get(
        'https://api.github.com/repos/$repository/releases/latest',
        options: Options(responseType: ResponseType.json),
      );
      if (response.statusCode != 200) return null;
      final data = response.data as Map<String, dynamic>;
      final remoteVersion = data['tag_name'];
      final version = globalState.packageInfo.version;
      final hasUpdate =
          utils.compareVersions(remoteVersion.replaceAll('v', ''), version) > 0;
      if (!hasUpdate) return null;
      return data;
    } catch (e) {
      commonPrint.log('checkForUpdate failed', logLevel: LogLevel.warning);
      return null;
    }
  }

  final Map<String, IpInfo Function(Map<String, dynamic>)> _ipInfoSources = {
    'https://ipwho.is': IpInfo.fromIpWhoIsJson,
    'https://api.myip.com': IpInfo.fromMyIpJson,
    'https://ipapi.co/json': IpInfo.fromIpApiCoJson,
    'https://ident.me/json': IpInfo.fromIdentMeJson,
    'http://ip-api.com/json': IpInfo.fromIpAPIJson,
    'https://api.ip.sb/geoip': IpInfo.fromIpSbJson,
    'https://ipinfo.io/json': IpInfo.fromIpInfoIoJson,
  };

  Future<Result<IpInfo?>> checkIp({CancelToken? cancelToken}) async {
    var failureCount = 0;
    final token = cancelToken ?? CancelToken();
    final futures = _ipInfoSources.entries.map((source) async {
      final Completer<Result<IpInfo?>> completer = Completer();
      void handleFailRes() {
        if (!completer.isCompleted && failureCount == _ipInfoSources.length) {
          completer.complete(Result.success(null));
        }
      }

      final future = dio
          .get<Map<String, dynamic>>(
            source.key,
            cancelToken: token,
            options: Options(responseType: ResponseType.json),
          )
          .timeout(const Duration(seconds: 10));
      future
          .then((res) {
            if (res.statusCode == HttpStatus.ok && res.data != null) {
              completer.complete(Result.success(source.value(res.data!)));
              return;
            }
            commonPrint.log('checkIp data empty', logLevel: LogLevel.info);
            failureCount++;
            handleFailRes();
          })
          .catchError((e) {
            failureCount++;
            if (e is DioException && e.type == DioExceptionType.cancel) {
              completer.complete(Result.error('cancelled'));
              return;
            }
            commonPrint.log('checkIp error $e', logLevel: LogLevel.warning);
            handleFailRes();
          });
      return completer.future;
    });
    final res = await Future.any(futures);
    token.cancel();
    return res;
  }
}

final request = Request();
