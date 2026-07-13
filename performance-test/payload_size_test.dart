// payload_size_test.dart
// Pengujian Ukuran Payload IDentia — skenario T1..T10 x kombinasi perlakuan P1..P12
// Jalankan: dart run payload_size_test.dart
//
// pubspec.yaml (dependencies):
//   cryptography: ^2.7.0
//
// Catatan: ukuran payload bersifat DETERMINISTIK — hanya dipengaruhi kompleksitas
// kredensial (faktor A), tidak oleh jaringan (B) maupun konkurensi (C). Karena itu
// pengukuran dilakukan offline; baris P1–P6 (minimal) identik, begitu pula P7–P12
// (lengkap). Faktor A hanya menggeser artefak yang dikonstruksi Holder/Issuer (T5).

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';

// ── Konfigurasi lingkungan uji IDentia ─────────────────────────────────
const String kBaseUrlIssuer = 'https://issuer.identia.my.id';
const String kBaseUrlVerifier = 'http://verifier.identia.my.id';
const String kPathCredentialOffer = '/.well-known/openid-credential-issuer';
const String kUsernameIssuer = 'admin';
const String kPasswordIssuer = 'admin123';
const String kPathCreateOffer = '/oid4vci/credential-offer';
const String kCredentialConfigId = 'kartu_bpjs_kesehatan';

// Credential Offer URI (deeplink yang diterima Holder pada langkah T3).
const String kCredentialOfferUri =
    'openid-credential-offer://?credential_offer_uri=https%3A%2F%2Fissuer.identia.my.id%2Foid4vci%2Fcredential-offer%2F9d046694-0659-4b93-80a5-12f7315cb085';

const String kHolderNik = '3201010203050001';
const String kHolderPassword = 'Deva123';
const String kHolderPublicKeyB64 =
    'z_yRmHTyDQhxMYXBAK_CXCJrPY897v62QWFzxHk1C2k';
const String kHolderDid =
    'did:jwk:eyJrdHkiOiJPS1AiLCJjcnYiOiJFZDI1NTE5IiwieCI6InpfeVJtSFR5RFFoeE1ZWEJBS19DWENKclBZODk3djYyUVdGenhIazFDMmsifQ';
const String kIssuerPublicKeyMultibase =
    'z6MkhyKruKxbzoUegAD4s7x8hzwbahsKa2q5rwAtK9CZ86dU';

// JWT VC uji nyata (utuh).
const String kJwtVc =
    'eyJraWQiOiJkaWQ6d2ViOmlzc3Vlci5pZGVudGlhLm15LmlkI2tleS0xIiwiYWxnIjoiRWREU0EiLCJ0eXAiOiJKV1QifQ.eyJ2YyI6eyJAY29udGV4dCI6WyJodHRwczovL3d3dy53My5vcmcvMjAxOC9jcmVkZW50aWFscy92MSJdLCJ0eXBlIjpbIlZlcmlmaWFibGVDcmVkZW50aWFsIiwiS2FydHVCUEpTS2VzZWhhdGFuIl0sImlkIjoidXJuOnV1aWQ6MDVhNDkzMTktY2MzNy00MThjLWIxNzEtZWY0NWE2ZDg5Mjk5IiwiaXNzdWVyIjoiZGlkOndlYjppc3N1ZXIuaWRlbnRpYS5teS5pZCIsImlzc3VhbmNlRGF0ZSI6IjIwMjYtMDctMDVUMDM6Mzk6MzIuMDAwWiIsImNyZWRlbnRpYWxTdWJqZWN0Ijp7ImlkIjoiZGlkOmp3azpleUpyZEhraU9pSlBTMUFpTENKamNuWWlPaUpGWkRJMU5URTVJaXdpZUNJNklucGZlVkp0U0ZSNVJGRm9lRTFaV0VKQlMxOURXRU5LY2xCWk9EazNkall5VVZkR2VuaElhekZETW1zaWZRIiwiY3JlZGVudGlhbE5hbWUiOiJLYXJ0dSBCUEpTIEtlc2VoYXRhbiIsImhvbGRlck5hbWUiOiJEZXZhIEZpbmFuZGEgU2FwdXRyYSIsIm5payI6IjMyMDEwMTAyMDMwNTAwMDEiLCJub0JQSlMiOiIzMjAxMDEwMjAzMDUwIiwidGFuZ2dhbExhaGlyIjoiMjAwNS0wMi0wMyJ9fSwic3ViIjoiZGlkOmp3azpleUpyZEhraU9pSlBTMUFpTENKamNuWWlPaUpGWkRJMU5URTVJaXdpZUNJNklucGZlVkp0U0ZSNVJGRm9lRTFaV0VKQlMxOURXRU5LY2xCWk9EazNkall5VVZkR2VuaElhekZETW1zaWZRIiwibmJmIjoxNzgzMjIyNzcyLCJqdGkiOiJ1cm46dXVpZDowNWE0OTMxOS1jYzM3LTQxOGMtYjE3MS1lZjQ1YTZkODkyOTkiLCJpc3MiOiJkaWQ6d2ViOmlzc3Vlci5pZGVudGlhLm15LmlkIn0.MCpfVugLALCaRPdBp2IBxF5LSnwy6MxHGKrxFl_H7SgaUP05u4C9vHcE73MsaO-KFQY7ZkRC6jD9GCw4kaPWAg';

