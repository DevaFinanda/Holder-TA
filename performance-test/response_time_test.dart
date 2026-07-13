// response_time_test.dart
// Pengujian Waktu Respons IDentia — skenario T1..T10 x kombinasi perlakuan P1..P12
// Jalankan: dart run response_time_test.dart
//
// pubspec.yaml (dependencies):
//   cryptography: ^2.7.0
//   http: ^1.2.0

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:http/http.dart' as http;

// ── Konfigurasi lingkungan uji IDentia ─────────────────────────────────
const String kBaseUrlIssuer = 'https://issuer.identia.my.id';
const String kBaseUrlVerifier = 'http://verifier.identia.my.id';
const String kPathCredentialOffer = '/.well-known/openid-credential-issuer';
const String kUsernameIssuer = 'admin';
const String kPasswordIssuer = 'admin123';

// Endpoint pembuatan Credential Offer.
const String kPathCreateOffer = '/oid4vci/credential-offer';
const String kCredentialConfigId = 'kartu_bpjs_kesehatan';

// Offer statik (single-use, kemungkinan sudah exhausted) — dipakai sebagai
// fallback bila mint offer baru tidak tersedia.
const String kCredentialOfferUri =
    'openid-credential-offer://?credential_offer_uri=https%3A%2F%2Fissuer.identia.my.id%2Foid4vci%2Fcredential-offer%2Fed1256b0-ca4c-4da7-aa2f-1e3fa972957c';

const String kHolderNik = '3201010203050001';
const String kHolderPassword = 'Deva123';
const String kHolderPublicKeyB64 =
    'z_yRmHTyDQhxMYXBAK_CXCJrPY897v62QWFzxHk1C2k';
const String kHolderDid =
    'did:jwk:eyJrdHkiOiJPS1AiLCJjcnYiOiJFZDI1NTE5IiwieCI6InpfeVJtSFR5RFFoeE1ZWEJBS19DWENKclBZODk3djYyUVdGenhIazFDMmsifQ';
const String kIssuerPublicKeyMultibase =
    'z6MkhyKruKxbzoUegAD4s7x8hzwbahsKa2q5rwAtK9CZ86dU';

const String kJwtVc =
    'eyJraWQiOiJkaWQ6d2ViOmlzc3Vlci5pZGVudGlhLm15LmlkI2tleS0xIiwiYWxnIjoiRWREU0EiLCJ0eXAiOiJKV1QifQ.eyJ2YyI6eyJAY29udGV4dCI6WyJodHRwczovL3d3dy53My5vcmcvMjAxOC9jcmVkZW50aWFscy92MSJdLCJ0eXBlIjpbIlZlcmlmaWFibGVDcmVkZW50aWFsIiwiS2FydHVCUEpTS2VzZWhhdGFuIl0sImlkIjoidXJuOnV1aWQ6MDVhNDkzMTktY2MzNy00MThjLWIxNzEtZWY0NWE2ZDg5Mjk5IiwiaXNzdWVyIjoiZGlkOndlYjppc3N1ZXIuaWRlbnRpYS5teS5pZCIsImlzc3VhbmNlRGF0ZSI6IjIwMjYtMDctMDVUMDM6Mzk6MzIuMDAwWiIsImNyZWRlbnRpYWxTdWJqZWN0Ijp7ImlkIjoiZGlkOmp3azpleUpyZEhraU9pSlBTMUFpTENKamNuWWlPaUpGWkRJMU5URTVJaXdpZUNJNklucGZlVkp0U0ZSNVJGRm9lRTFaV0VKQlMxOURXRU5LY2xCWk9EazNkall5VVZkR2VuaElhekZETW1zaWZRIiwiY3JlZGVudGlhbE5hbWUiOiJLYXJ0dSBCUEpTIEtlc2VoYXRhbiIsImhvbGRlck5hbWUiOiJEZXZhIEZpbmFuZGEgU2FwdXRyYSIsIm5payI6IjMyMDEwMTAyMDMwNTAwMDEiLCJub0JQSlMiOiIzMjAxMDEwMjAzMDUwIiwidGFuZ2dhbExhaGlyIjoiMjAwNS0wMi0wMyJ9fSwic3ViIjoiZGlkOmp3azpleUpyZEhraU9pSlBTMUFpTENKamNuWWlPaUpGWkRJMU5URTVJaXdpZUNJNklucGZlVkp0U0ZSNVJGRm9lRTFaV0VKQlMxOURXRU5LY2xCWk9EazNkall5VVZkR2VuaElhekZETW1zaWZRIiwibmJmIjoxNzgzMjIyNzcyLCJqdGkiOiJ1cm46dXVpZDowNWE0OTMxOS1jYzM3LTQxOGMtYjE3MS1lZjQ1YTZkODkyOTkiLCJpc3MiOiJkaWQ6d2ViOmlzc3Vlci5pZGVudGlhLm15LmlkIn0.MCpfVugLALCaRPdBp2IBxF5LSnwy6MxHGKrxFl_H7SgaUP05u4C9vHcE73MsaO-KFQY7ZkRC6jD9GCw4kaPWAg';

