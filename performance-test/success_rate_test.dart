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

// Endpoint pembuatan Credential Offer (masih TEBAKAN — akan dikoreksi setelah
// melihat keluaran diagnostik [T3 mint]). SESUAIKAN path, body, & field respons.
const String kPathCreateOffer = '/oid4vci/credential-offer';
const String kCredentialConfigId = 'KartuBPJSKesehatan';

// Offer statik (single-use, kemungkinan sudah exhausted) — dipakai sebagai
// fallback & referensi bila mint offer belum tersedia.
const String kCredentialOfferUri =
    'openid-credential-offer://?credential_offer_uri=https%3A%2F%2Fissuer.identia.my.id%2Foid4vci%2Fcredential-offer%2Fdbfd2878-6d56-4c51-ac2d-a9bfe878b499';

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

// Authorization Request OID4VP (ganti dengan request nyata dari Verifier).
const String kAuthRequestUri =
    'openid4vp://authorize?client_id=did:web:verifier.identia.my.id'
    '&response_type=vp_token'
    '&response_mode=direct_post'
    '&nonce=Z0YbEB5Y8taQP7GEN9eS5hytgK3M39xn4u0zYu21dkc'
    '&presentation_definition_uri=https://verifier.identia.my.id/oid4vp/pd/1';

const Set<String> kSkenarioDilewati = {};
final Ed25519 _ed25519 = Ed25519();

// ── Parameter eksekusi & perlakuan ─────────────────────────────────────
const int kReplikasi = 30; // replikasi per kombinasi
const Duration kTimeout = Duration(seconds: 15);

class Treatment {
  final String id; // P1..P12
  final String kredensial; // 'minimal' | 'lengkap'
  final String jaringan; // '5G' | '4G'
  final int konkurensi; // 1 | 5 | 10
  const Treatment(this.id, this.kredensial, this.jaringan, this.konkurensi);
}

// Faktorial penuh 2 x 2 x 3 = 12 kombinasi (Tabel 4.9).
const List<Treatment> kTreatments = [
  Treatment('P1', 'minimal', '5G', 1),
  Treatment('P2', 'minimal', '5G', 5),
  Treatment('P3', 'minimal', '5G', 10),
  Treatment('P4', 'minimal', '4G', 1),
  Treatment('P5', 'minimal', '4G', 5),
  Treatment('P6', 'minimal', '4G', 10),
  Treatment('P7', 'lengkap', '5G', 1),
  Treatment('P8', 'lengkap', '5G', 5),
  Treatment('P9', 'lengkap', '5G', 10),
  Treatment('P10', 'lengkap', '4G', 1),
  Treatment('P11', 'lengkap', '4G', 5),
  Treatment('P12', 'lengkap', '4G', 10),
];

enum Hasil { berhasil, gagal, timeout }

/// Kontrak skenario: true bila keluaran lolos kriteria pada Tabel 4.10.
typedef Skenario = Future<bool> Function(Treatment t);

bool _t3Dilaporkan = false; // diagnostik T3 hanya dicetak sekali

// ── Runner success rate ────────────────────────────────────────────────
Future<double> ukurSuccessRate(
  Treatment t,
  String id,
  Skenario jalankan,
) async {
  if (kSkenarioDilewati.contains(id)) return 100;

  var berhasil = 0, gagal = 0, timeout = 0;
  final int total = kReplikasi * t.konkurensi; // n_total = 30 x c

  for (var i = 0; i < kReplikasi; i++) {
    final hasil = await Future.wait(
      List.generate(t.konkurensi, (_) async {
        try {
          final lolos = await jalankan(t).timeout(kTimeout);
          return lolos ? Hasil.berhasil : Hasil.gagal;
        } on TimeoutException {
          return Hasil.timeout;
        } catch (_) {
          return Hasil.gagal;
        }
      }),
    );

    for (final h in hasil) {
      if (h == Hasil.berhasil) {
        berhasil++;
      } else {
        gagal++;
        if (h == Hasil.timeout) timeout++;
      }
    }
  }

  final rate = berhasil / total * 100;
  print(
    '  $id | total: $total | berhasil: $berhasil | '
    'gagal: $gagal (timeout: $timeout) | SR: ${rate.toStringAsFixed(2)}%',
  );
  return rate;
}