// JWT VP uji nyata (utuh; menyisipkan JWT VC di atas).
const String kJwtVp =
    'eyJhbGciOiJFZERTQSIsInR5cCI6InZwK2p3dCIsImtpZCI6ImRpZDpqd2s6ZXlKcmRIa2lPaUpQUzFBaUxDSmpjbllpT2lKRlpESTFOVEU1SWl3aWVDSTZJbnBmZVZKdFNGUjVSRkZvZUUxWldFSkJTMTlEV0VOS2NsQlpPRGszZGpZeVVWZEdlbmhJYXpGRE1tc2lmUSMwIn0.eyJpc3MiOiJkaWQ6andrOmV5SnJkSGtpT2lKUFMxQWlMQ0pqY25ZaU9pSkZaREkxTlRFNUlpd2llQ0k2SW5wZmVWSnRTRlI1UkZGb2VFMVpXRUpCUzE5RFdFTktjbEJaT0RrM2RqWXlVVmRHZW5oSWF6RkRNbXNpZlEiLCJzdWIiOiJkaWQ6andrOmV5SnJkSGtpT2lKUFMxQWlMQ0pqY25ZaU9pSkZaREkxTlRFNUlpd2llQ0k2SW5wZmVWSnRTRlI1UkZGb2VFMVpXRUpCUzE5RFdFTktjbEJaT0RrM2RqWXlVVmRHZW5oSWF6RkRNbXNpZlEiLCJhdWQiOiJkaWQ6d2ViOnZlcmlmaWVyLmlkZW50aWEubXkuaWQiLCJub25jZSI6IlowWWJFQjVZOHRhUVA3R0VOOWVTNWh5dGdLM00zOXhuNHUwell1MjFka2MiLCJpYXQiOjE3ODMyMjkyNTIsIm5iZiI6MTc4MzIyOTI1MiwiZXhwIjoxNzgzMjI5MzcyLCJqdGkiOiJ1cm46dXVpZDo1OGVhOGFkNy02MDg3LTRhM2UtOGU3YS1hY2IwYWEwZmU5YjAiLCJ2cCI6eyJpZCI6InVybjp1dWlkOjU4ZWE4YWQ3LTYwODctNGEzZS04ZTdhLWFjYjBhYTBmZTliMCIsIkBjb250ZXh0IjpbImh0dHBzOi8vd3d3LnczLm9yZy8yMDE4L2NyZWRlbnRpYWxzL3YxIl0sInR5cGUiOlsiVmVyaWZpYWJsZVByZXNlbnRhdGlvbiJdLCJob2xkZXIiOiJkaWQ6andrOmV5SnJkSGtpT2lKUFMxQWlMQ0pqY25ZaU9pSkZaREkxTlRFNUlpd2llQ0k2SW5wZmVWSnRTRlI1UkZGb2VFMVpXRUpCUzE5RFdFTktjbEJaT0RrM2RqWXlVVmRHZW5oSWF6RkRNbXNpZlEiLCJ2ZXJpZmlhYmxlQ3JlZGVudGlhbCI6WyJleUpyYVdRaU9pSmthV1E2ZDJWaU9tbHpjM1ZsY2k1cFpHVnVkR2xoTG0xNUxtbGtJMnRsZVMweElpd2lZV3huSWpvaVJXUkVVMEVpTENKMGVYQWlPaUpLVjFRaWZRLmV5SjJZeUk2ZXlKQVkyOXVkR1Y0ZENJNld5Sm9kSFJ3Y3pvdkwzZDNkeTUzTXk1dmNtY3ZNakF4T0M5amNtVmtaVzUwYVdGc2N5OTJNU0pkTENKMGVYQmxJanBiSWxabGNtbG1hV0ZpYkdWRGNtVmtaVzUwYVdGc0lpd2lTMkZ5ZEhWQ1VFcFRTMlZ6WldoaGRHRnVJbDBzSW1sa0lqb2lkWEp1T25WMWFXUTZNRFZoTkRrek1Ua3RZMk16TnkwME1UaGpMV0l4TnpFdFpXWTBOV0UyWkRnNU1qazVJaXdpYVhOemRXVnlJam9pWkdsa09uZGxZanBwYzNOMVpYSXVhV1JsYm5ScFlTNXRlUzVwWkNJc0ltbHpjM1ZoYm1ObFJHRjBaU0k2SWpJd01qWXRNRGN0TURWVU1ETTZNems2TXpJdU1EQXdXaUlzSW1OeVpXUmxiblJwWVd4VGRXSnFaV04wSWpwN0ltbGtJam9pWkdsa09tcDNhenBsZVVweVpFaHJhVTlwU2xCVE1VRnBURU5LYW1OdVdXbFBhVXBHV2tSSk1VNVVSVFZKYVhkcFpVTkpOa2x1Y0dabFZrcDBVMFpTTlZKR1JtOWxSVEZhVjBWS1FsTXhPVVJYUlU1TFkyeENXazlFYXpOa2FsbDVWVlprUjJWdWFFbGhla1pFVFcxemFXWlJJaXdpWTNKbFpHVnVkR2xoYkU1aGJXVWlPaUpMWVhKMGRTQkNVRXBUSUV0bGMyVm9ZWFJoYmlJc0ltaHZiR1JsY2s1aGJXVWlPaUpFWlhaaElFWnBibUZ1WkdFZ1UyRndkWFJ5WVNJc0ltNXBheUk2SWpNeU1ERXdNVEF5TURNd05UQXdNREVpTENKdWIwSlFTbE1pT2lJek1qQXhNREV3TWpBek1EVXdJaXdpZEdGdVoyZGhiRXhoYUdseUlqb2lNakF3TlMwd01pMHdNeUo5ZlN3aWMzVmlJam9pWkdsa09tcDNhenBsZVVweVpFaHJhVTlwU2xCVE1VRnBURU5LYW1OdVdXbFBhVXBHV2tSSk1VNVVSVFZKYVhkcFpVTkpOa2x1Y0dabFZrcDBVMFpTTlZKR1JtOWxSVEZhVjBWS1FsTXhPVVJYUlU1TFkyeENXazlFYXpOa2FsbDVWVlprUjJWdWFFbGhla1pFVFcxemFXWlJJaXdpYm1KbUlqb3hOemd6TWpJeU56Y3lMQ0pxZEdraU9pSjFjbTQ2ZFhWcFpEb3dOV0UwT1RNeE9TMWpZek0zTFRReE9HTXRZakUzTVMxbFpqUTFZVFprT0RreU9Ua2lMQ0pwYzNNaU9pSmthV1E2ZDJWaU9tbHpjM1ZsY2k1cFpHVnVkR2xoTG0xNUxtbGtJbjAuTUNwZlZ1Z0xBTENhUlBkQnAySUJ4RjVMU253eTZNeEhHS3J4RmxfSDdTZ2FVUDA1dTRDOXZIY0U3M01zYU8tS0ZRWTdaa1JDNmpEOUdDdzRrYVBXQWciXX19.zuvm4M3BbdiKg3lxcNhD4weHykCpAspWBLkrfBv-G3f0Y-FJGjGABHX8UXpKRrBGdDfH2GEnYmgzkN4Mp-ZMDQ';

