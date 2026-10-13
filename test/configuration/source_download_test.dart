import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fl_clash/common/request.dart';
import 'package:flutter_test/flutter_test.dart';

class _FailureAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    throw DioException.connectionError(
      requestOptions: options,
      reason: 'fixture failure with private-token',
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test(
    'subscription network errors expose no URL, token or credentials',
    () async {
      final dio = Dio()..httpClientAdapter = _FailureAdapter();
      final client = Request(profileClient: dio);
      await expectLater(
        client.getBoundedFileResponse(
          'https://example.invalid/private/path?token=private-token',
        ),
        throwsA(
          isA<SourceDownloadException>().having(
            (error) => error.toString(),
            'safe error',
            'source_download_network_failed',
          ),
        ),
      );
      dio.close(force: true);
    },
  );
}
