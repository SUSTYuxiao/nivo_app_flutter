import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'api_service.dart';

class OssService {
  final ApiService _apiService;

  OssService({required ApiService apiService}) : _apiService = apiService;

  /// Upload a local audio file to Alibaba OSS via STS credentials.
  /// Returns the OSS object key (e.g. "audio/1713456789_file.wav").
  Future<String> uploadAudio(
    String localPath, {
    void Function(double progress)? onProgress,
  }) async {
    final sts = await _apiService.getStsToken();
    debugPrint('[OssService] STS keys: ${sts.keys.toList()}');

    // Handle both camelCase and PascalCase keys
    final region = (sts['region'] ?? sts['Region']) as String;
    final bucket = (sts['bucket'] ?? sts['Bucket']) as String;
    final accessKeyId = (sts['accessKeyId'] ?? sts['AccessKeyId']) as String;
    final accessKeySecret = (sts['accessKeySecret'] ?? sts['AccessKeySecret']) as String;
    final securityToken = (sts['securityToken'] ?? sts['SecurityToken']) as String;

    final fileName = p.basename(localPath);
    final objectKey = 'audio/${DateTime.now().millisecondsSinceEpoch}_$fileName';
    debugPrint('[OssService] uploading to $objectKey, region=$region, bucket=$bucket');

    final file = File(localPath);
    final fileLength = await file.length();

    final host = '$bucket.$region.aliyuncs.com';
    final date = HttpDate.format(DateTime.now().toUtc());
    final contentType = 'application/octet-stream';

    // Build signature: PUT\n\nContent-Type\nDate\nx-oss-security-token:token\n/bucket/key
    final canonicalResource = '/$bucket/$objectKey';
    final stringToSign =
        'PUT\n\n$contentType\n$date\nx-oss-security-token:$securityToken\n$canonicalResource';
    final signature = base64Encode(
      Hmac(sha1, utf8.encode(accessKeySecret))
          .convert(utf8.encode(stringToSign))
          .bytes,
    );

    final dio = Dio();
    await dio.put(
      'https://$host/$objectKey',
      data: file.openRead(),
      options: Options(
        headers: {
          'Content-Type': contentType,
          'Content-Length': fileLength,
          'Date': date,
          'Authorization': 'OSS $accessKeyId:$signature',
          'x-oss-security-token': securityToken,
        },
      ),
      onSendProgress: (sent, total) {
        if (total > 0) onProgress?.call(sent / total);
      },
    );

    debugPrint('[OssService] upload done: $objectKey');
    return objectKey;
  }
}
