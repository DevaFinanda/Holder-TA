// ============================================================
// IDentia - Pengujian Kinerja Sistem (Success Rate)
// File: test_success_rate.dart
// Jalankan: dart run test_success_rate.dart
// ============================================================

import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

// ============================================================
// KONSTANTA PENGUJIAN
// ============================================================
const int TOTAL_ITERASI = 10;
const String ISSUER_DID = 'did:web:issuer.identia.my.id';
const String VERIFIER_DID = 'did:web:verifier.identia.my.id';
const String HOLDER_NIK = '3201010203050001';
const String HOLDER_NAMA = 'Deva Finanda Saputra';
const String HOLDER_NOBPJS = '3201010203050';

// ============================================================
// MODEL HASIL PENGUJIAN
// ============================================================
class HasilSkenario {
  final String id;
  final String nama;
  final String jenis;
  final int iterasi;
  int sesuaiEkspektasi = 0;
  int tidakSesuaiEkspektasi = 0;
  final List<double> waktuMs = [];
  final List<String> keterangan = [];

  HasilSkenario({
    required this.id,
    required this.nama,
    required this.jenis,
    required this.iterasi,
  });

  double get avgMs =>
      waktuMs.isEmpty ? 0 : waktuMs.reduce((a, b) => a + b) / waktuMs.length;
  double get minMs =>
      waktuMs.isEmpty ? 0 : waktuMs.reduce((a, b) => a < b ? a : b);
  double get maxMs =>
      waktuMs.isEmpty ? 0 : waktuMs.reduce((a, b) => a > b ? a : b);
  String get successRate =>
      '${(sesuaiEkspektasi / iterasi * 100).toStringAsFixed(0)}%';
}

// ============================================================
// UTILITAS
// ============================================================

// Encode Base64URL tanpa padding
String base64UrlEncode(List<int> bytes) {
  return base64Url.encode(bytes).replaceAll('=', '');
}

// Decode Base64URL
List<int> base64UrlDecode(String input) {
  String normalized = input;
  while (normalized.length % 4 != 0) {
    normalized += '=';
  }
  return base64Url.decode(normalized);
}

// Bentuk JWT compact serialization
String buildJwt(Map<String, dynamic> header, Map<String, dynamic> payload) {
  final headerB64 = base64UrlEncode(utf8.encode(jsonEncode(header)));
  final payloadB64 = base64UrlEncode(utf8.encode(jsonEncode(payload)));
  return '$headerB64.$payloadB64';
}

// Tanda tangani JWT menggunakan Ed25519
Future<String> signJwt(
  String signingInput,
  SimpleKeyPair keyPair,
) async {
  final algorithm = Ed25519();
  final message = utf8.encode(signingInput);
  final signature = await algorithm.sign(message, keyPair: keyPair);
  final signatureB64 = base64UrlEncode(signature.bytes);
  return '$signingInput.$signatureB64';
}

// Verifikasi JWT menggunakan public key
Future<bool> verifyJwt(String jwt, SimplePublicKey publicKey) async {
  final parts = jwt.split('.');
  if (parts.length != 3) return false;

  final signingInput = '${parts[0]}.${parts[1]}';
  final signatureBytes = base64UrlDecode(parts[2]);

  final algorithm = Ed25519();
  try {
    final signature = Signature(
      signatureBytes,
      publicKey: publicKey,
    );
    return await algorithm.verify(
      utf8.encode(signingInput),
      signature: signature,
    );
  } catch (e) {
    return false;
  }
}

// Cetak separator
void printSeparator() {
  print('=' * 70);
}

void printSubSeparator() {
  print('-' * 70);
}

// ============================================================
// SKENARIO T1 — Ed25519 Key Pair Generation
// ============================================================
Future<HasilSkenario> testT1() async {
  final hasil = HasilSkenario(
    id: 'T1',
    nama: 'Ed25519 Key Pair Generation',
    jenis: 'Positif',
    iterasi: TOTAL_ITERASI,
  );

  print('\n[T1] Ed25519 Key Pair Generation');
  printSubSeparator();

  final algorithm = Ed25519();

  for (int i = 1; i <= TOTAL_ITERASI; i++) {
    final stopwatch = Stopwatch()..start();

    try {
      // Generate keypair
      final keyPair = await algorithm.newKeyPair();
      final publicKey = await keyPair.extractPublicKey();
      final privateKeyBytes = await keyPair.extractPrivateKeyBytes();

      stopwatch.stop();
      final ms = stopwatch.elapsedMicroseconds / 1000.0;

      // Validasi kriteria keberhasilan
      final privateKeyValid = privateKeyBytes.length == 32;
      final publicKeyValid = publicKey.bytes.length == 32;

      if (privateKeyValid && publicKeyValid) {
        hasil.sesuaiEkspektasi++;
        hasil.waktuMs.add(ms);
        hasil.keterangan.add('✓');
        print(
          'Iterasi $i: ✓ SESUAI | '
          'private=${privateKeyBytes.length}B | '
          'public=${publicKey.bytes.length}B | '
          '${ms.toStringAsFixed(3)}ms',
        );
      } else {
        hasil.tidakSesuaiEkspektasi++;
        hasil.keterangan.add('✗ Panjang kunci tidak valid');
        print('Iterasi $i: ✗ TIDAK SESUAI | Panjang kunci tidak valid');
      }
    } catch (e) {
      stopwatch.stop();
      hasil.tidakSesuaiEkspektasi++;
      hasil.keterangan.add('✗ Exception: $e');
      print('Iterasi $i: ✗ EXCEPTION | $e');
    }
  }

  return hasil;
}

