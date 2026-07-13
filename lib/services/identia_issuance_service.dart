import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'secure_storage_service.dart';
import 'oid4vci_service.dart';

/// IDentia-specific credential issuance service.
///
/// Implements the custom Credo-style REST flow:
///   QR URL → POST /login → getHolderDid → POST /request-credential → validateCredential
class IdentiaIssuanceService {
  static const Duration _timeout = Duration(seconds: 30);

  // ─── URL Parsing ────────────────────────────────────────────────────────────

  /// Extract the `offerId` query parameter from the credential offer QR URL.
  /// e.g. https://issuer.identia.my.id/credential-offer?offerId=123 → "123"
  static String parseOfferId(String qrUrl) {
    final uri = Uri.tryParse(qrUrl);
    final offerId = uri?.queryParameters['offerId'];
    if (offerId == null || offerId.isEmpty) {
      throw Exception('offerId tidak ditemukan dalam URL: $qrUrl');
    }
    return offerId;
  }

  /// Extract the issuer base URL (scheme + host) from the credential offer QR URL.
  /// e.g. https://issuer.identia.my.id/credential-offer?offerId=123
  ///   → https://issuer.identia.my.id
  static String parseIssuerBaseUrl(String qrUrl) {
    final uri = Uri.tryParse(qrUrl);
    if (uri == null) throw Exception('URL tidak valid: $qrUrl');
    // Keep scheme + host + optional port
    final base =
        '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
    if (base == '://' || uri.host.isEmpty) {
      throw Exception('Tidak dapat mengurai issuerBaseUrl dari: $qrUrl');
    }
    return base;
  }

  // ─── Step 1: Login ──────────────────────────────────────────────────────────

  /// Authenticate with the issuer using username + password.
  ///
  /// Sends POST /login with body: {"username": ..., "password": ...}
  /// On success, stores the session token in secure storage and returns it.
  static Future<String> login(
    String issuerBaseUrl,
    String username,
    String password,
  ) async {
    final url = '${_stripTrailingSlash(issuerBaseUrl)}/login';
    debugPrint('[IDentia] POST $url (user: $username)');

    final responseBody = await _postJson(url, {
      'username': username,
      'password': password,
    });

    // The issuer may return the token under various keys
    final token = responseBody['token']?.toString() ??
        responseBody['access_token']?.toString() ??
        responseBody['sessionToken']?.toString();

    if (token == null || token.isEmpty) {
      final msg = responseBody['message']?.toString() ??
          responseBody['error']?.toString() ??
          'Token tidak ditemukan dalam response login';
      throw Exception(msg);
    }

    // Persist for potential later use (also available via loadAccessToken)
    await SecureStorageService.saveAccessToken(issuerBaseUrl, token);
    debugPrint('[IDentia] Login berhasil, token tersimpan');
    return token;
  }

  // ─── Step 2: Holder DID ─────────────────────────────────────────────────────

  /// Retrieve the holder DID.
  ///
  /// Reads from secure storage key "holder_did"; falls back to the default
  /// IDentia wallet DID if not configured.
  static Future<String> getHolderDid(String userId) async {
    final holderDid = await OID4VCIService.ensureHolderDid(userId: userId);
    debugPrint('[IDentia] Holder DID: $holderDid');
    return holderDid;
  }

  // ─── Step 3: Request Credential ─────────────────────────────────────────────

  /// Send POST /request-credential to the issuer.
  ///
  /// Uses Authorization: Bearer <token> header and body: {"holderDid": holderDid}
  /// Returns the raw JWT string of the issued Verifiable Credential.
  static Future<String> requestCredential({
    required String issuerBaseUrl,
    required String token,
    required String holderDid,
  }) async {
    final url = '${_stripTrailingSlash(issuerBaseUrl)}/request-credential';
    debugPrint('[IDentia] POST $url (holderDid: $holderDid)');

    final responseBody = await _postJson(
      url,
      {'holderDid': holderDid},
      bearerToken: token,
    );

    // Try common response shapes
    final rawJwt = responseBody['credential']?.toString() ??
        responseBody['vc']?.toString() ??
        responseBody['jwt']?.toString();

    if (rawJwt != null && rawJwt.isNotEmpty) {
      debugPrint('[IDentia] Credential JWT diterima (${rawJwt.length} chars)');
      return rawJwt;
    }

    // credentials array
    final credsList = responseBody['credentials'];
    if (credsList is List && credsList.isNotEmpty) {
      return credsList.first.toString();
    }

    throw Exception(
      'Credential tidak ditemukan dalam response. Keys: ${responseBody.keys.toList()}',
    );
  }

  // ─── Step 4: Validate Credential ────────────────────────────────────────────

