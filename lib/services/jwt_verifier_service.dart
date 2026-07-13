import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:cryptography/cryptography.dart' as crypto;
import '../models/did_document_model.dart';
import '../models/verification_result_model.dart';

/// JWT Verifier Service for EdDSA (Ed25519) signed Verifiable Credentials.
/// Supports did:web, did:key, and did:jwk DID resolution.
class JWTVerifierService {
  static const Duration _httpTimeout = Duration(seconds: 15);

  /// Main entry point: verify a raw JWT VC
  static Future<VerificationResult> verifyJWT(String rawJwt) async {
    debugPrint('[JWTVerifier] Starting verification of JWT...');
    try {
      final parts = rawJwt.trim().split('.');
      if (parts.length < 3) {
        return VerificationResult.failure(
            'JWT tidak valid: harus memiliki 3 segmen (header.payload.signature)');
      }

      // 1. Decode header
      final headerJson = _decodeBase64Url(parts[0]);
      final header = jsonDecode(headerJson) as Map<String, dynamic>;
      final alg = header['alg']?.toString() ?? '';
      final kid = header['kid']?.toString() ?? '';
      debugPrint('[JWTVerifier] alg=$alg  kid=$kid');

      // 2. Decode payload
      final payloadJson = _decodeBase64Url(parts[1]);
      final payload = jsonDecode(payloadJson) as Map<String, dynamic>;
      debugPrint('[JWTVerifier] Payload keys: ${payload.keys.toList()}');

      // 3. Extract issuer DID
      final issuerDid = _extractIssuerDid(payload);
      if (issuerDid == null || issuerDid.isEmpty) {
        return VerificationResult.failure(
            'Tidak ditemukan issuer DID dalam payload (field "iss")');
      }
      debugPrint('[JWTVerifier] Issuer DID: $issuerDid');

      // 4. Resolve DID Document
      DIDDocument? didDoc;
      try {
        didDoc = await resolveDid(issuerDid);
      } catch (e) {
        debugPrint('[JWTVerifier] DID resolution failed: $e');
        // Continue with partial result
        return VerificationResult(
          signatureValid: false,
          issuerTrusted: false,
          claimsValid: _validateClaims(payload),
          timingValid: _validateTiming(payload),
          issuerDid: issuerDid,
          algorithm: alg,
          errors: ['Gagal resolve DID Document: $e'],
          claims: _extractClaims(payload),
        );
      }

      if (didDoc.id.trim().isNotEmpty && didDoc.id.trim() != issuerDid.trim()) {
        debugPrint(
          '[JWTVerifier] DID mismatch: expected issuer=$issuerDid, resolved=${didDoc.id}',
        );
        return VerificationResult(
          signatureValid: false,
          issuerTrusted: false,
          claimsValid: _validateClaims(payload),
          timingValid: _validateTiming(payload),
          issuerDid: issuerDid,
          algorithm: alg,
          errors: [
            'DID Document mismatch: issuer di JWT adalah $issuerDid tetapi endpoint DID mengembalikan ${didDoc.id}',
          ],
          claims: _extractClaims(payload),
        );
      }

      // 5. Find verification method by kid
      final methods = didDoc.verificationMethods;
      if (methods.isEmpty) {
        return VerificationResult(
          signatureValid: false,
          issuerTrusted: true,
          claimsValid: _validateClaims(payload),
          timingValid: _validateTiming(payload),
          issuerDid: issuerDid,
          algorithm: alg,
          errors: ['Tidak ditemukan verification method di DID Document'],
          claims: _extractClaims(payload),
        );
      }

      // 6. Verify signature
      bool sigValid = false;
      final signingInput = '${parts[0]}.${parts[1]}';
      final signatureBytes = _base64UrlDecode(parts[2]);
      debugPrint(
          '[JWTVerifier] signature bytes length: ${signatureBytes.length}');

      final candidateMethods = <VerificationMethod>[];
      if (kid.isNotEmpty) {
        final byKid = didDoc.findByKid(kid);
        if (byKid != null) {
          candidateMethods.add(byKid);
        }
      }
      for (final method in methods) {
        if (!candidateMethods.any((m) => m.id == method.id)) {
          candidateMethods.add(method);
        }
      }

      if (kid.isNotEmpty && candidateMethods.first.id != methods.first.id) {
        debugPrint(
            '[JWTVerifier] candidate methods ordered by kid first: ${candidateMethods.map((m) => m.id).toList()}');
      }

      if (alg == 'EdDSA' || alg == 'Ed25519') {
        for (final method in candidateMethods) {
          debugPrint(
              '[JWTVerifier] Trying VM id=${method.id} type=${method.type}');
          sigValid = await _verifyEd25519(method, signingInput, signatureBytes);
          if (sigValid) {
            break;
          }
        }
      } else if (alg.startsWith('RS') || alg.startsWith('PS')) {
        // RSA – not primary but handle gracefully
        sigValid = false;
        debugPrint('[JWTVerifier] RSA not supported, treating as unverified');
      } else {
        debugPrint(
            '[JWTVerifier] Unknown algorithm: $alg, skipping signature check');
        sigValid = false;
      }

      final claimsValid = _validateClaims(payload);
      final timingValid = _validateTiming(payload);

      return VerificationResult(
        signatureValid: sigValid,
        issuerTrusted: true, // DID was resolved
        claimsValid: claimsValid,
        timingValid: timingValid,
        issuerDid: issuerDid,
        algorithm: alg,
        errors: sigValid ? [] : ['Verifikasi tanda tangan Ed25519 gagal'],
        claims: _extractClaims(payload),
      );
    } catch (e, st) {
      debugPrint('[JWTVerifier] Unexpected error: $e\n$st');
      return VerificationResult.failure('Error verifikasi JWT: $e');
    }
  }