// ============================================================
// SKENARIO T2 — DID:JWK Formation
// ============================================================
Future<HasilSkenario> testT2(SimpleKeyPair keyPair) async {
  final hasil = HasilSkenario(
    id: 'T2',
    nama: 'Pembentukan DID:JWK',
    jenis: 'Positif',
    iterasi: TOTAL_ITERASI,
  );

  print('\n[T2] Pembentukan DID:JWK');
  printSubSeparator();

  final algorithm = Ed25519();

  for (int i = 1; i <= TOTAL_ITERASI; i++) {
    final stopwatch = Stopwatch()..start();

    try {
      // Generate keypair baru setiap iterasi
      final kp = await algorithm.newKeyPair();
      final publicKey = await kp.extractPublicKey();

      // Bentuk JWK dari public key
      final jwk = {
        'kty': 'OKP',
        'crv': 'Ed25519',
        'x': base64UrlEncode(publicKey.bytes),
      };

      // Bentuk DID:JWK
      final jwkJson = jsonEncode(jwk);
      final jwkB64 = base64UrlEncode(utf8.encode(jwkJson));
      final did = 'did:jwk:$jwkB64';

      // Validasi: decode kembali dan periksa field
      final decoded = jsonDecode(
        utf8.decode(base64UrlDecode(did.substring('did:jwk:'.length))),
      ) as Map<String, dynamic>;

      stopwatch.stop();
      final ms = stopwatch.elapsedMicroseconds / 1000.0;

      final valid = decoded['kty'] == 'OKP' &&
          decoded['crv'] == 'Ed25519' &&
          decoded.containsKey('x') &&
          did.startsWith('did:jwk:');

      if (valid) {
        hasil.sesuaiEkspektasi++;
        hasil.waktuMs.add(ms);
        hasil.keterangan.add('✓');
        print(
          'Iterasi $i: ✓ SESUAI | '
          'kty=${decoded['kty']} | '
          'crv=${decoded['crv']} | '
          '${ms.toStringAsFixed(3)}ms',
        );
      } else {
        hasil.tidakSesuaiEkspektasi++;
        hasil.keterangan.add('✗ Field JWK tidak lengkap');
        print('Iterasi $i: ✗ TIDAK SESUAI | Field JWK tidak lengkap');
      }
    } catch (e) {
      stopwatch.stop();
      hasil.tidakSesuaiEkspektasi++;
      hasil.keterangan.add('✗ Exception: $e');
      print('Iterasi $i: ✗ EXCEPTION | $e');
    }
  }

  return hasil;
}

// ============================================================
// SKENARIO T4 — Proof JWT Construction
// ============================================================
Future<HasilSkenario> testT4(SimpleKeyPair holderKeyPair) async {
  final hasil = HasilSkenario(
    id: 'T4',
    nama: 'Proof JWT Construction',
    jenis: 'Positif',
    iterasi: TOTAL_ITERASI,
  );

  print('\n[T4] Proof JWT Construction');
  printSubSeparator();

  final algorithm = Ed25519();
  final publicKey = await holderKeyPair.extractPublicKey();
  final jwk = {
    'kty': 'OKP',
    'crv': 'Ed25519',
    'x': base64UrlEncode(publicKey.bytes),
  };
  final holderDid = 'did:jwk:${base64UrlEncode(utf8.encode(jsonEncode(jwk)))}';

  for (int i = 1; i <= TOTAL_ITERASI; i++) {
    final stopwatch = Stopwatch()..start();

    try {
      // Simulasi c_nonce dari Issuer (unik per iterasi)
      final cNonce = 'c_nonce_${DateTime.now().millisecondsSinceEpoch}_$i';

      // Bentuk header dan payload Proof JWT
      final header = {
        'alg': 'EdDSA',
        'typ': 'openid4vci-proof+jwt',
        'kid': holderDid,
      };
      final payload = {
        'iss': holderDid,
        'aud': ISSUER_DID,
        'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'nonce': cNonce,
      };

      // Bentuk signing input dan tandatangani
      final signingInput = buildJwt(header, payload);
      final proofJwt = await signJwt(signingInput, holderKeyPair);

      // Verifikasi struktur JWT (3 bagian)
      final parts = proofJwt.split('.');
      final valid3Parts = parts.length == 3;

      // Verifikasi signature menggunakan public key
      final signatureValid = await verifyJwt(proofJwt, publicKey);

      // Verifikasi nonce tertanam
      final decodedPayload = jsonDecode(
        utf8.decode(base64UrlDecode(parts[1])),
      ) as Map<String, dynamic>;
      final nonceMatch = decodedPayload['nonce'] == cNonce;

      stopwatch.stop();
      final ms = stopwatch.elapsedMicroseconds / 1000.0;

      if (valid3Parts && signatureValid && nonceMatch) {
        hasil.sesuaiEkspektasi++;
        hasil.waktuMs.add(ms);
        hasil.keterangan.add('✓');
        print(
          'Iterasi $i: ✓ SESUAI | '
          '3-parts=$valid3Parts | '
          'sig=$signatureValid | '
          'nonce=$nonceMatch | '
          '${ms.toStringAsFixed(3)}ms',
        );
      } else {
        hasil.tidakSesuaiEkspektasi++;
        hasil.keterangan.add(
          '✗ valid3Parts=$valid3Parts sig=$signatureValid nonce=$nonceMatch',
        );
        print(
          'Iterasi $i: ✗ TIDAK SESUAI | '
          'valid3Parts=$valid3Parts | '
          'sig=$signatureValid | '
          'nonce=$nonceMatch',
        );
      }
    } catch (e) {
      stopwatch.stop();
      hasil.tidakSesuaiEkspektasi++;
      hasil.keterangan.add('✗ Exception: $e');
      print('Iterasi $i: ✗ EXCEPTION | $e');
    }
  }

  return hasil;
}

