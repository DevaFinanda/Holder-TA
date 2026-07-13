import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:http/http.dart' as http;

const String kBaseUrlIssuer = 'https://issuer.identia.my.id';
const String kCredentialOfferUri =
    'https://issuer.identia.my.id/oid4vci/credential-offer/19eb9404-aa57-4f1f-8abf-bd789dbaa499';

// --- Ganti ke akun holder Deva (bukan admin) ---
const String kHolderEmail = '3201010203050001';
const String kHolderPassword = 'Deva123';

final Ed25519 _ed25519 = Ed25519();

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

Future<void> main() async {
  print('=== STEP 1: Ambil Credential Offer ===');
  final offerRes = await http.get(Uri.parse(kCredentialOfferUri));
  print('Status: ${offerRes.statusCode}');
  print('Body: ${offerRes.body}\n');
  if (offerRes.statusCode != 200) {
    print('Gagal ambil credential offer, berhenti.');
    return;
  }
  final offer = jsonDecode(offerRes.body) as Map<String, dynamic>;
  final issuerUrl = offer['credential_issuer']?.toString() ?? kBaseUrlIssuer;

  print('=== STEP 2: Ambil Metadata Issuer ===');
  final metaRes = await http.get(
    Uri.parse('$issuerUrl/.well-known/openid-credential-issuer'),
  );
  print('Status: ${metaRes.statusCode}');
  print('Body: ${metaRes.body}\n');
  if (metaRes.statusCode != 200) {
    print('Gagal ambil metadata issuer, berhenti.');
    return;
  }
  final metadata = jsonDecode(metaRes.body) as Map<String, dynamic>;
  final tokenEndpoint = metadata['token_endpoint']?.toString() ?? '';
  final credentialEndpoint = metadata['credential_endpoint']?.toString() ?? '';
  final authorizationEndpoint =
      metadata['authorization_endpoint']?.toString() ?? '';

  print('=== STEP 3: Generate Holder DID (keypair baru) ===');
  final keyPair = await _ed25519.newKeyPair();
  final pub = await keyPair.extractPublicKey();
  final jwk = {'kty': 'OKP', 'crv': 'Ed25519', 'x': b64urlEncode(pub.bytes)};
  final holderDid = 'did:jwk:${b64urlEncode(utf8.encode(jsonEncode(jwk)))}';
  print('Holder DID: $holderDid\n');

  print('=== STEP 4: Authorize via kredensial akun Deva ===');
  final state = randomToken(24);
  final params = {
    'response_type': 'code',
    'client_id': 'identia-holder-mobile',
    'redirect_uri': 'identia://callback',
    'state': state,
    'holder_did': holderDid,
    'identifier': kHolderEmail,
    'password': kHolderPassword,
  };
  final authRes = await http.post(
    Uri.parse(authorizationEndpoint),
    headers: {'Content-Type': 'application/x-www-form-urlencoded'},
    body: params,
  );
  print('Status: ${authRes.statusCode}');
  print('Body: ${authRes.body}');
  print('Location header: ${authRes.headers['location']}\n');
  if (authRes.statusCode >= 400) {
    print('Gagal authorize, berhenti.');
    return;
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
    print('Tidak menemukan authorization code, berhenti.');
    return;
  }
  print('Authorization code: $code\n');

  print('=== STEP 5: Tukar Authorization Code ke Token ===');
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
  print('Status: ${tokenRes.statusCode}');
  print('Body: ${tokenRes.body}\n');
  if (tokenRes.statusCode != 200) {
    print('Gagal tukar token, berhenti.');
    return;
  }
  final tokenJson = jsonDecode(tokenRes.body) as Map<String, dynamic>;

  final accessToken = tokenJson['access_token']?.toString() ?? '';
  final cNonce = tokenJson['c_nonce']?.toString() ?? '';
  print('Access token: $accessToken');
  print('c_nonce: $cNonce\n');
  if (accessToken.isEmpty || cNonce.isEmpty) {
    print('Access token atau c_nonce kosong, berhenti.');
    return;
  }

  print('=== STEP 6: Bangun Proof JWT ===');
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
  print('Proof JWT: $proofJwt\n');

  print('=== STEP 7: Request Credential ===');
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
  print('Status: ${credRes.statusCode}');
  print('Body: ${credRes.body}');
}