const String kJwtVp =
    'eyJhbGciOiJFZERTQSIsInR5cCI6InZwK2p3dCIsImtpZCI6ImRpZDpqd2s6ZXlKcmRIa2lPaUpQUzFBaUxDSmpjbllpT2lKRlpESTFOVEU1SWl3aWVDSTZJbnBmZVZKdFNGUjVSRkZvZUUxWldFSkJTMTlEV0VOS2NsQlpPRGszZGpZeVVWZEdlbmhJYXpGRE1tc2lmUSMwIn0.eyJpc3MiOiJkaWQ6andrOmV5SnJkSGtpT2lKUFMxQWlMQ0pqY25ZaU9pSkZaREkxTlRFNUlpd2llQ0k2SW5wZmVWSnRTRlI1UkZGb2VFMVpXRUpCUzE5RFdFTktjbEJaT0RrM2RqWXlVVmRHZW5oSWF6RkRNbXNpZlEiLCJzdWIiOiJkaWQ6andrOmV5SnJkSGtpT2lKUFMxQWlMQ0pqY25ZaU9pSkZaREkxTlRFNUlpd2llQ0k2SW5wZmVWSnRTRlI1UkZGb2VFMVpXRUpCUzE5RFdFTktjbEJaT0RrM2RqWXlVVmRHZW5oSWF6RkRNbXNpZlEiLCJhdWQiOiJkaWQ6d2ViOnZlcmlmaWVyLmlkZW50aWEubXkuaWQiLCJub25jZSI6IlowWWJFQjVZOHRhUVA3R0VOOWVTNWh5dGdLM00zOXhuNHUwell1MjFka2MiLCJpYXQiOjE3ODMyMjkyNTIsIm5iZiI6MTc4MzIyOTI1MiwiZXhwIjoxNzgzMjI5MzcyLCJqdGkiOiJ1cm46dXVpZDo1OGVhOGFkNy02MDg3LTRhM2UtOGU3YS1hY2IwYWEwZmU5YjAiLCJ2cCI6eyJpZCI6InVybjp1dWlkOjU4ZWE4YWQ3LTYwODctNGEzZS04ZTdhLWFjYjBhYTBmZTliMCIsIkBjb250ZXh0IjpbImh0dHBzOi8vd3d3LnczLm9yZy8yMDE4L2NyZWRlbnRpYWxzL3YxIl0sInR5cGUiOlsiVmVyaWZpYWJsZVByZXNlbnRhdGlvbiJdLCJob2xkZXIiOiJkaWQ6andrOmV5SnJkSGtpT2lKUFMxQWlMQ0pqY25ZaU9pSkZaREkxTlRFNUlpd2llQ0k2SW5wZmVWSnRTRlI1UkZGb2VFMVpXRUpCUzE5RFdFTktjbEJaT0RrM2RqWXlVVmRHZW5oSWF6RkRNbXNpZlEiLCJ2ZXJpZmlhYmxlQ3JlZGVudGlhbCI6WyJleUpyYVdRaU9pSmthV1E2ZDJWaU9tbHpjM1ZsY2k1cFpHVnVkR2xoTG0xNUxtbGtJMnRsZVMweElpd2lZV3huSWpvaVJXUkVVMEVpTENKMGVYQWlPaUpLVjFRaWZRLmV5SjJZeUk2ZXlKQVkyOXVkR1Y0ZENJNld5Sm9kSFJ3Y3pvdkwzZDNkeTUzTXk1dmNtY3ZNakF4T0M5amNtVmtaVzUwYVdGc2N5OTJNU0pkTENKMGVYQmxJanBiSWxabGNtbG1hV0ZpYkdWRGNtVmtaVzUwYVdGc0lpd2lTMkZ5ZEhWQ1VFcFRTMlZ6WldoaGRHRnVJbDBzSW1sa0lqb2lkWEp1T25WMWFXUTZNRFZoTkRrek1Ua3RZMk16TnkwME1UaGpMV0l4TnpFdFpXWTBOV0UyWkRnNU1qazVJaXdpYVhOemRXVnlJam9pWkdsa09uZGxZanBwYzNOMVpYSXVhV1JsYm5ScFlTNXRlUzVwWkNJc0ltbHpjM1ZoYm1ObFJHRjBaU0k2SWpJd01qWXRNRGN0TURWVU1ETTZNems2TXpJdU1EQXdXaUlzSW1OeVpXUmxiblJwWVd4VGRXSnFaV04wSWpwN0ltbGtJam9pWkdsa09tcDNhenBsZVVweVpFaHJhVTlwU2xCVE1VRnBURU5LYW1OdVdXbFBhVXBHV2tSSk1VNVVSVFZKYVhkcFpVTkpOa2x1Y0dabFZrcDBVMFpTTlZKR1JtOWxSVEZhVjBWS1FsTXhPVVJYUlU1TFkyeENXazlFYXpOa2FsbDVWVlprUjJWdWFFbGhla1pFVFcxemFXWlJJaXdpWTNKbFpHVnVkR2xoYkU1aGJXVWlPaUpMWVhKMGRTQkNVRXBUSUV0bGMyVm9ZWFJoYmlJc0ltaHZiR1JsY2s1aGJXVWlPaUpFWlhaaElFWnBibUZ1WkdFZ1UyRndkWFJ5WVNJc0ltNXBheUk2SWpNeU1ERXdNVEF5TURNd05UQXdNREVpTENKdWIwSlFTbE1pT2lJek1qQXhNREV3TWpBek1EVXdJaXdpZEdGdVoyZGhiRXhoYUdseUlqb2lNakF3TlMwd01pMHdNeUo5ZlN3aWMzVmlJam9pWkdsa09tcDNhenBsZVVweVpFaHJhVTlwU2xCVE1VRnBURU5LYW1OdVdXbFBhVXBHV2tSSk1VNVVSVFZKYVhkcFpVTkpOa2x1Y0dabFZrcDBVMFpTTlZKR1JtOWxSVEZhVjBWS1FsTXhPVVJYUlU1TFkyeENXazlFYXpOa2FsbDVWVlprUjJWdWFFbGhla1pFVFcxemFXWlJJaXdpYm1KbUlqb3hOemd6TWpJeU56Y3lMQ0pxZEdraU9pSjFjbTQ2ZFhWcFpEb3dOV0UwT1RNeE9TMWpZek0zTFRReE9HTXRZakUzTVMxbFpqUTFZVFprT0RreU9Ua2lMQ0pwYzNNaU9pSmthV1E2ZDJWaU9tbHpjM1ZsY2k1cFpHVnVkR2xoTG0xNUxtbGtJbjAuTUNwZlZ1Z0xBTENhUlBkQnAySUJ4RjVMU253eTZNeEhHS3J4RmxfSDdTZ2FVUDA1dTRDOXZIY0U3M01zYU8tS0ZRWTdaa1JDNmpEOUdDdzRrYVBXQWciXX19.zuvm4M3BbdiKg3lxcNhD4weHykCpAspWBLkrfBv-G3f0Y-FJGjGABHX8UXpKRrBGdDfH2GEnYmgzkN4Mp-ZMDQ';