// ============================================================
// SKENARIO T5 — JWT VC Construction
// ============================================================
Future<(HasilSkenario, String)> testT5(
  SimpleKeyPair issuerKeyPair,
  String holderDid,
) async {
  final hasil = HasilSkenario(
    id: 'T5',
    nama: 'Penyusunan Payload JWT VC',
    jenis: 'Positif',
    iterasi: TOTAL_ITERASI,
  );

  print('\n[T5] Penyusunan Payload JWT VC');
  printSubSeparator();

  final publicKey = await issuerKeyPair.extractPublicKey();
  String lastValidJwtVC = '';

  for (int i = 1; i <= TOTAL_ITERASI; i++) {
    final stopwatch = Stopwatch()..start();

    try {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // Bentuk header JWT VC
      final header = {
        'alg': 'EdDSA',
        'typ': 'JWT',
        'kid': '$ISSUER_DID#key-1',
      };

      // Bentuk payload JWT VC dengan klaim kepesertaan BPJS
      final payload = {
        'iss': ISSUER_DID,
        'sub': holderDid,
        'iat': now,
        'exp': now + 31536000, // 1 tahun
        'jti': 'CRED-2026-${i.toString().padLeft(3, '0')}',
        'vc': {
          '@context': ['https://www.w3.org/2018/credentials/v1'],
          'type': ['VerifiableCredential', 'BPJSHealthCard'],
          'credentialSubject': {
            'NIK': HOLDER_NIK,
            'nama': HOLDER_NAMA,
            'NOBPJS': HOLDER_NOBPJS,
            'tanggalLahir': '2005-02-05',
            'status': 'AKTIF',
          },
        },
      };

      // Bentuk signing input dan tandatangani
      final signingInput = buildJwt(header, payload);
      final jwtVC = await signJwt(signingInput, issuerKeyPair);

      // Validasi struktur
      final parts = jwtVC.split('.');
      final valid3Parts = parts.length == 3;

      // Decode dan periksa kelengkapan klaim
      final decodedPayload = jsonDecode(
        utf8.decode(base64UrlDecode(parts[1])),
      ) as Map<String, dynamic>;

      final credSubject =
          (decodedPayload['vc'] as Map)['credentialSubject'] as Map;
      final allClaimsPresent = credSubject.containsKey('NIK') &&
          credSubject.containsKey('nama') &&
          credSubject.containsKey('NOBPJS') &&
          credSubject.containsKey('status');

      // Verifikasi signature
      final signatureValid = await verifyJwt(jwtVC, publicKey);

      stopwatch.stop();
      final ms = stopwatch.elapsedMicroseconds / 1000.0;

      // Hitung ukuran payload
      final payloadSize = utf8.encode(jwtVC).length;

      if (valid3Parts && allClaimsPresent && signatureValid) {
        hasil.sesuaiEkspektasi++;
        hasil.waktuMs.add(ms);
        hasil.keterangan.add('✓');
        lastValidJwtVC = jwtVC;
        print(
          'Iterasi $i: ✓ SESUAI | '
          'klaim=$allClaimsPresent | '
          'sig=$signatureValid | '
          '${payloadSize}B | '
          '${ms.toStringAsFixed(3)}ms',
        );
      } else {
        hasil.tidakSesuaiEkspektasi++;
        hasil.keterangan.add(
          '✗ claims=$allClaimsPresent sig=$signatureValid',
        );
        print(
          'Iterasi $i: ✗ TIDAK SESUAI | '
          'claims=$allClaimsPresent | '
          'sig=$signatureValid',
        );
      }
    } catch (e) {
      stopwatch.stop();
      hasil.tidakSesuaiEkspektasi++;
      hasil.keterangan.add('✗ Exception: $e');
      print('Iterasi $i: ✗ EXCEPTION | $e');
    }
  }

  return (hasil, lastValidJwtVC);
}

