import {
  getNestedVcToken,
  loadVpToken,
  decodeJwtPayload,
} from './vp-fixtures';

describe('STRIDE-D: Information Disclosure', () => {
  it('memeriksa apakah data yang dipresentasikan ke Verifier dibatasi sesuai kebutuhan verifikasi (data minimization)', async () => {
    const jwtVp = loadVpToken();
    const jwtVc = getNestedVcToken(jwtVp);

    const vcPayload = decodeJwtPayload(jwtVc) as any;
    const credentialSubject = vcPayload.vc.credentialSubject;

    console.log('\n===== Data pada Credential Subject yang Dipresentasikan =====');
    console.log(credentialSubject);
    
    const fieldDiperlukan = ['id', 'credentialName'];
    const semuaField = Object.keys(credentialSubject);
    const fieldBerlebih = semuaField.filter(
      (f) => !fieldDiperlukan.includes(f),
    );

    console.log('\nField yang sebenarnya diperlukan untuk verifikasi:', fieldDiperlukan);
    console.log('Field yang ikut terungkap (berlebih):', fieldBerlebih);

    const adaDataSensitifTerbuka =
      fieldBerlebih.includes('nik') || fieldBerlebih.includes('tanggalLahir');

    console.log(
      '\nHasil: Data sensitif (NIK/tanggal lahir) ' +
        (adaDataSensitifTerbuka ? 'TERUNGKAP' : 'TIDAK terungkap') +
        ' pada presentasi ini',
    );

    expect(semuaField).toEqual(
      expect.arrayContaining(['nik', 'tanggalLahir']),
    );
  });
});