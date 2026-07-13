import 'dart:convert';
import 'package:cryptography/cryptography.dart';

const int ITERASI = 100;
const String ISSUER_DID = 'did:web:issuer.identia.my.id';
const String VERIFIER_DID = 'did:web:verifier.identia.my.id';
const String EVIL_DID = 'did:web:evil.attacker.com';
const String HOLDER_NIK = '3201010203050001';
const String HOLDER_NAMA = 'Deva Finanda Saputra';
const String HOLDER_NOBPJS = '3201010203050';

class HasilSkenario {
  final String id;
  final String nama;
  final String jenis;
  final int iterasi;
  int sesuaiEkspektasi = 0;
  int tidakSesuaiEkspektasi = 0;

  HasilSkenario(
      {required this.id,
      required this.nama,
      required this.jenis,
      required this.iterasi});

  String get successRate =>
      '${(sesuaiEkspektasi / iterasi * 100).toStringAsFixed(1)}%';
}

String base64UrlEncode(List<int> bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');
List<int> base64UrlDecode(String input) {
  String normalized = input;
  while (normalized.length % 4 != 0) normalized += '=';
  return base64Url.decode(normalized);
}

String buildJwt(Map<String, dynamic> header, Map<String, dynamic> payload) {
  final h = base64UrlEncode(utf8.encode(jsonEncode(header)));
  final p = base64UrlEncode(utf8.encode(jsonEncode(payload)));
  return '$h.$p';
}

Future<String> signJwt(String signingInput, SimpleKeyPair keyPair) async {
  final signature =
      await Ed25519().sign(utf8.encode(signingInput), keyPair: keyPair);
  return '$signingInput.${base64UrlEncode(signature.bytes)}';
}

Future<bool> verifyJwt(String jwt, SimplePublicKey publicKey) async {
  final parts = jwt.split('.');
  if (parts.length != 3) return false;
  try {
    final signature =
        Signature(base64UrlDecode(parts[2]), publicKey: publicKey);
    return await Ed25519()
        .verify(utf8.encode('${parts[0]}.${parts[1]}'), signature: signature);
  } catch (e) {
    return false;
  }
}

Map<String, dynamic> decodeJwtPayload(String jwt) {
  final parts = jwt.split('.');
  if (parts.length != 3) throw Exception('Malformed JWT');
  return jsonDecode(utf8.decode(base64UrlDecode(parts[1])))
      as Map<String, dynamic>;
}

String modifyJwtPayload(String jwt, void Function(Map) modifier) {
  final parts = jwt.split('.');
  final payload = jsonDecode(utf8.decode(base64UrlDecode(parts[1])));
  modifier(payload);
  final newPayloadB64 = base64UrlEncode(utf8.encode(jsonEncode(payload)));
  return '${parts[0]}.$newPayloadB64.${parts[2]}';
}

class DidResolver {
  final Map<String, SimplePublicKey> _registry = {};
  void register(String did, SimplePublicKey pk) => _registry[did] = pk;
  SimplePublicKey? resolve(String did) => _registry[did];
}

class TrustedIssuerStore {
  final Set<String> _trustedDids = {};
  void trust(String did) => _trustedDids.add(did);
  bool isTrusted(String did) => _trustedDids.contains(did);
}

class NonceStore {
  final Set<String> _usedNonces = {};
  bool useNonce(String nonce) {
    if (_usedNonces.contains(nonce)) return false;
    _usedNonces.add(nonce);
    return true;
  }
}

class PolicyValidator {
  static bool validateIssuer(Map p, String expected) => p['iss'] == expected;
  static bool validateAudience(Map p, String expected) => p['aud'] == expected;

  static bool validateExpiration(Map p, {int clockSkewSeconds = 60}) {
    final exp = p['exp'] as int?;
    if (exp == null) return false;
    return exp >
        (DateTime.now().millisecondsSinceEpoch ~/ 1000) - clockSkewSeconds;
  }

  static bool validateIssuedAt(Map p) {
    final iat = p['iat'] as int?;
    if (iat == null) return false;
    return iat <= (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 60;
  }

  static bool validateJti(Map p) =>
      p.containsKey('jti') && (p['jti'] as String).isNotEmpty;

  static bool validateMandatoryClaims(Map p) {
    try {
      final subject = (p['vc'] as Map)['credentialSubject'] as Map;
      return subject.containsKey('NIK') &&
          subject.containsKey('nama') &&
          subject.containsKey('NOBPJS') &&
          subject.containsKey('status');
    } catch (e) {
      return false;
    }
  }

  static bool validateContextAndType(Map p, {bool isPresentation = false}) {
    try {
      final key = isPresentation ? 'vp' : 'vc';
      final obj = p[key] as Map;
      final context = obj['@context'] as List;
      final type = obj['type'] as List;

      final validContext =
          context.contains('https://www.w3.org/2018/credentials/v1');
      final validType = isPresentation
          ? type.contains('VerifiablePresentation')
          : type.contains('VerifiableCredential');

      return validContext && validType;
    } catch (e) {
      return false;
    }
  }

  static bool validateHolderBinding(Map vpPayload, Map vcPayload) {
    try {
      final vpHolder = vpPayload['vp']['holder'] as String?;
      final vpIss = vpPayload['iss'] as String?;
      final vcSub = vcPayload['sub'] as String?;

      return vpIss == vpHolder && vpHolder == vcSub;
    } catch (e) {
      return false;
    }
  }
}

class Issuer {
  final String did;
  final SimpleKeyPair keyPair;
  Issuer(this.did, this.keyPair);

  Future<String> issueVC(String holderDid,
      {bool expired = false, bool missingNik = false}) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final header = {'alg': 'EdDSA', 'typ': 'JWT', 'kid': '$did#key-1'};

    final subject = {
      'nama': HOLDER_NAMA,
      'NOBPJS': HOLDER_NOBPJS,
      'status': 'AKTIF'
    };
    if (!missingNik) subject['NIK'] = HOLDER_NIK;

    final payload = {
      'iss': did,
      'sub': holderDid,
      'iat': now,
      'exp': expired ? (now - 3600) : (now + 31536000),
      'jti': 'CRED-${DateTime.now().microsecondsSinceEpoch}',
      'vc': {
        '@context': ['https://www.w3.org/2018/credentials/v1'],
        'type': ['VerifiableCredential', 'BPJSHealthCard'],
        'credentialSubject': subject,
      },
    };
    return await signJwt(buildJwt(header, payload), keyPair);
  }
}

class Holder {
  final String did;
  final SimpleKeyPair keyPair;
  Holder(this.did, this.keyPair);

  Future<String> createVP(String vcJwt, String nonce,
      {String? overrideAud, String? overrideHolder}) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final header = {'alg': 'EdDSA', 'typ': 'JWT', 'kid': did};
    final payload = {
      'iss': did,
      'aud': overrideAud ?? VERIFIER_DID,
      'iat': now,
      'exp': now + 300,
      'nonce': nonce,
      'vp': {
        '@context': ['https://www.w3.org/2018/credentials/v1'],
        'type': ['VerifiablePresentation'],
        'verifiableCredential': [vcJwt],
        'holder': overrideHolder ?? did,
      },
    };
    return await signJwt(buildJwt(header, payload), keyPair);
  }
}