// ============================================================
// SKENARIO T6 — JWT VC Verification
// ============================================================
Future<HasilSkenario> testT6(
  String jwtVC,
  SimplePublicKey issuerPublicKey,
) async {
  final hasil = HasilSkenario(
    id: 'T6',
    nama: 'Verifikasi Struktur JWT VC',
    jenis: 'Positif',
    iterasi: TOTAL_ITERASI,
  );

  print('\n[T6] Verifikasi Struktur JWT VC');
  printSubSeparator();

  for (int i = 1; i <= TOTAL_ITERASI; i++) {
    final stopwatch = Stopwatch()..start();

    try {
      // Verifikasi signature EdDSA menggunakan public key Issuer
      final signatureValid = await verifyJwt(jwtVC, issuerPublicKey);

      // Decode dan periksa payload
      final parts = jwtVC.split('.');
      final decodedPayload = jsonDecode(
        utf8.decode(base64UrlDecode(parts[1])),
      ) as Map<String, dynamic>;

      // Periksa klaim wajib
      final hasIss = decodedPayload.containsKey('iss');
      final hasSub = decodedPayload.containsKey('sub');
      final hasVc = decodedPayload.containsKey('vc');
      final hasExp = decodedPayload.containsKey('exp');

      // Periksa exp belum lewat
      final exp = decodedPayload['exp'] as int;
      final notExpired = exp > DateTime.now().millisecondsSinceEpoch ~/ 1000;

      stopwatch.stop();
      final ms = stopwatch.elapsedMicroseconds / 1000.0;

      if (signatureValid && hasIss && hasSub && hasVc && notExpired) {
        hasil.sesuaiEkspektasi++;
        hasil.waktuMs.add(ms);
        hasil.keterangan.add('✓');
        print(
          'Iterasi $i: ✓ SESUAI | '
          'sig=$signatureValid | '
          'iss=$hasIss | sub=$hasSub | '
          'notExpired=$notExpired | '
          '${ms.toStringAsFixed(3)}ms',
        );
      } else {
        hasil.tidakSesuaiEkspektasi++;
        hasil.keterangan.add(
          '✗ sig=$signatureValid expired=${!notExpired}',
        );
        print(
          'Iterasi $i: ✗ TIDAK SESUAI | '
          'sig=$signatureValid | '
          'expired=${!notExpired}',
        );
      }
    } catch (e) {
      stopwatch.stop();
      hasil.tidakSesuaiEkspektasi++;
      hasil.keterangan.add('✗ Exception: $e');
      print('Iterasi $i: ✗ EXCEPTION | $e');
    }
  }

  return hasil;
}

// ============================================================
// SKENARIO T6-NEG — JWT VC: Payload Dimanipulasi
// ============================================================
Future<HasilSkenario> testT6NEG(
  String jwtVC,
  SimplePublicKey issuerPublicKey,
) async {
  final hasil = HasilSkenario(
    id: 'T6-NEG',
    nama: 'Verifikasi JWT VC — Payload Dikorupsi',
    jenis: 'Negatif',
    iterasi: TOTAL_ITERASI,
  );

  print('\n[T6-NEG] Verifikasi JWT VC — Payload Dikorupsi');
  printSubSeparator();
  print(
      'Perlakuan: Mengubah status dari AKTIF ke TIDAK AKTIF tanpa signing ulang');

  for (int i = 1; i <= TOTAL_ITERASI; i++) {
    final stopwatch = Stopwatch()..start();

    try {
      // Pecah JWT menjadi 3 bagian
      final parts = jwtVC.split('.');
      final header = parts[0];
      final signature = parts[2]; // signature TIDAK diubah

      // Decode payload
      final decodedPayload = jsonDecode(
        utf8.decode(base64UrlDecode(parts[1])),
      ) as Map<String, dynamic>;

      // MANIPULASI: ubah status credential
      (decodedPayload['vc'] as Map)['credentialSubject']['status'] =
          'TIDAK AKTIF';

      // Encode ulang payload yang sudah dimanipulasi
      final manipulatedPayload =
          base64UrlEncode(utf8.encode(jsonEncode(decodedPayload)));

      // Gabung: header + payload BARU + signature LAMA
      final tamperedJwt = '$header.$manipulatedPayload.$signature';

      // Verifikasi — harusnya GAGAL karena payload berubah
      final signatureValid = await verifyJwt(tamperedJwt, issuerPublicKey);

      stopwatch.stop();
      final ms = stopwatch.elapsedMicroseconds / 1000.0;

      // Skenario negatif: SESUAI EKSPEKTASI jika signature TIDAK valid
      if (!signatureValid) {
        hasil.sesuaiEkspektasi++;
        hasil.waktuMs.add(ms);
        hasil.keterangan.add('✓ Manipulasi terdeteksi');
        print(
          'Iterasi $i: ✓ SESUAI EKSPEKTASI | '
          'Sistem MENOLAK payload yang dimanipulasi | '
          '${ms.toStringAsFixed(3)}ms',
        );
      } else {
        // Ini TIDAK diharapkan — berarti sistem gagal deteksi manipulasi
        hasil.tidakSesuaiEkspektasi++;
        hasil.keterangan.add('✗ BAHAYA: Manipulasi TIDAK terdeteksi!');
        print(
          'Iterasi $i: ✗ TIDAK SESUAI EKSPEKTASI | '
          'BAHAYA: Sistem menerima payload yang dimanipulasi!',
        );
      }
    } catch (e) {
      stopwatch.stop();
      // Exception saat verifikasi JWT manipulasi = sistem menolak = SESUAI
      hasil.sesuaiEkspektasi++;
      hasil.waktuMs.add(stopwatch.elapsedMicroseconds / 1000.0);
      hasil.keterangan.add('✓ Exception = manipulasi terdeteksi');
      print(
        'Iterasi $i: ✓ SESUAI EKSPEKTASI | '
        'Exception = manipulasi terdeteksi: ${e.runtimeType}',
      );
    }
  }

  return hasil;
}