  // ─── DID Resolution ───────────────────────────────────────────────────────

  /// Resolve a DID to its DID Document
  static Future<DIDDocument> resolveDid(String did) async {
    if (did.startsWith('did:web:')) {
      return _resolveDidWeb(did);
    } else if (did.startsWith('did:key:')) {
      return _resolveDidKey(did);
    } else if (did.startsWith('did:jwk:')) {
      return _resolveDidJwk(did);
    } else {
      throw Exception('Unsupported DID method: $did');
    }
  }

  /// Resolve did:web by fetching /.well-known/did.json
  static Future<DIDDocument> _resolveDidWeb(String did) async {
    // did:web:example.com → https://example.com/.well-known/did.json
    // did:web:example.com:path:sub → https://example.com/path/sub/did.json
    String identifier = did.substring('did:web:'.length);
    // URL decode colons that were encoded
    identifier = Uri.decodeComponent(identifier.replaceAll('%3A', ':'));

    // Prevent localhost resolving (ensuring we only hit public URLs)
    if (identifier.startsWith('localhost') ||
        identifier.startsWith('127.0.0.1') ||
        identifier.startsWith('10.0.2.2')) {
      throw Exception(
          'DID Web dengan localhost tidak diizinkan. Gunakan public URL.');
    }

    final parts = identifier.split(':');
    final host = parts[0];
    String path;
    if (parts.length > 1) {
      path = '/${parts.sublist(1).join('/')}/did.json';
    } else {
      path = '/.well-known/did.json';
    }

    final url = 'https://$host$path';
    debugPrint('[JWTVerifier] Resolving did:web from: $url');

    final httpClient = HttpClient()
      ..badCertificateCallback = (cert, host, port) => true;
    final req = await httpClient.getUrl(Uri.parse(url));
    req.headers.set('Accept', 'application/json');
    final resp = await req.close().timeout(_httpTimeout);
    final body = await resp.transform(utf8.decoder).join();
    httpClient.close();

    if (resp.statusCode != 200) {
      throw Exception(
          'HTTP ${resp.statusCode} fetching DID Document from $url');
    }

    final json = jsonDecode(body) as Map<String, dynamic>;
    return DIDDocument.fromJson(json);
  }

