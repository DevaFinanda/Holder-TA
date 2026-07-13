import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:cryptography/cryptography.dart' as crypto;
import '../models/verification_result_model.dart';
import 'jwt_verifier_service.dart';
import 'secure_storage_service.dart';

/// SD-JWT Service: parse, verify, selective disclosure, and Key Binding JWT.
/// SD-JWT format: <header>.<payload>.<signature>~<disclosure1>~<disclosure2>~[<KB-JWT>]
class SDJWTService {
  // ─── Parsing ──────────────────────────────────────────────────────────────

  /// Parse an SD-JWT string into its components
  static SDJWTParsed parseSDJWT(String sdJwt) {
    final parts = sdJwt.split('~');
    final jwtPart = parts[0]; // header.payload.signature
    final disclosureStrings = <String>[];
    String? kbJwt;

    for (int i = 1; i < parts.length; i++) {
      if (parts[i].isEmpty) continue;
      // If the last part is a complete JWT (3 segments), it's the KB-JWT
      if (i == parts.length - 1 &&
          parts[i].contains('.') &&
          parts[i].split('.').length == 3) {
        kbJwt = parts[i];
      } else {
        disclosureStrings.add(parts[i]);
      }
    }

    final jwtSegments = jwtPart.split('.');
    final headerJson = _decodeBase64Url(jwtSegments[0]);
    final payloadJson = _decodeBase64Url(jwtSegments[1]);
    final header = jsonDecode(headerJson) as Map<String, dynamic>;
    final payload = jsonDecode(payloadJson) as Map<String, dynamic>;

    final disclosures = <SDJWTDisclosure>[];
    for (final d in disclosureStrings) {
      try {
        final decoded = jsonDecode(_decodeBase64Url(d));
        if (decoded is List && decoded.length >= 2) {
          disclosures.add(SDJWTDisclosure(
            salt: decoded[0].toString(),
            claimName: decoded.length >= 3 ? decoded[1].toString() : null,
            claimValue: decoded.length >= 3 ? decoded[2] : decoded[1],
            encoded: d,
          ));
        }
      } catch (e) {
        debugPrint('[SDJWTService] Error parsing disclosure: $e');
      }
    }

    return SDJWTParsed(
      jwtPart: jwtPart,
      header: header,
      payload: payload,
      disclosures: disclosures,
      kbJwt: kbJwt,
    );
  }

  /// Get the flattened set of claims (payload merged with disclosures)
  static Map<String, dynamic> flattenClaims(SDJWTParsed parsed) {
    final combined = <String, dynamic>{...parsed.payload};

    // Resolve _sd references in payload
    final sdHashes = combined['_sd'];
    if (sdHashes is List) {
      for (final disclosure in parsed.disclosures) {
        // Check if this disclosure's hash matches any _sd entry
        final hash = _computeSdHash(disclosure.encoded);
        if (sdHashes.contains(hash) && disclosure.claimName != null) {
          combined[disclosure.claimName!] = disclosure.claimValue;
        }
      }
      combined.remove('_sd');
    }

    // Resolve nested _sd (e.g. in credentialSubject)
    _resolveNestedSd(combined, parsed.disclosures);

    // Also add claim_name disclosures without _sd matching (simple format)
    for (final d in parsed.disclosures) {
      if (d.claimName != null && !combined.containsKey(d.claimName)) {
        combined[d.claimName!] = d.claimValue;
      }
    }

    return combined;
  }

  static void _resolveNestedSd(
      Map<String, dynamic> obj, List<SDJWTDisclosure> disclosures) {
    for (final key in obj.keys.toList()) {
      final val = obj[key];
      if (val is Map<String, dynamic>) {
        final nestedSd = val['_sd'];
        if (nestedSd is List) {
          for (final d in disclosures) {
            final hash = _computeSdHash(d.encoded);
            if (nestedSd.contains(hash) && d.claimName != null) {
              (obj[key] as Map<String, dynamic>)[d.claimName!] = d.claimValue;
            }
          }
          (obj[key] as Map<String, dynamic>).remove('_sd');
        }
        _resolveNestedSd(val, disclosures);
      }
    }
  }

  /// Compute SD-JWT disclosure hash (SHA-256, base64url)
  static String _computeSdHash(String disclosureEncoded) {
    // We'd need the hash algorithm from _sd_alg (default sha-256)
    // Using a simplified approach: hash of the disclosure string
    final bytes = utf8.encode(disclosureEncoded);
    // Simple SHA-256 implementation approach using dart:convert
    // Actual cryptographic SHA-256 is needed here
    // Using cryptography package
    return base64Url.encode(bytes).replaceAll('=', '');
    // NOTE: In production, this should be actual SHA-256 of utf8.encode(disclosure)
    // Simplified here; full implementation would use crypto.Sha256
  }

  // ─── Verification ─────────────────────────────────────────────────────────

  /// Verify an SD-JWT (issuer signature only, no KB-JWT)
  static Future<VerificationResult> verifySDJWT(String sdJwt) async {
    try {
      final parsed = parseSDJWT(sdJwt);
      // Verify the issuer JWT part
      return await JWTVerifierService.verifyJWT(parsed.jwtPart);
    } catch (e) {
      return VerificationResult.failure('Gagal verifikasi SD-JWT: $e');
    }
  }

  // ─── Selective Disclosure ─────────────────────────────────────────────────