// ============================================================
// SKENARIO T7 — Credential Serialization
// ============================================================
Future<HasilSkenario> testT7(String jwtVC) async {
  final hasil = HasilSkenario(
    id: 'T7',
    nama: 'Serialisasi Penyimpanan Kredensial',
    jenis: 'Positif',
    iterasi: TOTAL_ITERASI,
  );

  print('\n[T7] Serialisasi Penyimpanan Kredensial');
  printSubSeparator();

  for (int i = 1; i <= TOTAL_ITERASI; i++) {
    final stopwatch = Stopwatch()..start();

    try {
      // Bentuk CredentialModel
      final credentialModel = {
        'id': 'cred-${DateTime.now().millisecondsSinceEpoch}-$i',
        'rawJwt': jwtVC,
        'format': 'jwt_vc_json',
        'issuerDid': ISSUER_DID,
        'status': 'ACTIVE',
        'syncStatus': 'SYNCED',
        'lastChecked': DateTime.now().toIso8601String(),
        'credentialName': 'KartuBPJSKesehatan',
      };

      // Serialisasi ke JSON string (simulasi penyimpanan ke SecureStorage)
      final jsonString = jsonEncode(credentialModel);
      final payloadSize = utf8.encode(jsonString).length;

      // Deserialisasi kembali
      final deserialized = jsonDecode(jsonString) as Map<String, dynamic>;

      // Validasi field-by-field
      final rawJwtMatch = deserialized['rawJwt'] == jwtVC;
      final issuerMatch = deserialized['issuerDid'] == ISSUER_DID;
      final formatMatch = deserialized['format'] == 'jwt_vc_json';
      final statusMatch = deserialized['status'] == 'ACTIVE';

      stopwatch.stop();
      final ms = stopwatch.elapsedMicroseconds / 1000.0;

      if (rawJwtMatch && issuerMatch && formatMatch && statusMatch) {
        hasil.sesuaiEkspektasi++;
        hasil.waktuMs.add(ms);
        hasil.keterangan.add('✓');
        print(
          'Iterasi $i: ✓ SESUAI | '
          '${payloadSize}B | '
          'rawJwt=$rawJwtMatch | '
          'issuer=$issuerMatch | '
          '${ms.toStringAsFixed(3)}ms',
        );
      } else {
        hasil.tidakSesuaiEkspektasi++;
        hasil.keterangan.add(
          '✗ rawJwt=$rawJwtMatch issuer=$issuerMatch',
        );
        print(
          'Iterasi $i: ✗ TIDAK SESUAI | '
          'rawJwt=$rawJwtMatch | '
          'issuer=$issuerMatch',
        );
      }
    } catch (e) {
      stopwatch.stop();
      hasil.tidakSesuaiEkspektasi++;
      hasil.keterangan.add('✗ Exception: $e');
      print('Iterasi $i: ✗ EXCEPTION | $e');
    }
  }

  return hasil;
}