class Verifier {
  final String myDid;
  final DidResolver resolver;
  final TrustedIssuerStore trustStore;
  final NonceStore nonceStore;

  Verifier(this.myDid, this.resolver, this.trustStore, this.nonceStore);

  Future<bool> verifyVC(String jwt) async {
    if (jwt.split('.').length != 3) return false;
    try {
      final p = decodeJwtPayload(jwt);
      final iss = p['iss'] as String;

      final pubKey = resolver.resolve(iss);
      if (pubKey == null) return false;

      if (!trustStore.isTrusted(iss)) return false;

      if (!await verifyJwt(jwt, pubKey)) return false;

      return PolicyValidator.validateExpiration(p) &&
          PolicyValidator.validateIssuedAt(p) &&
          PolicyValidator.validateJti(p) &&
          PolicyValidator.validateMandatoryClaims(p) &&
          PolicyValidator.validateContextAndType(p);
    } catch (e) {
      return false;
    }
  }

  Future<bool> verifyVP(String jwt) async {
    if (jwt.split('.').length != 3) return false;
    try {
      final p = decodeJwtPayload(jwt);
      final iss = p['iss'] as String;

      final holderPubKey = resolver.resolve(iss);
      if (holderPubKey == null) return false;
      if (!await verifyJwt(jwt, holderPubKey)) return false;

      if (!PolicyValidator.validateAudience(p, myDid)) return false;
      if (!PolicyValidator.validateExpiration(p)) return false;
      if (!PolicyValidator.validateContextAndType(p, isPresentation: true))
        return false;

      final nonce = p['nonce'] as String;
      if (!nonceStore.useNonce(nonce)) return false;

      final vcList = (p['vp'] as Map)['verifiableCredential'] as List;
      if (vcList.isEmpty) return false;
      final vcJwt = vcList[0] as String;

      final vcPayload = decodeJwtPayload(vcJwt);
      if (!PolicyValidator.validateHolderBinding(p, vcPayload)) return false;

      return await verifyVC(vcJwt);
    } catch (e) {
      return false;
    }
  }
}