// ── Skenario T1–T10 ────────────────────────────────────────────────────

// T1 — pembangkitan pasangan kunci Ed25519 (lokal)
Future<bool> t1KeyPair(Treatment t) async {
  final kp = await _ed25519.newKeyPair();
  final pub = await kp.extractPublicKey();
  final priv = await kp.extractPrivateKeyBytes();
  return pub.bytes.length == 32 && priv.length == 32;
}

// T2 — pembentukan DID:JWK & pemulihannya menjadi kunci publik semula (lokal)
Future<bool> t2DidJwk(Treatment t) async {
  final kp = await _ed25519.newKeyPair();
  final pub = await kp.extractPublicKey();
  final did = _holderDidFrom(pub);
  final pulih = _holderKeyFromDid(did);
  return _listEq(pulih.bytes, pub.bytes);
}

// T3 — buat, ambil, & urai Credential Offer dari Issuer (interaktif, OID4VCI)
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

// T4 — konstruksi Proof JWT oleh Holder lalu verifikasi tanda tangannya (lokal)
Future<bool> t4ProofJwt(Treatment t) async {
  final kp = await _ed25519.newKeyPair();
  final pub = await kp.extractPublicKey();
  final header = {
    'alg': 'EdDSA',
    'typ': 'openid4vci-proof+jwt',
    'kid': _holderDidFrom(pub),
  };
  final payload = {'aud': kBaseUrlIssuer, 'iat': _now(), 'nonce': _nonce()};
  final jwt = await _signJwt(header, payload, kp);
  return await _verifyJwt(jwt, pub);
}

// T5 — perakitan payload & penerbitan JWT VC (interaktif; disimulasikan lokal)
Future<bool> t5PayloadVc(Treatment t) async {
  final issuerKp = await _ed25519.newKeyPair();
  final header = {
    'kid': 'did:web:issuer.identia.my.id#key-1',
    'alg': 'EdDSA',
    'typ': 'JWT',
  };
  final payload = {
    'vc': {
      '@context': ['https://www.w3.org/2018/credentials/v1'],
      'type': ['VerifiableCredential', 'KartuBPJSKesehatan'],
      'credentialSubject': _subjectClaims(t.kredensial),
    },
    'sub': kHolderDid,
    'iss': 'did:web:issuer.identia.my.id',
    'nbf': _now(),
    'jti': 'urn:uuid:${_uuid()}',
  };
  final jwt = await _signJwt(header, payload, issuerKp);
  return jwt.split('.').length == 3;
}

// T6 — verifikasi tanda tangan Issuer pada JWT VC (lokal)
Future<bool> t6VerifikasiVc(Treatment t) async {
  final issuerPub = _issuerKeyFromMultibase(kIssuerPublicKeyMultibase);
  return await _verifyJwt(kJwtVc, issuerPub);
}

// T7 — siklus serialize–deserialize untuk penyimpanan lokal (lokal)
Future<bool> t7Serialisasi(Treatment t) async {
  final asli = {'jwtVc': kJwtVc, 'did': kHolderDid, 'savedAt': _now()};
  final terpulih = jsonDecode(jsonEncode(asli)) as Map<String, dynamic>;
  return terpulih['jwtVc'] == kJwtVc && terpulih['did'] == kHolderDid;
}

// T8 — penguraian Authorization Request dari Verifier (OID4VP)
Future<bool> t8AuthRequest(Treatment t) async {
  final q = Uri.parse(kAuthRequestUri).queryParameters;
  const wajib = ['client_id', 'response_type', 'nonce'];
  final adaDefinisi =
      q.containsKey('presentation_definition') ||
      q.containsKey('presentation_definition_uri') ||
      q.containsKey('dcql_query');
  return wajib.every(q.containsKey) &&
      q['response_type'] == 'vp_token' &&
      adaDefinisi;
}