// Authorization Request OID4VP (utuh).
const String kAuthRequestUri =
    'openid4vp://authorize?client_id=did:web:verifier.identia.my.id'
    '&response_type=vp_token'
    '&response_mode=direct_post'
    '&nonce=Z0YbEB5Y8taQP7GEN9eS5hytgK3M39xn4u0zYu21dkc'
    '&presentation_definition_uri=https://verifier.identia.my.id/oid4vp/pd/1';

// ── Parameter eksekusi ─────────────────────────────────────────────────
final Ed25519 _ed25519 = Ed25519();
final Random _rng = Random.secure();

// ── Rancangan faktorial P1..P12 (lihat Tabel 4.9) ──────────────────────
class Treatment {
  final String kode; // P1..P12
  final bool lengkap; // faktor A: kompleksitas kredensial
  final String jaringan; // faktor B: '5G' / '4G'
  final int konkurensi; // faktor C: 1 / 5 / 10
  const Treatment(this.kode, this.lengkap, this.jaringan, this.konkurensi);
}

const List<Treatment> kKombinasi = [
  Treatment('P1', false, '5G', 1),
  Treatment('P2', false, '5G', 5),
  Treatment('P3', false, '5G', 10),
  Treatment('P4', false, '4G', 1),
  Treatment('P5', false, '4G', 5),
  Treatment('P6', false, '4G', 10),
  Treatment('P7', true, '5G', 1),
  Treatment('P8', true, '5G', 5),
  Treatment('P9', true, '5G', 10),
  Treatment('P10', true, '4G', 1),
  Treatment('P11', true, '4G', 5),
  Treatment('P12', true, '4G', 10),
];