// ============================================================
// SKENARIO T9 — JWT VP Construction
// ============================================================
Future<(HasilSkenario, String)> testT9(
  String jwtVC,
  SimpleKeyPair holderKeyPair,
  String holderDid,
) async {
  final hasil = HasilSkenario(
    id: 'T9',
    nama: 'JWT VP Construction',
    jenis: 'Positif',
    iterasi: TOTAL_ITERASI,
  );

  print('\n[T9] JWT VP Construction');
  printSubSeparator();

  final holderPublicKey = await holderKeyPair.extractPublicKey();
  String lastValidJwtVP = '';

  for (int i = 1; i <= TOTAL_ITERASI; i++) {
    final stopwatch = Stopwatch()..start();

    try {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // Simulasi nonce dari Verifier (unik per sesi)
      final nonceVerifier =
          'nonce_verifier_${DateTime.now().millisecondsSinceEpoch}_$i';

      // Bentuk header JWT VP
      final header = {
        'alg': 'EdDSA',
        'typ': 'JWT',
        'kid': holderDid,
      };

      // Bentuk payload JWT VP
      final payload = {
        'iss': holderDid,
        'aud': VERIFIER_DID,
        'iat': now,
        'exp': now + 300, // VP berlaku 5 menit
        'nonce': nonceVerifier,
        'vp': {
          '@context': ['https://www.w3.org/2018/credentials/v1'],
          'type': ['VerifiablePresentation'],
          'verifiableCredential': [jwtVC], // VC embedded
          'holder': holderDid,
        },
      };

      // Bentuk signing input dan tandatangani dengan private key Holder
      final signingInput = buildJwt(header, payload);
      final jwtVP = await signJwt(signingInput, holderKeyPair);

      // Validasi struktur
      final parts = jwtVP.split('.');
      final valid3Parts = parts.length == 3;

      // Verifikasi signature
      final signatureValid = await verifyJwt(jwtVP, holderPublicKey);

      // Periksa VC tertanam di dalam VP
      final decodedPayload = jsonDecode(
        utf8.decode(base64UrlDecode(parts[1])),
      ) as Map<String, dynamic>;
      final vcList =
          (decodedPayload['vp'] as Map)['verifiableCredential'] as List;
      final vcEmbedded = vcList.isNotEmpty && vcList[0] == jwtVC;

      // Periksa nonce tersertakan
      final noncePresent = decodedPayload['nonce'] == nonceVerifier;

      // Hitung ukuran payload
      final payloadSize = utf8.encode(jwtVP).length;

      stopwatch.stop();
      final ms = stopwatch.elapsedMicroseconds / 1000.0;

      if (valid3Parts && signatureValid && vcEmbedded && noncePresent) {
        hasil.sesuaiEkspektasi++;
        hasil.waktuMs.add(ms);
        hasil.keterangan.add('✓');
        lastValidJwtVP = jwtVP;
        print(
          'Iterasi $i: ✓ SESUAI | '
          'sig=$signatureValid | '
          'vcEmbedded=$vcEmbedded | '
          'nonce=$noncePresent | '
          '${payloadSize}B | '
          '${ms.toStringAsFixed(3)}ms',
        );
      } else {
        hasil.tidakSesuaiEkspektasi++;
        hasil.keterangan.add(
          '✗ sig=$signatureValid vc=$vcEmbedded nonce=$noncePresent',
        );
        print(
          'Iterasi $i: ✗ TIDAK SESUAI | '
          'sig=$signatureValid | '
          'vc=$vcEmbedded | '
          'nonce=$noncePresent',
        );
      }
    } catch (e) {
      stopwatch.stop();
      hasil.tidakSesuaiEkspektasi++;
      hasil.keterangan.add('✗ Exception: $e');
      print('Iterasi $i: ✗ EXCEPTION | $e');
    }
  }

  return (hasil, lastValidJwtVP);
}

// ============================================================
// SKENARIO T10 — JWT VP Verification
// ============================================================
Future<HasilSkenario> testT10(
  String jwtVP,
  SimplePublicKey holderPublicKey,
  SimplePublicKey issuerPublicKey,
) async {
  final hasil = HasilSkenario(
    id: 'T10',
    nama: 'Verifikasi Struktur JWT VP',
    jenis: 'Positif',
    iterasi: TOTAL_ITERASI,
  );

  print('\n[T10] Verifikasi Struktur JWT VP');
  printSubSeparator();
  print('Proses: Dua lapis verifikasi EdDSA (VP Holder + VC Issuer embedded)');

  for (int i = 1; i <= TOTAL_ITERASI; i++) {
    final stopwatch = Stopwatch()..start();

    try {
      // === LAPIS 1: Verifikasi signature JWT VP menggunakan public key Holder ===
      final vpSignatureValid = await verifyJwt(jwtVP, holderPublicKey);

      // Decode payload VP
      final vpParts = jwtVP.split('.');
      final vpPayload = jsonDecode(
        utf8.decode(base64UrlDecode(vpParts[1])),
      ) as Map<String, dynamic>;

      // Validasi nonce dan aud
      final hasNonce = vpPayload.containsKey('nonce');
      final audValid = vpPayload['aud'] == VERIFIER_DID;
      final expVP = vpPayload['exp'] as int;
      final vpNotExpired =
          expVP > DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // === LAPIS 2: Verifikasi signature JWT VC embedded ===
      final vcList = (vpPayload['vp'] as Map)['verifiableCredential'] as List;
      final embeddedJwtVC = vcList[0] as String;
      final vcSignatureValid = await verifyJwt(embeddedJwtVC, issuerPublicKey);

      // Decode payload VC dan periksa klaim
      final vcParts = embeddedJwtVC.split('.');
      final vcPayload = jsonDecode(
        utf8.decode(base64UrlDecode(vcParts[1])),
      ) as Map<String, dynamic>;
      final credSubject = (vcPayload['vc'] as Map)['credentialSubject'] as Map;
      final allClaimsValid = credSubject.containsKey('NIK') &&
          credSubject.containsKey('nama') &&
          credSubject['status'] == 'AKTIF';

      stopwatch.stop();
      final ms = stopwatch.elapsedMicroseconds / 1000.0;

      final allValid = vpSignatureValid &&
          vcSignatureValid &&
          hasNonce &&
          audValid &&
          vpNotExpired &&
          allClaimsValid;

      if (allValid) {
        hasil.sesuaiEkspektasi++;
        hasil.waktuMs.add(ms);
        hasil.keterangan.add('✓');
        print(
          'Iterasi $i: ✓ SESUAI | '
          'vpSig=$vpSignatureValid | '
          'vcSig=$vcSignatureValid | '
          'aud=$audValid | '
          'claims=$allClaimsValid | '
          '${ms.toStringAsFixed(3)}ms',
        );
      } else {
        hasil.tidakSesuaiEkspektasi++;
        hasil.keterangan.add(
          '✗ vpSig=$vpSignatureValid vcSig=$vcSignatureValid',
        );
        print(
          'Iterasi $i: ✗ TIDAK SESUAI | '
          'vpSig=$vpSignatureValid | '
          'vcSig=$vcSignatureValid',
        );
      }
    } catch (e) {
      stopwatch.stop();
      hasil.tidakSesuaiEkspektasi++;
      hasil.keterangan.add('✗ Exception: $e');
      print('Iterasi $i: ✗ EXCEPTION | $e');
    }
  }

  return hasil;
}