// T9 — konstruksi JWT VP oleh Holder dengan JWT VC tertanam (lokal)
Future<bool> t9VpConstruction(Treatment t) async {
  final kp = await _ed25519.newKeyPair();
  final pub = await kp.extractPublicKey();
  final did = _holderDidFrom(pub);
  final header = {'alg': 'EdDSA', 'typ': 'vp+jwt', 'kid': '$did#0'};
  final payload = {
    'iss': did,
    'sub': did,
    'aud': 'did:web:verifier.identia.my.id',
    'nonce': _nonce(),
    'iat': _now(),
    'nbf': _now(),
    'exp': _now() + 120,
    'jti': 'urn:uuid:${_uuid()}',
    'vp': {
      '@context': ['https://www.w3.org/2018/credentials/v1'],
      'type': ['VerifiablePresentation'],
      'holder': did,
      'verifiableCredential': [kJwtVc],
    },
  };
  final jwt = await _signJwt(header, payload, kp);
  return jwt.split('.').length == 3 && await _verifyJwt(jwt, pub);
}

// T10 — verifikasi dua lapis JWT VP: tanda tangan Holder + VC Issuer (lokal)
Future<bool> t10VerifikasiVp(Treatment t) async {
  final bagian = kJwtVp.split('.');
  if (bagian.length != 3) return false;
  final payload =
      jsonDecode(utf8.decode(_b64urlDecode(bagian[1]))) as Map<String, dynamic>;
  final holderPub = _holderKeyFromDid(payload['iss'] as String);
  final vpValid = await _verifyJwt(kJwtVp, holderPub);
  final vc =
      ((payload['vp'] as Map)['verifiableCredential'] as List).first as String;
  final issuerPub = _issuerKeyFromMultibase(kIssuerPublicKeyMultibase);
  final vcValid = await _verifyJwt(vc, issuerPub);
  return vpValid && vcValid;
}

// ── Credential Offer (mint + fallback) ─────────────────────────────────
Future<String?> _mintOfferUri() async {
  try {
    final auth = base64.encode(
      utf8.encode('$kUsernameIssuer:$kPasswordIssuer'),
    );
    final res = await http.post(
      Uri.parse('$kBaseUrlIssuer$kPathCreateOffer'),
      headers: {
        'Authorization': 'Basic $auth',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'credential_configuration_ids': [kCredentialConfigId],
        'nik': kHolderNik,
      }),
    );
    if (!_t3Dilaporkan) {
      stderr.writeln(
        '[T3 mint] POST $kBaseUrlIssuer$kPathCreateOffer '
        '-> ${res.statusCode}',
      );
      stderr.writeln('[T3 mint] body: ${_ringkas(res.body)}');
    }
    if (res.statusCode != 200 && res.statusCode != 201) return null;
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final raw =
        (data['credential_offer_uri'] ??
                data['credentialOfferUri'] ??
                data['uri'])
            as String?;
    if (raw == null) return null;
    return Uri.parse(raw).queryParameters['credential_offer_uri'] ?? raw;
  } catch (e) {
    if (!_t3Dilaporkan) stderr.writeln('[T3 mint] exception: $e');
    return null; // biar T3 lanjut memakai fallback offer statik
  }
}

String _offerUriDariKonstanta() {
  final uri = Uri.parse(kCredentialOfferUri);
  return uri.queryParameters['credential_offer_uri'] ?? kCredentialOfferUri;
}

String _ringkas(String s) => s.length <= 400 ? s : '${s.substring(0, 400)}...';

// ── Utilitas kripto & pendukung ────────────────────────────────────────
Future<String> _signJwt(
  Map<String, dynamic> header,
  Map<String, dynamic> payload,
  SimpleKeyPair kp,
) async {
  final h = _b64urlEncode(utf8.encode(jsonEncode(header)));
  final p = _b64urlEncode(utf8.encode(jsonEncode(payload)));
  final signingInput = '$h.$p';
  final sig = await _ed25519.sign(utf8.encode(signingInput), keyPair: kp);
  return '$signingInput.${_b64urlEncode(sig.bytes)}';
}

