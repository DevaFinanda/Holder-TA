import {
  getNestedVcIssuerPublicKey,
  getNestedVcToken,
  loadVpToken,
  verifyJwtAtIssuedTime,
  decodeJwtPayload,
} from './vp-fixtures';

describe('STRIDE-C: Repudiation', () => {
  it('harus membuktikan Issuer menerbitkan JWT VC nested di dalam JWT VP', async () => {
    const jwtVp = loadVpToken();
    const jwtVc = getNestedVcToken(jwtVp);
    const issuerPublicKey = (await getNestedVcIssuerPublicKey(jwtVp)) as any;

    const verificationResult = await verifyJwtAtIssuedTime(jwtVc, issuerPublicKey);
    const vcPayload = decodeJwtPayload(jwtVc);

    console.log('\n=== Verifikasi Signature JWT VC ===');
    console.log('JWT VC asli diambil dari claim vp.verifiableCredential[0]');
    console.log('Menggunakan public key Issuer dari DID Document...');
    console.log('Hasil verifikasi: VALID ✓');
    console.log('Issuer DID     :', verificationResult.payload.iss);
    console.log('Holder DID     :', verificationResult.payload.sub);
    console.log('Credential ID  :', verificationResult.payload.jti);
    console.log('Nested VC iss  :', vcPayload.iss);
    console.log('Nested VC sub  :', vcPayload.sub);

    console.log('\n=== Kesimpulan ===');
    console.log('Signature VALID membuktikan VC diterbitkan');
    console.log('oleh pemegang private key Issuer yang sesuai.');
    console.log('Penyangkalan (repudiation) TIDAK DAPAT dilakukan. ✓');

    expect(verificationResult).not.toBeNull();
    expect(verificationResult.payload.iss).toBe('did:web:issuer.identia.my.id');
    expect(verificationResult.payload.sub).toBe(vcPayload.sub);
    expect(vcPayload.iss).toBe('did:web:issuer.identia.my.id');
  });
});