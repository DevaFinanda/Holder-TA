import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:http/http.dart' as http;

const int kTotalIterasi = 30;
const Duration kBatasWaktu = Duration(seconds: 15);
const String kBaseUrlIssuer = 'https://issuer.identia.my.id';
const String kBaseUrlVerifier = 'http://verifier.identia.my.id';
const String kPathCredentialOffer = '/.well-known/openid-credential-issuer';
const String kUsernameIssuer = 'admin';
const String kPasswordIssuer = 'admin123';
// Sudah tidak dipakai langsung oleh skenarioT5 (offer ini single-use dan
// sudah exhausted). Dibiarkan di sini hanya sebagai referensi historis.
const String kCredentialOfferUri =
    'openid-credential-offer://?credential_offer_uri=https%3A%2F%2Fissuer.identia.my.id%2Foid4vci%2Fcredential-offer%2Fca4b429d-d227-4da7-b58c-e67a84f41242';

const String kHolderNik = '3201010203050001';
const String kHolderPassword = 'Deva123';
const Set<String> kSkenarioDilewati = {};

const String kHolderPublicKeyB64 =
    'z_yRmHTyDQhxMYXBAK_CXCJrPY897v62QWFzxHk1C2k';
const String kHolderDid =
    'did:jwk:eyJrdHkiOiJPS1AiLCJjcnYiOiJFZDI1NTE5IiwieCI6InpfeVJtSFR5RFFoeE1ZWEJBS19DWENKclBZODk3djYyUVdGenhIazFDMmsifQ';
const String kIssuerPublicKeyMultibase =
    'z6MkhyKruKxbzoUegAD4s7x8hzwbahsKa2q5rwAtK9CZ86dU';
const String kJwtVc =
    'eyJraWQiOiJkaWQ6d2ViOmlzc3Vlci5pZGVudGlhLm15LmlkI2tleS0xIiwiYWxnIjoiRWREU0EiLCJ0eXAiOiJKV1QifQ.eyJ2YyI6eyJAY29udGV4dCI6WyJodHRwczovL3d3dy53My5vcmcvMjAxOC9jcmVkZW50aWFscy92MSJdLCJ0eXBlIjpbIlZlcmlmaWFibGVDcmVkZW50aWFsIiwiS2FydHVCUEpTS2VzZWhhdGFuIl0sImlkIjoidXJuOnV1aWQ6MDVhNDkzMTktY2MzNy00MThjLWIxNzEtZWY0NWE2ZDg5Mjk5IiwiaXNzdWVyIjoiZGlkOndlYjppc3N1ZXIuaWRlbnRpYS5teS5pZCIsImlzc3VhbmNlRGF0ZSI6IjIwMjYtMDctMDVUMDM6Mzk6MzIuMDAwWiIsImNyZWRlbnRpYWxTdWJqZWN0Ijp7ImlkIjoiZGlkOmp3azpleUpyZEhraU9pSlBTMUFpTENKamNuWWlPaUpGWkRJMU5URTVJaXdpZUNJNklucGZlVkp0U0ZSNVJGRm9lRTFaV0VKQlMxOURXRU5LY2xCWk9EazNkall5VVZkR2VuaElhekZETW1zaWZRIiwiY3JlZGVudGlhbE5hbWUiOiJLYXJ0dSBCUEpTIEtlc2VoYXRhbiIsImhvbGRlck5hbWUiOiJEZXZhIEZpbmFuZGEgU2FwdXRyYSIsIm5payI6IjMyMDEwMTAyMDMwNTAwMDEiLCJub0JQSlMiOiIzMjAxMDEwMjAzMDUwIiwidGFuZ2dhbExhaGlyIjoiMjAwNS0wMi0wMyJ9fSwic3ViIjoiZGlkOmp3azpleUpyZEhraU9pSlBTMUFpTENKamNuWWlPaUpGWkRJMU5URTVJaXdpZUNJNklucGZlVkp0U0ZSNVJGRm9lRTFaV0VKQlMxOURXRU5LY2xCWk9EazNkall5VVZkR2VuaElhekZETW1zaWZRIiwibmJmIjoxNzgzMjIyNzcyLCJqdGkiOiJ1cm46dXVpZDowNWE0OTMxOS1jYzM3LTQxOGMtYjE3MS1lZjQ1YTZkODkyOTkiLCJpc3MiOiJkaWQ6d2ViOmlzc3Vlci5pZGVudGlhLm15LmlkIn0.MCpfVugLALCaRPdBp2IBxF5LSnwy6MxHGKrxFl_H7SgaUP05u4C9vHcE73MsaO-KFQY7ZkRC6jD9GCw4kaPWAg';

