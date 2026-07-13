import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/credential_model.dart';
import '../models/presentation_models.dart';
import '../models/verification_result_model.dart';
import '../services/crypto_service.dart';
import '../services/secure_storage_service.dart';
import '../services/jwt_verifier_service.dart';
import '../services/oid4vci_service.dart';
import '../services/oid4vp_service.dart';
import '../services/sd_jwt_service.dart';
import '../services/identia_issuance_service.dart';
import '../services/credential_status_service.dart';

enum IssuanceStatus {
  idle,
  parsingOffer,
  fetchingMetadata,
  authorizing,
  exchangingToken,
  buildingProof,
  requestingCredential,
  saved,
  error
}

/// Status enum for the IDentia REST-based credential issuance flow.
enum IdentiaFlowStatus {
  idle,
  gettingHolderDid,
  requestingCredential,
  receivingCredential,
  validatingCredential,
  saving,
  done,
  error,
}

enum PresentationStatus {
  idle,
  parsingRequest,
  matchingCredentials,
  buildingVP,
  submitting,
  done,
  error
}

typedef OID4VCIFlowRunner = Future<OID4VCIResult> Function({
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
});

typedef HolderDidResolver = Future<String> Function(String userId);

class WalletProvider with ChangeNotifier {
  static const Duration _statusPollInterval = Duration(seconds: 20);

  final List<CredentialModel> _credentials = [];
  String _activeUserScope = 'global';
  bool _isLoading = false;
  bool _isSyncingStatuses = false;
  String? _lastScanResult;
  bool? _lastVerificationResult;
  DateTime? _lastStatusSyncAt;
  Timer? _statusRealtimeTimer;

  // Issuance flow state
  IssuanceStatus _issuanceStatus = IssuanceStatus.idle;
  String _issuanceMessage = '';
  String? _issuanceError;
  int _issuanceAttemptCounter = 0;
  int _activeIssuanceAttemptId = 0;
  final OID4VCIFlowRunner _issuanceFlowRunner;
  final HolderDidResolver _holderDidResolver;

  // IDentia issuance flow state
  IdentiaFlowStatus _identiaFlowStatus = IdentiaFlowStatus.idle;
  String _identiaFlowMessage = '';
  String? _identiaFlowError;

  // Presentation flow state
  PresentationStatus _presentationStatus = PresentationStatus.idle;
  String _presentationMessage = '';
  String? _presentationError;
  PresentationRequest? _pendingPresentationRequest;
  List<CredentialMatch> _matchedCredentials = [];

  List<CredentialModel> get credentials => _credentials;
  String? get preferredVerifiedNik {
    final activeCredentials = _credentials.where((c) => c.isActive).toList()
      ..sort((a, b) => b.issuedDate.compareTo(a.issuedDate));

    for (final credential in activeCredentials) {
      final fromDocument = credential.documentNumber.trim();
      if (fromDocument.isNotEmpty) {
        return fromDocument;
      }

      final additional = credential.additionalData;
      if (additional == null) continue;

      final candidates = [
        additional['nik'],
        additional['NIK'],
        additional['national_id'],
        additional['nationalId'],
        additional['nomor_induk_kependudukan'],
      ];

      for (final candidate in candidates) {
        final value = candidate?.toString().trim() ?? '';
        if (value.isNotEmpty) {
          return value;
        }
      }
    }

    return null;
  }

  bool get isLoading => _isLoading;
  bool get isSyncingStatuses => _isSyncingStatuses;
  DateTime? get lastStatusSyncAt => _lastStatusSyncAt;
  String? get lastScanResult => _lastScanResult;
  bool? get lastVerificationResult => _lastVerificationResult;
  IssuanceStatus get issuanceStatus => _issuanceStatus;
  String get issuanceMessage => _issuanceMessage;
  String? get issuanceError => _issuanceError;
  IdentiaFlowStatus get identiaFlowStatus => _identiaFlowStatus;
  String get identiaFlowMessage => _identiaFlowMessage;
  String? get identiaFlowError => _identiaFlowError;
  PresentationStatus get presentationStatus => _presentationStatus;
  String get presentationMessage => _presentationMessage;
  String? get presentationError => _presentationError;
  PresentationRequest? get pendingPresentationRequest =>
      _pendingPresentationRequest;
  List<CredentialMatch> get matchedCredentials => _matchedCredentials;