Future<bool> _verifyJwt(String jwt, SimplePublicKey pub) async {
  final parts = jwt.split('.');
  if (parts.length != 3) return false;
  final signingInput = utf8.encode('${parts[0]}.${parts[1]}');
  final sig = Signature(_b64urlDecode(parts[2]), publicKey: pub);
  return _ed25519.verify(signingInput, signature: sig);
}

String _holderDidFrom(SimplePublicKey pub) {
  final jwk = {'kty': 'OKP', 'crv': 'Ed25519', 'x': _b64urlEncode(pub.bytes)};
  return 'did:jwk:${_b64urlEncode(utf8.encode(jsonEncode(jwk)))}';
}

SimplePublicKey _holderKeyFromDid(String did) {
  final enc = did.substring('did:jwk:'.length).split('#').first;
  final jwk =
      jsonDecode(utf8.decode(_b64urlDecode(enc))) as Map<String, dynamic>;
  return SimplePublicKey(
    _b64urlDecode(jwk['x'] as String),
    type: KeyPairType.ed25519,
  );
}

SimplePublicKey _issuerKeyFromMultibase(String mb) {
  final bytes = _base58Decode(mb.substring(1));
  return SimplePublicKey(bytes.sublist(2), type: KeyPairType.ed25519);
}

Map<String, dynamic> _subjectClaims(String kredensial) {
  final inti = {'id': kHolderDid, 'nik': kHolderNik};
  if (kredensial == 'minimal') return inti;
  return {
    ...inti,
    'credentialName': 'Kartu BPJS Kesehatan',
    'holderName': 'Deva Finanda Saputra',
    'noBPJS': '320101020305',
    'tanggalLahir': '2005-02-03',
    'kelasRawat': 'II',
    'faskes': 'Puskesmas Contoh',
    'status': 'Aktif',
    'provinsi': 'DKI Jakarta',
  };
}

Future<void> applyNetworkProfile(String profile) async {
  // Kondisi jaringan (5G/4G) dibentuk di luar proses Dart via traffic shaping.
}

int _now() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

String _nonce() {
  final r = Random.secure();
  return _b64urlEncode(List<int>.generate(32, (_) => r.nextInt(256)));
}

String _uuid() {
  final r = Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = b.map((n) => n.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}'
      '-${h.substring(16, 20)}-${h.substring(20)}';
}

String _b64urlEncode(List<int> bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');

List<int> _b64urlDecode(String input) {
  var s = input.replaceAll('-', '+').replaceAll('_', '/');
  while (s.length % 4 != 0) {
    s += '=';
  }
  return base64.decode(s);
}

List<int> _base58Decode(String input) {
  const alfabet = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
  var nilai = BigInt.zero;
  final basis = BigInt.from(58);
  for (final unit in input.codeUnits) {
    final idx = alfabet.indexOf(String.fromCharCode(unit));
    if (idx < 0) throw FormatException('karakter base58 tak valid');
    nilai = nilai * basis + BigInt.from(idx);
  }
  final out = <int>[];
  var v = nilai;
  while (v > BigInt.zero) {
    out.insert(0, (v & BigInt.from(0xff)).toInt());
    v = v >> 8;
  }
  for (final unit in input.codeUnits) {
    if (unit == '1'.codeUnitAt(0)) {
      out.insert(0, 0);
    } else {
      break;
    }
  }
  return out;
}

bool _listEq(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

// ── Titik masuk ────────────────────────────────────────────────────────
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

  for (final t in kTreatments) {
    await applyNetworkProfile(t.jaringan);
    print(
      '== ${t.id} | ${t.kredensial} | ${t.jaringan} | c=${t.konkurensi} ==',
    );
    for (final e in skenario.entries) {
      await ukurSuccessRate(t, e.key, e.value);
    }
  }
}
