import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

class OID4VPStartResult {
  final String requestUri;
  final String? deepLink;

  OID4VPStartResult({
    required this.requestUri,
    required this.deepLink,
  });

  String get launchUrl =>
      (deepLink?.trim().isNotEmpty ?? false) ? deepLink!.trim() : requestUri;
}

class OID4VPStartService {
  static const Duration _timeout = Duration(seconds: 30);

  static Future<OID4VPStartResult> startVerification({
    required String backendBaseUrl,
  }) async {
    final base = _normalizeBaseUrl(backendBaseUrl);
    final endpoint = '$base/api/verify/start';

    debugPrint('================= OUTGOING REQUEST =================');
    debugPrint('[OID4VP_VERIFY_START] POST $endpoint');
    debugPrint('====================================================');

    final client = HttpClient()..connectionTimeout = _timeout;
    try {
      final req = await client.postUrl(Uri.parse(endpoint));
      req.headers.contentType = ContentType.json;
      req.headers.set('Accept', 'application/json');
      req.write(jsonEncode(<String, dynamic>{}));

      final resp = await req.close().timeout(_timeout);
      final body = await resp.transform(utf8.decoder).join();

      debugPrint('================= RESPONSE GET =================');
      debugPrint('[OID4VP_VERIFY_START] HTTP ${resp.statusCode}');
      debugPrint('[OID4VP_VERIFY_START] BODY: ${_truncate(body)}');
      debugPrint('================================================');

      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw Exception(
            'verify_start_failed: HTTP ${resp.statusCode} | body=${_truncate(body)}');
      }

      final json = jsonDecode(body) as Map<String, dynamic>;
      final requestUri =
          (json['requestUri'] ?? json['request_uri'] ?? '').toString().trim();
      final deepLinkRaw =
          (json['deepLink'] ?? json['deep_link'] ?? '').toString().trim();
      final deepLink = deepLinkRaw.isEmpty ? null : deepLinkRaw;

      if (requestUri.isEmpty && deepLink == null) {
        throw Exception(
            'verify_start_invalid_response: requestUri/deepLink tidak ditemukan');
      }

      final normalizedRequestUri = requestUri.isNotEmpty
          ? requestUri
          : _extractRequestUriFromDeepLink(deepLink!);
      if (normalizedRequestUri.isEmpty) {
        throw Exception(
            'verify_start_invalid_response: requestUri kosong dan tidak dapat diekstrak dari deepLink');
      }

      // STRICT PROTOCOL VALIDATION:
      if (normalizedRequestUri.contains('/authorize')) {
        debugPrint('⚠️ WARNING: LEGACY ENDPOINT DETECTED IN requestUri: $normalizedRequestUri');
      }

      return OID4VPStartResult(
        requestUri: normalizedRequestUri,
        deepLink: deepLink,
      );
    } on SocketException catch (e) {
      throw Exception('verify_start_network_error: ${e.message}');
    } on HandshakeException {
      throw Exception(
          'verify_start_tls_error: gagal TLS/sertifikat saat ke backend verifier');
    } finally {
      client.close(force: true);
    }
  }

  static Future<bool> launchRequestLink(OID4VPStartResult result) async {
    final target = result.launchUrl;
    final uri = Uri.parse(target);

    final mode = _resolveLaunchMode(uri);
    debugPrint('[OID4VPStart] Launching URL: $target mode=$mode');

    return launchUrl(uri, mode: mode);
  }

  static String _normalizeBaseUrl(String value) {
    var base = value.trim();
    if (base.isEmpty) {
      throw Exception('backend_base_url_required');
    }

    if (!base.startsWith('http://') && !base.startsWith('https://')) {
      base = 'https://$base';
    }

    if (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }

    final uri = Uri.tryParse(base);
    if (uri == null ||
        uri.host.isEmpty ||
        (uri.scheme != 'https' && uri.scheme != 'http')) {
      throw Exception('backend_base_url_invalid: $value');
    }

    return base;
  }

  static String _extractRequestUriFromDeepLink(String deepLink) {
    final uri = Uri.tryParse(deepLink);
    if (uri == null) return '';
    final requestUri = uri.queryParameters['request_uri']?.trim() ?? '';
    return requestUri;
  }

  static LaunchMode _resolveLaunchMode(Uri uri) {
    if (uri.scheme == 'openid4vp' ||
        uri.scheme == 'openid-vc' ||
        uri.scheme == 'haip' ||
        uri.scheme == 'mdoc-openid4vp') {
      return LaunchMode.externalNonBrowserApplication;
    }
    return LaunchMode.externalApplication;
  }

  static String _truncate(String input, {int max = 300}) {
    if (input.length <= max) return input;
    return '${input.substring(0, max)}...';
  }
}
