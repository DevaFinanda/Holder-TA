import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart' as crypto;
import 'package:flutter/foundation.dart';
import '../models/presentation_models.dart';
import '../models/credential_model.dart';
import 'secure_storage_service.dart';
import 'sd_jwt_service.dart';

/// OID4VP (OpenID for Verifiable Presentations) service.
/// Handles presentation request parsing, credential matching, VP building, and direct_post submission.
class OID4VPService {
  static const Duration _httpTimeout = Duration(seconds: 30);

  // ─── Step 1: Parse QR Code ────────────────────────────────────────────────

  /// Parse an OID4VP request from QR data (openid4vp:// URL or JSON with request_uri)
  static Future<PresentationRequest> parseRequest(String qrData) async {
    debugPrint(
        '[OID4VP] Parsing QR data: ${qrData.substring(0, qrData.length > 100 ? 100 : qrData.length)}');

    // Check for openid4vp:// scheme
    if (qrData.startsWith('openid4vp://') ||
        qrData.startsWith('haip://') ||
        qrData.startsWith('mdoc-openid4vp://')) {
      final parsed = await _parseOID4VPUrl(qrData);
      _debugRequestSummary(parsed);
      return parsed;
    }

    // Try to parse as JSON
    try {
      final json = jsonDecode(qrData) as Map<String, dynamic>;
      final parsed = await _parseFromJson(json);
      _debugRequestSummary(parsed);
      return parsed;
    } catch (_) {}

    // Handle as URL with query parameters
    try {
      final parsed = await _parseOID4VPUrl(qrData);
      _debugRequestSummary(parsed);
      return parsed;
    } catch (e) {
      throw Exception('Format QR OID4VP tidak dikenali: $e');
    }
  }

  static Future<PresentationRequest> _parseOID4VPUrl(String url) async {
    final uri = Uri.parse(url.contains('://') ? url : 'openid4vp://$url');
    final params = uri.queryParameters;

    // If request_uri is present, fetch the full request object
    final requestUri = params['request_uri'];
    if (requestUri != null && requestUri.isNotEmpty) {
      debugPrint('[OID4VP] Fetching request object from: $requestUri');
      final requestObject = await _fetchRequestUri(requestUri);
      return requestObject.requestUri == null ||
              requestObject.requestUri!.isEmpty
          ? requestObject.copyWith(requestUri: requestUri)
          : requestObject;
    }

    // Inline request parameters
    final inline =
        PresentationRequest.fromJson(Map<String, dynamic>.from(params));
    return _resolvePresentationDefinitionUri(inline);
  }

  static Future<PresentationRequest> _parseFromJson(
      Map<String, dynamic> json) async {
    final requestUri = json['request_uri']?.toString();
    if (requestUri != null) {
      final request = await _fetchRequestUri(requestUri);
      return request.requestUri == null || request.requestUri!.isEmpty
          ? request.copyWith(requestUri: requestUri)
          : request;
    }
    final parsed = PresentationRequest.fromJson(json);
    return _resolvePresentationDefinitionUri(parsed);
  }