  WalletProvider({
    OID4VCIFlowRunner? issuanceFlowRunner,
    HolderDidResolver? holderDidResolver,
  })  : _issuanceFlowRunner =
            issuanceFlowRunner ?? OID4VCIService.fullIssuanceFlow,
        _holderDidResolver = holderDidResolver ??
            ((userId) => OID4VCIService.ensureHolderDid(userId: userId)) {
    _configureStatusRealtimeSync();
    unawaited(_loadCredentials());
  }

  void updateUserScope(String? userScope) {
    final normalized = (userScope ?? '').trim().toLowerCase();
    final nextScope = normalized.isEmpty ? 'global' : normalized;
    if (_activeUserScope == nextScope) return;

    OID4VCIService.reset();
    if (nextScope != 'global') {
      OID4VCIService.setActiveIdentityUser(nextScope);
    }
    _activeUserScope = nextScope;
    _configureStatusRealtimeSync();
    unawaited(_loadCredentials());
  }

  void _configureStatusRealtimeSync() {
    final shouldRun = _activeUserScope.trim().isNotEmpty &&
        _activeUserScope.trim() != 'global';

    if (!shouldRun) {
      _statusRealtimeTimer?.cancel();
      _statusRealtimeTimer = null;
      return;
    }

    if (_statusRealtimeTimer != null && _statusRealtimeTimer!.isActive) {
      return;
    }

    _statusRealtimeTimer = Timer.periodic(_statusPollInterval, (_) {
      if (_credentials.isEmpty || _isSyncingStatuses) {
        return;
      }

      unawaited(() async {
        final updated = await syncCredentialStatuses(silent: true);
        if (updated > 0) {
          debugPrint(
            '[WalletProvider] Realtime status update applied: $updated credential(s)',
          );
        }
      }());
    });
  }

  Future<void> _loadCredentials() async {
    try {
      await SecureStorageService.setStorageScope(_activeUserScope);
      final saved = await SecureStorageService.loadAllCredentialModels();
      _credentials.clear();
      _credentials.addAll(saved);
      _configureStatusRealtimeSync();
      debugPrint(
          '[WalletProvider] Loaded ${saved.length} credentials from secure storage');
      await syncCredentialStatuses(silent: true);
    } catch (e) {
      debugPrint('[WalletProvider] Error loading credentials: $e');
    }
    notifyListeners();
  }

  void clearWalletSession() {
    _statusRealtimeTimer?.cancel();
    _statusRealtimeTimer = null;
    _credentials.clear();
    _isLoading = false;
    _isSyncingStatuses = false;
    _lastScanResult = null;
    _lastVerificationResult = null;
    _lastStatusSyncAt = null;

    _issuanceStatus = IssuanceStatus.idle;
    _issuanceMessage = '';
    _issuanceError = null;

    _identiaFlowStatus = IdentiaFlowStatus.idle;
    _identiaFlowMessage = '';
    _identiaFlowError = null;

    _presentationStatus = PresentationStatus.idle;
    _presentationMessage = '';
    _presentationError = null;
    _pendingPresentationRequest = null;
    _matchedCredentials = [];

    notifyListeners();
  }

  Future<void> refreshWalletData() async {
    await _loadCredentials();
  }

  Future<int> syncCredentialStatuses({bool silent = false}) async {
    if (_isSyncingStatuses) return 0;

    _isSyncingStatuses = true;
    if (!silent) {
      notifyListeners();
    }

    var updatedCount = 0;
    try {
      for (var i = 0; i < _credentials.length; i++) {
        final credential = _credentials[i];
        final statusUrl = credential.credentialStatusUrl ??
            _buildFallbackStatusUrl(credential);
        if (statusUrl == null || statusUrl.isEmpty) {
          continue;
        }

        try {
          final result = await CredentialStatusService.fetchStatus(statusUrl);
          final updated = credential.copyWith(
            syncedStatus: result.status,
            statusActive: result.active,
            statusCheckedAt: result.checkedAt,
          );

          final isChanged = updated.syncedStatus != credential.syncedStatus ||
              updated.statusActive != credential.statusActive ||
              updated.statusCheckedAt != credential.statusCheckedAt;

          if (isChanged) {
            _credentials[i] = updated;
            await SecureStorageService.saveCredentialMetadata(
                updated.id, updated);
            updatedCount++;
          }
        } catch (e) {
          debugPrint(
              '[WalletProvider] Failed syncing status for ${credential.id}: $e');
        }
      }
      _lastStatusSyncAt = DateTime.now();
      return updatedCount;
    } finally {
      _isSyncingStatuses = false;
      notifyListeners();
    }
  }