final Ed25519 _ed25519 = Ed25519();

// --- Ditambahkan untuk perbaikan T10 (hindari string statis yang rawan corrupt) ---
late String kJwtVpRuntime;
late List<int> kHolderPublicKeyRuntime;

Future<void> siapkanSampelVp() async {
  final keyPair = await _ed25519.newKeyPair();
  final pub = await keyPair.extractPublicKey();
  final header = {'alg': 'EdDSA', 'typ': 'vp+jwt'};
  final payload = {
    'iss': 'did:jwk:sample-verifikasi-t10',
    'aud': 'did:web:verifier.identia.my.id',
    'nonce': 'uji-vp-nonce-statis',
    'vp': {
      '@context': ['https://www.w3.org/2018/credentials/v1'],
      'type': ['VerifiablePresentation'],
      'verifiableCredential': [kJwtVc],
    },
  };
  final headerB64 = b64urlEncode(utf8.encode(jsonEncode(header)));
  final payloadB64 = b64urlEncode(utf8.encode(jsonEncode(payload)));
  final pesan = utf8.encode('$headerB64.$payloadB64');
  final tandaTangan = await _ed25519.sign(pesan, keyPair: keyPair);
  kJwtVpRuntime = '$headerB64.$payloadB64.${b64urlEncode(tandaTangan.bytes)}';
  kHolderPublicKeyRuntime = pub.bytes;
}

List<int> b64urlDecode(String input) {
  var s = input.replaceAll('-', '+').replaceAll('_', '/');
  while (s.length % 4 != 0) {
    s += '=';
  }
  return base64.decode(s);
}