  /// Resolve did:key by parsing multibase-encoded public key
  static Future<DIDDocument> _resolveDidKey(String did) async {
    // did:key:z6Mk... where z prefix = base58btc + ed25519 multicodec
    final keyPart = did.substring('did:key:'.length);
    if (!keyPart.startsWith('z')) {
      throw Exception('Only base58btc (z prefix) did:key supported');
    }
    // The identifier itself is the key ID
    final vm = VerificationMethod(
      id: '$did#$keyPart',
      type: 'Ed25519VerificationKey2020',
      controller: did,
      publicKeyMultibase: keyPart,
    );
    return DIDDocument(id: did, verificationMethods: [vm]);
  }

  /// Resolve did:jwk by base64url-decoding the JWK from the DID
  static Future<DIDDocument> _resolveDidJwk(String did) async {
    final encoded = did.substring('did:jwk:'.length);
    final jwkJson = _decodeBase64Url(encoded);
    final jwk = jsonDecode(jwkJson) as Map<String, dynamic>;
    final vm = VerificationMethod(
      id: '$did#0',
      type: jwk['crv'] == 'Ed25519' ? 'JsonWebKey2020' : 'JsonWebKey2020',
      controller: did,
      publicKeyJwk: jwk,
    );
    return DIDDocument(id: did, verificationMethods: [vm]);
  }

  // ─── Signature Verification ───────────────────────────────────────────────

  static Future<bool> _verifyEd25519(
    VerificationMethod vm,
    String signingInput,
    Uint8List signature,
  ) async {
    try {
      Uint8List? publicKeyBytes;

      if (vm.publicKeyJwk != null) {
        publicKeyBytes = _ed25519PublicKeyFromJwk(vm.publicKeyJwk!);
      } else if (vm.publicKeyBase58 != null) {
        publicKeyBytes = _base58Decode(vm.publicKeyBase58!);
      } else if (vm.publicKeyMultibase != null) {
        publicKeyBytes = _multibaseDecode(vm.publicKeyMultibase!);
      }

      if (publicKeyBytes == null || publicKeyBytes.isEmpty) {
        debugPrint('[JWTVerifier] No public key bytes extracted');
        return false;
      }

      debugPrint(
          '[JWTVerifier] Public key bytes length: ${publicKeyBytes.length}');

      final algorithm = crypto.Ed25519();
      final publicKey = crypto.SimplePublicKey(
        publicKeyBytes.toList(),
        type: crypto.KeyPairType.ed25519,
      );
      final sig = crypto.Signature(signature.toList(), publicKey: publicKey);
      final inputBytes = utf8.encode(signingInput);
      final valid = await algorithm.verify(inputBytes, signature: sig);
      debugPrint('[JWTVerifier] Ed25519 verification result: $valid');
      return valid;
    } catch (e) {
      debugPrint('[JWTVerifier] Ed25519 verification error: $e');
      return false;
    }
  }

  static Uint8List? _ed25519PublicKeyFromJwk(Map<String, dynamic> jwk) {
    final crv = jwk['crv']?.toString();
    final x = jwk['x']?.toString();
    if (crv != 'Ed25519' || x == null) return null;
    return _base64UrlDecode(x);
  }

  // ─── Claim Validation ─────────────────────────────────────────────────────

  static bool _validateClaims(Map<String, dynamic> payload) {
    // Check vc.type
    final vc = payload['vc'];
    if (vc is Map) {
      final type = vc['type'];
      if (type is List) {
        final hasVC = type.contains('VerifiableCredential');
        if (!hasVC) {
          debugPrint('[JWTVerifier] Missing VerifiableCredential type');
          return false;
        }
      }
      final cs = vc['credentialSubject'];
      if (cs is Map) {
        const requiredFields = <String>[
          'holderName',
          'nik',
          'noBPJS',
          'tanggalLahir',
        ];
        final missingFields = requiredFields
            .where((field) =>
                !cs.containsKey(field) ||
                cs[field] == null ||
                '${cs[field]}'.trim().isEmpty)
            .toList();
        if (missingFields.isNotEmpty) {
          debugPrint(
            '[JWTVerifier] credentialSubject missing required fields: $missingFields',
          );
          return false;
        }
      }
    }
    return true;
  }

