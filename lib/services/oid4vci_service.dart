import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:app_links/app_links.dart';
import 'package:cryptography/cryptography.dart' as crypto;
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/credential_offer_model.dart';
import '../models/issuer_metadata_model.dart';
import 'secure_storage_service.dart';

/// OID4VCI service with DID-bound issuance and mandatory proof JWT.
class OID4VCIService {
  static const Duration _httpTimeout = Duration(seconds: 30);
  static const String _defaultFormat = 'jwt_vc_json';
  static const String _defaultClientId = 'identia-holder-mobile';
  static String? _activeIdentityUserId;

  static const _criticalDuplicateDidLog =
      '[CRITICAL] Duplicate DID detected → regenerating';

  // ---------------------------------------------------------------------------
  // Holder DID + key material
  // ---------------------------------------------------------------------------

  static void setActiveIdentityUser(String? userId) {
    final normalized = userId?.trim() ?? '';
    _activeIdentityUserId = normalized.isEmpty ? null : normalized;
  }

  static void reset() {
    _activeIdentityUserId = null;
  }

  static String _requireIdentityUserId({required String userId}) {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      throw Exception(
        'active_user_required: userId wajib dikirim untuk akses identitas holder.',
      );
    }

    final active = _activeIdentityUserId?.trim() ?? '';
    if (active.isEmpty) {
      throw Exception(
        'active_user_required: Tidak ada user aktif untuk akses identitas holder.',
      );
    }
    if (active != normalizedUserId) {
      throw Exception(
        'active_user_mismatch: userId=$normalizedUserId tidak sama dengan user aktif=$active.',
      );
    }

