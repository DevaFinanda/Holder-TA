import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

class CredentialStatusResult {
  final String status;
  final bool active;
  final DateTime checkedAt;

  CredentialStatusResult({
    required this.status,
    required this.active,
    required this.checkedAt,
  });
}

class CredentialStatusService {
  static const Duration _timeout = Duration(seconds: 20);

  static Future<CredentialStatusResult> fetchStatus(String statusUrl) async {
    final client = HttpClient()
      ..badCertificateCallback = (cert, host, port) => true;

    try {
      final req = await client.getUrl(Uri.parse(statusUrl));
      req.headers.set('Accept', 'application/json');

      final resp = await req.close().timeout(_timeout);
      final body = await resp.transform(utf8.decoder).join();

      debugPrint(
          '[CredentialStatus] GET $statusUrl -> HTTP ${resp.statusCode}');

      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw Exception('HTTP ${resp.statusCode} saat cek status credential');
      }

      final json = jsonDecode(body) as Map<String, dynamic>;
      final rawStatus = json['status']?.toString() ?? 'UNKNOWN';
      final normalizedStatus = _normalizeStatus(rawStatus);

      final activeFromServer = json['active'];
      final active = activeFromServer is bool
          ? activeFromServer
          : normalizedStatus == 'ACTIVE';

      return CredentialStatusResult(
        status: normalizedStatus,
        active: active,
        checkedAt: DateTime.now(),
      );
    } finally {
      client.close();
    }
  }

  static String _normalizeStatus(String raw) {
    final value = raw.trim().toUpperCase();
    switch (value) {
      case 'ACTIVE':
      case 'REVOKED':
      case 'SUSPENDED':
      case 'EXPIRED':
        return value;
      default:
        return 'UNKNOWN';
    }
  }
}