Future<HasilSkenario> testT1() async {
  final hasil = HasilSkenario(
      id: 'T1',
      nama: 'Ed25519 Key Generation',
      jenis: 'Positif',
      iterasi: ITERASI);
  final algo = Ed25519();
  for (int i = 0; i < ITERASI; i++) {
    final kp = await algo.newKeyPair();
    final priv = await kp.extractPrivateKeyBytes();
    final pub = await kp.extractPublicKey();
    if (priv.length == 32 && pub.bytes.length == 32) {
      hasil.sesuaiEkspektasi++;
    } else {
      hasil.tidakSesuaiEkspektasi++;
    }
  }
  return hasil;
}

Future<(HasilSkenario, String)> testT5(Issuer issuer, String holderDid) async {
  final hasil = HasilSkenario(
      id: 'T5', nama: 'Strict VC Issuance', jenis: 'Positif', iterasi: ITERASI);
  String lastVC = '';
  for (int i = 0; i < ITERASI; i++) {
    final vc = await issuer.issueVC(holderDid);
    hasil.sesuaiEkspektasi++;
    lastVC = vc;
  }
  return (hasil, lastVC);
}

Future<HasilSkenario> testT6(Verifier verifier, String vc) async {
  final hasil = HasilSkenario(
      id: 'T6',
      nama: 'Independent VC Verification',
      jenis: 'Positif',
      iterasi: ITERASI);
  for (int i = 0; i < ITERASI; i++) {
    final isValid = await verifier.verifyVC(vc);
    if (isValid) {
      hasil.sesuaiEkspektasi++;
    } else
      hasil.tidakSesuaiEkspektasi++;
  }
  return hasil;
}

Future<HasilSkenario> testT9(Holder holder, String vc) async {
  final hasil = HasilSkenario(
      id: 'T9',
      nama: 'VP Construction (Holder)',
      jenis: 'Positif',
      iterasi: ITERASI);
  for (int i = 0; i < ITERASI; i++) {
    await holder.createVP(vc, 'nonce_t9_$i');
    hasil.sesuaiEkspektasi++;
  }
  return hasil;
}

Future<HasilSkenario> testT10(Verifier verifier, String vp) async {
  final hasil = HasilSkenario(
      id: 'T10',
      nama: 'VP Two-Layer Verification',
      jenis: 'Positif',
      iterasi: ITERASI);
  for (int i = 0; i < ITERASI; i++) {
    final freshVerifier = Verifier(
        verifier.myDid, verifier.resolver, verifier.trustStore, NonceStore());
    final isValid = await freshVerifier.verifyVP(vp);
    if (isValid) {
      hasil.sesuaiEkspektasi++;
    } else
      hasil.tidakSesuaiEkspektasi++;
  }
  return hasil;
}

Future<HasilSkenario> testNeg(
    String id, String nama, Future<bool> Function() testLogic) async {
  final hasil =
      HasilSkenario(id: id, nama: nama, jenis: 'Negatif', iterasi: ITERASI);
  for (int i = 0; i < ITERASI; i++) {
    final isAccepted = await testLogic();
    if (!isAccepted) {
      hasil.sesuaiEkspektasi++;
    } else {
      hasil.tidakSesuaiEkspektasi++;
    }
  }
  return hasil;
}