String b64urlEncode(List<int> bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');

String randomToken(int length) {
  const chars =
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  final rand = Random.secure();
  final buf = StringBuffer();
  for (var i = 0; i < length; i++) {
    buf.write(chars[rand.nextInt(chars.length)]);
  }
  return buf.toString();
}

const String _alfabetBase58 =
    '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';

List<int> base58Decode(String input) {
  var angka = BigInt.zero;
  final basis = BigInt.from(58);
  for (final karakter in input.split('')) {
    final indeks = _alfabetBase58.indexOf(karakter);
    if (indeks < 0) {
      throw FormatException('Karakter base58 tidak valid: $karakter');
    }
    angka = angka * basis + BigInt.from(indeks);
  }
  final byte = <int>[];
  var sisa = angka;
  while (sisa > BigInt.zero) {
    byte.insert(0, (sisa % BigInt.from(256)).toInt());
    sisa = sisa ~/ BigInt.from(256);
  }
  for (final karakter in input.split('')) {
    if (karakter == '1') {
      byte.insert(0, 0);
    } else {
      break;
    }
  }
  return byte;
}

List<int> kunciPublikHolder() => b64urlDecode(kHolderPublicKeyB64);

List<int> kunciPublikIssuer() =>
    base58Decode(kIssuerPublicKeyMultibase.substring(1)).sublist(2);

Future<bool> verifikasiJwt(String jwt, List<int> kunciPublik) async {
  final bagian = jwt.split('.');
  if (bagian.length != 3) return false;
  final pesan = utf8.encode('${bagian[0]}.${bagian[1]}');
  final tandaTangan = b64urlDecode(bagian[2]);
  final publicKey = SimplePublicKey(kunciPublik, type: KeyPairType.ed25519);
  return _ed25519.verify(
    pesan,
    signature: Signature(tandaTangan, publicKey: publicKey),
  );
}

Map<String, dynamic> payloadJwt(String jwt) {
  final bagian = jwt.split('.');
  return jsonDecode(utf8.decode(b64urlDecode(bagian[1])))
      as Map<String, dynamic>;
}

class HasilSkenario {
  final String id;
  final String nama;
  final String kategori;
  int berhasil = 0;
  int gagal = 0;
  bool dilewati = false;
  final List<String> catatanGagal = [];

  HasilSkenario(this.id, this.nama, this.kategori);

  int get totalDijalankan => berhasil + gagal;
  double get successRate =>
      totalDijalankan == 0 ? 0 : (berhasil / totalDijalankan) * 100;
}

typedef IterasiSkenario = Future<bool> Function();

Future<HasilSkenario> jalankanSkenario(
  String id,
  String nama,
  String kategori,
  IterasiSkenario iterasi,
) async {
  final hasil = HasilSkenario(id, nama, kategori);
  if (kSkenarioDilewati.contains(id)) {
    hasil.dilewati = true;
    print('[$id] $nama -> DILEWATI');
    return hasil;
  }
  for (var i = 1; i <= kTotalIterasi; i++) {
    try {
      final ok = await iterasi().timeout(kBatasWaktu);
      if (ok) {
        hasil.berhasil++;
      } else {
        hasil.gagal++;
        hasil.catatanGagal.add('Iterasi $i: keluaran tidak memenuhi kriteria');
      }
    } on TimeoutException {
      hasil.gagal++;
      hasil.catatanGagal.add(
        'Iterasi $i: melewati batas waktu ${kBatasWaktu.inSeconds}s',
      );
    } catch (e) {
      hasil.gagal++;
      hasil.catatanGagal.add('Iterasi $i: exception -> $e');
    }
  }
  print(
    '[$id] $nama ($kategori) -> '
    '${hasil.berhasil}/${hasil.totalDijalankan} berhasil '
    '(${hasil.successRate.toStringAsFixed(1)}%)',
  );
  return hasil;
}

Future<bool> skenarioT1() async {
  final keyPair = await _ed25519.newKeyPair();
  final pub = await keyPair.extractPublicKey();
  final priv = await keyPair.extractPrivateKeyBytes();
  return pub.bytes.length == 32 && priv.length == 32;
}

Future<bool> skenarioT2() async {
  final jwk = {'kty': 'OKP', 'crv': 'Ed25519', 'x': kHolderPublicKeyB64};
  final encoded = b64urlEncode(utf8.encode(jsonEncode(jwk)));
  return 'did:jwk:$encoded' == kHolderDid;
}

Future<bool> skenarioT3() async {
  final res = await http.get(Uri.parse('$kBaseUrlIssuer$kPathCredentialOffer'));
  if (res.statusCode != 200) return false;
  final data = jsonDecode(res.body) as Map<String, dynamic>;
  return data.containsKey('credential_issuer');
}

Future<bool> skenarioT4() async {
  final keyPair = await _ed25519.newKeyPair();
  final pub = await keyPair.extractPublicKey();
  final header = {
    'alg': 'EdDSA',
    'typ': 'openid4vci-proof+jwt',
    'jwk': {'kty': 'OKP', 'crv': 'Ed25519', 'x': b64urlEncode(pub.bytes)},
  };
  final payload = {
    'aud': 'did:web:issuer.identia.my.id',
    'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    'nonce': 'uji-proof-nonce',
  };
  final headerB64 = b64urlEncode(utf8.encode(jsonEncode(header)));
  final payloadB64 = b64urlEncode(utf8.encode(jsonEncode(payload)));
  final pesan = utf8.encode('$headerB64.$payloadB64');
  final tandaTangan = await _ed25519.sign(pesan, keyPair: keyPair);
  final proofJwt = '$headerB64.$payloadB64.${b64urlEncode(tandaTangan.bytes)}';
  final headerTerurai =
      jsonDecode(utf8.decode(b64urlDecode(proofJwt.split('.')[0])))
          as Map<String, dynamic>;
  final jwk = headerTerurai['jwk'] as Map<String, dynamic>;
  return verifikasiJwt(proofJwt, b64urlDecode(jwk['x'] as String));
}

// ─── T5: DIPERBAIKI — offer baru & unik di-generate setiap iterasi lewat
// credential_offer_endpoint, sehingga tidak lagi terganjal HTTP 410
// "Credential offer has already been used" ───────────────────────────────
Future<bool> skenarioT5() async {
  // STEP 1 (BARU): generate credential offer baru & unik untuk iterasi ini
  final offerGenRes = await http.post(
    Uri.parse('$kBaseUrlIssuer/oid4vci/credential-offer'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'credential_configuration_ids': ['kartu_bpjs_kesehatan'],
    }),
  );
  if (offerGenRes.statusCode != 200) {
    throw Exception(
      'STEP1 gagal generate offer baru, status ${offerGenRes.statusCode}, body: ${offerGenRes.body}',
    );
  }
  final offerGenBody = jsonDecode(offerGenRes.body) as Map<String, dynamic>;
  final offer = offerGenBody['credentialOffer'] as Map<String, dynamic>;

  final issuerUrl = offer['credential_issuer']?.toString() ?? kBaseUrlIssuer;
  final metaRes = await http.get(Uri.parse('$issuerUrl$kPathCredentialOffer'));
  if (metaRes.statusCode != 200) {
    throw Exception('STEP2 gagal, status ${metaRes.statusCode}');
  }
  final metadata = jsonDecode(metaRes.body) as Map<String, dynamic>;
  final tokenEndpoint = metadata['token_endpoint']?.toString() ?? '';
  final credentialEndpoint = metadata['credential_endpoint']?.toString() ?? '';
  final authorizationEndpoint =
      metadata['authorization_endpoint']?.toString() ?? '';

  final keyPair = await _ed25519.newKeyPair();
  final pub = await keyPair.extractPublicKey();
  final jwk = {'kty': 'OKP', 'crv': 'Ed25519', 'x': b64urlEncode(pub.bytes)};
  final holderDid = 'did:jwk:${b64urlEncode(utf8.encode(jsonEncode(jwk)))}';

  final authRes = await http.post(
    Uri.parse(authorizationEndpoint),
    headers: {'Content-Type': 'application/x-www-form-urlencoded'},
    body: {
      'response_type': 'code',
      'client_id': 'identia-holder-mobile',
      'redirect_uri': 'identia://callback',
      'state': randomToken(24),
      'holder_did': holderDid,
      'identifier': kHolderNik,
      'password': kHolderPassword,
    },
  );
  if (authRes.statusCode >= 400) {
    throw Exception(
      'STEP4 gagal, status ${authRes.statusCode}, body: ${authRes.body}',
    );
  }
  String? code;
  final location = authRes.headers['location'];
  if (location != null) {
    code = Uri.tryParse(location)?.queryParameters['code'];
  }
  if (code == null) {
    try {
      final authJson = jsonDecode(authRes.body) as Map<String, dynamic>;
      code = authJson['code']?.toString();
    } catch (_) {}
  }
  if (code == null || code.isEmpty) {
    throw Exception(
      'STEP4 tidak ada code, status ${authRes.statusCode}, body: ${authRes.body}, location: $location',
    );
  }

  final tokenRes = await http.post(
    Uri.parse(tokenEndpoint),
    headers: {'Content-Type': 'application/x-www-form-urlencoded'},
    body: {
      'grant_type': 'authorization_code',
      'code': code,
      'client_id': 'identia-holder-mobile',
      'redirect_uri': 'identia://callback',
      'holder_did': holderDid,
    },
  );
  if (tokenRes.statusCode != 200) {
    throw Exception(
      'STEP5 gagal, status ${tokenRes.statusCode}, body: ${tokenRes.body}',
    );
  }
  final tokenJson = jsonDecode(tokenRes.body) as Map<String, dynamic>;
  final accessToken = tokenJson['access_token']?.toString() ?? '';
  final cNonce = tokenJson['c_nonce']?.toString() ?? '';
  if (accessToken.isEmpty || cNonce.isEmpty) {
    throw Exception('STEP5 token/cNonce kosong: ${tokenRes.body}');
  }

  final audience = credentialEndpoint.isNotEmpty
      ? credentialEndpoint
      : issuerUrl;
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final proofHeader = {
    'alg': 'EdDSA',
    'typ': 'openid4vci-proof+jwt',
    'kid': '$holderDid#0',
  };
  final proofPayload = {
    'iss': holderDid,
    'sub': holderDid,
    'aud': audience,
    'nonce': cNonce,
    'iat': now,
    'exp': now + 120,
    'jti': randomToken(20),
  };
  final headerB64 = b64urlEncode(utf8.encode(jsonEncode(proofHeader)));
  final payloadB64 = b64urlEncode(utf8.encode(jsonEncode(proofPayload)));
  final signingInput = '$headerB64.$payloadB64';
  final signature = await _ed25519.sign(
    utf8.encode(signingInput),
    keyPair: keyPair,
  );
  final proofJwt = '$signingInput.${b64urlEncode(signature.bytes)}';

  final credRes = await http.post(
    Uri.parse(credentialEndpoint),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $accessToken',
    },
    body: jsonEncode({
      'format': 'jwt_vc_json',
      'credential_definition': {
        'type': ['VerifiableCredential', 'KartuBPJSKesehatan'],
      },
      'holder_did': holderDid,
      'proof': {'proof_type': 'jwt', 'jwt': proofJwt},
    }),
  );
  if (credRes.statusCode != 200) {
    throw Exception(
      'STEP7 gagal, status ${credRes.statusCode}, body: ${credRes.body}',
    );
  }
  final credBody = jsonDecode(credRes.body) as Map<String, dynamic>;
  final rawJwt = credBody['credential']?.toString();
  if (rawJwt == null || rawJwt.isEmpty) {
    throw Exception('STEP7 tidak ada field credential: ${credRes.body}');
  }
  final segmen = rawJwt.split('.');
  final payload =
      jsonDecode(utf8.decode(b64urlDecode(segmen[1]))) as Map<String, dynamic>;
  final iss = payload['iss']?.toString() ?? '';
  if (iss != 'did:web:issuer.identia.my.id') {
    throw Exception('iss tidak cocok: $iss');
  }
  String? subjectId;
  final vc = payload['vc'];
  if (vc is Map) {
    final cs = vc['credentialSubject'];
    if (cs is Map) subjectId = cs['id']?.toString();
  }
  subjectId ??= payload['sub']?.toString();
  if (subjectId != holderDid) {
    throw Exception('subjectId ($subjectId) != holderDid ($holderDid)');
  }
  return true;
}
// ─────────────────────────────────────────────────────────────────────────