int _now() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

String _b64url(List<int> b) => base64Url.encode(b).replaceAll('=', '');

String _nonce([int n = 24]) =>
    _b64url(List<int>.generate(n, (_) => _rng.nextInt(256)));

String _uuid() {
  final b = List<int>.generate(16, (_) => _rng.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  String hx(int x) => x.toRadixString(16).padLeft(2, '0');
  final s = b.map(hx).join();
  return '${s.substring(0, 8)}-${s.substring(8, 12)}-${s.substring(12, 16)}-'
      '${s.substring(16, 20)}-${s.substring(20)}';
}

Future<String> _signJwt(
  Map<String, dynamic> header,
  Map<String, dynamic> payload,
  SimpleKeyPair kp,
) async {
  final h = _b64url(utf8.encode(jsonEncode(header)));
  final p = _b64url(utf8.encode(jsonEncode(payload)));
  final signingInput = '$h.$p';
  final sig = await _ed25519.sign(utf8.encode(signingInput), keyPair: kp);
  return '$signingInput.${_b64url(sig.bytes)}';
}

Map<String, dynamic> _subjectClaims(bool lengkap) {
  final dasar = {'id': kHolderDid, 'nik': kHolderNik};
  if (!lengkap) return dasar;
  return {
    ...dasar,
    'credentialName': 'Kartu BPJS Kesehatan',
    'holderName': 'Deva Finanda Saputra',
    'noBPJS': '320101020305',
    'tanggalLahir': '2005-02-03',
    'kelasRawat': 'II',
    'faskesTingkat1': 'Puskesmas Kartasura',
    'statusPeserta': 'AKTIF',
    'golonganDarah': 'O',
  };
}

// Pasangan kunci Holder dipakai ulang lintas skenario penandatanganan.
SimpleKeyPair? _holderKp;
Future<SimpleKeyPair> _holder() async =>
    _holderKp ??= await _ed25519.newKeyPair();

// ── Pengukur ukuran payload ────────────────────────────────────────────
// Kontrak skenario: membangun artefak (string) yang ukurannya ditimbang.
typedef Artefak = Future<String> Function(Treatment t);

/// Ukuran payload (byte) = panjang representasi UTF-8 artefak.
Future<int> ukurUkuranPayload(Treatment t, String id, Artefak bangun) async {
  final artefak = await bangun(t);
  final bytes = utf8.encode(artefak).length; // S = panjang(utf8(artefak))
  print('${t.kode} | $id | payload: $bytes byte');
  return bytes;
}

// ── Definisi artefak T1..T10 (mengikuti operasi pada skrip waktu respons) ─
// T1 - Ed25519 Key Pair Generation -> representasi kunci publik (JWK).
Future<String> t1KeyPair(Treatment t) async {
  final pub = await (await _holder()).extractPublicKey();
  return jsonEncode({'kty': 'OKP', 'crv': 'Ed25519', 'x': _b64url(pub.bytes)});
}

// T2 - Pembentukan DID:JWK -> string DID Holder.
Future<String> t2DidJwk(Treatment t) async => kHolderDid;

// T3 - Credential Offer (OID4VCI) -> deeplink offer yang diterima Holder.
Future<String> t3CredentialOffer(Treatment t) async => kCredentialOfferUri;

// T4 - Proof JWT Construction (ditandatangani Holder).
Future<String> t4ProofJwt(Treatment t) async {
  final kp = await _holder();
  return _signJwt(
    {'typ': 'openid4vci-proof+jwt', 'alg': 'EdDSA', 'kid': '$kHolderDid#0'},
    {
      'iss': kHolderDid,
      'aud': kBaseUrlIssuer,
      'iat': _now(),
      'nonce': _nonce(),
    },
    kp,
  );
}

// T5 - Penyusunan & penerbitan Payload JWT VC (FAKTOR A berlaku di sini).
Future<String> t5PayloadVc(Treatment t) async {
  final issuerKp = await _ed25519.newKeyPair(); // simulasi penandatangan Issuer
  return _signJwt(
    {'typ': 'JWT', 'alg': 'EdDSA', 'kid': 'did:web:issuer.identia.my.id#key-1'},
    {
      'iss': 'did:web:issuer.identia.my.id',
      'sub': kHolderDid,
      'nbf': _now(),
      'jti': 'urn:uuid:${_uuid()}',
      'vc': {
        '@context': ['https://www.w3.org/2018/credentials/v1'],
        'type': ['VerifiableCredential', 'KartuBPJSKesehatan'],
        'issuer': 'did:web:issuer.identia.my.id',
        'credentialSubject': _subjectClaims(t.lengkap),
      },
    },
    issuerKp,
  );
}

// T6 - Verifikasi Struktur JWT VC -> artefak yang diverifikasi (VC nyata).
Future<String> t6VerifikasiVc(Treatment t) async => kJwtVc;

// T7 - Serialisasi Penyimpanan Kredensial -> envelope penyimpanan lokal.
Future<String> t7Serialisasi(Treatment t) async =>
    jsonEncode({'vc': kJwtVc, 'savedAt': _now(), 'ref': 'urn:uuid:${_uuid()}'});

// T8 - Penguraian Permintaan Otorisasi OID4VP -> Authorization Request nyata.
Future<String> t8AuthRequest(Treatment t) async => kAuthRequestUri;

// T9 - JWT VP Construction (menyisipkan JWT VC, ditandatangani Holder).
Future<String> t9VpConstruction(Treatment t) async {
  final kp = await _holder();
  return _signJwt(
    {'typ': 'vp+jwt', 'alg': 'EdDSA', 'kid': '$kHolderDid#0'},
    {
      'iss': kHolderDid,
      'sub': kHolderDid,
      'aud': 'did:web:verifier.identia.my.id',
      'nonce': _nonce(),
      'iat': _now(),
      'jti': 'urn:uuid:${_uuid()}',
      'vp': {
        '@context': ['https://www.w3.org/2018/credentials/v1'],
        'type': ['VerifiablePresentation'],
        'holder': kHolderDid,
        'verifiableCredential': [kJwtVc],
      },
    },
    kp,
  );
}

// T10 - Verifikasi Struktur JWT VP dua lapis -> artefak VP nyata.
Future<String> t10VerifikasiVp(Treatment t) async => kJwtVp;

// ── Eksekusi seluruh kombinasi perlakuan ───────────────────────────────
Future<void> main() async {
  final skenario = <String, Artefak>{
    'T1': t1KeyPair,
    'T2': t2DidJwk,
    'T3': t3CredentialOffer,
    'T4': t4ProofJwt,
    'T5': t5PayloadVc,
    'T6': t6VerifikasiVc,
    'T7': t7Serialisasi,
    'T8': t8AuthRequest,
    'T9': t9VpConstruction,
    'T10': t10VerifikasiVp,
  };
  final ids = skenario.keys.toList();
  final matriks = <String, Map<String, int>>{};

  for (final t in kKombinasi) {
    print(
      '== ${t.kode} | ${t.lengkap ? "lengkap" : "minimal"} | '
      '${t.jaringan} | c=${t.konkurensi} ==',
    );
    matriks[t.kode] = {};
    for (final s in skenario.entries) {
      matriks[t.kode]![s.key] = await ukurUkuranPayload(t, s.key, s.value);
    }
  }

  // Matriks ukuran payload (byte) — salin langsung untuk mengisi Tabel 4.13.
  print('\n== MATRIKS UKURAN PAYLOAD (byte) ==');
  print('Kombinasi\t${ids.join("\t")}');
  for (final t in kKombinasi) {
    final row = ids.map((id) => matriks[t.kode]![id]).join('\t');
    print('${t.kode}\t$row');
  }
}