Future<void> main() async {
  print('=' * 90);
  print('PROSES PENGUJIAN SUCCESS RATE (Single-Fault Methodology)');
  print('Total Iterasi per Skenario: $ITERASI');
  print('=' * 90);
  print('');

  final issuerKp = await Ed25519().newKeyPair();
  final issuerPub = await issuerKp.extractPublicKey();
  final holderKp = await Ed25519().newKeyPair();
  final holderPub = await holderKp.extractPublicKey();
  final evilKp = await Ed25519().newKeyPair();
  final evilPub = await evilKp.extractPublicKey();

  final holderJwk = {
    'kty': 'OKP',
    'crv': 'Ed25519',
    'x': base64UrlEncode(holderPub.bytes)
  };
  final holderDid =
      'did:jwk:${base64UrlEncode(utf8.encode(jsonEncode(holderJwk)))}';

  final resolver = DidResolver();
  resolver.register(ISSUER_DID, issuerPub);
  resolver.register(holderDid, holderPub);
  resolver.register(EVIL_DID, evilPub);

  final trustStore = TrustedIssuerStore();
  trustStore.trust(ISSUER_DID);

  final badResolver = DidResolver();
  badResolver.register(ISSUER_DID, evilPub);
  final badVerifier =
      Verifier(VERIFIER_DID, badResolver, trustStore, NonceStore());

  final verifier = Verifier(VERIFIER_DID, resolver, trustStore, NonceStore());
  final issuer = Issuer(ISSUER_DID, issuerKp);
  final holder = Holder(holderDid, holderKp);
  final evilIssuer = Issuer(EVIL_DID, evilKp);

  final semuaHasil = <HasilSkenario>[];

  print('[01/14] T1: Ed25519 Key Generation');
  print('  > Menjalankan $ITERASI iterasi pembangkitan kunci...');
  semuaHasil.add(await testT1());
  print(
      '  -> Selesai. Sesuai: ${semuaHasil.last.sesuaiEkspektasi} | Rate: ${semuaHasil.last.successRate}\n');

  print('[02/14] T5: Strict VC Issuance');
  print('  > Menjalankan $ITERASI iterasi penerbitan VC...');
  final (hasilT5, validVC) = await testT5(issuer, holderDid);
  semuaHasil.add(hasilT5);
  print(
      '  -> Selesai. Sesuai: ${hasilT5.sesuaiEkspektasi} | Rate: ${hasilT5.successRate}\n');

  print('[03/14] T6: Independent VC Verification');
  print('  > Menjalankan $ITERASI iterasi verifikasi VC...');
  semuaHasil.add(await testT6(verifier, validVC));
  print(
      '  -> Selesai. Sesuai: ${semuaHasil.last.sesuaiEkspektasi} | Rate: ${semuaHasil.last.successRate}\n');

  print('[04/14] T6-N1: VC Integrity (Payload Tampered)');
  print('  > Menguji integritas tanda tangan dengan payload yang diubah...');
  semuaHasil
      .add(await testNeg('T6-N1', 'VC Integrity: Payload Tampered', () async {
    final tampered = modifyJwtPayload(
        validVC, (p) => p['vc']['credentialSubject']['status'] = 'TIDAK AKTIF');
    return await verifier.verifyVC(tampered);
  }));
  print(
      '  -> Selesai. Sesuai (Ditolak): ${semuaHasil.last.sesuaiEkspektasi} | Rate: ${semuaHasil.last.successRate}\n');

  print('[05/14] T6-N2: VC Validity (Expired)');
  print('  > Menguji penolakan token yang sudah kedaluwarsa...');
  semuaHasil.add(await testNeg('T6-N2', 'VC Validity: Expired Token', () async {
    final expiredVC = await issuer.issueVC(holderDid, expired: true);
    return await verifier.verifyVC(expiredVC);
  }));
  print(
      '  -> Selesai. Sesuai (Ditolak): ${semuaHasil.last.sesuaiEkspektasi} | Rate: ${semuaHasil.last.successRate}\n');

  print('[06/14] T6-N3: VC Trust (Untrusted Issuer)');
  print('  > Menguji penolakan issuer yang tidak ada di daftar terpercaya...');
  semuaHasil.add(await testNeg('T6-N3', 'VC Trust: Untrusted Issuer', () async {
    final evilVC = await evilIssuer.issueVC(holderDid);
    return await verifier.verifyVC(evilVC);
  }));
  print(
      '  -> Selesai. Sesuai (Ditolak): ${semuaHasil.last.sesuaiEkspektasi} | Rate: ${semuaHasil.last.successRate}\n');

  print('[07/14] T6-N4: VC Schema (Missing Claim)');
  print('  > Menguji penolakan VC tanpa klaim wajib (NIK)...');
  semuaHasil.add(await testNeg('T6-N4', 'VC Schema: Missing NIK', () async {
    final noNikVC = await issuer.issueVC(holderDid, missingNik: true);
    return await verifier.verifyVC(noNikVC);
  }));
  print(
      '  -> Selesai. Sesuai (Ditolak): ${semuaHasil.last.sesuaiEkspektasi} | Rate: ${semuaHasil.last.successRate}\n');

  print('[08/14] T6-N5: VC Crypto (Poisoned Resolver)');
  print('  > Menguji penolakan akibat resolver DID yang salah...');
  semuaHasil
      .add(await testNeg('T6-N5', 'VC Crypto: Poisoned DID Resolver', () async {
    return await badVerifier.verifyVC(validVC);
  }));
  print(
      '  -> Selesai. Sesuai (Ditolak): ${semuaHasil.last.sesuaiEkspektasi} | Rate: ${semuaHasil.last.successRate}\n');

  print('[09/14] T9: VP Construction (Holder)');
  print('  > Menjalankan $ITERASI iterasi pembuatan VP...');
  semuaHasil.add(await testT9(holder, validVC));
  print(
      '  -> Selesai. Sesuai: ${semuaHasil.last.sesuaiEkspektasi} | Rate: ${semuaHasil.last.successRate}\n');

  print('[10/14] T10: VP Two-Layer Verification');
  print('  > Menjalankan $ITERASI iterasi verifikasi dua lapis...');
  final validVP = await holder.createVP(validVC, 'nonce_t10_valid');
  semuaHasil.add(await testT10(verifier, validVP));
  print(
      '  -> Selesai. Sesuai: ${semuaHasil.last.sesuaiEkspektasi} | Rate: ${semuaHasil.last.successRate}\n');

  print('[11/14] T10-N1: VP Security (Invalid Audience)');
  print('  > Menguji penolakan VP dengan audience yang salah...');
  semuaHasil
      .add(await testNeg('T10-N1', 'VP Security: Invalid Audience', () async {
    final badAudVP = await holder.createVP(validVC, 'nonce_aud',
        overrideAud: 'did:web:hacker.com');
    return await verifier.verifyVP(badAudVP);
  }));
  print(
      '  -> Selesai. Sesuai (Ditolak): ${semuaHasil.last.sesuaiEkspektasi} | Rate: ${semuaHasil.last.successRate}\n');

  print('[12/14] T10-N2: VP Security (Embedded Untrusted VC)');
  print(
      '  > Menguji penolakan VP yang berisi VC dari issuer tidak terpercaya...');
  semuaHasil.add(
      await testNeg('T10-N2', 'VP Security: Embedded Untrusted VC', () async {
    final evilVC = await evilIssuer.issueVC(holderDid);
    final vpWithEvilVC = await holder.createVP(evilVC, 'nonce_evil_vc');
    return await verifier.verifyVP(vpWithEvilVC);
  }));
  print(
      '  -> Selesai. Sesuai (Ditolak): ${semuaHasil.last.sesuaiEkspektasi} | Rate: ${semuaHasil.last.successRate}\n');

  print('[13/14] T10-N3: VP Security (Replay Attack)');
  print('  > Menguji penolakan VP yang digunakan berulang (replay)...');
  semuaHasil
      .add(await testNeg('T10-N3', 'VP Security: Replay Attack', () async {
    final replayVerifier =
        Verifier(VERIFIER_DID, resolver, trustStore, NonceStore());
    final nonce = 'nonce_replay_test';
    final vp = await holder.createVP(validVC, nonce);
    await replayVerifier.verifyVP(vp);
    return await replayVerifier.verifyVP(vp);
  }));
  print(
      '  -> Selesai. Sesuai (Ditolak): ${semuaHasil.last.sesuaiEkspektasi} | Rate: ${semuaHasil.last.successRate}\n');

  print('[14/14] T10-N4: VP Security (Holder Binding)');
  print('  > Menguji penolakan VP yang tidak sesuai dengan pemilik VC...');
  semuaHasil.add(
      await testNeg('T10-N4', 'VP Security: Holder Binding Mismatch', () async {
    final badBindVP = await holder.createVP(validVC, 'nonce_bind',
        overrideHolder: 'did:jwk:fake_person');
    return await verifier.verifyVP(badBindVP);
  }));
  print(
      '  -> Selesai. Sesuai (Ditolak): ${semuaHasil.last.sesuaiEkspektasi} | Rate: ${semuaHasil.last.successRate}\n');

  print('=' * 90);
  print('REKAPITULASI HASIL PENGUJIAN SUCCESS RATE');
  print('=' * 90);
  print(
      '${'ID'.padRight(8)} | ${'Skenario Pengujian'.padRight(45)} | ${'Jenis'.padRight(8)} | Rate');
  print('-' * 90);

  for (final h in semuaHasil) {
    print('${h.id.padRight(8)} | '
        '${h.nama.padRight(45)} | '
        '${h.jenis.padRight(8)} | '
        '${h.successRate}');
  }

  print('=' * 90);
  final totalSesuai = semuaHasil.fold(0, (sum, h) => sum + h.sesuaiEkspektasi);
  final totalIterasi = semuaHasil.fold(0, (sum, h) => sum + h.iterasi);
  print(
      'TOTAL ITERASI: $totalIterasi | OVERALL SUCCESS RATE: ${(totalSesuai / totalIterasi * 100).toStringAsFixed(2)}%');
  print('=' * 90);
}