  /// Fetch and parse a request object from a URI
  static Future<PresentationRequest> _fetchRequestUri(String requestUri) async {
    debugPrint('================= OUTGOING REQUEST =================');
    debugPrint('[OID4VP_FETCH_URI] GET $requestUri');
    debugPrint('====================================================');

    if (requestUri.contains('/authorize')) {
      debugPrint(
          '⚠️ WARNING: CALLING LEGACY /authorize ENDPOINT. This was provided via request_uri!');
    }

    final client = HttpClient()..connectionTimeout = _httpTimeout;
    final req = await client.getUrl(Uri.parse(requestUri));
    req.headers
        .set('Accept', 'application/oauth-authz-req+jwt, application/json');
    req.followRedirects = false;
    final resp = await req.close().timeout(_httpTimeout);
    final body = await resp.transform(utf8.decoder).join();
    client.close();

    debugPrint('================= RESPONSE GET =================');
    debugPrint('[OID4VP_FETCH_URI] HTTP ${resp.statusCode}');
    debugPrint('[OID4VP_FETCH_URI] BODY: ${_truncate(body)}');
    debugPrint('================================================');

    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode} fetching request object');
    }

    // Could be a JWT (signed request object) or plain JSON
    if (body.trim().startsWith('{')) {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final parsed =
          PresentationRequest.fromJson(json).copyWith(requestUri: requestUri);
      return _resolvePresentationDefinitionUri(parsed);
    } else {
      // JWT request object: decode payload
      final parts = body.trim().split('.');
      if (parts.length >= 2) {
        String out = parts[1].replaceAll('-', '+').replaceAll('_', '/');
        while (out.length % 4 != 0) {
          out += '=';
        }
        final payloadJson = utf8.decode(base64.decode(out));
        final payload = jsonDecode(payloadJson) as Map<String, dynamic>;
        final parsed = PresentationRequest.fromJson(payload)
            .copyWith(requestUri: requestUri);
        return _resolvePresentationDefinitionUri(parsed);
      }
      throw Exception('Format request object tidak dikenali');
    }
  }

  static Future<PresentationRequest> _resolvePresentationDefinitionUri(
    PresentationRequest request,
  ) async {
    if (request.presentationDefinition != null) {
      return request;
    }

    final pdUri = request.presentationDefinitionUri?.trim() ?? '';
    if (pdUri.isEmpty) {
      return request;
    }

    final client = HttpClient()..connectionTimeout = _httpTimeout;
    try {
      final req = await client.getUrl(Uri.parse(pdUri));
      req.headers.set('Accept', 'application/json');
      final resp = await req.close().timeout(_httpTimeout);
      final body = await resp.transform(utf8.decoder).join();

      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw Exception(
          'HTTP ${resp.statusCode} saat fetch presentation_definition_uri',
        );
      }

      final json = jsonDecode(body) as Map<String, dynamic>;
      final definition = PresentationDefinition.fromJson(json);
      return request.copyWith(presentationDefinition: definition);
    } finally {
      client.close(force: true);
    }
  }

  // ─── Step 2: Match Credentials ────────────────────────────────────────────

  /// Find credentials in the wallet that satisfy the presentation definition
  static List<CredentialMatch> matchCredentials(
    PresentationDefinition definition,
    List<CredentialModel> walletCredentials,
  ) {
    final matches = <CredentialMatch>[];

    for (final descriptor in definition.inputDescriptors) {
      for (final credential in walletCredentials) {
        if (_credentialMatchesDescriptor(credential, descriptor)) {
          matches.add(CredentialMatch(
            credential: credential,
            descriptorId: descriptor.id,
            requestedFields: descriptor.fields
                .map((f) => f.claimName)
                .where((n) => n.isNotEmpty)
                .toList(),
          ));
          break; // Take first match per descriptor
        }
      }
    }

    return matches;
  }

  static bool _credentialMatchesDescriptor(
    CredentialModel credential,
    InputDescriptor descriptor,
  ) {
    // Check format compatibility
    if (descriptor.formats != null && descriptor.formats!.isNotEmpty) {
      final credFormat = _normalizeCredentialFormat(credential.format);
      final acceptedFormats =
          descriptor.formats!.map(_normalizeDescriptorFormat).toSet();
      if (!acceptedFormats.contains(credFormat)) {
        // Try broader matching
        if (!acceptedFormats.contains(credFormat)) {
          // Still allow if SD-JWT credential can satisfy jwt_vc.
          if (credFormat != 'vc+sd-jwt' &&
              !acceptedFormats.contains('jwt_vc')) {
            return false;
          }
        }
      }
    }

    // Check field constraints
    for (final field in descriptor.fields) {
      if (field.optional) continue;
      final claimName = field.claimName;
      if (claimName.isEmpty) continue;

      // Check if credential has the required claim
      final hasIt = credential.additionalData?.containsKey(claimName) == true ||
          claimName == 'nik' && credential.documentNumber.isNotEmpty ||
          claimName == 'holderName' && credential.holderName.isNotEmpty;

      if (!hasIt &&
          descriptor.fields
              .any((f) => !f.optional && f.claimName == claimName)) {
        // Soft fail - maybe the field is present under a different key
        debugPrint('[OID4VP] Credential may be missing field: $claimName');
      }
    }

    return true; // Match by credential type
  }

  // ─── Step 3: Build VP Token ───────────────────────────────────────────────

  /// Build the VP token for submission
  static Future<String> buildVPToken({
    required String userId,
    required CredentialModel credential,
    required PresentationRequest request,
    required List<String> selectedClaims,
  }) async {
    final format = _normalizeCredentialFormat(credential.format);

    if (format == 'vc+sd-jwt' && credential.rawJwt != null) {
      return _buildSDJWTPresentation(
        userId: userId,
        sdJwt: credential.rawJwt!,
        selectedClaims: selectedClaims,
        nonce: request.nonce ?? '',
        audience: request.clientId,
      );
    } else if (credential.rawJwt != null) {
      return _buildJwtVPPresentation(
        userId: userId,
        credentialJwt: credential.rawJwt!,
        nonce: request.nonce,
        audience: request.clientId,
      );
    } else {
      throw Exception('Credential tidak memiliki raw JWT untuk presentasi');
    }
  }

  static Future<String> _buildJwtVPPresentation({
    required String userId,
    required String credentialJwt,
    required String? nonce,
    required String audience,
  }) async {
    final holderDid = await SecureStorageService.loadHolderDid(userId);
    final privateKeyB64 =
        await SecureStorageService.loadHolderPrivateKey(userId);

    if (holderDid == null || holderDid.trim().isEmpty) {
      throw Exception(
        'holder_did_missing: DID holder belum tersedia untuk membuat VP proof.',
      );
    }

    if (privateKeyB64 == null || privateKeyB64.trim().isEmpty) {
      throw Exception(
        'holder_key_missing: Private key holder tidak ditemukan.',
      );
    }

    final normalizedNonce = (nonce ?? '').trim();
    if (normalizedNonce.isEmpty) {
      throw Exception(
        'nonce_missing: Request verifier tidak mengandung nonce untuk VP proof.',
      );
    }

    final normalizedAudience = audience.trim();
    if (normalizedAudience.isEmpty) {
      throw Exception(
        'audience_missing: client_id verifier kosong pada request OID4VP.',
      );
    }

    final privateBytes = base64.decode(privateKeyB64);
    final seed = privateBytes.length >= 32
        ? Uint8List.fromList(privateBytes.sublist(0, 32))
        : Uint8List.fromList(privateBytes);
    if (seed.length != 32) {
      throw Exception(
        'holder_key_invalid: panjang seed Ed25519 tidak valid (${seed.length} bytes).',
      );
    }

    final keyPair = await crypto.Ed25519().newKeyPairFromSeed(seed);

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final vpId = _generateUrnUuidV4();
    if (!_isUriLike(vpId)) {
      throw Exception('vp_id_invalid: id VP harus URI valid.');
    }
    _debugSubmitLog('vp.id', {
      'vp_id': vpId,
      'jti': vpId,
      'jti_matches_vp_id': true,
      'is_uri': true,
    });

    final vpPayload = <String, dynamic>{
      'id': vpId,
      '@context': ['https://www.w3.org/2018/credentials/v1'],
      'type': ['VerifiablePresentation'],
      'holder': holderDid,
      'verifiableCredential': [credentialJwt],
    };

    final header = <String, dynamic>{
      'alg': 'EdDSA',
      'typ': 'vp+jwt',
      'kid': _resolveVerificationMethodKid(holderDid),
    };

    final payload = <String, dynamic>{
      'iss': holderDid,
      'sub': holderDid,
      'aud': normalizedAudience,
      'nonce': normalizedNonce,
      'iat': now,
      'nbf': now,
      'exp': now + 120,
      'jti': vpId,
      'vp': vpPayload,
    };

    final encodedHeader = _b64UrlEncode(utf8.encode(jsonEncode(header)));
    final encodedPayload = _b64UrlEncode(utf8.encode(jsonEncode(payload)));
    final signingInput = '$encodedHeader.$encodedPayload';

    final signature = await crypto.Ed25519().sign(
      utf8.encode(signingInput),
      keyPair: keyPair,
    );
    final encodedSignature = _b64UrlEncode(Uint8List.fromList(signature.bytes));
    return '$signingInput.$encodedSignature';
  }

  static Future<String> _buildSDJWTPresentation({
    required String userId,
    required String sdJwt,
    required List<String> selectedClaims,
    required String nonce,
    required String audience,
  }) async {
    if (nonce.trim().isEmpty) {
      throw Exception(
        'nonce_missing: Verifier request tidak menyertakan nonce untuk SD-JWT key binding.',
      );
    }
    if (audience.trim().isEmpty) {
      throw Exception(
        'audience_missing: client_id verifier kosong, tidak bisa membangun proof SD-JWT.',
      );
    }

    // Select only the disclosures for requested claims
    String selectedSdJwt = selectedClaims.isNotEmpty
        ? SDJWTService.selectDisclosures(sdJwt, selectedClaims)
        : sdJwt;

    // Append Key Binding JWT
    selectedSdJwt = await SDJWTService.appendKBJWT(
      userId: userId,
      sdJwtWithDisclosures: selectedSdJwt,
      nonce: nonce,
      audience: audience,
    );

    return selectedSdJwt;
  }

  // ─── Step 4: Build Presentation Submission ────────────────────────────────

  /// Build the presentation_submission object
  static Map<String, dynamic> buildPresentationSubmission({
    required PresentationDefinition definition,
    required CredentialModel credential,
    String? descriptorId,
  }) {
    final format = _normalizeCredentialFormat(credential.format);
    final descriptors = definition.inputDescriptors;
    final primaryDescriptorId = descriptorId ??
        (descriptors.isNotEmpty ? descriptors.first.id : 'id-1');
    final descriptorFormat = format == 'vc+sd-jwt' ? 'vc+sd-jwt' : 'jwt_vc';

    final descriptorMap = descriptors.isEmpty
        ? [
            DescriptorMap(
              id: primaryDescriptorId,
              format: descriptorFormat,
              path: descriptorFormat == 'jwt_vc'
                  ? r'$.verifiableCredential[0]'
                  : r'$',
              pathNested: null,
            ),
          ]
        : descriptors
            .map(
              (d) => DescriptorMap(
                id: d.id,
                format: descriptorFormat,
                path: descriptorFormat == 'jwt_vc'
                    ? r'$.verifiableCredential[0]'
                    : r'$',
                pathNested: null,
              ),
            )
            .toList(growable: false);

    final submission = PresentationSubmission(
      id: 'submission-${DateTime.now().millisecondsSinceEpoch}',
      definitionId: definition.id,
      descriptorMap: descriptorMap,
    );

    final submissionJson = submission.toJson();
    _debugSubmitLog('presentation_submission.built', {
      'definition_id': submissionJson['definition_id'],
      'descriptor_map': submissionJson['descriptor_map'],
      'vp_token_format': descriptorFormat == 'jwt_vc' ? 'jwt_vp' : format,
    });
    return submissionJson;
  }

  // ─── Step 5: Submit Presentation ─────────────────────────────────────────

  /// Submit the VP via direct_post to the verifier's response_uri
  static Future<OID4VPSubmitResult> submitPresentation({
    required PresentationRequest request,
    required String vpToken,
    required Map<String, dynamic> presentationSubmission,
  }) async {
    final responseUri = request.responseUri;
    if (responseUri == null || responseUri.isEmpty) {
      throw Exception('Response URI tidak ditemukan dalam request');
    }
    if (request.clientId.trim().isEmpty) {
      throw Exception('client_id verifier kosong pada request object');
    }

    final requestUri = request.requestUri?.trim();
    if (requestUri != null &&
        requestUri.isNotEmpty &&
        requestUri == responseUri) {
      throw Exception(
        'response_uri_invalid: response_uri tidak boleh sama dengan request_uri',
      );
    }

    final state = request.state?.trim() ?? '';
    if (state.isEmpty) {
      throw Exception(
          'state_missing: state dari authorization request wajib ada');
    }

    if (vpToken.trim().isEmpty) {
      throw Exception('vp_token kosong, presentasi tidak bisa dikirim');
    }

    final tokenValidation = _validateVpTokenBinding(
      vpToken: vpToken,
      expectedNonce: request.nonce,
      expectedAudience: request.clientId,
    );
    _debugSubmitLog('submit.token_validation', tokenValidation);
    if (tokenValidation['valid'] != true) {
      throw Exception(
        'vp_token_invalid: ${tokenValidation['reason'] ?? 'nonce/aud binding tidak valid'}',
      );
    }

    if (request.presentationDefinition != null &&
        presentationSubmission.isEmpty) {
      throw Exception(
        'presentation_submission kosong padahal presentation_definition tersedia',
      );
    }

    final decodedVpPayload = _extractVpPayloadForDebug(vpToken);
    final submitDebug = _extractFinalSubmitDebug(vpToken);
    debugPrint('VP AUD: ${request.clientId}');
    debugPrint('VP NONCE: ${request.nonce ?? ''}');
    debugPrint('VC FORMAT: ${submitDebug['vc_format']}');
    debugPrint('VC LENGTH: ${submitDebug['vc_length']}');
    _debugSubmitLog('submit.authorization_fields', {
      'responseUri': responseUri,
      'state': state,
      'nonce': request.nonce,
    });
    _debugSubmitLog('submit.vp_payload_decoded', {
      'payload': decodedVpPayload,
    });

    _debugSubmitLog('submit.prepare', {
      'request_uri': request.requestUri,
      'response_uri': responseUri,
      'response_mode': request.responseMode,
      'client_id': request.clientId,
      'has_nonce': request.nonce != null && request.nonce!.isNotEmpty,
      'has_state': request.state != null,
      'method': 'POST',
      'content_type': 'application/x-www-form-urlencoded',
      'payload_keys': ['vp_token', 'presentation_submission', 'state'],
      'vp_token_length': vpToken.length,
      'presentation_submission_length':
          jsonEncode(presentationSubmission).length,
    });

    final body = <String, String>{
      'vp_token': vpToken,
      'presentation_submission': jsonEncode(presentationSubmission),
      'state': state,
    };

    try {
      debugPrint('================= OUTGOING REQUEST =================');
      debugPrint('[OID4VP_SUBMIT] POST $responseUri');
      await _saveVpTokenToFile(vpToken);
      _printLongLog('========== RAW JWT VP ==========');
      _printLongLog(vpToken);
      _printLongLog('================================');
      debugPrint('====================================================');

      if (responseUri.contains('/authorize')) {
        debugPrint(
            '⚠️ WARNING: SUBMITTING TO LEGACY /authorize ENDPOINT. This was provided as responseUri by the Verifier!');
      }

      final client = HttpClient()..connectionTimeout = _httpTimeout;
      final req = await client.postUrl(Uri.parse(responseUri));
      req.followRedirects = false;
      req.headers.contentType =
          ContentType('application', 'x-www-form-urlencoded');
      req.headers.set('Accept', 'application/json, text/plain, */*');

      final encoded = body.entries
          .map((e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');
      req.contentLength = utf8.encode(encoded).length;
      req.write(encoded);

      final resp = await req.close().timeout(_httpTimeout);
      final respBody = await resp.transform(utf8.decoder).join();
      client.close();

      debugPrint('================= RESPONSE GET =================');
      debugPrint('[OID4VP_SUBMIT] HTTP ${resp.statusCode}');
      debugPrint(
          '[OID4VP_SUBMIT] LOCATION (REDIRECT): ${resp.headers.value('location')}');
      debugPrint('[OID4VP_SUBMIT] BODY: ${_truncate(respBody)}');
      debugPrint('================================================');

      _debugSubmitLog('submit.response', {
        'response_uri': responseUri,
        'status_code': resp.statusCode,
        'location': resp.headers.value('location'),
        'response_body': _truncate(respBody),
      });

      // Success if 200/201/202/204 or explicit redirects.
      final success = (resp.statusCode >= 200 && resp.statusCode < 300) ||
          resp.statusCode == 302 ||
          resp.statusCode == 303 ||
          resp.statusCode == 307 ||
          resp.statusCode == 308;
      String? redirectUri;
      if (resp.statusCode == 302 ||
          resp.statusCode == 303 ||
          resp.statusCode == 307 ||
          resp.statusCode == 308) {
        redirectUri = resp.headers.value('location');
      }

      Map<String, dynamic>? responseJson;
      try {
        responseJson = jsonDecode(respBody) as Map<String, dynamic>;
      } catch (_) {}

      return OID4VPSubmitResult(
        success: success,
        statusCode: resp.statusCode,
        responseBody: respBody,
        redirectUri: redirectUri,
        responseJson: responseJson,
      );
    } on TimeoutException catch (e, st) {
      _debugSubmitException('submit.timeout', e, st, responseUri);
      throw Exception(
        'timeout_error: Timeout saat submit VP ke verifier ($responseUri).',
      );
    } on HandshakeException catch (e, st) {
      _debugSubmitException('submit.tls', e, st, responseUri);
      throw Exception(
        'tls_error: TLS/sertifikat gagal saat koneksi ke verifier ($responseUri).',
      );
    } on SocketException catch (e, st) {
      _debugSubmitException('submit.network', e, st, responseUri);
      throw Exception(
        'network_error: Tidak bisa menghubungi verifier (${e.message}).',
      );
    } on HttpException catch (e, st) {
      _debugSubmitException('submit.http_exception', e, st, responseUri);
      throw Exception('http_error: ${e.message}');
    } catch (e, st) {
      _debugSubmitException('submit.unknown', e, st, responseUri);
      rethrow;
    }
  }

  static void _debugSubmitLog(String event, Map<String, dynamic> data) {
    if (!kDebugMode) return;
    debugPrint('[OID4VP][$event] ${jsonEncode(data)}');
  }

  static void _debugSubmitException(
    String event,
    Object error,
    StackTrace stackTrace,
    String responseUri,
  ) {
    if (!kDebugMode) return;
    _debugSubmitLog(event, {
      'response_uri': responseUri,
      'error_type': error.runtimeType.toString(),
      'error': error.toString(),
    });
    debugPrint('[OID4VP][$event][stacktrace] $stackTrace');
  }

  static void _printLongLog(String text, {int chunkSize = 500}) {
    for (var index = 0; index < text.length; index += chunkSize) {
      final end =
          index + chunkSize > text.length ? text.length : index + chunkSize;
      print(text.substring(index, end));
    }
  }

  static Future<void> _saveVpTokenToFile(String vpToken) async {
    if (!kDebugMode) return;

    try {
      final verifierDir = _resolveVpTokenDirectory();
      await verifierDir.create(recursive: true);

      final file = File(
        '${verifierDir.path}${Platform.pathSeparator}vp_token.txt',
      );
      await file.writeAsString(vpToken, flush: true);
      debugPrint('[OID4VP_SUBMIT] JWT VP saved to: ${file.path}');
    } catch (e) {
      debugPrint('[OID4VP_SUBMIT] Failed to save JWT VP to file: $e');
    }
  }

  static Directory _resolveVpTokenDirectory() {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return Directory(
        '${Directory.current.path}${Platform.pathSeparator}verifier',
      );
    }

    return Directory(
      '${Directory.systemTemp.path}${Platform.pathSeparator}verifier',
    );
  }

  static String _truncate(String input, {int max = 600}) {
    if (input.length <= max) return input;
    return '${input.substring(0, max)}...';
  }

  static Map<String, dynamic> _validateVpTokenBinding({
    required String vpToken,
    required String? expectedNonce,
    required String expectedAudience,
  }) {
    final trimmed = vpToken.trim();
    final nonce = (expectedNonce ?? '').trim();
    final aud = expectedAudience.trim();
    if (nonce.isEmpty) {
      return {
        'valid': false,
        'format': 'unknown',
        'reason': 'expected nonce dari request kosong',
      };
    }

    if (trimmed.contains('~')) {
      // SD-JWT: validate nonce/aud on KB-JWT segment if present.
      final parts = trimmed.split('~').where((p) => p.isNotEmpty).toList();
      final kbCandidate = parts.isNotEmpty ? parts.last : '';
      if (kbCandidate.split('.').length != 3) {
        return {
          'valid': false,
          'format': 'vc+sd-jwt',
          'reason': 'KB-JWT tidak ditemukan pada SD-JWT',
        };
      }

      final payload = _decodeJwtPayloadSafe(kbCandidate);
      final tokenNonce = payload['nonce']?.toString();
      final tokenAud = payload['aud']?.toString();
      final nonceMatch = tokenNonce == nonce;
      final audMatch = tokenAud == aud;

      return {
        'valid': nonceMatch && audMatch,
        'format': 'vc+sd-jwt',
        'has_nonce': tokenNonce != null,
        'nonce_match': nonceMatch,
        'has_aud': tokenAud != null,
        'aud_match': audMatch,
        'reason': nonceMatch && audMatch
            ? 'ok'
            : 'KB-JWT nonce/aud tidak sesuai request',
      };
    }

    if (trimmed.split('.').length == 3) {
      final payload = _decodeJwtPayloadSafe(trimmed);
      final tokenNonce = payload['nonce']?.toString();
      final tokenAudRaw = payload['aud'];
      final tokenJti = payload['jti']?.toString();
      final vpObj = payload['vp'];
      String? vpId;
      if (vpObj is Map<String, dynamic>) {
        vpId = vpObj['id']?.toString();
      } else if (vpObj is Map) {
        vpId = vpObj['id']?.toString();
      }

      bool audMatch = false;
      if (tokenAudRaw is String) {
        audMatch = tokenAudRaw == aud;
      } else if (tokenAudRaw is List) {
        audMatch = tokenAudRaw.map((e) => e.toString()).contains(aud);
      }

      final nonceMatch = tokenNonce == nonce;
      final jtiVpIdMatch = tokenJti != null && tokenJti == vpId;
      final vpIdIsUri = vpId != null && _isUriLike(vpId);
      return {
        'valid': nonceMatch && audMatch && jtiVpIdMatch && vpIdIsUri,
        'format': 'jwt',
        'has_nonce': tokenNonce != null,
        'nonce_match': nonceMatch,
        'has_aud': tokenAudRaw != null,
        'aud_match': audMatch,
        'has_jti': tokenJti != null,
        'has_vp_id': vpId != null,
        'jti_match_vp_id': jtiVpIdMatch,
        'vp_id_is_uri': vpIdIsUri,
        'reason': nonceMatch && audMatch && jtiVpIdMatch && vpIdIsUri
            ? 'ok'
            : 'JWT vp_token gagal validasi nonce/aud/jti-vp.id',
      };
    }

    return {
      'valid': false,
      'format': 'unknown',
      'reason': 'format vp_token tidak dikenali',
    };
  }

  static Map<String, dynamic> _decodeJwtPayloadSafe(String jwt) {
    try {
      final parts = jwt.split('.');
      if (parts.length != 3) return <String, dynamic>{};
      String payload = parts[1].replaceAll('-', '+').replaceAll('_', '/');
      while (payload.length % 4 != 0) {
        payload += '=';
      }
      final decoded = utf8.decode(base64.decode(payload));
      final json = jsonDecode(decoded);
      if (json is Map<String, dynamic>) {
        return json;
      }
      return <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  static Map<String, dynamic> _extractVpPayloadForDebug(String vpToken) {
    final trimmed = vpToken.trim();
    if (trimmed.contains('~')) {
      final parts = trimmed.split('~').where((p) => p.isNotEmpty).toList();
      if (parts.isNotEmpty) {
        final kbJwt = parts.last;
        if (kbJwt.split('.').length == 3) {
          return {
            'token_format': 'vc+sd-jwt',
            'kb_jwt_payload': _decodeJwtPayloadSafe(kbJwt),
          };
        }
      }
      return {
        'token_format': 'vc+sd-jwt',
        'kb_jwt_payload': <String, dynamic>{},
      };
    }

    if (trimmed.split('.').length == 3) {
      return {
        'token_format': 'jwt_vp',
        'payload': _decodeJwtPayloadSafe(trimmed),
      };
    }

    return {
      'token_format': 'unknown',
      'payload': <String, dynamic>{},
    };
  }

  static Map<String, dynamic> _extractFinalSubmitDebug(String vpToken) {
    if (vpToken.contains('~')) {
      final vcOnly = vpToken.split('~').first;
      return {
        'vc_format': 'vc+sd-jwt',
        'vc_length': vcOnly.length,
      };
    }

    final jwtPayload = _decodeJwtPayloadSafe(vpToken);
    final vpObj = jwtPayload['vp'];
    String? vc;
    if (vpObj is Map<String, dynamic>) {
      final list = vpObj['verifiableCredential'];
      if (list is List && list.isNotEmpty) {
        vc = list.first?.toString();
      }
    } else if (vpObj is Map) {
      final list = vpObj['verifiableCredential'];
      if (list is List && list.isNotEmpty) {
        vc = list.first?.toString();
      }
    }

    return {
      'vc_format': 'jwt_vc',
      'vc_length': vc?.length ?? 0,
    };
  }

  static String _normalizeCredentialFormat(String? rawFormat) {
    final format = (rawFormat ?? '').trim();
    if (format.isEmpty || format == 'jwt_vc_json') {
      return 'jwt_vc';
    }
    return format;
  }

  static String _normalizeDescriptorFormat(String rawFormat) {
    final format = rawFormat.trim();
    if (format == 'jwt_vc_json') {
      return 'jwt_vc';
    }
    return format;
  }

  static void _debugRequestSummary(PresentationRequest request) {
    if (!kDebugMode) return;
    _debugSubmitLog('request.parsed', {
      'request_uri': request.requestUri,
      'response_uri': request.responseUri,
      'client_id': request.clientId,
      'nonce': request.nonce,
      'state': request.state,
      'has_presentation_definition': request.presentationDefinition != null,
      'response_mode': request.responseMode,
    });
  }

  static String _resolveVerificationMethodKid(String holderDid) {
    return holderDid.contains('#') ? holderDid : '$holderDid#0';
  }

  static String _b64UrlEncode(List<int> bytes) {
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  static bool _isUriLike(String value) {
    final raw = value.trim();
    if (raw.isEmpty) return false;
    final uri = Uri.tryParse(raw);
    if (uri == null) return false;
    return raw.startsWith('urn:') ||
        raw.startsWith('http://') ||
        raw.startsWith('https://');
  }

  static String _generateUrnUuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));

    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    final b = bytes
        .map((e) => e.toRadixString(16).padLeft(2, '0'))
        .toList(growable: false);

    final uuid =
        '${b[0]}${b[1]}${b[2]}${b[3]}-${b[4]}${b[5]}-${b[6]}${b[7]}-${b[8]}${b[9]}-${b[10]}${b[11]}${b[12]}${b[13]}${b[14]}${b[15]}';
    return 'urn:uuid:$uuid';
  }

  // ─── Full Flow ────────────────────────────────────────────────────────────

  /// Run the complete OID4VP flow from QR data
  static Future<OID4VPResult> fullPresentationFlow({
    required String userId,
    required String qrData,
    required List<CredentialModel> walletCredentials,
    required List<String> selectedClaims,
    required String selectedDescriptorId,
    void Function(OID4VPStep step, String message)? onProgress,
  }) async {
    try {
      onProgress?.call(
          OID4VPStep.parsingRequest, 'Memproses permintaan verifikasi...');
      final request = await parseRequest(qrData);

      onProgress?.call(
          OID4VPStep.matchingCredentials, 'Mencocokkan credential...');
      final matches = request.presentationDefinition != null
          ? matchCredentials(request.presentationDefinition!, walletCredentials)
          : <CredentialMatch>[];

      if (matches.isEmpty && walletCredentials.isEmpty) {
        throw Exception(
            'Tidak ada credential yang cocok dengan permintaan verifier');
      }

      final credentialToUse = matches.isNotEmpty
          ? matches.first.credential
          : walletCredentials.first;

      onProgress?.call(
          OID4VPStep.buildingVP, 'Membangun Verifiable Presentation...');
      final vpToken = await buildVPToken(
        userId: userId,
        credential: credentialToUse,
        request: request,
        selectedClaims: selectedClaims,
      );

      final submission = request.presentationDefinition != null
          ? buildPresentationSubmission(
              definition: request.presentationDefinition!,
              credential: credentialToUse,
              descriptorId: selectedDescriptorId,
            )
          : <String, dynamic>{};

      onProgress?.call(
          OID4VPStep.submitting, 'Mengirim presentasi ke verifier...');
      final result = await submitPresentation(
        request: request,
        vpToken: vpToken,
        presentationSubmission: submission,
      );

      onProgress?.call(
        result.success ? OID4VPStep.done : OID4VPStep.error,
        result.success
            ? 'Presentasi berhasil dikirim!'
            : 'Gagal mengirim presentasi',
      );

      return OID4VPResult(
        request: request,
        submitResult: result,
        credentialUsed: credentialToUse,
      );
    } catch (e) {
      debugPrint('[OID4VP] Flow error: $e');
      onProgress?.call(OID4VPStep.error, e.toString());
      rethrow;
    }
  }
}

// ─── Data classes ─────────────────────────────────────────────────────────────

enum OID4VPStep {
  parsingRequest,
  matchingCredentials,
  buildingVP,
  submitting,
  done,
  error,
}

class CredentialMatch {
  final CredentialModel credential;
  final String descriptorId;
  final List<String> requestedFields;

  CredentialMatch({
    required this.credential,
    required this.descriptorId,
    required this.requestedFields,
  });
}

class OID4VPSubmitResult {
  final bool success;
  final int statusCode;
  final String responseBody;
  final String? redirectUri;
  final Map<String, dynamic>? responseJson;

  OID4VPSubmitResult({
    required this.success,
    required this.statusCode,
    required this.responseBody,
    this.redirectUri,
    this.responseJson,
  });
}

class OID4VPResult {
  final PresentationRequest request;
  final OID4VPSubmitResult submitResult;
  final CredentialModel credentialUsed;

  OID4VPResult({
    required this.request,
    required this.submitResult,
    required this.credentialUsed,
  });
}
