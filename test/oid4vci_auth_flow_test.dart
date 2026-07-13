import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:identia/providers/wallet_provider.dart';
import 'package:identia/services/oid4vci_service.dart';

String _fakeJwt(
    {required String holderDid,
    required String nik,
    required String holderName,
    required String noBPJS,
    required String tanggalLahir}) {
  final header = base64Url
      .encode(utf8.encode('{"alg":"none","typ":"JWT"}'))
      .replaceAll('=', '');
  final payloadJson = jsonEncode({
    'iss': 'did:web:issuer.identia.my.id',
    'sub': holderDid,
    'iat': 1710000000,
    'vc': {
      'type': ['VerifiableCredential', 'IdentityCredential'],
      'credentialSubject': {
        'id': holderDid,
        'holderName': holderName,
        'nik': nik,
        'noBPJS': noBPJS,
        'tanggalLahir': tanggalLahir,
      }
    }
  });
  final payload =
      base64Url.encode(utf8.encode(payloadJson)).replaceAll('=', '');
  return '$header.$payload.signature';
}

OID4VCIResult _resultFor(
    {required String holderDid,
    required String nik,
    required String holderName,
    String? noBPJS,
    String tanggalLahir = '1990-01-01'}) {
  final resolvedNoBPJS =
      noBPJS ?? 'BPJS-${nik.substring(nik.length >= 4 ? nik.length - 4 : 0)}';
  return OID4VCIResult(
    rawJwt: _fakeJwt(
      holderDid: holderDid,
      nik: nik,
      holderName: holderName,
      noBPJS: resolvedNoBPJS,
      tanggalLahir: tanggalLahir,
    ),
    issuerDid: 'did:web:issuer.identia.my.id',
    credentialTypes: const ['VerifiableCredential', 'IdentityCredential'],
    holderDid: holderDid,
    credentialStatusUrl: 'https://issuer.identia.my.id/credential/status/test',
    grantTypeUsed: 'authorization_code',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OID4VCI Holder auth flow', () {
    test(
        'akun A lalu akun B pada wallet profile sama tidak menyisakan error palsu saat backend sukses',
        () async {
      const sharedHolderDid = 'did:jwk:shared-wallet-profile';
      var callCount = 0;

      final provider = WalletProvider(
        holderDidResolver: (_) async => sharedHolderDid,
        issuanceFlowRunner: ({
          required userId,
          required credentialOfferInput,
          required clientId,
          required redirectUri,
          holderDid,
          authIdentifier,
          authPassword,
          presentedVc,
          requestId,
          userNik,
          onProgress,
        }) async {
          callCount++;
          onProgress?.call(OID4VCIStep.authorizing, 'Membuka browser...');
          onProgress?.call(OID4VCIStep.exchangingToken, 'Autentikasi berhasil');
          onProgress?.call(OID4VCIStep.done, 'Sukses');

          if (callCount == 1) {
            return _resultFor(
              holderDid: sharedHolderDid,
              nik: '1111222233334444',
              holderName: 'A',
            );
          }
          return _resultFor(
            holderDid: sharedHolderDid,
            nik: '5555666677778888',
            holderName: 'B',
          );
        },
      );

      provider.updateUserScope('user-a');

      await provider.startIssuanceFlow(
        'openid-credential-offer://issuer?credential_offer=dummy',
        authIdentifier: '1111222233334444',
        authPassword: 'secret-a',
        userNik: '1111222233334444',
      );
      expect(provider.issuanceStatus, IssuanceStatus.saved);
      expect(provider.issuanceError, isNull);

      // Simulate logout/session transition before second account auth attempt.
      provider.resetIssuanceStatus();
      provider.updateUserScope('user-b');

      await provider.startIssuanceFlow(
        'openid-credential-offer://issuer?credential_offer=dummy-2',
        authIdentifier: '5555666677778888',
        authPassword: 'secret-b',
        userNik: '5555666677778888',
      );
      expect(provider.issuanceStatus, IssuanceStatus.saved);
      expect(provider.issuanceError, isNull);
    });

    test('abaikan respons lama ketika user submit ulang', () async {
      const sharedHolderDid = 'did:jwk:shared-wallet-profile';
      var callCount = 0;

      final provider = WalletProvider(
        holderDidResolver: (_) async => sharedHolderDid,
        issuanceFlowRunner: ({
          required userId,
          required credentialOfferInput,
          required clientId,
          required redirectUri,
          holderDid,
          authIdentifier,
          authPassword,
          presentedVc,
          requestId,
          userNik,
          onProgress,
        }) async {
          callCount++;
          final current = callCount;

          if (current == 1) {
            onProgress?.call(OID4VCIStep.authorizing, 'Attempt 1');
            await Future<void>.delayed(const Duration(milliseconds: 120));
            throw Exception(
                'did_binding_conflict: stale response should be ignored');
          }

          onProgress?.call(OID4VCIStep.authorizing, 'Attempt 2');
          await Future<void>.delayed(const Duration(milliseconds: 20));
          onProgress?.call(OID4VCIStep.done, 'Attempt 2 success');
          return _resultFor(
            holderDid: sharedHolderDid,
            nik: '9999000011112222',
            holderName: 'B',
          );
        },
      );

      provider.updateUserScope('user-a');

      final first = provider.startIssuanceFlow(
        'openid-credential-offer://issuer?credential_offer=first',
        authIdentifier: '1111222233334444',
        authPassword: 'secret-a',
        userNik: '1111222233334444',
      );

      await Future<void>.delayed(const Duration(milliseconds: 10));
      final second = provider.startIssuanceFlow(
        'openid-credential-offer://issuer?credential_offer=second',
        authIdentifier: '9999000011112222',
        authPassword: 'secret-b',
        userNik: '9999000011112222',
      );

      await Future.wait([first, second]);

      expect(provider.issuanceStatus, IssuanceStatus.saved);
      expect(provider.issuanceError, isNull);
      expect(
          provider.issuanceMessage, contains('Credential berhasil disimpan'));
    });

    test('tampilkan instruksi jelas jika holder DID tidak tersedia', () async {
      var runnerCalled = false;
      final provider = WalletProvider(
        holderDidResolver: (_) async => '',
        issuanceFlowRunner: ({
          required userId,
          required credentialOfferInput,
          required clientId,
          required redirectUri,
          holderDid,
          authIdentifier,
          authPassword,
          presentedVc,
          requestId,
          userNik,
          onProgress,
        }) async {
          runnerCalled = true;
          throw UnimplementedError();
        },
      );

      provider.updateUserScope('user-a');

      await provider.startIssuanceFlow(
        'openid-credential-offer://issuer?credential_offer=missing-did',
        authIdentifier: '1234567890123456',
        authPassword: 'secret',
        userNik: '1234567890123456',
      );

      expect(runnerCalled, isFalse);
      expect(provider.issuanceStatus, IssuanceStatus.error);
      expect(provider.issuanceError, contains('holder_did_missing'));
      expect(provider.issuanceError, contains('wallet aktif'));
    });

    test('isolasi DID ketat antar user dan stabil saat switch kembali',
        () async {
      final didByUser = <String, String>{};

      final provider = WalletProvider(
        holderDidResolver: (userId) async {
          return didByUser.putIfAbsent(userId, () => 'did:jwk:$userId');
        },
        issuanceFlowRunner: ({
          required userId,
          required credentialOfferInput,
          required clientId,
          required redirectUri,
          holderDid,
          authIdentifier,
          authPassword,
          presentedVc,
          requestId,
          userNik,
          onProgress,
        }) async {
          onProgress?.call(OID4VCIStep.done, 'Sukses');
          return _resultFor(
            holderDid: holderDid ?? 'did:jwk:$userId',
            nik: userNik ?? '0000000000000000',
            holderName: userId,
          );
        },
      );

      provider.updateUserScope('user-a');
      final didA = await provider
          .startIssuanceFlow(
            'openid-credential-offer://issuer?credential_offer=a',
            authIdentifier: '1111222233334444',
            authPassword: 'secret-a',
            userNik: '1111222233334444',
          )
          .then((_) => didByUser['user-a']);

      provider.clearWalletSession();
      provider.updateUserScope('user-b');
      final didB = await provider
          .startIssuanceFlow(
            'openid-credential-offer://issuer?credential_offer=b',
            authIdentifier: '5555666677778888',
            authPassword: 'secret-b',
            userNik: '5555666677778888',
          )
          .then((_) => didByUser['user-b']);

      provider.updateUserScope('user-a');
      final didABack = didByUser['user-a'];

      expect(didA, isNotNull);
      expect(didB, isNotNull);
      expect(didA, isNot(equals(didB)));
      expect(didABack, equals(didA));
    });
  });
}