  static bool _validateTiming(Map<String, dynamic> payload) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // Check nbf (not before)
    final nbf = payload['nbf'];
    if (nbf != null) {
      final nbfInt = nbf is int ? nbf : int.tryParse(nbf.toString());
      if (nbfInt != null && now < nbfInt - 60) {
        // 60s clock skew tolerance
        debugPrint('[JWTVerifier] JWT not yet valid (nbf: $nbfInt, now: $now)');
        return false;
      }
    }

    // Check exp (expiry)
    final exp = payload['exp'];
    if (exp != null) {
      final expInt = exp is int ? exp : int.tryParse(exp.toString());
      if (expInt != null && now > expInt + 60) {
        debugPrint('[JWTVerifier] JWT expired (exp: $expInt, now: $now)');
        return false;
      }
    }

    return true;
  }

  static Map<String, dynamic> _extractClaims(Map<String, dynamic> payload) {
    final claims = <String, dynamic>{
      'iss': payload['iss'],
      'sub': payload['sub'],
      'iat': payload['iat'],
      'exp': payload['exp'],
      'nbf': payload['nbf'],
      'jti': payload['jti'],
    };

    final vc = payload['vc'];
    if (vc is Map) {
      final cs = vc['credentialSubject'];
      if (cs is Map) {
        for (final entry in cs.entries) {
          claims[entry.key] = entry.value;
        }
      }
      claims['vc_type'] = vc['type'];
    }

    claims.removeWhere((k, v) => v == null);
    return claims;
  }

  static String? _extractIssuerDid(Map<String, dynamic> payload) {
    final iss = payload['iss']?.toString();
    if (iss != null && iss.startsWith('did:')) return iss;
    // Some issuers put DID in vc.issuer
    final vc = payload['vc'];
    if (vc is Map) {
      final issuer = vc['issuer'];
      if (issuer is String && issuer.startsWith('did:')) return issuer;
      if (issuer is Map) {
        final id = issuer['id']?.toString();
        if (id != null && id.startsWith('did:')) return id;
      }
    }
    return iss;
  }

  // ─── Utilities ────────────────────────────────────────────────────────────

  static String _decodeBase64Url(String input) {
    final normalized = _normalizeBase64Url(input);
    return utf8.decode(base64.decode(normalized));
  }

  static Uint8List _base64UrlDecode(String input) {
    final normalized = _normalizeBase64Url(input);
    return Uint8List.fromList(base64.decode(normalized));
  }

  static String _normalizeBase64Url(String input) {
    String out = input.replaceAll('-', '+').replaceAll('_', '/');
    while (out.length % 4 != 0) {
      out += '=';
    }
    return out;
  }

  /// Base58 decode (Bitcoin alphabet)
  static Uint8List _base58Decode(String input) {
    const alphabet =
        '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
    final bytes = <int>[];
    var n = BigInt.zero;
    for (final char in input.split('')) {
      n = n * BigInt.from(58) + BigInt.from(alphabet.indexOf(char));
    }
    while (n > BigInt.zero) {
      bytes.insert(0, (n % BigInt.from(256)).toInt());
      n = n ~/ BigInt.from(256);
    }
    for (final char in input.split('')) {
      if (char != '1') break;
      bytes.insert(0, 0);
    }
    // Remove multicodec prefix for Ed25519 (0xed 0x01)
    if (bytes.length > 2 && bytes[0] == 0xed && bytes[1] == 0x01) {
      return Uint8List.fromList(bytes.sublist(2));
    }
    return Uint8List.fromList(bytes);
  }

  /// Multibase decode (z = base58btc)
  static Uint8List _multibaseDecode(String input) {
    if (input.startsWith('z')) {
      return _base58Decode(input.substring(1));
    }
    throw Exception('Unsupported multibase prefix: ${input[0]}');
  }
}