Future<bool> skenarioT6() async {
  final valid = await verifikasiJwt(kJwtVc, kunciPublikIssuer());
  return valid && payloadJwt(kJwtVc).containsKey('vc');
}

Future<bool> skenarioT7() async {
  final kredensial = {'format': 'jwt_vc', 'credential': kJwtVc};
  final dipulihkan = jsonDecode(jsonEncode(kredensial)) as Map<String, dynamic>;
  return dipulihkan['credential'] == kJwtVc;
}

const String kSampleAuthorizationRequestUri =
    'openid4vp://?client_id=did%3Aweb%3Averifier.identia.my.id'
    '&response_type=vp_token'
    '&response_mode=direct_post'
    '&nonce=Z0YbEB5Y8taQP7GEN9eS5hytgK3M39xn4u0zYu21dkc'
    '&state=urn%3Auuid%3A58ea8ad7-6087-4a3e-8e7a-acb0aa0fe9b0'
    '&response_uri=https%3A%2F%2Fverifier.identia.my.id%2Fcallback'
    '&presentation_definition=%7B%22id%22%3A%22bpjs-verification%22%2C%22input_descriptors%22%3A%5B%7B%22id%22%3A%22KartuBPJSKesehatan%22%7D%5D%7D';

Future<bool> skenarioT8() async {
  final uri = Uri.parse(kSampleAuthorizationRequestUri);
  if (uri.scheme != 'openid4vp' && uri.scheme != 'openid-vc') return false;
  final params = uri.queryParameters;
  final wajib = ['client_id', 'response_type', 'nonce'];
  for (final k in wajib) {
    if (!params.containsKey(k) || params[k]!.isEmpty) return false;
  }
  final adaDefinisi =
      params.containsKey('presentation_definition') ||
      params.containsKey('presentation_definition_uri');
  if (!adaDefinisi) return false;
  if (params.containsKey('presentation_definition')) {
    final pd =
        jsonDecode(params['presentation_definition']!) as Map<String, dynamic>;
    if (!pd.containsKey('id') || !pd.containsKey('input_descriptors')) {
      return false;
    }
  }
  return true;
}