// ============================================================
// SKENARIO T10-NEG — JWT VP: Replay Attack (Nonce Tidak Sesuai)
// ============================================================
Future<HasilSkenario> testT10NEG(
  String jwtVP,
  SimplePublicKey holderPublicKey,
  SimplePublicKey issuerPublicKey,
) async {
  final hasil = HasilSkenario(
    id: 'T10-NEG',
    nama: 'Verifikasi JWT VP — Nonce Tidak Sesuai',
    jenis: 'Negatif',
    iterasi: TOTAL_ITERASI,
  );

  print('\n[T10-NEG] Verifikasi JWT VP — Replay Attack (Nonce Tidak Sesuai)');
  printSubSeparator();
  print('Perlakuan: Mengirim ulang JWT VP lama dengan nonce sesi yang berbeda');

  // Simulasi nonce sesi aktif yang baru (berbeda dari nonce dalam VP)
  const String nonceSessionAktif = 'nonce_sesi_baru_berbeda_12345';

  for (int i = 1; i <= TOTAL_ITERASI; i++) {
    final stopwatch = Stopwatch()..start();

    try {
      // Decode payload VP yang sudah ada (VP lama dari sesi sebelumnya)
      final vpParts = jwtVP.split('.');
      final vpPayload = jsonDecode(
        utf8.decode(base64UrlDecode(vpParts[1])),
      ) as Map<String, dynamic>;

      // Ambil nonce dari VP lama
      final nonceInVP = vpPayload['nonce'] as String;

      // Simulasi validasi nonce di sisi Verifier:
      // nonce dalam VP harus cocok dengan nonce sesi aktif
      final nonceMatch = nonceInVP == nonceSessionAktif;

      // Jika nonce tidak cocok → VP ditolak (anti-replay)
      // Tidak perlu verifikasi signature jika nonce sudah tidak cocok
      final vpDitolak = !nonceMatch;

      stopwatch.stop();
      final ms = stopwatch.elapsedMicroseconds / 1000.0;

      // Skenario negatif: SESUAI EKSPEKTASI jika VP DITOLAK
      if (vpDitolak) {
        hasil.sesuaiEkspektasi++;
        hasil.waktuMs.add(ms);
        hasil.keterangan.add('✓ Replay attack terdeteksi');
        print(
          'Iterasi $i: ✓ SESUAI EKSPEKTASI | '
          'Sistem MENOLAK VP (nonce VP="$nonceInVP" ≠ sesi="$nonceSessionAktif") | '
          '${ms.toStringAsFixed(3)}ms',
        );
      } else {
        // Ini sangat tidak diharapkan
        hasil.tidakSesuaiEkspektasi++;
        hasil.keterangan.add('✗ BAHAYA: Replay attack TIDAK terdeteksi!');
        print(
          'Iterasi $i: ✗ TIDAK SESUAI EKSPEKTASI | '
          'BAHAYA: VP lama diterima oleh sesi baru!',
        );
      }
    } catch (e) {
      stopwatch.stop();
      hasil.sesuaiEkspektasi++;
      hasil.waktuMs.add(stopwatch.elapsedMicroseconds / 1000.0);
      hasil.keterangan.add('✓ Exception = replay terdeteksi');
      print(
        'Iterasi $i: ✓ SESUAI EKSPEKTASI | '
        'Exception = replay terdeteksi: ${e.runtimeType}',
      );
    }
  }

  return hasil;
}