    return normalizedUserId;
  }

  static Future<_ValidatedHolderIdentity?> _loadValidatedHolderIdentity(
    String userId,
  ) async {
    final existingDid = await SecureStorageService.loadHolderDid(userId);
    final existingPriv =
        await SecureStorageService.loadHolderPrivateKey(userId);
    final existingPub = await SecureStorageService.loadHolderPublicKey(userId);

    if (existingDid == null ||
        existingDid.isEmpty ||
        existingPriv == null ||
        existingPriv.isEmpty ||
        existingPub == null ||
        existingPub.isEmpty) {
      return null;
    }

    final pubBytes = base64.decode(existingPub);
    final derivedDidFromPublic = _buildDidJwkFromPublicKey(pubBytes);

    final privBytes = base64.decode(existingPriv);
    final seed = privBytes.length >= 32
        ? Uint8List.fromList(privBytes.sublist(0, 32))
        : Uint8List.fromList(privBytes);

    if (seed.length != 32) {
      throw Exception(
        'Invalid Ed25519 private seed length (${seed.length})',
      );
    }

    final derivedPair = await crypto.Ed25519().newKeyPairFromSeed(seed);
    final derivedPub = await derivedPair.extractPublicKey();
    final derivedDidFromPrivate = _buildDidJwkFromPublicKey(derivedPub.bytes);

    if (derivedDidFromPublic != existingDid ||
        derivedDidFromPrivate != existingDid) {
      return null;
    }

    return _ValidatedHolderIdentity(
      did: existingDid,
      privateKeyBase64: existingPriv,
      publicKeyBase64: existingPub,
    );
  }

  static Future<_ValidatedHolderIdentity> _loadValidatedIdentityOrRegenerate(
    String userId,
  ) async {
    try {
      final validated = await _loadValidatedHolderIdentity(userId);
      if (validated != null) {
        await SecureStorageService.assertUniqueHolderDidForUser(
          userId: userId,
          holderDid: validated.did,
        );
        return validated;
      }
    } catch (e) {
      final message = e.toString();
      if (message.contains('critical_did_conflict')) {
        debugPrint(_criticalDuplicateDidLog);
      }
    }

    await SecureStorageService.clearHolderIdentityForUser(userId);
    final regeneratedDid = await ensureHolderDid(userId: userId);
    final reloaded = await _loadValidatedHolderIdentity(userId);
    if (reloaded == null || reloaded.did != regeneratedDid) {
      throw Exception(
        'holder_identity_invalid: Gagal memuat ulang identitas setelah regenerasi.',
      );
    }
    return reloaded;
  }

  /// Ensure wallet has persistent holder key pair + DID.
  static Future<String> ensureHolderDid({required String userId}) async {
    final activeUserId = _requireIdentityUserId(userId: userId);
    setActiveIdentityUser(activeUserId);

    await SecureStorageService.purgeLegacyGlobalHolderIdentity();
    final wasDuplicateMigrated =
        await SecureStorageService.clearHolderIdentityIfDidDuplicatedForUser(
      activeUserId,
    );
    if (wasDuplicateMigrated) {
      debugPrint(_criticalDuplicateDidLog);
    }

    try {
      final validated = await _loadValidatedHolderIdentity(activeUserId);
      if (validated != null) {
        await SecureStorageService.assertUniqueHolderDidForUser(
          userId: activeUserId,
          holderDid: validated.did,
        );
        debugPrint(
          '[IDENTITY] userId=$activeUserId DID=${validated.did} source=loaded',
        );
        return validated.did;
      }
    } catch (e) {
      final message = e.toString();
      if (message.contains('critical_did_conflict')) {
        debugPrint(_criticalDuplicateDidLog);
      }
      debugPrint('[OID4VCI] Failed to validate holder keypair: $e');
    }

    await SecureStorageService.clearHolderIdentityForUser(activeUserId);

    final algorithm = crypto.Ed25519();
    final keyPair = await algorithm.newKeyPair();
    final privateBytes = await keyPair.extractPrivateKeyBytes();
    final publicKey = await keyPair.extractPublicKey();

    final privateB64 = base64.encode(privateBytes);
    final publicB64 = base64.encode(publicKey.bytes);
    await SecureStorageService.saveHolderKeyPair(
      userId: activeUserId,
      privateKeyBase64: privateB64,
      publicKeyBase64: publicB64,
    );

    final holderDid = _buildDidJwkFromPublicKey(publicKey.bytes);
    await SecureStorageService.saveHolderDid(
      userId: activeUserId,
      holderDid: holderDid,
    );
    await SecureStorageService.assertUniqueHolderDidForUser(
      userId: activeUserId,
      holderDid: holderDid,
    );
    await SecureStorageService.clearOID4VCISessionsForActiveScope();
    debugPrint(
      '[IDENTITY] userId=$activeUserId DID=$holderDid '
      'source=generated',
    );
    return holderDid;
  }

  /// Resolve holder DID for authorization without auto-generating a new DID.
  ///
  /// This avoids silent DID drift and lets UI show a clear action message
  /// before any authorize request is submitted.
  static Future<String> resolveHolderDidForAuthorization({
    required String userId,
  }) async {
    final activeUserId = _requireIdentityUserId(userId: userId);
    final validated = await _loadValidatedIdentityOrRegenerate(activeUserId);
    debugPrint(
      '[IDENTITY] userId=$activeUserId DID=${validated.did} source=loaded',
    );
    return validated.did;
  }

  static String _buildDidJwkFromPublicKey(List<int> publicKeyBytes) {
    final jwk = <String, dynamic>{
      'kty': 'OKP',
      'crv': 'Ed25519',
      'x': _b64UrlEncode(Uint8List.fromList(publicKeyBytes)),
    };
    return 'did:jwk:${_b64UrlEncode(utf8.encode(jsonEncode(jwk)))}';
  }

  // ---------------------------------------------------------------------------
  // Offer + metadata
  // ---------------------------------------------------------------------------

  static Future<CredentialOffer> parseCredentialOffer(String input) async {
    debugPrint(
      '[OID4VCI] Parsing credential offer from: '
      '${input.substring(0, input.length > 120 ? 120 : input.length)}',
    );

    late final Uri uri;
    try {
      uri = Uri.parse(input);
    } catch (e) {
      throw Exception('URL credential offer tidak valid: $e');
    }

    final offerUri = uri.queryParameters['credential_offer_uri'];
    if (offerUri != null && offerUri.isNotEmpty) {
      return fetchCredentialOffer(offerUri);
    }

    final inlineOffer = uri.queryParameters['credential_offer'];
    if (inlineOffer != null && inlineOffer.isNotEmpty) {
      final decoded = Uri.decodeComponent(inlineOffer);
      final json = jsonDecode(decoded) as Map<String, dynamic>;
      return CredentialOffer.fromJson(json);
    }

    throw Exception(
        'Parameter credential_offer atau credential_offer_uri tidak ditemukan');
  }

  static Future<CredentialOffer> fetchCredentialOffer(String uri) async {
    debugPrint('[OID4VCI] Fetching credential offer from: $uri');
    final body = await _getJson(uri);
    return CredentialOffer.fromJson(body);
  }

  static Future<IssuerMetadata> fetchIssuerMetadata(String issuerUrl) async {
    final base = issuerUrl.endsWith('/')
        ? issuerUrl.substring(0, issuerUrl.length - 1)
        : issuerUrl;
    final metadataUrl = '$base/.well-known/openid-credential-issuer';
    debugPrint('[OID4VCI] Fetching issuer metadata from: $metadataUrl');

    final body = await _getJson(metadataUrl);
    final metadata = IssuerMetadata.fromJson(body);

    if (metadata.authorizationEndpoint.isEmpty &&
        metadata.tokenEndpoint.isEmpty &&
        metadata.credentialEndpoint.isEmpty) {
      throw Exception('Metadata issuer tidak lengkap untuk alur OID4VCI');
    }

    return metadata;
  }

  // ---------------------------------------------------------------------------
  // Authorization code flow
  // ---------------------------------------------------------------------------

  static Future<String> launchAndCaptureAuthCode({
    required String authorizationEndpoint,
    required String clientId,
    required String holderDid,
    required String redirectUri,
    String? authIdentifier,
    String? authPassword,
    String? requestId,
    String? issuerState,
    String? scope,
  }) async {
    final state = _randomToken(24);
    final params = <String, String>{
      'response_type': 'code',
      'client_id': clientId,
      'redirect_uri': redirectUri,
      'state': state,
      'holder_did': holderDid,
      if (scope != null && scope.isNotEmpty) 'scope': scope,
      if (issuerState != null && issuerState.isNotEmpty)
        'issuer_state': issuerState,
    };

    final identifier = authIdentifier?.trim() ?? '';
    final password = authPassword ?? '';
    if (identifier.isNotEmpty && password.isNotEmpty) {
      final code = await _tryAuthorizeWithCredentials(
        authorizationEndpoint: authorizationEndpoint,
        params: {
          ...params,
          'identifier': identifier,
          'password': password,
        },
        expectedState: state,
        requestId: requestId,
      );
      if (code != null && code.isNotEmpty) {
        return code;
      }
    }

    final authUrl = Uri.parse(authorizationEndpoint).replace(
      queryParameters: params,
    );
    debugPrint('[OID4VCI] Launching auth URL: $authUrl');

    if (!await launchUrl(authUrl, mode: LaunchMode.externalApplication)) {
      throw Exception('Tidak dapat membuka browser untuk autentikasi issuer');
    }

    return _waitForRedirectCode(
      expectedRedirectUri: redirectUri,
      expectedState: state,
    );
  }

  static Future<String?> _tryAuthorizeWithCredentials({
    required String authorizationEndpoint,
    required Map<String, String> params,
    required String expectedState,
    String? requestId,
  }) async {
    final client = HttpClient()
      ..badCertificateCallback = (cert, host, port) => true;

    try {
      final req = await client.postUrl(Uri.parse(authorizationEndpoint));
      req.headers.contentType =
          ContentType('application', 'x-www-form-urlencoded');
      req.headers.set('Accept', 'application/json, text/html');

      final body = params.entries
          .map((e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');
      req.write(body);

      final resp = await req.close().timeout(_httpTimeout);
      final responseBody = await resp.transform(utf8.decoder).join();
      final location = resp.headers.value(HttpHeaders.locationHeader);

      debugPrint(
        '[OID4VCI][telemetry] request_id=${requestId ?? '-'} '
        'authorize_mode=direct status_code=${resp.statusCode}',
      );

      if (resp.statusCode >= 400) {
        _throwAuthorizeError(
            resp.statusCode, authorizationEndpoint, responseBody);
      }

      final fromLocation = _extractCodeFromRedirectUri(location, expectedState);
      if (fromLocation != null && fromLocation.isNotEmpty) {
        return fromLocation;
      }

      if (responseBody.isNotEmpty) {
        final lowered = responseBody.toLowerCase();
        if (lowered.contains('holder_did is required') ||
            lowered.contains('client_id must be a did')) {
          throw Exception(
            'holder_did_missing: Issuer menolak authorize karena holder_did tidak terbaca. '
            'Silakan ulangi issuance dari akun wallet aktif yang sama.',
          );
        }

        try {
          final json = jsonDecode(responseBody) as Map<String, dynamic>;
          if (json.containsKey('error')) {
            throw _issuerErrorToException(json);
          }

          final code = json['code']?.toString();
          if (code != null && code.isNotEmpty) {
            final returnedState = json['state']?.toString();
            if (returnedState == null || returnedState == expectedState) {
              return code;
            }
            throw Exception(
                'State authorize tidak valid. Silakan ulangi proses login.');
          }

          final redirect = json['redirect_uri']?.toString() ??
              json['redirectUrl']?.toString() ??
              json['location']?.toString();
          final fromJsonRedirect =
              _extractCodeFromRedirectUri(redirect, expectedState);
          if (fromJsonRedirect != null && fromJsonRedirect.isNotEmpty) {
            return fromJsonRedirect;
          }
        } catch (e) {
          if (e.toString().contains('did_binding_conflict') ||
              e.toString().contains('holder_did')) {
            rethrow;
          }
        }
      }

      return null;
    } finally {
      client.close();
    }
  }

  static String? _extractCodeFromRedirectUri(
      String? redirectUri, String expectedState) {
    if (redirectUri == null || redirectUri.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(redirectUri);
    if (uri == null) {
      return null;
    }

    final error = uri.queryParameters['error'];
    if (error != null && error.isNotEmpty) {
      throw _issuerErrorToException({
        'error': error,
        'error_description': uri.queryParameters['error_description'],
      });
    }

    final returnedState = uri.queryParameters['state'];
    if (returnedState == null || returnedState != expectedState) {
      return null;
    }

    final code = uri.queryParameters['code'];
    return (code == null || code.isEmpty) ? null : code;
  }

  static Never _throwAuthorizeError(int statusCode, String url, String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      if (json.containsKey('error')) {
        final mapped = _issuerErrorToException(json);
        throw mapped;
      }
    } on FormatException {
      // Fall through to generic HTTP mapping when body is not JSON.
    }
    throw Exception(_httpError(statusCode, url, body));
  }

  static Future<String> _waitForRedirectCode({
    required String expectedRedirectUri,
    required String expectedState,
  }) async {
    final expected = Uri.parse(expectedRedirectUri);
    final appLinks = AppLinks();
    final completer = Completer<String>();

    final subscription = appLinks.uriLinkStream.listen((uri) {
      if (!_redirectMatches(expected, uri)) {
        return;
      }

      final returnedState = uri.queryParameters['state'];
      if (returnedState == null || returnedState != expectedState) {
        if (!completer.isCompleted) {
          completer.completeError(
            Exception(
                'State redirect tidak valid. Silakan ulangi proses login.'),
          );
        }
        return;
      }

      final error = uri.queryParameters['error'];
      if (error != null) {
        if (!completer.isCompleted) {
          completer.completeError(_issuerErrorToException({
            'error': error,
            'error_description': uri.queryParameters['error_description'],
          }));
        }
        return;
      }

      final code = uri.queryParameters['code'];
      if (code != null && code.isNotEmpty && !completer.isCompleted) {
        completer.complete(code);
      }
    });

    try {
      return await completer.future.timeout(const Duration(minutes: 10));
    } finally {
      await subscription.cancel();
    }
  }

  static bool _redirectMatches(Uri expected, Uri actual) {
    if (expected.scheme != actual.scheme) return false;

    final expectedHost = expected.host;
    final actualHost = actual.host;
    if (expectedHost.isNotEmpty && actualHost != expectedHost) return false;

    final expectedPath = expected.path;
    final actualPath = actual.path;
    if (expectedPath.isNotEmpty &&
        expectedPath != '/' &&
        actualPath != expectedPath) {
      return false;
    }

    return true;
  }

  // ---------------------------------------------------------------------------
  // Token exchange + c_nonce lifecycle
  // ---------------------------------------------------------------------------

  static Future<OID4VCITokenSession> exchangeAuthorizationCodeToken({
    required String tokenEndpoint,
    required String issuerKey,
    required String code,
    required String clientId,
    required String redirectUri,
    required String holderDid,
  }) async {
    final payload = <String, String>{
      'grant_type': 'authorization_code',
      'code': code,
      'client_id': clientId,
      'redirect_uri': redirectUri,
      'holder_did': holderDid,
    };

    final json = await _postForm(tokenEndpoint, payload);
    final session = OID4VCITokenSession.fromTokenResponse(issuerKey, json);
    await SecureStorageService.saveOID4VCISession(issuerKey, session.toJson());
    return session;
  }

  static Future<OID4VCITokenSession> exchangePreAuthorizedCodeToken({
    required String tokenEndpoint,
    required String issuerKey,
    required String preAuthorizedCode,
    required String clientId,
    required String holderDid,
  }) async {
    final payload = <String, String>{
      'grant_type': 'urn:ietf:params:oauth:grant-type:pre-authorized_code',
      'pre-authorized_code': preAuthorizedCode,
      'client_id': clientId,
      'holder_did': holderDid,
    };

    final json = await _postForm(tokenEndpoint, payload);
    final session = OID4VCITokenSession.fromTokenResponse(issuerKey, json);
    await SecureStorageService.saveOID4VCISession(issuerKey, session.toJson());
    return session;
  }

  // ---------------------------------------------------------------------------
  // Proof JWT
  // ---------------------------------------------------------------------------

  static Future<String> buildCredentialProofJwt({
    required String userId,
    required String holderDid,
    required String issuerAudience,
    required String nonce,
  }) async {
    final activeUserId = _requireIdentityUserId(userId: userId);
    final validated = await _loadValidatedIdentityOrRegenerate(activeUserId);
    if (validated.did != holderDid) {
      throw Exception(
        'holder_did_mismatch: DID request tidak sama dengan DID tersimpan user aktif.',
      );
    }
    final privB64 = validated.privateKeyBase64;
    final pubB64 = validated.publicKeyBase64;

    final normalizedAudience = issuerAudience.trim();
    if (normalizedAudience.isEmpty) {
      throw Exception('Audience proof JWT tidak boleh kosong');
    }
    if (normalizedAudience.startsWith('did:')) {
      throw Exception('Audience proof JWT wajib URL issuer, bukan DID');
    }
    final audUri = Uri.tryParse(normalizedAudience);
    if (audUri == null ||
        !(audUri.scheme == 'http' || audUri.scheme == 'https')) {
      throw Exception('Audience proof JWT wajib URL HTTP(S) issuer');
    }

    final normalizedNonce = nonce.trim();
    if (normalizedNonce.isEmpty) {
      throw Exception('Nonce proof JWT tidak boleh kosong');
    }

    final privateBytes = base64.decode(privB64);
    if (privateBytes.isEmpty) {
      throw Exception('Private key holder tidak valid');
    }

    final seed = privateBytes.length >= 32
        ? Uint8List.fromList(privateBytes.sublist(0, 32))
        : Uint8List.fromList(privateBytes);

    if (seed.length != 32) {
      throw Exception(
          'Panjang private key Ed25519 tidak valid (${seed.length} bytes)');
    }

    final publicBytes = base64.decode(pubB64);
    final didFromPublic = _buildDidJwkFromPublicKey(publicBytes);
    final algorithm = crypto.Ed25519();
    final keyPair = await algorithm.newKeyPairFromSeed(seed);
    final derivedPublic = await keyPair.extractPublicKey();
    final didFromPrivate = _buildDidJwkFromPublicKey(derivedPublic.bytes);

    if (didFromPublic != holderDid || didFromPrivate != holderDid) {
      throw Exception(
        'holder_key_mismatch: DID payload tidak cocok dengan key signing aktif. '
        'Silakan regenerate holder DID lalu ulangi issuance.',
      );
    }

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final kid = _resolveVerificationMethodKid(holderDid);
    final header = <String, dynamic>{
      'alg': 'EdDSA',
      'typ': 'openid4vci-proof+jwt',
      'kid': kid,
    };

    final payload = <String, dynamic>{
      'iss': holderDid,
      'sub': holderDid,
      'aud': normalizedAudience,
      'nonce': normalizedNonce,
      'iat': now,
      'exp': now + 120,
      'jti': _randomToken(20),
    };

    final encodedHeader = _b64UrlEncode(utf8.encode(jsonEncode(header)));
    final encodedPayload = _b64UrlEncode(utf8.encode(jsonEncode(payload)));
    final signingInput = '$encodedHeader.$encodedPayload';

    final signature = await algorithm.sign(
      utf8.encode(signingInput),
      keyPair: keyPair,
    );

    final encodedSignature = _b64UrlEncode(Uint8List.fromList(signature.bytes));
    return '$signingInput.$encodedSignature';
  }

  // ---------------------------------------------------------------------------
  // Credential requests (proof is mandatory)
  // ---------------------------------------------------------------------------

  static Future<Map<String, dynamic>> requestCredential({
    required String credentialEndpoint,
    required String accessToken,
    required String holderDid,
    required String proofJwt,
    required List<String> credentialTypes,
    String format = _defaultFormat,
  }) async {
    if (proofJwt.trim().isEmpty) {
      throw Exception('Credential request wajib menyertakan proof JWT');
    }

    final body = <String, dynamic>{
      'format': format,
      'credential_definition': {
        'type': credentialTypes,
      },
      'holder_did': holderDid,
      'proof': {
        'proof_type': 'jwt',
        'jwt': proofJwt,
      },
    };

    return _postJson(credentialEndpoint, body, accessToken);
  }

  static Future<Map<String, dynamic>> requestNativeCredential({
    required String ssiNativeEndpoint,
    required String accessToken,
    required String holderDid,
    required String proofJwt,
    required String presentedVc,
    required List<String> credentialTypes,
    String format = _defaultFormat,
  }) async {
    if (presentedVc.trim().isEmpty) {
      throw Exception('Mode SSI native membutuhkan presented_vc');
    }

    final body = <String, dynamic>{
      'format': format,
      'credential_definition': {
        'type': credentialTypes,
      },
      'holder_did': holderDid,
      'presented_vc': presentedVc,
      'proof': {
        'proof_type': 'jwt',
        'jwt': proofJwt,
      },
    };

    return _postJson(ssiNativeEndpoint, body, accessToken);
  }

  // ---------------------------------------------------------------------------
  // Full flow
  // ---------------------------------------------------------------------------

  static Future<OID4VCIResult> fullIssuanceFlow({
    required String userId,
    required String credentialOfferInput,
    required String clientId,
    required String redirectUri,
    String? holderDid,
    String? authIdentifier,
    String? authPassword,
    String? presentedVc,
    String? requestId,
    String? userNik,
    void Function(OID4VCIStep step, String message)? onProgress,
  }) async {
    final rid = (requestId ?? '').trim().isEmpty
        ? 'rid-${DateTime.now().millisecondsSinceEpoch}-${_randomToken(6)}'
        : requestId!.trim();

    final maskedNik = _maskNik(userNik);

    try {
      onProgress?.call(
          OID4VCIStep.parsingOffer, 'Memproses credential offer...');
      final offer = await parseCredentialOffer(credentialOfferInput);

      onProgress?.call(
          OID4VCIStep.fetchingMetadata, 'Mengambil metadata issuer...');
      final metadata = await fetchIssuerMetadata(offer.credentialIssuer);

      final resolvedHolderDid = holderDid?.trim() ?? '';
      if (resolvedHolderDid.isEmpty) {
        throw Exception(
          'holder_did_missing: Holder DID belum tersedia pada wallet aktif. '
          'Silakan login ulang lalu coba issuance kembali.',
        );
      }
      final effectiveClientId =
          clientId.trim().isEmpty ? _defaultClientId : clientId.trim();
      final effectiveIdentifier = authIdentifier?.trim() ?? '';
      final effectivePassword = authPassword ?? '';

      debugPrint(
        '[OID4VCI][telemetry] request_id=$rid nik=${maskedNik ?? '-'} '
        'holder_did=${_maskDid(resolvedHolderDid)} '
        'auth_identifier=${_maskNik(effectiveIdentifier) ?? '-'} status=start',
      );

      OID4VCITokenSession session;

      if (offer.hasPreAuthorizedCode &&
          (offer.preAuthorizedCode?.isNotEmpty ?? false)) {
        onProgress?.call(
          OID4VCIStep.exchangingToken,
          'Menukar pre-authorized code ke token issuer...',
        );

        session = await exchangePreAuthorizedCodeToken(
          tokenEndpoint: metadata.tokenEndpoint,
          issuerKey: metadata.credentialIssuer,
          preAuthorizedCode: offer.preAuthorizedCode!,
          clientId: effectiveClientId,
          holderDid: resolvedHolderDid,
        );
      } else {
        if (metadata.authorizationEndpoint.isEmpty) {
          throw Exception(
              'Authorization endpoint tidak tersedia di metadata issuer');
        }

        onProgress?.call(OID4VCIStep.authorizing,
            'Membuka browser untuk proses autentikasi issuer...');

        if (effectiveIdentifier.isEmpty || effectivePassword.isEmpty) {
          onProgress?.call(
            OID4VCIStep.authorizing,
            'Kredensial akun tidak lengkap, lanjut autentikasi manual via browser...',
          );
        }

        final code = await launchAndCaptureAuthCode(
          authorizationEndpoint: metadata.authorizationEndpoint,
          clientId: effectiveClientId,
          holderDid: resolvedHolderDid,
          redirectUri: redirectUri,
          authIdentifier: effectiveIdentifier,
          authPassword: effectivePassword,
          requestId: rid,
          issuerState: offer.issuerState,
          scope: 'openid',
        );

        onProgress?.call(
          OID4VCIStep.exchangingToken,
          'Autentikasi berhasil, memproses callback issuer...',
        );

        onProgress?.call(
          OID4VCIStep.exchangingToken,
          'Menukar authorization code ke token...',
        );
        session = await exchangeAuthorizationCodeToken(
          tokenEndpoint: metadata.tokenEndpoint,
          issuerKey: metadata.credentialIssuer,
          code: code,
          clientId: effectiveClientId,
          redirectUri: redirectUri,
          holderDid: resolvedHolderDid,
        );
      }

      final proofHolderDid =
          await _resolveProofHolderDid(userId, resolvedHolderDid, session);
      final proofAudience = _resolveProofAudience(metadata, session);

      if (session.cNonce.isEmpty) {
        throw Exception(
            'Token issuer tidak mengembalikan c_nonce yang wajib untuk proof');
      }

      onProgress?.call(OID4VCIStep.buildingProof,
          'Membangun proof JWT berbasis DID holder...');
      final proofJwt = await buildCredentialProofJwt(
        userId: userId,
        holderDid: proofHolderDid,
        issuerAudience: proofAudience,
        nonce: session.cNonce,
      );

      onProgress?.call(OID4VCIStep.requestingCredential,
          'Meminta credential dengan proof JWT...');
      final requestedTypes = _resolveCredentialTypes(offer, metadata);

      final Map<String, dynamic> response;
      if (presentedVc != null && presentedVc.isNotEmpty) {
        final nativeEndpoint = _resolveSsiNativeEndpoint(metadata);
        response = await requestNativeCredential(
          ssiNativeEndpoint: nativeEndpoint,
          accessToken: session.accessToken,
          holderDid: proofHolderDid,
          proofJwt: proofJwt,
          presentedVc: presentedVc,
          credentialTypes: requestedTypes,
        );
      } else {
        response = await requestCredential(
          credentialEndpoint: metadata.credentialEndpoint,
          accessToken: session.accessToken,
          holderDid: proofHolderDid,
          proofJwt: proofJwt,
          credentialTypes: requestedTypes,
        );
      }

      final updatedNonce = response['c_nonce']?.toString();
      if (updatedNonce != null && updatedNonce.isNotEmpty) {
        session = session.copyWith(
          cNonce: updatedNonce,
          cNonceExpiresIn: _toInt(response['c_nonce_expires_in']),
          updatedAtEpochSeconds: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        );
        await SecureStorageService.saveOID4VCISession(
          metadata.credentialIssuer,
          session.toJson(),
        );
      }

      final rawJwt = _extractCredential(response);
      final credentialId = _extractCredentialId(rawJwt, response);
      final statusUrl = _buildStatusUrl(
        credentialIssuer: metadata.credentialIssuer,
        credentialId: credentialId,
      );

      onProgress?.call(OID4VCIStep.done, 'Credential berhasil diterima');
      debugPrint(
        '[OID4VCI][telemetry] request_id=$rid nik=${maskedNik ?? '-'} '
        'holder_did=${_maskDid(proofHolderDid)} status=success',
      );

      return OID4VCIResult(
        rawJwt: rawJwt,
        issuerDid: metadata.credentialIssuer,
        credentialTypes: requestedTypes,
        holderDid: resolvedHolderDid,
        credentialStatusUrl: statusUrl,
        grantTypeUsed: offer.hasPreAuthorizedCode
            ? 'pre-authorized_code'
            : 'authorization_code',
      );
    } catch (e) {
      final code = _extractErrorCode(e.toString());
      debugPrint(
        '[OID4VCI][telemetry] request_id=$rid nik=${maskedNik ?? '-'} '
        'holder_did=${_maskDid(holderDid)} status=error code=$code',
      );

      onProgress?.call(OID4VCIStep.error, e.toString());
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // HTTP helpers
  // ---------------------------------------------------------------------------

  static Future<Map<String, dynamic>> _getJson(String url) async {
    final client = HttpClient()
      ..badCertificateCallback = (cert, host, port) => true;

    try {
      final req = await client.getUrl(Uri.parse(url));
      req.headers.set('Accept', 'application/json, application/jwt');
      final resp = await req.close().timeout(_httpTimeout);
      final body = await resp.transform(utf8.decoder).join();

      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw Exception(_httpError(resp.statusCode, url, body));
      }

      return jsonDecode(body) as Map<String, dynamic>;
    } finally {
      client.close();
    }
  }

  static Future<Map<String, dynamic>> _postForm(
    String url,
    Map<String, String> params,
  ) async {
    final client = HttpClient()
      ..badCertificateCallback = (cert, host, port) => true;

    try {
      final req = await client.postUrl(Uri.parse(url));
      req.headers.contentType =
          ContentType('application', 'x-www-form-urlencoded');
      req.headers.set('Accept', 'application/json');

      final body = params.entries
          .map((e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');
      req.write(body);

      final resp = await req.close().timeout(_httpTimeout);
      final respBody = await resp.transform(utf8.decoder).join();

      Map<String, dynamic> json;
      try {
        json = jsonDecode(respBody) as Map<String, dynamic>;
      } catch (_) {
        if (resp.statusCode >= 400) {
          throw Exception(_httpError(resp.statusCode, url, respBody));
        }
        throw Exception('Response token endpoint bukan JSON valid');
      }

      if (resp.statusCode >= 400 || json.containsKey('error')) {
        throw _issuerErrorToException(json);
      }

      return json;
    } finally {
      client.close();
    }
  }

  static Future<Map<String, dynamic>> _postJson(
    String url,
    Map<String, dynamic> data,
    String accessToken,
  ) async {
    final client = HttpClient()
      ..badCertificateCallback = (cert, host, port) => true;

    try {
      final req = await client.postUrl(Uri.parse(url));
      req.headers.contentType = ContentType.json;
      req.headers.set('Accept', 'application/json');
      req.headers.set('Authorization', 'Bearer $accessToken');
      req.write(jsonEncode(data));

      final resp = await req.close().timeout(_httpTimeout);
      final body = await resp.transform(utf8.decoder).join();

      Map<String, dynamic> json;
      try {
        json = jsonDecode(body) as Map<String, dynamic>;
      } catch (_) {
        if (resp.statusCode >= 400) {
          throw Exception(_httpError(resp.statusCode, url, body));
        }
        throw Exception('Response credential endpoint bukan JSON valid');
      }

      if (resp.statusCode >= 400 || json.containsKey('error')) {
        throw _issuerErrorToException(json);
      }

      return json;
    } finally {
      client.close();
    }
  }

  // ---------------------------------------------------------------------------
  // Response parsing + errors
  // ---------------------------------------------------------------------------

  static String _extractCredential(Map<String, dynamic> response) {
    final credential = response['credential'];
    if (credential is String && credential.isNotEmpty) {
      return credential;
    }

    final credentials = response['credentials'];
    if (credentials is List && credentials.isNotEmpty) {
      final first = credentials.first;
      if (first is String && first.isNotEmpty) {
        return first;
      }
      if (first is Map && first['credential'] is String) {
        return first['credential'].toString();
      }
    }

    throw Exception('Credential tidak ditemukan pada respons issuer');
  }

  static String _extractCredentialId(
      String rawJwt, Map<String, dynamic> response) {
    final fromResponse = response['credential_id']?.toString();
    if (fromResponse != null && fromResponse.isNotEmpty) {
      return fromResponse;
    }

    try {
      final jwtPart = rawJwt.split('~').first;
      final segments = jwtPart.split('.');
      if (segments.length >= 2) {
        final payload = jsonDecode(utf8.decode(_b64UrlDecode(segments[1])))
            as Map<String, dynamic>;
        final jti = payload['jti']?.toString();
        if (jti != null && jti.isNotEmpty) {
          return jti;
        }
      }
    } catch (_) {}

    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  static List<String> _resolveCredentialTypes(
    CredentialOffer offer,
    IssuerMetadata metadata,
  ) {
    if (offer.credentialConfigurationIds.isNotEmpty) {
      final configId = offer.credentialConfigurationIds.first;
      final config = metadata.credentialConfigurationsSupported[configId];
      if (config is Map) {
        final credentialDefinition = config['credential_definition'];
        if (credentialDefinition is Map) {
          final types = credentialDefinition['type'];
          if (types is List && types.isNotEmpty) {
            return types.map((e) => e.toString()).toList();
          }
        }
      }
      return ['VerifiableCredential', configId];
    }

    return ['VerifiableCredential', 'IdentityCredential'];
  }

  static String _resolveSsiNativeEndpoint(IssuerMetadata metadata) {
    if (metadata.ssiNativeCredentialEndpoint.isNotEmpty) {
      return metadata.ssiNativeCredentialEndpoint;
    }

    final credentialEndpoint = metadata.credentialEndpoint;
    if (credentialEndpoint.endsWith('/credential')) {
      return '$credentialEndpoint/ssi-native';
    }

    return '${metadata.credentialIssuer}/credential/ssi-native';
  }

  static String _buildStatusUrl({
    required String credentialIssuer,
    required String credentialId,
  }) {
    final base = credentialIssuer.endsWith('/')
        ? credentialIssuer.substring(0, credentialIssuer.length - 1)
        : credentialIssuer;
    return '$base/credential/status/$credentialId';
  }

  static Exception _issuerErrorToException(Map<String, dynamic> json) {
    final error = json['error']?.toString() ?? 'server_error';
    final desc = json['error_description']?.toString() ??
        json['message']?.toString() ??
        'Tidak ada detail error dari issuer';

    switch (error) {
      case 'invalid_request':
        return Exception('invalid_request: $desc');
      case 'invalid_grant':
        return Exception('invalid_grant: $desc');
      case 'invalid_token':
        return Exception('invalid_token: $desc');
      case 'invalid_proof':
        return Exception(
          'invalid_proof: $desc. Silakan retry issuance agar proof dibangun '
          'ulang dengan nonce terbaru.',
        );
      case 'access_denied':
        if (desc.contains('did_binding_conflict') ||
            error == 'did_binding_conflict') {
          return Exception(
            'did_binding_conflict: Wallet profile ini sedang mengacu ke akun lain. '
            'Silakan ganti wallet profile atau lanjut dengan akun yang sesuai.',
          );
        }
        if (desc.contains('registry_match_below_threshold')) {
          return Exception(
            'access_denied: Issuance policy rejected (registry match di bawah threshold). '
            'Holder sudah mengirim request auth, namun issuer menolak karena kecocokan data rendah. '
            'Pastikan akun issuer yang digunakan sesuai NIK/identitas yang terdaftar.',
          );
        }
        return Exception('access_denied: $desc');
      case 'server_error':
        return Exception('server_error: $desc');
      default:
        return Exception('$error: $desc');
    }
  }

  static String _httpError(int statusCode, String url, String body) {
    final host = Uri.tryParse(url)?.host ?? url;
    String? jsonError;

    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      jsonError = json['error_description']?.toString() ??
          json['error']?.toString() ??
          json['message']?.toString();
    } catch (_) {}

    if (jsonError != null && jsonError.isNotEmpty) {
      return jsonError;
    }

    switch (statusCode) {
      case 400:
        return 'Permintaan tidak valid (400) ke $host';
      case 401:
        return 'Akses ditolak, token tidak valid atau kedaluwarsa (401)';
      case 403:
        return 'Akses ditolak (403)';
      case 404:
        return 'Endpoint issuer tidak ditemukan (404)';
      case 500:
      case 502:
      case 503:
        return 'Server issuer mengalami gangguan (HTTP $statusCode)';
      default:
        return 'HTTP $statusCode dari $host';
    }
  }

  // ---------------------------------------------------------------------------
  // Utility
  // ---------------------------------------------------------------------------

  static String _randomToken(int length) {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random.secure();
    final buf = StringBuffer();
    for (var i = 0; i < length; i++) {
      buf.write(chars[rand.nextInt(chars.length)]);
    }
    return buf.toString();
  }

  static int? _toInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  static String _b64UrlEncode(List<int> bytes) {
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  static Uint8List _b64UrlDecode(String input) {
    var normalized = input.replaceAll('-', '+').replaceAll('_', '/');
    while (normalized.length % 4 != 0) {
      normalized += '=';
    }
    return Uint8List.fromList(base64.decode(normalized));
  }

  static String _maskDid(String? did) {
    final value = did?.trim() ?? '';
    if (value.isEmpty) {
      return '-';
    }
    if (value.length <= 18) {
      return '${value.substring(0, value.length ~/ 2)}***';
    }
    return '${value.substring(0, 10)}***${value.substring(value.length - 6)}';
  }

  static String? _maskNik(String? nik) {
    final value = nik?.replaceAll(RegExp(r'\s+'), '') ?? '';
    if (value.isEmpty) return null;
    if (value.length <= 6) return '${value.substring(0, 2)}***';
    return '${value.substring(0, 3)}***${value.substring(value.length - 3)}';
  }

  static String _extractErrorCode(String raw) {
    final normalized = raw.replaceFirst('Exception: ', '').trim();
    final idx = normalized.indexOf(':');
    if (idx <= 0) return 'unknown';
    return normalized.substring(0, idx).trim();
  }

  static String _resolveProofAudience(
    IssuerMetadata metadata,
    OID4VCITokenSession session,
  ) {
    final tokenAudience = (session.tokenAudience ?? '').trim();
    if (_isValidProofAudience(tokenAudience)) {
      return tokenAudience;
    }

    final credentialEndpoint = metadata.credentialEndpoint.trim();
    if (_isValidProofAudience(credentialEndpoint)) {
      return credentialEndpoint;
    }

    final issuerIdentifier = metadata.credentialIssuer.trim();
    if (_isValidProofAudience(issuerIdentifier)) {
      return issuerIdentifier;
    }

    throw Exception(
      'issuer_audience_invalid: Tidak dapat menentukan audience URL valid '
      'untuk proof JWT dari metadata issuer.',
    );
  }

  static bool _isValidProofAudience(String audience) {
    if (audience.isEmpty || audience.startsWith('did:')) {
      return false;
    }

    final uri = Uri.tryParse(audience);
    if (uri == null) {
      return false;
    }

    return uri.scheme == 'http' || uri.scheme == 'https';
  }

  static String _resolveVerificationMethodKid(String holderDid) {
    // For did:jwk, VM id defaults to fragment #0.
    if (holderDid.startsWith('did:jwk:')) {
      return '$holderDid#0';
    }
    return '$holderDid#key-1';
  }

  static Future<String> _resolveProofHolderDid(
    String userId,
    String requestedHolderDid,
    OID4VCITokenSession session,
  ) async {
    final tokenDid = (session.tokenBoundDid ?? '').trim();
    if (tokenDid.isEmpty || tokenDid == requestedHolderDid) {
      return requestedHolderDid;
    }

    final canSign = await _canSignForDid(userId, tokenDid);
    if (!canSign) {
      throw Exception(
        'did_token_mismatch: Token issuer terikat ke DID lain '
        '(${_maskDid(tokenDid)}), namun wallet aktif tidak memiliki key yang sesuai. '
        'Silakan login ulang lalu ulangi issuance.',
      );
    }

    debugPrint(
      '[OID4VCI] Using token-bound holder DID for proof: '
      '${_maskDid(tokenDid)}',
    );
    return tokenDid;
  }

  static Future<bool> _canSignForDid(String userId, String did) async {
    if (did.trim().isEmpty) return false;

    final activeUserId = _requireIdentityUserId(userId: userId);
    final pubB64 = await SecureStorageService.loadHolderPublicKey(activeUserId);
    if (pubB64 == null || pubB64.isEmpty) return false;

    try {
      final pubBytes = base64.decode(pubB64);
      final derived = _buildDidJwkFromPublicKey(pubBytes);
      return derived == did;
    } catch (_) {
      return false;
    }
  }

  static String? _extractTokenBoundDid(Map<String, dynamic> tokenResponse) {
    final candidates = [
      tokenResponse['holder_did'],
      tokenResponse['holderDid'],
      tokenResponse['did'],
      tokenResponse['sub'],
    ];

    for (final candidate in candidates) {
      final value = candidate?.toString().trim() ?? '';
      if (value.startsWith('did:')) {
        return value;
      }
    }

    final accessToken = tokenResponse['access_token']?.toString() ?? '';
    final parts = accessToken.split('.');
    if (parts.length < 2) {
      return null;
    }

    try {
      final payload = jsonDecode(
        utf8.decode(_b64UrlDecode(parts[1])),
      ) as Map<String, dynamic>;

      final tokenCandidates = [
        payload['holder_did'],
        payload['holderDid'],
        payload['did'],
        payload['sub'],
      ];

      for (final candidate in tokenCandidates) {
        final value = candidate?.toString().trim() ?? '';
        if (value.startsWith('did:')) {
          return value;
        }
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  static String? _extractTokenAudience(Map<String, dynamic> tokenResponse) {
    final candidates = [
      tokenResponse['audience'],
      tokenResponse['aud'],
      tokenResponse['credential_audience'],
    ];

    for (final candidate in candidates) {
      final value = candidate?.toString().trim() ?? '';
      if (_isValidProofAudience(value)) {
        return value;
      }
    }

    final accessToken = tokenResponse['access_token']?.toString() ?? '';
    final parts = accessToken.split('.');
    if (parts.length < 2) {
      return null;
    }

    try {
      final payload = jsonDecode(
        utf8.decode(_b64UrlDecode(parts[1])),
      ) as Map<String, dynamic>;

      final audClaim = payload['aud'];
      if (audClaim is String && _isValidProofAudience(audClaim.trim())) {
        return audClaim.trim();
      }
      if (audClaim is List) {
        for (final item in audClaim) {
          final value = item?.toString().trim() ?? '';
          if (_isValidProofAudience(value)) {
            return value;
          }
        }
      }
    } catch (_) {
      return null;
    }

    return null;
  }
}

class _ValidatedHolderIdentity {
  final String did;
  final String privateKeyBase64;
  final String publicKeyBase64;

  const _ValidatedHolderIdentity({
    required this.did,
    required this.privateKeyBase64,
    required this.publicKeyBase64,
  });
}

enum OID4VCIStep {
  parsingOffer,
  fetchingMetadata,
  authorizing,
  exchangingToken,
  buildingProof,
  requestingCredential,
  done,
  error,
}

class OID4VCIResult {
  final String rawJwt;
  final String issuerDid;
  final List<String> credentialTypes;
  final String holderDid;
  final String credentialStatusUrl;
  final String grantTypeUsed;

  OID4VCIResult({
    required this.rawJwt,
    required this.issuerDid,
    required this.credentialTypes,
    required this.holderDid,
    required this.credentialStatusUrl,
    required this.grantTypeUsed,
  });
}

class OID4VCITokenSession {
  final String issuerKey;
  final String accessToken;
  final int? expiresIn;
  final String? tokenAudience;
  final String? tokenBoundDid;
  final String cNonce;
  final int? cNonceExpiresIn;
  final int updatedAtEpochSeconds;

  OID4VCITokenSession({
    required this.issuerKey,
    required this.accessToken,
    required this.expiresIn,
    required this.tokenAudience,
    required this.tokenBoundDid,
    required this.cNonce,
    required this.cNonceExpiresIn,
    required this.updatedAtEpochSeconds,
  });

  factory OID4VCITokenSession.fromTokenResponse(
    String issuerKey,
    Map<String, dynamic> json,
  ) {
    final accessToken = json['access_token']?.toString() ?? '';
    if (accessToken.isEmpty) {
      throw Exception(
          'Access token tidak ditemukan pada respons token endpoint');
    }

    final nonce = json['c_nonce']?.toString() ?? '';
    if (nonce.isEmpty) {
      throw Exception('c_nonce tidak ditemukan pada respons token endpoint');
    }

    return OID4VCITokenSession(
      issuerKey: issuerKey,
      accessToken: accessToken,
      expiresIn: OID4VCIService._toInt(json['expires_in']),
      tokenAudience: OID4VCIService._extractTokenAudience(json),
      tokenBoundDid: OID4VCIService._extractTokenBoundDid(json),
      cNonce: nonce,
      cNonceExpiresIn: OID4VCIService._toInt(json['c_nonce_expires_in']),
      updatedAtEpochSeconds: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
  }

  OID4VCITokenSession copyWith({
    String? accessToken,
    int? expiresIn,
    String? tokenAudience,
    String? tokenBoundDid,
    String? cNonce,
    int? cNonceExpiresIn,
    int? updatedAtEpochSeconds,
  }) {
    return OID4VCITokenSession(
      issuerKey: issuerKey,
      accessToken: accessToken ?? this.accessToken,
      expiresIn: expiresIn ?? this.expiresIn,
      tokenAudience: tokenAudience ?? this.tokenAudience,
      tokenBoundDid: tokenBoundDid ?? this.tokenBoundDid,
      cNonce: cNonce ?? this.cNonce,
      cNonceExpiresIn: cNonceExpiresIn ?? this.cNonceExpiresIn,
      updatedAtEpochSeconds:
          updatedAtEpochSeconds ?? this.updatedAtEpochSeconds,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'issuer_key': issuerKey,
      'access_token': accessToken,
      'expires_in': expiresIn,
      'token_audience': tokenAudience,
      'token_bound_did': tokenBoundDid,
      'c_nonce': cNonce,
      'c_nonce_expires_in': cNonceExpiresIn,
      'updated_at_epoch_seconds': updatedAtEpochSeconds,
    };
  }
}
