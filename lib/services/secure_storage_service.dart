import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cryptography/cryptography.dart';
import '../models/credential_model.dart';

/// Secure storage service for VC credentials and tokens.
/// Uses flutter_secure_storage (Keystore on Android, Keychain on iOS).
class SecureStorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const _vcPrefix = 'vc_';
  static const _tokenPrefix = 'token_';
  static const _holderDidKey = 'holder_did';
  static const _holderPrivateKey = 'holder_private_key';
  static const _holderPublicKey = 'holder_public_key';
  static const _oid4vciSessionPrefix = 'oid4vci_session_';
  static const _accountPasswordPrefix = 'account_password_';
  static const _pinCodeKey = 'settings_pin_code';
  static const _scopeAesKey = 'aes_scope_key';
  static const _userAesKeyPrefix = 'aes_user_key_';
  static const _encPrefix = 'enc_v1:';
  static var _currentScope = 'global';
  static final _cipher = AesGcm.with256bits();

  /// Scope storage per user so multiple accounts can coexist on one device.
  static Future<void> setStorageScope(String? scope) async {
    _currentScope = _normalizeScope(scope);
    debugPrint('[SecureStorage] Active scope: $_currentScope');
  }

  static String _normalizeScope(String? scope) {
    final raw = (scope ?? '').trim().toLowerCase();
    if (raw.isEmpty) {
      return 'global';
    }
    return raw.replaceAll(RegExp(r'[^a-z0-9._-]'), '_');
  }

  static String get activeScope => _currentScope;

  static String _scoped(String key) => 's:$_currentScope:$key';

  static String _legacyVcKey(String id) => '$_vcPrefix$id';
  static String _legacyVcMetaKey(String id) => '${_vcPrefix}meta_$id';

  static Future<String?> _readScopedFirstThenGlobal(String key) async {
    final scoped = await _storage.read(key: _scoped(key));
    if (scoped != null && scoped.isNotEmpty) {
      return scoped;
    }
    return _storage.read(key: key);
  }

  static Future<String?> _readScopedFirstThenLegacyGlobalAndMigrateToScope(
      String key) async {
    final scopedKey = _scoped(key);
    final scoped = await _storage.read(key: scopedKey);
    if (scoped != null && scoped.isNotEmpty) {
      return scoped;
    }

    final legacyGlobal = await _storage.read(key: key);
    if (legacyGlobal == null || legacyGlobal.isEmpty) {
      return null;
    }

    if (_currentScope != 'global') {
      // Migrate once from old global key into active account scope.
      await _storage.write(key: scopedKey, value: legacyGlobal);
      await _storage.delete(key: key);
      return legacyGlobal;
    }

    // Never reuse legacy global holder identity in shared/global scope.
    return null;
  }

  static Future<String?> _readScopedOnly(String key) async {
    return _storage.read(key: _scoped(key));
  }

  static String _normalizeUserId(String userId) {
    final normalized = userId.trim().toLowerCase();
    if (normalized.isEmpty || normalized == 'global') {
      throw Exception('active_user_required: userId aktif wajib tersedia');
    }
    return normalized.replaceAll(RegExp(r'[^a-z0-9._-]'), '_');
  }

  static String _identityDidKeyForUser(String userId) =>
      '${_holderDidKey}_${_normalizeUserId(userId)}';

  static String _identityPrivateKeyForUser(String userId) =>
      '${_holderPrivateKey}_${_normalizeUserId(userId)}';

  static String _identityPublicKeyForUser(String userId) =>
      '${_holderPublicKey}_${_normalizeUserId(userId)}';

  static String _accountPasswordKeyForUser(String userId) =>
      '$_accountPasswordPrefix${_normalizeUserId(userId)}';

  static String _aesKeyForUser(String userId) =>
      '$_userAesKeyPrefix${_normalizeUserId(userId)}';

  /// Delete legacy global holder identity keys to prevent cross-user reuse.
  static Future<void> purgeLegacyGlobalHolderIdentity() async {
    await _storage.delete(key: _holderDidKey);
    await _storage.delete(key: _holderPrivateKey);
    await _storage.delete(key: _holderPublicKey);
  }

  /// Load all per-user holder DID values as userId -> DID mapping.
  static Future<Map<String, String>> loadHolderDidMapByUser() async {
    final all = await _storage.readAll();
    final result = <String, String>{};
    final didPrefix = '${_holderDidKey}_';

    for (final entry in all.entries) {
      final key = entry.key;
      if (!key.startsWith(didPrefix)) {
        continue;
      }

      final value = entry.value.trim();
      if (value.isEmpty) {
        continue;
      }

      final userId = key.substring(didPrefix.length).trim();
      if (userId.isEmpty) {
        continue;
      }

      result[userId] = value;
    }

    return result;
  }

  /// Ensure DID for userId does not match DID from any other user.
  static Future<void> assertUniqueHolderDidForUser({
    required String userId,
    required String holderDid,
  }) async {
    final normalizedUserId = _normalizeUserId(userId);
    final normalizedDid = holderDid.trim();
    if (normalizedDid.isEmpty) {
      throw Exception('holder_did_invalid: Holder DID tidak boleh kosong');
    }

    final allMap = await loadHolderDidMapByUser();
    final conflicts = <String>[];

    for (final entry in allMap.entries) {
      if (entry.key == normalizedUserId) {
        continue;
      }
      if (entry.value == normalizedDid) {
        conflicts.add(entry.key);
      }
    }

    final mappingLog =
        allMap.entries.map((e) => '${e.key}->${e.value}').join(', ');
    debugPrint(
      '[SecureStorage] Holder DID map: ${mappingLog.isEmpty ? '-' : mappingLog}',
    );

    if (conflicts.isNotEmpty) {
      throw Exception(
        'critical_did_conflict: DID aktif dipakai juga oleh user lain '
        '(userId=${conflicts.join(',')}).',
      );
    }
  }

  /// Remove holder DID + keypair for a specific user.
  static Future<void> clearHolderIdentityForUser(String userId) async {
    await _storage.delete(key: _identityDidKeyForUser(userId));
    await _storage.delete(key: _identityPrivateKeyForUser(userId));
    await _storage.delete(key: _identityPublicKeyForUser(userId));
  }

  /// Save account password in secure storage (per-user).
  static Future<void> saveAccountPassword({
    required String userId,
    required String password,
  }) async {
    final encrypted = await _encryptForUser(userId, password);
    await _storage.write(
      key: _accountPasswordKeyForUser(userId),
      value: encrypted,
    );
  }

  /// Load account password from secure storage (per-user).
  static Future<String?> loadAccountPassword(String userId) async {
    final raw = await _storage.read(key: _accountPasswordKeyForUser(userId));
    if (raw == null) return null;
    return _decryptForUser(userId, raw);
  }

  /// Remove account password from secure storage (per-user).
  static Future<void> clearAccountPassword(String userId) async {
    await _storage.delete(key: _accountPasswordKeyForUser(userId));
  }

  /// If user shares a DID with other users, clear user identity.
  /// Caller should generate a fresh keypair + DID afterwards.
  static Future<bool> clearHolderIdentityIfDidDuplicatedForUser(
    String userId,
  ) async {
    final normalizedUserId = _normalizeUserId(userId);
    final allMap = await loadHolderDidMapByUser();
    final activeDid = allMap[normalizedUserId]?.trim() ?? '';
    if (activeDid.isEmpty) {
      return false;
    }

    final conflictingScopes = allMap.entries
        .where((e) => e.key != normalizedUserId && e.value == activeDid)
        .map((e) => e.key)
        .toList();

    if (conflictingScopes.isEmpty) {
      return false;
    }

    debugPrint(
      '[SecureStorage] critical_did_conflict detected for userId=$normalizedUserId '
      'did=$activeDid conflicts=${conflictingScopes.join(',')}. '
      'Clearing active identity for regeneration.',
    );
    await clearHolderIdentityForUser(normalizedUserId);
    await clearOID4VCISessionsForActiveScope();
    return true;
  }

  /// Save a credential (raw JWT string) by its ID
  static Future<void> saveCredential(String id, String rawJwt) async {
    final encrypted = await _encryptForScope(rawJwt);
    await _storage.write(key: _scoped('$_vcPrefix$id'), value: encrypted);
    debugPrint('[SecureStorage] Saved credential: $id');
  }

  /// Load all stored credentials as raw JWT strings
  static Future<Map<String, String>> loadAllCredentials() async {
    final all = await _storage.readAll();
    final scopedPrefix = _scoped(_vcPrefix);
    final result = <String, String>{};

    for (final entry in all.entries) {
      if (entry.key.startsWith(scopedPrefix) &&
          !entry.key.startsWith(_scoped('${_vcPrefix}meta_'))) {
        final decrypted = await _decryptForScope(entry.value);
        if (decrypted != null) {
          result[entry.key.substring(scopedPrefix.length)] = decrypted;
        }
      }
    }

    if (result.isEmpty) {
      for (final entry in all.entries) {
        if (entry.key.startsWith(_vcPrefix) &&
            !entry.key.startsWith('${_vcPrefix}meta_')) {
          final decrypted = await _decryptForScope(entry.value);
          if (decrypted != null) {
            result[entry.key.substring(_vcPrefix.length)] = decrypted;
          }
        }
      }
    }

    debugPrint('[SecureStorage] Loaded ${result.length} credentials');
    return result;
  }

  /// Delete a single credential
  static Future<void> deleteCredential(String id) async {
    await _storage.delete(key: _scoped('$_vcPrefix$id'));
    await _storage.delete(key: _scoped('${_vcPrefix}meta_$id'));
    // Cleanup legacy keys for migrated users.
    await _storage.delete(key: _legacyVcKey(id));
    await _storage.delete(key: _legacyVcMetaKey(id));
    debugPrint('[SecureStorage] Deleted credential: $id');
  }

  /// Save an access token for an issuer
  static Future<void> saveAccessToken(String issuer, String token) async {
    await _storage.write(key: _scoped('$_tokenPrefix$issuer'), value: token);
  }

  /// Load access token for an issuer
  static Future<String?> loadAccessToken(String issuer) async {
    return _readScopedFirstThenGlobal('$_tokenPrefix$issuer');
  }

  /// Save holder key pair (Ed25519) as base64
  static Future<void> saveHolderKeyPair({
    required String userId,
    required String privateKeyBase64,
    required String publicKeyBase64,
  }) async {
    await _storage.write(
      key: _identityPrivateKeyForUser(userId),
      value: privateKeyBase64,
    );
    await _storage.write(
      key: _identityPublicKeyForUser(userId),
      value: publicKeyBase64,
    );
  }

  /// Load holder private key as base64
  static Future<String?> loadHolderPrivateKey(String userId) async {
    return _storage.read(key: _identityPrivateKeyForUser(userId));
  }

  /// Load holder public key as base64
  static Future<String?> loadHolderPublicKey(String userId) async {
    return _storage.read(key: _identityPublicKeyForUser(userId));
  }

  /// Save persistent holder DID used for OID4VCI issuance.
  static Future<void> saveHolderDid({
    required String userId,
    required String holderDid,
  }) async {
    await _storage.write(
      key: _identityDidKeyForUser(userId),
      value: holderDid,
    );
  }

  /// Load persistent holder DID.
  static Future<String?> loadHolderDid(String userId) async {
    return _storage.read(key: _identityDidKeyForUser(userId));
  }

  /// Save OID4VCI token session data keyed by issuer.
  static Future<void> saveOID4VCISession(
    String issuer,
    Map<String, dynamic> session,
  ) async {
    await _storage.write(
      key: _scoped('$_oid4vciSessionPrefix$issuer'),
      value: jsonEncode(session),
    );
  }

  /// Load OID4VCI token session data keyed by issuer.
  static Future<Map<String, dynamic>?> loadOID4VCISession(String issuer) async {
    final raw =
        await _storage.read(key: _scoped('$_oid4vciSessionPrefix$issuer')) ??
            await _storage.read(key: '$_oid4vciSessionPrefix$issuer');
    if (raw == null || raw.isEmpty) return null;

    try {
      return Map<String, dynamic>.from(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (e) {
      debugPrint('[SecureStorage] Failed to parse OID4VCI session: $e');
      return null;
    }
  }

  /// Clear OID4VCI sessions in active scope to prevent stale DID-bound tokens.
  static Future<void> clearOID4VCISessionsForActiveScope() async {
    final all = await _storage.readAll();
    final scopedPrefix = _scoped(_oid4vciSessionPrefix);

    for (final key in all.keys) {
      if (key.startsWith(scopedPrefix) ||
          key.startsWith(_oid4vciSessionPrefix)) {
        await _storage.delete(key: key);
      }
    }
  }

  /// Save credential model metadata (JSON) alongside raw JWT
  static Future<void> saveCredentialMetadata(
      String id, CredentialModel credential) async {
    final json = jsonEncode(credential.toJson());
    final encrypted = await _encryptForScope(json);
    await _storage.write(
      key: _scoped('${_vcPrefix}meta_$id'),
      value: encrypted,
    );
  }

  /// Load credential model from metadata
  static Future<CredentialModel?> loadCredentialMetadata(String id) async {
    final raw = await _storage.read(key: _scoped('${_vcPrefix}meta_$id')) ??
        await _storage.read(key: '${_vcPrefix}meta_$id');
    if (raw == null) return null;
    try {
      final decrypted = await _decryptForScope(raw);
      if (decrypted == null || decrypted.isEmpty) {
        return null;
      }
      final json = jsonDecode(decrypted) as Map<String, dynamic>;
      return CredentialModel.fromJson(json);
    } catch (e) {
      debugPrint('[SecureStorage] Error loading metadata for $id: $e');
      return null;
    }
  }

  /// Load all saved CredentialModel objects
  static Future<List<CredentialModel>> loadAllCredentialModels() async {
    final all = await _storage.readAll();
    final result = <CredentialModel>[];

    final scopedMetaPrefix = _scoped('${_vcPrefix}meta_');
    for (final entry in all.entries) {
      if (entry.key.startsWith(scopedMetaPrefix)) {
        try {
          final decrypted = await _decryptForScope(entry.value);
          if (decrypted == null || decrypted.isEmpty) {
            continue;
          }
          final json = jsonDecode(decrypted) as Map<String, dynamic>;
          result.add(CredentialModel.fromJson(json));
        } catch (e) {
          debugPrint('[SecureStorage] Error parsing credential: $e');
        }
      }
    }

    if (result.isEmpty) {
      for (final entry in all.entries) {
        if (entry.key.startsWith('${_vcPrefix}meta_')) {
          try {
            final decrypted = await _decryptForScope(entry.value);
            if (decrypted == null || decrypted.isEmpty) {
              continue;
            }
            final json = jsonDecode(decrypted) as Map<String, dynamic>;
            final credential = CredentialModel.fromJson(json);
            result.add(credential);

            // Migrate legacy data into the active scope lazily.
            final encryptedMeta = await _encryptForScope(decrypted);
            await _storage.write(
              key: _scoped(entry.key),
              value: encryptedMeta,
            );

            final legacyRaw = all[_legacyVcKey(credential.id)];
            if (legacyRaw != null && legacyRaw.isNotEmpty) {
              final encryptedRaw = await _encryptForScope(legacyRaw);
              await _storage.write(
                key: _scoped(_legacyVcKey(credential.id)),
                value: encryptedRaw,
              );
            }
          } catch (e) {
            debugPrint('[SecureStorage] Error parsing legacy credential: $e');
          }
        }
      }
    }

    return result;
  }

  /// Clear everything (use for logout)
  static Future<void> clearAll() async {
    await _storage.deleteAll();
    debugPrint('[SecureStorage] Cleared all secure storage');
  }

  /// Save PIN code in secure storage (per active scope).
  static Future<void> savePinCode(String pinCode) async {
    final encrypted = await _encryptForScope(pinCode);
    await _storage.write(key: _scoped(_pinCodeKey), value: encrypted);
  }

  /// Load PIN code from secure storage (per active scope).
  static Future<String?> loadPinCode() async {
    final raw = await _readScopedOnly(_pinCodeKey);
    if (raw == null) return null;
    return _decryptForScope(raw);
  }

  /// Clear PIN code from secure storage (per active scope).
  static Future<void> clearPinCode() async {
    await _storage.delete(key: _scoped(_pinCodeKey));
  }

  static Future<SecretKey> _getOrCreateScopeKey() async {
    final raw = await _storage.read(key: _scoped(_scopeAesKey));
    if (raw != null && raw.isNotEmpty) {
      return SecretKey(base64Decode(raw));
    }

    final keyBytes = await _cipher.newSecretKey();
    final exported = await keyBytes.extractBytes();
    await _storage.write(
      key: _scoped(_scopeAesKey),
      value: base64Encode(exported),
    );
    return SecretKey(exported);
  }

  static Future<SecretKey?> _getScopeKey() async {
    final raw = await _storage.read(key: _scoped(_scopeAesKey));
    if (raw == null || raw.isEmpty) return null;
    return SecretKey(base64Decode(raw));
  }

  static Future<SecretKey> _getOrCreateUserKey(String userId) async {
    final keyName = _aesKeyForUser(userId);
    final raw = await _storage.read(key: keyName);
    if (raw != null && raw.isNotEmpty) {
      return SecretKey(base64Decode(raw));
    }

    final keyBytes = await _cipher.newSecretKey();
    final exported = await keyBytes.extractBytes();
    await _storage.write(key: keyName, value: base64Encode(exported));
    return SecretKey(exported);
  }

  static Future<SecretKey?> _getUserKey(String userId) async {
    final raw = await _storage.read(key: _aesKeyForUser(userId));
    if (raw == null || raw.isEmpty) return null;
    return SecretKey(base64Decode(raw));
  }

  static Future<String> _encryptForScope(String plaintext) async {
    final key = await _getOrCreateScopeKey();
    return _encryptWithKey(plaintext, key);
  }

  static Future<String?> _decryptForScope(String raw) async {
    if (!raw.startsWith(_encPrefix)) {
      return raw;
    }

    final key = await _getScopeKey();
    if (key == null) {
      debugPrint('[SecureStorage] AES scope key missing for decrypt');
      return null;
    }
    return _decryptWithKey(raw, key);
  }

  static Future<String> _encryptForUser(String userId, String plaintext) async {
    final key = await _getOrCreateUserKey(userId);
    return _encryptWithKey(plaintext, key);
  }

  static Future<String?> _decryptForUser(String userId, String raw) async {
    if (!raw.startsWith(_encPrefix)) {
      return raw;
    }

    final key = await _getUserKey(userId);
    if (key == null) {
      debugPrint('[SecureStorage] AES user key missing for decrypt');
      return null;
    }
    return _decryptWithKey(raw, key);
  }

  static Future<String> _encryptWithKey(String plaintext, SecretKey key) async {
    final secretBox = await _cipher.encrypt(
      utf8.encode(plaintext),
      secretKey: key,
    );

    final payload = jsonEncode({
      'v': 1,
      'n': base64Encode(secretBox.nonce),
      'c': base64Encode(secretBox.cipherText),
      'm': base64Encode(secretBox.mac.bytes),
    });

    return '$_encPrefix$payload';
  }

  static Future<String?> _decryptWithKey(String raw, SecretKey key) async {
    try {
      final payload = raw.substring(_encPrefix.length);
      final parsed = jsonDecode(payload) as Map<String, dynamic>;
      final nonce = base64Decode(parsed['n']?.toString() ?? '');
      final cipherText = base64Decode(parsed['c']?.toString() ?? '');
      final macBytes = base64Decode(parsed['m']?.toString() ?? '');
      final secretBox = SecretBox(
        cipherText,
        nonce: nonce,
        mac: Mac(macBytes),
      );
      final clearBytes = await _cipher.decrypt(
        secretBox,
        secretKey: key,
      );
      return utf8.decode(clearBytes);
    } catch (e) {
      debugPrint('[SecureStorage] AES decrypt failed: $e');
      return null;
    }
  }
}
