import {
  getVpHolderPublicKey,
  loadVpToken,
  tamperJwtPayload,
  verifyVp,
} from './vp-fixtures';

describe('STRIDE-B: Tampering', () => {
  it('harus menolak JWT VP yang payloadnya dimanipulasi', async () => {
    const jwtVp = loadVpToken();
    const holderPublicKey = (await getVpHolderPublicKey(jwtVp)) as any;

    const originalVerification = await verifyVp(jwtVp, holderPublicKey);

    const tamperedJwtVp = tamperJwtPayload(jwtVp, (payload) => {
      payload.nonce = `${String(payload.nonce)}-tampered`;
    });

    let verificationPassed = false;
    try {
      await verifyVp(tamperedJwtVp, holderPublicKey);
      verificationPassed = true;
    } catch (err: any) {
      verificationPassed = false;
      console.log('Tampering berhasil dideteksi:', err.message);
    }

    expect(verificationPassed).toBe(false);
    console.log('Hasil: JWT VP yang dimanipulasi DITOLAK sistem ✓');
    expect(originalVerification.payload.nonce).toBeDefined();
  });
});