  /// Perform basic validation on the received Verifiable Credential JWT.
  ///
  /// Checks:
  ///   1. Issuer DID (`iss`) is present and non-empty
  ///   2. `credentialSubject.id` matches the expected holder DID
  ///   3. Credential has not expired (`exp` claim)
  ///
  /// Throws [Exception] with a descriptive message if any check fails.
  static void validateCredential(String rawJwt, String holderDid) {
    debugPrint('[IDentia] Memvalidasi credential...');

    // Use the first segment (in case it is an SD-JWT with ~ separator)
    final jwtPart = rawJwt.split('~').first;
    final segments = jwtPart.split('.');
    if (segments.length < 2) {
      throw Exception('Format credential tidak valid (bukan JWT)');
    }

    Map<String, dynamic> payload;
    try {
      String b64 = segments[1].replaceAll('-', '+').replaceAll('_', '/');
      while (b64.length % 4 != 0) {
        b64 += '=';
      }
      final decoded = utf8.decode(base64.decode(b64));
      payload = jsonDecode(decoded) as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Gagal mendekode payload credential: $e');
    }

    // 1. Issuer DID must be exact match
    final iss = payload['iss']?.toString() ?? '';
    if (iss.isEmpty) {
      throw Exception('Credential tidak memiliki issuer DID (iss kosong)');
    }
    const expectedIss = 'did:web:issuer.identia.my.id';
    if (iss != expectedIss) {
      throw Exception(
          'Issuer DID tidak dikenali: $iss (diharapkan $expectedIss)');
    }
    debugPrint('[IDentia] Issuer DID: $iss');

    // 2. credentialSubject.id must match holderDid
    String? subjectId;
    final vc = payload['vc'];
    if (vc is Map) {
      final cs = vc['credentialSubject'];
      if (cs is Map) {
        subjectId = cs['id']?.toString();
      }
    }
    // Also check top-level sub claim
    subjectId ??= payload['sub']?.toString();

    if (subjectId != null && subjectId.isNotEmpty && subjectId != holderDid) {
      throw Exception(
        'credentialSubject.id ($subjectId) tidak sesuai dengan holder DID ($holderDid)',
      );
    }

    // 3. Expiry check
    final exp = payload['exp'];
    if (exp is int) {
      final expiryDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      if (DateTime.now().isAfter(expiryDate)) {
        throw Exception(
          'Credential sudah kedaluwarsa pada ${expiryDate.toLocal()}',
        );
      }
    }

    debugPrint('[IDentia] Credential valid ✓');
  }

  // ─── HTTP Helpers ───────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> _postJson(
    String url,
    Map<String, dynamic> data, {
    String? bearerToken,
  }) async {
    final client = HttpClient()
      ..badCertificateCallback = (cert, host, port) => true;

    try {
      final req = await client.postUrl(Uri.parse(url));
      req.headers.contentType = ContentType.json;
      req.headers.set('Accept', 'application/json');
      if (bearerToken != null) {
        req.headers.set('Authorization', 'Bearer $bearerToken');
      }
      final body = jsonEncode(data);
      req.contentLength = utf8.encode(body).length;
      req.write(body);

      final resp = await req.close().timeout(_timeout);
      final respBody = await resp.transform(utf8.decoder).join();

      debugPrint('[IDentia] POST $url → HTTP ${resp.statusCode}');

      if (resp.statusCode >= 400) {
        _throwHttpError(resp.statusCode, url, respBody);
      }

      try {
        return jsonDecode(respBody) as Map<String, dynamic>;
      } catch (_) {
        throw Exception(
          'Response bukan JSON dari $url: ${respBody.substring(0, respBody.length > 200 ? 200 : respBody.length)}',
        );
      }
    } finally {
      client.close();
    }
  }

  static void _throwHttpError(int statusCode, String url, String body) {
    String? jsonMsg;
    String? errorType;
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      jsonMsg = json['message']?.toString() ??
          json['error']?.toString() ??
          json['error_description']?.toString();
      errorType = json['error']?.toString();
    } catch (_) {}

    final host = Uri.tryParse(url)?.host ?? url;
    switch (statusCode) {
      case 400:
        if (errorType == 'invalid_request') {
          throw Exception(jsonMsg ??
              'Permintaan tidak valid (periksa validasi holderDid).');
        }
        throw Exception(jsonMsg ?? 'Permintaan tidak valid (400) ke $host');
      case 401:
        if (url.endsWith('/request-credential')) {
          throw Exception(
              'Sesi kadaluarsa atau token tidak valid. Silakan login ulang.');
        }
        throw Exception(jsonMsg ?? 'Username atau password salah (401)');
      case 403:
        throw Exception(jsonMsg ?? 'Akses ditolak (403)');
      case 404:
        throw Exception('Endpoint tidak ditemukan (404): $url');
      case 410:
        throw Exception('Offer expired/used, minta scan QR baru.');
      default:
        throw Exception(
          jsonMsg ??
              'HTTP $statusCode dari $host\n${body.substring(0, body.length > 150 ? 150 : body.length)}',
        );
    }
  }

  static String _stripTrailingSlash(String url) =>
      url.endsWith('/') ? url.substring(0, url.length - 1) : url;
}

// ─── Data structures ────────────────────────────────────────────────────────

/// Progress steps for the IDentia issuance flow.
enum IdentiaIssuanceStep {
  gettingHolderDid,
  requestingCredential,
  receivingCredential,
  validatingCredential,
  saving,
  done,
  error,
}

/// Result object returned after a successful IDentia issuance.
class IdentiaIssuanceResult {
  final String rawJwt;
  final String issuerBaseUrl;
  final String holderDid;

  IdentiaIssuanceResult({
    required this.rawJwt,
    required this.issuerBaseUrl,
    required this.holderDid,
  });
}