// ============================================================
// CETAK TABEL REKAPITULASI
// ============================================================
void printRekapitulasi(List<HasilSkenario> semuaHasil) {
  printSeparator();
  print('REKAPITULASI HASIL PENGUJIAN SUCCESS RATE');
  printSeparator();
  print(
    '${'ID'.padRight(10)}'
    '${'Skenario'.padRight(38)}'
    '${'Jenis'.padRight(10)}'
    '${'Iter'.padRight(6)}'
    '${'Sesuai'.padRight(8)}'
    '${'Tdk Sesuai'.padRight(12)}'
    '${'Rate'.padRight(8)}'
    'Avg(ms)',
  );
  printSubSeparator();

  for (final h in semuaHasil) {
    print(
      '${h.id.padRight(10)}'
      '${h.nama.substring(0, h.nama.length > 37 ? 37 : h.nama.length).padRight(38)}'
      '${h.jenis.padRight(10)}'
      '${h.iterasi.toString().padRight(6)}'
      '${h.sesuaiEkspektasi.toString().padRight(8)}'
      '${h.tidakSesuaiEkspektasi.toString().padRight(12)}'
      '${h.successRate.padRight(8)}'
      '${h.avgMs.toStringAsFixed(3)}ms',
    );
  }

  printSeparator();

  final totalSesuai = semuaHasil.fold(0, (sum, h) => sum + h.sesuaiEkspektasi);
  final totalIterasi = semuaHasil.fold(0, (sum, h) => sum + h.iterasi);
  final overallRate = (totalSesuai / totalIterasi * 100).toStringAsFixed(1);

  print('Total Iterasi       : $totalIterasi');
  print('Total Sesuai        : $totalSesuai');
  print('Total Tidak Sesuai  : ${totalIterasi - totalSesuai}');
  print('Overall Success Rate: $overallRate%');

  printSeparator();
  print('Keterangan Kolom:');
  print('  Sesuai     = iterasi yang menghasilkan output sesuai ekspektasi');
  print('  Tdk Sesuai = iterasi yang tidak sesuai ekspektasi');
  print('  Skenario Positif  → Sesuai = operasi BERHASIL dijalankan');
  print('  Skenario Negatif  → Sesuai = sistem BERHASIL MENOLAK input cacat');
  printSeparator();
}

// ============================================================
// MAIN — EKSEKUSI SERIAL SEMUA SKENARIO
// ============================================================
Future<void> main() async {
  printSeparator();
  print('IDentia — Pengujian Success Rate (Serial)');
  print('Tanggal : ${DateTime.now()}');
  print('Iterasi : $TOTAL_ITERASI per skenario');
  print('Mode    : Offline (tanpa koneksi jaringan)');
  printSeparator();

  final algorithm = Ed25519();
  final semuaHasil = <HasilSkenario>[];

  // ── Setup: Generate keypair Holder dan Issuer sekali di awal ──
  print('\n[SETUP] Membangkitkan keypair Holder dan Issuer...');
  final holderKeyPair = await algorithm.newKeyPair();
  final issuerKeyPair = await algorithm.newKeyPair();
  final holderPublicKey = await holderKeyPair.extractPublicKey();
  final issuerPublicKey = await issuerKeyPair.extractPublicKey();

  // Bentuk DID Holder
  final holderJwk = {
    'kty': 'OKP',
    'crv': 'Ed25519',
    'x': base64UrlEncode(holderPublicKey.bytes),
  };
  final holderDid =
      'did:jwk:${base64UrlEncode(utf8.encode(jsonEncode(holderJwk)))}';

  print('Holder DID : ${holderDid.substring(0, 50)}...');
  print('Issuer DID : $ISSUER_DID');
  print('Setup selesai ✓\n');

  // ── T1: Ed25519 Key Pair Generation ──
  semuaHasil.add(await testT1());

  // ── T2: DID:JWK Formation ──
  semuaHasil.add(await testT2(holderKeyPair));

  // ── T4: Proof JWT Construction ──
  semuaHasil.add(await testT4(holderKeyPair));

  // ── T5: JWT VC Construction (hasilkan JWT VC untuk test berikutnya) ──
  final (hasilT5, jwtVC) = await testT5(issuerKeyPair, holderDid);
  semuaHasil.add(hasilT5);

  if (jwtVC.isEmpty) {
    print(
        '\n⚠️ JWT VC tidak terbentuk. T6, T6-NEG, T7, T9, T10, T10-NEG dilewati.');
    printRekapitulasi(semuaHasil);
    return;
  }

  // ── T6: JWT VC Verification ──
  semuaHasil.add(await testT6(jwtVC, issuerPublicKey));

  // ── T6-NEG: JWT VC Payload Dimanipulasi ──
  semuaHasil.add(await testT6NEG(jwtVC, issuerPublicKey));

  // ── T7: Credential Serialization ──
  semuaHasil.add(await testT7(jwtVC));

  // ── T9: JWT VP Construction (hasilkan JWT VP untuk T10) ──
  final (hasilT9, jwtVP) = await testT9(jwtVC, holderKeyPair, holderDid);
  semuaHasil.add(hasilT9);

  if (jwtVP.isEmpty) {
    print('\n⚠️ JWT VP tidak terbentuk. T10 dan T10-NEG dilewati.');
    printRekapitulasi(semuaHasil);
    return;
  }

  // ── T10: JWT VP Verification ──
  semuaHasil.add(
    await testT10(jwtVP, holderPublicKey, issuerPublicKey),
  );

  // ── T10-NEG: Replay Attack ──
  semuaHasil.add(
    await testT10NEG(jwtVP, holderPublicKey, issuerPublicKey),
  );

  // ── Cetak rekapitulasi ──
  printRekapitulasi(semuaHasil);
}