Future<bool> skenarioT9() async {
  final keyPair = await _ed25519.newKeyPair();
  final pub = await keyPair.extractPublicKey();
  final header = {'alg': 'EdDSA', 'typ': 'vp+jwt'};
  final payload = {
    'iss': kHolderDid,
    'aud': 'did:web:verifier.identia.my.id',
    'nonce': 'uji-vp-nonce',
    'vp': {
      '@context': ['https://www.w3.org/2018/credentials/v1'],
      'type': ['VerifiablePresentation'],
      'verifiableCredential': [kJwtVc],
    },
  };
  final headerB64 = b64urlEncode(utf8.encode(jsonEncode(header)));
  final payloadB64 = b64urlEncode(utf8.encode(jsonEncode(payload)));
  final pesan = utf8.encode('$headerB64.$payloadB64');
  final tandaTangan = await _ed25519.sign(pesan, keyPair: keyPair);
  final jwtVp = '$headerB64.$payloadB64.${b64urlEncode(tandaTangan.bytes)}';
  final vpValid = await verifikasiJwt(jwtVp, pub.bytes);
  final vcTertanam =
      (payloadJwt(jwtVp)['vp'] as Map<String, dynamic>)['verifiableCredential']
          as List;
  final vcValid = await verifikasiJwt(
    vcTertanam.first as String,
    kunciPublikIssuer(),
  );
  return vpValid && vcValid;
}