// Authorization Request OID4VP.
const String kAuthRequestUri =
    'openid4vp://authorize?client_id=did:web:verifier.identia.my.id'
    '&response_type=vp_token'
    '&response_mode=direct_post'
    '&nonce=Z0YbEB5Y8taQP7GEN9eS5hytgK3M39xn4u0zYu21dkc'
    '&presentation_definition_uri=https://verifier.identia.my.id/oid4vp/pd/1';

// ── Parameter eksekusi ─────────────────────────────────────────────────
const int kReplikasi = 30; // replikasi per kombinasi
const Duration kTimeout = Duration(seconds: 15); // batas satu operasi
// Jeda antar-replikasi khusus skenario berjaringan (di LUAR Stopwatch, tidak
// memengaruhi angka waktu respons) untuk menekan risiko blacklist IP.
const Set<String> kSkenarioJaringan = {'T3'};
const Duration kJedaAntarReplikasi = Duration(milliseconds: 400);

final Ed25519 _ed25519 = Ed25519();
final Random _rng = Random.secure();
bool _t3Dilaporkan = false;

// ── Rancangan faktorial P1..P12 (lihat Tabel 4.9) ──────────────────────
class Treatment {
  final String kode; // P1..P12
  final bool lengkap; // faktor A: kompleksitas kredensial
  final String jaringan; // faktor B: '5G' / '4G' (diemulasi via tc/netem OS)
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

// ── Pengukur waktu respons ─────────────────────────────────────────────
class StatistikWaktu {
  final double rataRata, minimum, maksimum;
  final int nSukses, nGagal;
  const StatistikWaktu(
    this.rataRata,
    this.minimum,
    this.maksimum,
    this.nSukses,
    this.nGagal,
  );
}

// Kontrak skenario: true bila operasi tuntas sesuai kriteria.
typedef Skenario = Future<bool> Function(Treatment t);

/// Rata-rata/min/maks waktu respons (ms) satu skenario pada satu kombinasi.
/// Tiap replikasi memicu `t.konkurensi` eksekusi serentak; durasi tiap
/// eksekusi diukur sendiri sehingga tekanan konkurensi ikut tercermin.
Future<StatistikWaktu> ukurWaktuRespons(
  Treatment t,
  String id,
  Skenario jalankan,
) async {
  final durasiMs = <double>[];
  var gagal = 0;

  for (var i = 0; i < kReplikasi; i++) {
    final hasil = await Future.wait(
      List.generate(t.konkurensi, (_) async {
        final sw = Stopwatch()..start();
        try {
          final ok = await jalankan(t).timeout(kTimeout);
          sw.stop();
          return ok
              ? sw.elapsedMicroseconds / 1000.0
              : null; // t_ms = t_us/1000
        } catch (_) {
          sw.stop();
          return null; // gagal/timeout -> tidak dihitung ke statistik waktu
        }
      }),
    );
    for (final d in hasil) {
      if (d != null) {
        durasiMs.add(d);
      } else {
        gagal++;
      }
    }
    if (kSkenarioJaringan.contains(id)) {
      await Future.delayed(kJedaAntarReplikasi);
    }
  }

  if (durasiMs.isEmpty) {
    print('${t.kode} | $id | tidak ada sampel sukses (gagal: $gagal)');
    return StatistikWaktu(0, 0, 0, 0, gagal);
  }

  final rata = durasiMs.reduce((a, b) => a + b) / durasiMs.length;
  final min = durasiMs.reduce((a, b) => a < b ? a : b);
  final maks = durasiMs.reduce((a, b) => a > b ? a : b);
  print(
    '${t.kode} | $id | avg: ${rata.toStringAsFixed(3)} ms | '
    'min: ${min.toStringAsFixed(3)} | maks: ${maks.toStringAsFixed(3)} | '
    'n: ${durasiMs.length} (gagal: $gagal)',
  );
  return StatistikWaktu(rata, min, maks, durasiMs.length, gagal);
}

// ── Helper encoding & kripto ───────────────────────────────────────────
int _now() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

String _b64url(List<int> b) => base64Url.encode(b).replaceAll('=', '');

List<int> _b64urlDecode(String s) {
  final pad = (4 - s.length % 4) % 4;
  return base64Url.decode(s + '=' * pad);
}

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

String _ringkas(String s, [int n = 160]) =>
    s.length <= n ? s : '${s.substring(0, n)}...';

const String _b58 =
    '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';

List<int> _base58Decode(String input) {
  var val = BigInt.zero;
  final base = BigInt.from(58);
  for (final c in input.split('')) {
    final idx = _b58.indexOf(c);
    if (idx < 0) throw FormatException('char base58 tak valid: $c');
    val = val * base + BigInt.from(idx);
  }
  final out = <int>[];
  while (val > BigInt.zero) {
    out.insert(0, (val & BigInt.from(0xff)).toInt());
    val = val >> 8;
  }
  for (final c in input.split('')) {
    if (c == '1') {
      out.insert(0, 0);
    } else {
      break;
    }
  }
  return out;
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

Future<bool> _verifyJwt(String jwt, SimplePublicKey pub) async {
  final parts = jwt.split('.');
  if (parts.length != 3) return false;
  final signingInput = utf8.encode('${parts[0]}.${parts[1]}');
  final sig = Signature(_b64urlDecode(parts[2]), publicKey: pub);
  return _ed25519.verify(signingInput, signature: sig);
}

SimplePublicKey _issuerPublicKey() {
  // Multibase base58btc ('z') + multicodec ed25519-pub (0xed 0x01) + 32 byte.
  final raw = _base58Decode(kIssuerPublicKeyMultibase.substring(1));
  return SimplePublicKey(raw.sublist(2), type: KeyPairType.ed25519);
}

SimplePublicKey _holderPubFromDid(String did) {
  final enc = did.substring('did:jwk:'.length);
  final jwk =
      jsonDecode(utf8.decode(_b64urlDecode(enc))) as Map<String, dynamic>;
  return SimplePublicKey(
    _b64urlDecode(jwk['x'] as String),
    type: KeyPairType.ed25519,
  );
}

String _didJwkFrom(List<int> pub) {
  final jwk = {'kty': 'OKP', 'crv': 'Ed25519', 'x': _b64url(pub)};
  return 'did:jwk:${_b64url(utf8.encode(jsonEncode(jwk)))}';
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

// Mint Credential Offer baru; kembalikan URL offer yang bisa di-GET.
Future<String?> _mintOfferUri() async {
  try {
    final auth =
        'Basic ${base64.encode(utf8.encode('$kUsernameIssuer:$kPasswordIssuer'))}';
    final res = await http.post(
      Uri.parse('$kBaseUrlIssuer$kPathCreateOffer'),
      headers: {'Authorization': auth, 'Content-Type': 'application/json'},
      body: jsonEncode({
        'credentialConfigurationIds': [kCredentialConfigId],
      }),
    );
    if (!_t3Dilaporkan) {
      stderr.writeln(
        '[T3 mint] POST $kBaseUrlIssuer$kPathCreateOffer '
        '-> ${res.statusCode}',
      );
      stderr.writeln('[T3 mint] body: ${_ringkas(res.body)}');
    }
    if (res.statusCode != 200) return null;
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final offerId = data['offerId'] ?? data['offer_id'];
    if (offerId != null) return '$kBaseUrlIssuer$kPathCreateOffer/$offerId';
    final ou = data['credentialOfferUri'] as String?;
    if (ou != null) return _urlDariOfferUri(ou);
    return null;
  } catch (_) {
    return null;
  }
}

String _offerUriDariKonstanta() => _urlDariOfferUri(kCredentialOfferUri);

String _urlDariOfferUri(String offerUri) {
  final uri = Uri.parse(offerUri);
  final byUri = uri.queryParameters['credential_offer_uri'];
  if (byUri != null) return byUri; // URL yang dapat di-GET
  return offerUri; // offer inline
}

// ── Definisi skenario T1..T10 ──────────────────────────────────────────
// T1 - Ed25519 Key Pair Generation (lokal)
Future<bool> t1KeyPair(Treatment t) async {
  final kp = await _ed25519.newKeyPair();
  final pub = await kp.extractPublicKey();
  return pub.bytes.length == 32;
}

// T2 - Pembentukan DID:JWK (lokal)
Future<bool> t2DidJwk(Treatment t) async {
  final pub = await (await _holder()).extractPublicKey();
  return _didJwkFrom(pub.bytes).startsWith('did:jwk:');
}

// T3 - buat, ambil, & urai Credential Offer dari Issuer (interaktif, OID4VCI)
Future<bool> t3CredentialOffer(Treatment t) async {
  final offerUri = await _mintOfferUri() ?? _offerUriDariKonstanta();
  final res = await http.get(Uri.parse(offerUri));
  if (!_t3Dilaporkan) {
    stderr.writeln('[T3 get] $offerUri -> ${res.statusCode}');
    stderr.writeln('[T3 get] body: ${_ringkas(res.body)}');
    _t3Dilaporkan = true;
  }
  if (res.statusCode != 200) return false;
  final offer = jsonDecode(res.body) as Map<String, dynamic>;
  return offer.containsKey('credential_issuer') &&
      (offer.containsKey('credential_configuration_ids') ||
          offer.containsKey('credentials'));
}

// T4 - Proof JWT Construction (lokal, ditandatangani Holder)
Future<bool> t4ProofJwt(Treatment t) async {
  final kp = await _holder();
  final jwt = await _signJwt(
    {'typ': 'openid4vci-proof+jwt', 'alg': 'EdDSA', 'kid': '$kHolderDid#0'},
    {
      'iss': kHolderDid,
      'aud': kBaseUrlIssuer,
      'iat': _now(),
      'nonce': _nonce(),
    },
    kp,
  );
  return _verifyJwt(jwt, await kp.extractPublicKey());
}

// T5 - Penyusunan & penerbitan Payload JWT VC (faktor A berlaku)
Future<bool> t5PayloadVc(Treatment t) async {
  final issuerKp = await _ed25519.newKeyPair(); // simulasi penandatangan Issuer
  final jwt = await _signJwt(
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
  return jwt.split('.').length == 3;
}

// T6 - Verifikasi Struktur JWT VC (lokal)
Future<bool> t6VerifikasiVc(Treatment t) async {
  if (kJwtVc.split('.').length != 3) return false;
  return _verifyJwt(kJwtVc, _issuerPublicKey());
}

// T7 - Serialisasi Penyimpanan Kredensial (lokal)
Future<bool> t7Serialisasi(Treatment t) async {
  final s = jsonEncode({
    'vc': kJwtVc,
    'savedAt': _now(),
    'ref': 'urn:uuid:${_uuid()}',
  });
  final back = jsonDecode(s) as Map<String, dynamic>;
  return back['vc'] == kJwtVc;
}

// T8 - Penguraian Permintaan Otorisasi OID4VP (lokal)
Future<bool> t8AuthRequest(Treatment t) async {
  final uri = Uri.parse(kAuthRequestUri);
  return uri.queryParameters['client_id'] != null &&
      uri.queryParameters['response_type'] == 'vp_token';
}

// T9 - JWT VP Construction (menyisipkan VC, ditandatangani Holder)
Future<bool> t9VpConstruction(Treatment t) async {
  final kp = await _holder();
  final vp = await _signJwt(
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
  return vp.split('.').length == 3;
}

// T10 - Verifikasi Struktur JWT VP dua lapis (lokal)
Future<bool> t10VerifikasiVp(Treatment t) async {
  final parts = kJwtVp.split('.');
  if (parts.length != 3) return false;
  final payload =
      jsonDecode(utf8.decode(_b64urlDecode(parts[1]))) as Map<String, dynamic>;
  // Lapis 1: tanda tangan VP oleh Holder.
  final okVp = await _verifyJwt(
    kJwtVp,
    _holderPubFromDid(payload['iss'] as String),
  );
  // Lapis 2: tanda tangan tiap VC tertanam oleh Issuer.
  final vcs = ((payload['vp'] as Map)['verifiableCredential'] as List)
      .cast<String>();
  var okVc = true;
  for (final vc in vcs) {
    okVc = okVc && await _verifyJwt(vc, _issuerPublicKey());
  }
  return okVp && okVc;
}

// ── Eksekusi seluruh kombinasi perlakuan ───────────────────────────────
Future<void> main() async {
  final skenario = <String, Skenario>{
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
  final matriks = <String, Map<String, double>>{};

  for (final t in kKombinasi) {
    print(
      '== ${t.kode} | ${t.lengkap ? "lengkap" : "minimal"} | '
      '${t.jaringan} | c=${t.konkurensi} ==',
    );
    matriks[t.kode] = {};
    for (final s in skenario.entries) {
      final stat = await ukurWaktuRespons(t, s.key, s.value);
      matriks[t.kode]![s.key] = stat.rataRata;
    }
  }

  // Matriks rata-rata (ms) — salin langsung untuk mengisi Tabel 4.12.
  print('\n== MATRIKS RATA-RATA WAKTU RESPONS (ms) ==');
  print('Kombinasi\t${ids.join("\t")}');
  for (final t in kKombinasi) {
    final row = ids
        .map((id) => (matriks[t.kode]![id] ?? 0).toStringAsFixed(3))
        .join('\t');
    print('${t.kode}\t$row');
  }
}