  // Demo data dihapus — wallet mulai kosong dan diisi via OID4VCI

  // ─── QR Scan ────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> scanAndVerifyQR(String qrData) async {
    _isLoading = true;
    _lastScanResult = qrData;
    notifyListeners();

    try {
      debugPrint(
          '[WalletProvider] Processing QR: ${qrData.substring(0, qrData.length > 100 ? 100 : qrData.length)}');
      final result = await CryptoService.processQRData(qrData);

      _lastVerificationResult = result['isValid'];

      if (result['isValid'] == true &&
          result['isVerifierRequest'] != true &&
          result['credential'] != null) {
        final credential = result['credential'] as CredentialModel;
        _addOrUpdateCredential(credential);
      }

      _isLoading = false;
      notifyListeners();
      return result;
    } catch (e) {
      debugPrint('[WalletProvider] Error: $e');
      _isLoading = false;
      _lastVerificationResult = false;
      notifyListeners();
      return {'isValid': false, 'error': 'Kesalahan memproses QR Code: $e'};
    }
  }

  // ─── OID4VCI Issuance ────────────────────────────────────────────────────

  Future<void> startIssuanceFlow(
    String deepLink, {
    String clientId = '',
    String redirectUri = 'identia://callback',
    String? authIdentifier,
    String? authPassword,
    String? presentedVc,
    String? userNik,
  }) async {
    final attemptId = ++_issuanceAttemptCounter;
    _activeIssuanceAttemptId = attemptId;
    final requestId =
        'oid4vci-${DateTime.now().millisecondsSinceEpoch}-$attemptId';

    _issuanceStatus = IssuanceStatus.parsingOffer;
    _issuanceMessage = 'Memulai proses issuance...';
    _issuanceError = null;
    debugPrint('[WalletProvider][OID4VCI] request_id=$requestId status=submit');
    notifyListeners();

    try {
      final activeUserId = _activeUserScope.trim();
      if (activeUserId.isEmpty || activeUserId == 'global') {
        throw Exception(
          'active_user_required: Tidak ada user aktif untuk issuance.',
        );
      }

      final holderDid = (await _holderDidResolver(activeUserId)).trim();
      if (holderDid.isEmpty) {
        throw Exception(
          'holder_did_missing: Holder DID belum tersedia pada wallet aktif. '
          'Silakan buka ulang aplikasi, login kembali, lalu coba issuance lagi.',
        );
      }

      if (!_isCurrentIssuanceAttempt(attemptId)) {
        return;
      }

      final result = await _issuanceFlowRunner(
        userId: activeUserId,
        credentialOfferInput: deepLink,
        clientId: clientId,
        redirectUri: redirectUri,
        holderDid: holderDid,
        authIdentifier: authIdentifier,
        authPassword: authPassword,
        presentedVc: presentedVc,
        requestId: requestId,
        userNik: userNik,
        onProgress: (step, message) {
          if (!_isCurrentIssuanceAttempt(attemptId)) {
            return;
          }

          _issuanceMessage = message;
          if (step != OID4VCIStep.error) {
            _issuanceError = null;
          }

          switch (step) {
            case OID4VCIStep.parsingOffer:
              _issuanceStatus = IssuanceStatus.parsingOffer;
              break;
            case OID4VCIStep.fetchingMetadata:
              _issuanceStatus = IssuanceStatus.fetchingMetadata;
              break;
            case OID4VCIStep.authorizing:
              _issuanceStatus = IssuanceStatus.authorizing;
              break;
            case OID4VCIStep.exchangingToken:
              _issuanceStatus = IssuanceStatus.exchangingToken;
              break;
            case OID4VCIStep.buildingProof:
              _issuanceStatus = IssuanceStatus.buildingProof;
              break;
            case OID4VCIStep.requestingCredential:
              _issuanceStatus = IssuanceStatus.requestingCredential;
              break;
            case OID4VCIStep.done:
              _issuanceStatus = IssuanceStatus.saved;
              break;
            case OID4VCIStep.error:
              _issuanceStatus = IssuanceStatus.error;
              break;
          }
          notifyListeners();
        },
      );

      if (!_isCurrentIssuanceAttempt(attemptId)) {
        return;
      }

      // Parse and save the received JWT credential
      final credential = await _buildCredentialFromJWT(
          result.rawJwt, result.issuerDid, result.credentialTypes);
      final credentialWithStatus = credential.copyWith(
        issuerDid: result.issuerDid,
        credentialStatusUrl: result.credentialStatusUrl,
      );
      await _saveCredential(credentialWithStatus, result.rawJwt);

      _issuanceStatus = IssuanceStatus.saved;
      _issuanceMessage = 'Credential berhasil disimpan!';
      _issuanceError = null;
      notifyListeners();
    } catch (e) {
      if (!_isCurrentIssuanceAttempt(attemptId)) {
        return;
      }

      debugPrint('[WalletProvider] Issuance flow error: $e');
      _issuanceStatus = IssuanceStatus.error;
      _issuanceError = e.toString();
      _issuanceMessage = 'Gagal mendapatkan credential';
      notifyListeners();
    }
  }

  Future<CredentialModel> _buildCredentialFromJWT(
    String rawJwt,
    String issuerDid,
    List<String> credentialTypes,
  ) async {
    final parts = rawJwt.split('~');
    final jwtPart = parts[0];
    final jwtSegments = jwtPart.split('.');
    final isSDJWT = parts.length > 1;

    Map<String, dynamic> payload = {};
    Map<String, dynamic> claims = {};

    if (jwtSegments.length >= 2) {
      try {
        String b64 = jwtSegments[1].replaceAll('-', '+').replaceAll('_', '/');
        while (b64.length % 4 != 0) {
          b64 += '=';
        }
        final payloadJson = String.fromCharCodes(base64.decode(b64));
        payload = jsonDecode(payloadJson) as Map<String, dynamic>;
      } catch (e) {
        debugPrint('[WalletProvider] Error decoding JWT payload: $e');
      }
    }

    if (isSDJWT) {
      final parsed = SDJWTService.parseSDJWT(rawJwt);
      claims = SDJWTService.flattenClaims(parsed);
    } else {
      claims = {...payload};
      final vc = payload['vc'];
      if (vc is Map) {
        final cs = vc['credentialSubject'];
        if (cs is Map) {
          for (final e in cs.entries) {
            claims[e.key] = e.value;
          }
        }
      }
    }

    final id = payload['jti']?.toString() ??
        payload['sub']?.toString() ??
        DateTime.now().millisecondsSinceEpoch.toString();

    final holderName = claims['nama']?.toString() ??
        claims['name']?.toString() ??
        claims['holderName']?.toString() ??
        claims['nama_lengkap']?.toString() ??
        '';

    final docNumber = claims['nik']?.toString() ??
        claims['noBPJS']?.toString() ??
        claims['documentNumber']?.toString() ??
        '';

    final iss = payload['iss']?.toString() ?? issuerDid;
    String? credentialStatusUrl;

    final vcPayload = payload['vc'];
    if (vcPayload is Map) {
      final credentialStatus = vcPayload['credentialStatus'];
      if (credentialStatus is Map) {
        credentialStatusUrl = credentialStatus['id']?.toString();
      } else if (credentialStatus is String) {
        credentialStatusUrl = credentialStatus;
      }
    }

    // Parse dates
    DateTime issuedDate = DateTime.now();
    final iat = payload['iat'];
    if (iat is int) {
      issuedDate = DateTime.fromMillisecondsSinceEpoch(iat * 1000);
    }

    DateTime? expiryDate;
    final exp = payload['exp'];
    if (exp is int) {
      expiryDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
    }

    // Determine type label
    String typeLabel = credentialTypes.lastWhere(
      (t) => t != 'VerifiableCredential',
      orElse: () => credentialTypes.isNotEmpty
          ? credentialTypes.first
          : 'Verifiable Credential',
    );

    final vc = payload['vc'];
    if (vc is Map) {
      final types = vc['type'];
      if (types is List) {
        typeLabel = types
            .lastWhere(
              (t) => t != 'VerifiableCredential',
              orElse: () => typeLabel,
            )
            .toString();
      }
    }

    // Collect additional claims
    final additionalData = <String, dynamic>{};
    const standardKeys = {
      'iss',
      'sub',
      'iat',
      'exp',
      'nbf',
      'jti',
      'vc',
      '@context',
      '_sd',
      '_sd_alg'
    };
    for (final entry in claims.entries) {
      if (!standardKeys.contains(entry.key) && entry.value != null) {
        additionalData[entry.key] = entry.value;
      }
    }

    return CredentialModel(
      id: id,
      type: typeLabel,
      issuer: iss,
      holderName: holderName,
      documentNumber: docNumber,
      issuedDate: issuedDate,
      expiryDate: expiryDate,
      isVerified: true,
      additionalData: additionalData.isNotEmpty ? additionalData : null,
      rawJwt: rawJwt,
      format: isSDJWT ? 'vc+sd-jwt' : 'jwt_vc_json',
      issuerDid: issuerDid,
      credentialStatusUrl: credentialStatusUrl,
    );
  }

  Future<void> _saveCredential(
      CredentialModel credential, String rawJwt) async {
    try {
      await SecureStorageService.setStorageScope(_activeUserScope);
      var toStore = credential;
      final hasCollision =
          _credentials.any((existing) => existing.id == credential.id);
      if (hasCollision) {
        final uniqueId =
            '${credential.id}-${DateTime.now().millisecondsSinceEpoch}';
        toStore = credential.copyWith(id: uniqueId);
      }

      await SecureStorageService.saveCredential(toStore.id, rawJwt);
      await SecureStorageService.saveCredentialMetadata(toStore.id, toStore);
      _addOrUpdateCredential(toStore);
      await syncCredentialStatuses(silent: true);
      debugPrint('[WalletProvider] Credential saved: ${toStore.type}');
    } catch (e) {
      debugPrint('[WalletProvider] Error saving credential: $e');
    }
  }

  void _addOrUpdateCredential(CredentialModel credential) {
    final existingIndex = _credentials.indexWhere((c) => c.id == credential.id);
    if (existingIndex == -1) {
      _credentials.add(credential);
    } else {
      _credentials[existingIndex] = credential;
    }
    notifyListeners();
  }

  void resetIssuanceStatus() {
    _activeIssuanceAttemptId = ++_issuanceAttemptCounter;
    _issuanceStatus = IssuanceStatus.idle;
    _issuanceMessage = '';
    _issuanceError = null;
    notifyListeners();
  }

  bool _isCurrentIssuanceAttempt(int attemptId) {
    return attemptId == _activeIssuanceAttemptId;
  }

  // ─── IDentia Issuance (Custom REST Flow) ──────────────────────────────────

  /// Run the IDentia-specific credential issuance flow:
  ///   1. GET holder DID
  ///   2. POST /request-credential with Bearer token
  ///   3. Validate received JWT VC
  ///   4. Save to secure storage
  Future<void> startIdentiaIssuanceFlow({
    required String issuerBaseUrl,
    required String sessionToken,
    required String holderDid,
  }) async {
    _identiaFlowStatus = IdentiaFlowStatus.gettingHolderDid;
    _identiaFlowMessage = 'Mengambil Holder DID...';
    _identiaFlowError = null;
    notifyListeners();

    try {
      // Step 1 — confirm holderDid (already resolved by login screen)
      debugPrint('[WalletProvider] IDentia holderDid: $holderDid');
      await Future.delayed(const Duration(milliseconds: 300)); // brief UX pause

      // Step 2 — request credential
      _identiaFlowStatus = IdentiaFlowStatus.requestingCredential;
      _identiaFlowMessage = 'Mengirim permintaan credential...';
      notifyListeners();

      final rawJwt = await IdentiaIssuanceService.requestCredential(
        issuerBaseUrl: issuerBaseUrl,
        token: sessionToken,
        holderDid: holderDid,
      );

      // Step 3 — receiving (update status)
      _identiaFlowStatus = IdentiaFlowStatus.receivingCredential;
      _identiaFlowMessage = 'Credential JWT diterima...';
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 300));

      // Step 4 — validate
      _identiaFlowStatus = IdentiaFlowStatus.validatingCredential;
      _identiaFlowMessage = 'Memvalidasi credential...';
      notifyListeners();
      IdentiaIssuanceService.validateCredential(rawJwt, holderDid);

      // Step 5 — save
      _identiaFlowStatus = IdentiaFlowStatus.saving;
      _identiaFlowMessage = 'Menyimpan credential ke wallet...';
      notifyListeners();

      final credential = await _buildCredentialFromJWT(
        rawJwt,
        issuerBaseUrl, // use issuer base URL as issuerDid placeholder
        ['VerifiableCredential'],
      );
      await _saveCredential(credential, rawJwt);

      _identiaFlowStatus = IdentiaFlowStatus.done;
      _identiaFlowMessage = 'Credential berhasil disimpan!';
      notifyListeners();
    } catch (e) {
      debugPrint('[WalletProvider] IDentia issuance error: $e');
      _identiaFlowStatus = IdentiaFlowStatus.error;
      _identiaFlowError = e.toString().replaceFirst('Exception: ', '');
      _identiaFlowMessage = 'Gagal mendapatkan credential';
      notifyListeners();
    }
  }

  void resetIdentiaFlowStatus() {
    _identiaFlowStatus = IdentiaFlowStatus.idle;
    _identiaFlowMessage = '';
    _identiaFlowError = null;
    notifyListeners();
  }

  // ─── OID4VP Presentation ─────────────────────────────────────────────────

  Future<PresentationRequest?> preparePresentationRequest(String qrData) async {
    _presentationStatus = PresentationStatus.parsingRequest;
    _presentationMessage = 'Memproses permintaan verifikasi...';
    _presentationError = null;
    notifyListeners();

    try {
      final request = await OID4VPService.parseRequest(qrData);
      if (request.clientId.trim().isEmpty) {
        throw Exception(
          'client_id_missing: Authorization request tidak memiliki client_id verifier.',
        );
      }
      _pendingPresentationRequest = request;

      if (request.presentationDefinition != null) {
        _matchedCredentials = OID4VPService.matchCredentials(
          request.presentationDefinition!,
          _credentials.where((c) => c.isActive).toList(),
        );
      } else {
        _matchedCredentials = _credentials
            .where((c) => c.isActive)
            .map((c) => CredentialMatch(
                credential: c, descriptorId: 'id', requestedFields: []))
            .toList();
      }

      _presentationStatus = PresentationStatus.matchingCredentials;
      _presentationMessage =
          '${_matchedCredentials.length} credential tersedia';
      notifyListeners();
      return request;
    } catch (e) {
      debugPrint('[WalletProvider] Error preparing presentation: $e');
      _presentationStatus = PresentationStatus.error;
      _presentationError = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> submitPresentation({
    required CredentialModel credential,
    required List<String> selectedClaims,
    String descriptorId = 'id',
  }) async {
    final authorizationRequest = _pendingPresentationRequest;
    if (authorizationRequest == null) {
      _presentationStatus = PresentationStatus.error;
      _presentationError =
          'request_missing: Permintaan verifikasi tidak ditemukan. Silakan scan QR ulang.';
      notifyListeners();
      return false;
    }
    final verifierClientId = authorizationRequest.clientId.trim();
    if (verifierClientId.isEmpty) {
      _presentationStatus = PresentationStatus.error;
      _presentationError =
          'client_id_missing: client_id verifier tidak ditemukan pada authorization request.';
      notifyListeners();
      return false;
    }
    final requestNonce = (authorizationRequest.nonce ?? '').trim();
    if (requestNonce.isEmpty) {
      _presentationStatus = PresentationStatus.error;
      _presentationError =
          'nonce_missing: nonce authorization request belum tersedia.';
      notifyListeners();
      return false;
    }
    final requestState = (authorizationRequest.state ?? '').trim();
    if (requestState.isEmpty) {
      _presentationStatus = PresentationStatus.error;
      _presentationError =
          'state_missing: state authorization request belum tersedia.';
      notifyListeners();
      return false;
    }
    final requestUri = (authorizationRequest.requestUri ?? '').trim();
    if (requestUri.isEmpty) {
      _presentationStatus = PresentationStatus.error;
      _presentationError =
          'request_uri_missing: request_uri authorization request belum tersedia.';
      notifyListeners();
      return false;
    }

    _presentationStatus = PresentationStatus.buildingVP;
    _presentationMessage = 'Membangun Verifiable Presentation...';
    _presentationError = null;
    notifyListeners();

    try {
      final activeUserId = _activeUserScope.trim();
      if (activeUserId.isEmpty || activeUserId == 'global') {
        throw Exception(
          'active_user_required: Tidak ada user aktif untuk presentasi.',
        );
      }

      _presentationMessage = 'Membangun Verifiable Presentation...';
      _presentationStatus = PresentationStatus.buildingVP;
      notifyListeners();

      final vpToken = await OID4VPService.buildVPToken(
        userId: activeUserId,
        credential: credential,
        request: authorizationRequest,
        selectedClaims: selectedClaims,
      );

      final normalizedFormat =
          credential.format == 'vc+sd-jwt' ? 'vc+sd-jwt' : 'jwt_vc';
      final vcLength = credential.rawJwt?.length ?? 0;
      debugPrint('VP AUD: $verifierClientId');
      debugPrint('VP NONCE: $requestNonce');
      debugPrint('VC FORMAT: $normalizedFormat');
      debugPrint('VC LENGTH: $vcLength');

      final submission = authorizationRequest.presentationDefinition != null
          ? OID4VPService.buildPresentationSubmission(
              definition: authorizationRequest.presentationDefinition!,
              credential: credential,
              descriptorId: descriptorId,
            )
          : <String, dynamic>{};

      _presentationMessage = 'Mengirim presentasi ke verifier...';
      _presentationStatus = PresentationStatus.submitting;
      notifyListeners();

      final submitResult = await OID4VPService.submitPresentation(
        request: authorizationRequest,
        vpToken: vpToken,
        presentationSubmission: submission,
      );

      final success = submitResult.success;
      _presentationStatus =
          success ? PresentationStatus.done : PresentationStatus.error;
      if (success) {
        _presentationMessage = 'Presentasi berhasil dikirim ke verifier!';
        _presentationError = null;
      } else {
        final body = submitResult.responseBody.trim();
        final bodyPreview = body.isEmpty
            ? '-'
            : (body.length > 240 ? '${body.substring(0, 240)}...' : body);
        _presentationError =
            'verifier_error: HTTP ${submitResult.statusCode} | body=$bodyPreview';
        _presentationMessage =
            'Verifier menolak presentasi (HTTP ${submitResult.statusCode})';
      }
      notifyListeners();
      return success;
    } catch (e) {
      debugPrint('[WalletProvider] Presentation error: $e');
      _presentationStatus = PresentationStatus.error;
      _presentationError = e.toString().replaceFirst('Exception: ', '');
      _presentationMessage = 'Gagal mengirim presentasi ke verifier';
      notifyListeners();
      return false;
    }
  }

  void resetPresentationStatus() {
    _presentationStatus = PresentationStatus.idle;
    _presentationMessage = '';
    _presentationError = null;
    _pendingPresentationRequest = null;
    _matchedCredentials = [];
    notifyListeners();
  }

  // ─── Credential Verification ──────────────────────────────────────────────

  Future<VerificationResult> verifyCredential(
      CredentialModel credential) async {
    if (credential.rawJwt == null) {
      return VerificationResult(
        signatureValid: false,
        issuerTrusted: false,
        claimsValid: false,
        timingValid: false,
        errors: [
          'Credential tidak memiliki rawJwt untuk diverifikasi (credential demo lokal)'
        ],
      );
    }

    final isSDJWT = credential.rawJwt!.contains('~');
    if (isSDJWT) {
      return JWTVerifierService.verifyJWT(credential.rawJwt!.split('~')[0]);
    } else {
      return JWTVerifierService.verifyJWT(credential.rawJwt!);
    }
  }

  // ─── Misc ─────────────────────────────────────────────────────────────────

  List<CredentialModel> getMatchingCredentials(List<dynamic> requestedTypes) {
    return _credentials.where((c) {
      if (!c.isActive) return false;
      return requestedTypes.any((type) =>
          c.type.toLowerCase().contains(type.toString().toLowerCase()));
    }).toList();
  }

  Future<void> removeCredential(String id) async {
    try {
      await SecureStorageService.setStorageScope(_activeUserScope);
      await SecureStorageService.deleteCredential(id);
    } catch (e) {
      debugPrint('[WalletProvider] Error deleting from storage: $e');
    }
    _credentials.removeWhere((c) => c.id == id);
    notifyListeners();
  }

  void clearLastScan() {
    _lastScanResult = null;
    _lastVerificationResult = null;
    notifyListeners();
  }

  String? _buildFallbackStatusUrl(CredentialModel credential) {
    final issuer = credential.issuerDid ?? credential.issuer;
    if (issuer.isEmpty || credential.id.isEmpty) {
      return null;
    }

    final base =
        issuer.endsWith('/') ? issuer.substring(0, issuer.length - 1) : issuer;
    return '$base/credential/status/${credential.id}';
  }

  @override
  void dispose() {
    _statusRealtimeTimer?.cancel();
    _statusRealtimeTimer = null;
    super.dispose();
  }
}