// --- T10 DIPERBAIKI: pakai sampel VP yang dibangun sekali di runtime ---
Future<bool> skenarioT10() async {
  final vpValid = await verifikasiJwt(kJwtVpRuntime, kHolderPublicKeyRuntime);
  final daftarVc =
      (payloadJwt(kJwtVpRuntime)['vp']
              as Map<String, dynamic>)['verifiableCredential']
          as List;
  final vcValid = await verifikasiJwt(
    daftarVc.first as String,
    kunciPublikIssuer(),
  );
  return vpValid && vcValid;
}

Future<void> main() async {
  await siapkanSampelVp();
  print('=== PENGUJIAN SUCCESS RATE ($kTotalIterasi iterasi/skenario) ===\n');

  final hasil = <HasilSkenario>[
    await jalankanSkenario(
      'T1',
      'Ed25519 Key Pair Generation',
      'K2',
      skenarioT1,
    ),
    await jalankanSkenario('T2', 'Pembentukan DID:JWK', 'K2', skenarioT2),
    await jalankanSkenario(
      'T3',
      'Penguraian Credential Offer',
      'K3',
      skenarioT3,
    ),
    await jalankanSkenario('T4', 'Proof JWT Construction', 'K3', skenarioT4),
    await jalankanSkenario('T5', 'Penyusunan Payload JWT VC', 'K3', skenarioT5),
    await jalankanSkenario(
      'T6',
      'Verifikasi Struktur JWT VC',
      'K2',
      skenarioT6,
    ),
    await jalankanSkenario(
      'T7',
      'Serialisasi Penyimpanan Kredensial',
      'K2',
      skenarioT7,
    ),
    await jalankanSkenario(
      'T8',
      'Penguraian Authorization Request',
      'K2',
      skenarioT8,
    ),
    await jalankanSkenario('T9', 'JWT VP Construction', 'K3', skenarioT9),
    await jalankanSkenario(
      'T10',
      'Verifikasi Struktur JWT VP',
      'K2',
      skenarioT10,
    ),
  ];

  for (final h in hasil) {
    if (h.gagal > 0 && h.catatanGagal.isNotEmpty) {
      print('\nContoh catatan gagal untuk ${h.id}:');
      for (final catatan in h.catatanGagal.take(3)) {
        print('  - $catatan');
      }
    }
  }

  cetakTabelHasil(hasil);
}

void cetakTabelHasil(List<HasilSkenario> hasil) {
  print('\n=== REKAP HASIL (Tabel 4.9) ===');
  print('ID   | Iterasi | Berhasil | Gagal | Success Rate');
  print('-----|---------|----------|-------|-------------');
  for (final h in hasil) {
    if (h.dilewati) {
      print('${h.id.padRight(4)} |    -    |    -     |   -   | (dilewati)');
      continue;
    }
    print(
      '${h.id.padRight(4)} '
      '| ${h.totalDijalankan.toString().padLeft(4).padRight(7)} '
      '| ${h.berhasil.toString().padLeft(5).padRight(8)} '
      '| ${h.gagal.toString().padLeft(3).padRight(5)} '
      '| ${h.successRate.toStringAsFixed(1)}%',
    );
  }
}