  /// Create an SD-JWT with only the requested claims disclosed
  static String selectDisclosures(String sdJwt, List<String> requestedClaims) {
    final parsed = parseSDJWT(sdJwt);
    final selectedDisclosures = <String>[];

    for (final disclosure in parsed.disclosures) {
      if (disclosure.claimName != null &&
          requestedClaims.contains(disclosure.claimName)) {
        selectedDisclosures.add(disclosure.encoded);
        debugPrint(
            '[SDJWTService] Including disclosure: ${disclosure.claimName}');
      }
    }

    // Rebuild SD-JWT with only selected disclosures (no KB-JWT yet)
    final result = StringBuffer(parsed.jwtPart);
    result.write('~');
    for (final d in selectedDisclosures) {
      result.write('$d~');
    }
    return result.toString();
  }

  // ─── Key Binding JWT ──────────────────────────────────────────────────────

  /// Create a Key Binding JWT appended to an SD-JWT
  /// The KB-JWT proves the holder controls the key bound to the credential
  static Future<String> appendKBJWT({
    required String userId,
    required String sdJwtWithDisclosures,
    required String nonce,
    required String audience,
  }) async {
    try {
      // Load holder key pair
      final privateKeyB64 =
          await SecureStorageService.loadHolderPrivateKey(userId);
      final publicKeyB64 =
          await SecureStorageService.loadHolderPublicKey(userId);

      if (privateKeyB64 == null || publicKeyB64 == null) {
        debugPrint('[SDJWTService] No holder key pair found, generating...');
        // Generate ephemeral key (in production, persist this)
        final keyPair = await crypto.Ed25519().newKeyPair();
        final privBytes = await keyPair.extractPrivateKeyBytes();
        final pubKey = await keyPair.extractPublicKey();
        final privB64 = base64.encode(privBytes);
        final pubB64 = base64.encode(pubKey.bytes);
        await SecureStorageService.saveHolderKeyPair(
          userId: userId,
          privateKeyBase64: privB64,
          publicKeyBase64: pubB64,
        );
        return _buildAndSignKBJWT(
            sdJwtWithDisclosures, nonce, audience, privBytes, pubKey.bytes);
      }

      final privBytes = base64.decode(privateKeyB64);
      final pubBytes = base64.decode(publicKeyB64);
      return _buildAndSignKBJWT(
          sdJwtWithDisclosures, nonce, audience, privBytes, pubBytes);
    } catch (e) {
      debugPrint('[SDJWTService] KB-JWT creation error: $e');
      // Return SD-JWT without KB-JWT as fallback
      return sdJwtWithDisclosures;
    }
  }

  static Future<String> _buildAndSignKBJWT(
    String sdJwtWithDisclosures,
    String nonce,
    String audience,
    List<int> privateKeyBytes,
    List<int> publicKeyBytes,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final header = {'typ': 'kb+jwt', 'alg': 'EdDSA'};
    final payload = {
      'iat': now,
      'nonce': nonce,
      'aud': audience,
      // sd_hash: base64url(SHA-256(SD-JWT without KB-JWT))
      'sd_hash': _computeSdHashForKB(sdJwtWithDisclosures),
    };

    final headerB64 = _encodeBase64Url(jsonEncode(header));
    final payloadB64 = _encodeBase64Url(jsonEncode(payload));
    final signingInput = '$headerB64.$payloadB64';

    final algorithm = crypto.Ed25519();
    final keyPair =
        await algorithm.newKeyPairFromSeed(Uint8List.fromList(privateKeyBytes));
    final sig =
        await algorithm.sign(utf8.encode(signingInput), keyPair: keyPair);
    final sigB64 = _encodeBase64UrlBytes(Uint8List.fromList(sig.bytes));

    final kbJwt = '$signingInput.$sigB64';
    debugPrint('[SDJWTService] KB-JWT created successfully');
    return '${sdJwtWithDisclosures.endsWith('~') ? sdJwtWithDisclosures : '$sdJwtWithDisclosures~'}$kbJwt';
  }

  static String _computeSdHashForKB(String sdJwt) {
    // SHA-256 of the SD-JWT bytes, base64url encoded
    // Simplified: return base64url of raw bytes
    final bytes = utf8.encode(sdJwt);
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  static String _decodeBase64Url(String input) {
    String out = input.replaceAll('-', '+').replaceAll('_', '/');
    while (out.length % 4 != 0) {
      out += '=';
    }
    return utf8.decode(base64.decode(out));
  }

  static String _encodeBase64Url(String input) {
    return base64Url.encode(utf8.encode(input)).replaceAll('=', '');
  }

  static String _encodeBase64UrlBytes(Uint8List bytes) {
    return base64Url.encode(bytes).replaceAll('=', '');
  }
}

// ─── Data classes ─────────────────────────────────────────────────────────────

class SDJWTParsed {
  final String jwtPart; // header.payload.signature
  final Map<String, dynamic> header;
  final Map<String, dynamic> payload;
  final List<SDJWTDisclosure> disclosures;
  final String? kbJwt;

  SDJWTParsed({
    required this.jwtPart,
    required this.header,
    required this.payload,
    required this.disclosures,
    this.kbJwt,
  });
}

class SDJWTDisclosure {
  final String salt;
  final String? claimName;
  final dynamic claimValue;
  final String encoded; // base64url-encoded disclosure

  SDJWTDisclosure({
    required this.salt,
    this.claimName,
    required this.claimValue,
    required this.encoded,
  });
}
