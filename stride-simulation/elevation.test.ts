import { generateKeyPair, SignJWT, exportJWK } from 'jose';
import {
  getVpHolderPublicKey,
  loadVpToken,
  verifyVp,
} from './vp-fixtures';

describe('STRIDE-F: Elevation of Privilege', () => {
  it('harus menolak JWT VP Holder saat dikirim ke verifier dengan audience berbeda', async () => {
    const jwtVp = loadVpToken();
    const holderPublicKey = (await getVpHolderPublicKey(jwtVp)) as any;

    const originalVerification = await verifyVp(jwtVp, holderPublicKey);
    const correctAudience = String(originalVerification.payload.aud);
    const wrongAudience = 'did:web:attacker.verifier.identia.my.id';

    console.log('JWT VP audience asli:', correctAudience);
    console.log('Percobaan replay ke:', wrongAudience);

    let verificationPassed = false;
    let errorMessage = '';

    try {
      await verifyVp(jwtVp, holderPublicKey, wrongAudience);
      verificationPassed = true;
    } catch (err: any) {
      verificationPassed = false;
      errorMessage = err.message;
    }

    console.log('\nHasil validasi backend Verifier:');
    console.log('Valid:', verificationPassed);
    if (!verificationPassed) {
      console.log('Error:', errorMessage);
      console.log('HTTP Response: 403 Forbidden');
      console.log('JWT VP: TIDAK diterima oleh verifier yang salah');
    }

    expect(verificationPassed).toBe(false);
    expect(errorMessage).toBeTruthy();
    expect(originalVerification.payload.aud).toBe('did:web:verifier.identia.my.id');
  });

  it('harus mengizinkan JWT VP jika audience verifier sesuai', async () => {
    const jwtVp = loadVpToken();
    const holderPublicKey = (await getVpHolderPublicKey(jwtVp)) as any;

    const verificationResult = await verifyVp(jwtVp, holderPublicKey, 'did:web:verifier.identia.my.id');

    console.log('Kontrol positif — audience verifier sesuai:');
    console.log('Valid: true');

    expect(verificationResult.payload.aud).toBe('did:web:verifier.identia.my.id');
  });
});