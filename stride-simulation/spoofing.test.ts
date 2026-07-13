import { generateKeyPair, SignJWT } from "jose";
import {
  decodeJwtHeader,
  decodeJwtPayload,
  getVpHolderPublicKey,
  loadVpToken,
  verifyVp,
} from "./vp-fixtures";

describe("STRIDE-A : Spoofing", () => {

  it("Reject JWT VP signed by random private key", async () => {

    const jwtVp = loadVpToken();

    console.log("\n===== JWT VP =====");
    console.log(jwtVp.substring(0,100) + "...");
    console.log("Length :", jwtVp.length);
    console.log("Dot Count :", (jwtVp.match(/\./g) || []).length);

    expect(jwtVp).toBeTruthy();

    expect(jwtVp.split(".")).toHaveLength(3);

    const header = decodeJwtHeader(jwtVp);

    console.log("\nHeader");
    console.log(header);

    //
    // Decode Payload
    //
    const payload = decodeJwtPayload(jwtVp);

    console.log("\nPayload DID");
    console.log(payload.iss);

    //
    // Ambil Public Key Holder
    //
    const holderPublicKey =
      await getVpHolderPublicKey(jwtVp);

    //
    // Verifikasi VP Asli
    //
    const original =
      await verifyVp(jwtVp, holderPublicKey);

    expect(original.payload.iss)
      .toBe(payload.iss);

    console.log("\nJWT VP Asli VALID");

    //
    // Generate Private Key Penyerang
    //
    const {
      privateKey: attackerPrivateKey,
    } = await generateKeyPair("EdDSA");

    console.log("Attacker Key Generated");

    //
    // Buat VP Baru
    //
    const fakeVP =
      await new SignJWT(payload)

      .setProtectedHeader({

        alg: header.alg!,

        typ: header.typ!,

        kid: header.kid!

      })

      .sign(attackerPrivateKey);

    console.log("Fake VP Generated");

    //
    // Harus Gagal
    //
    await expect(

      verifyVp(
        fakeVP,
        holderPublicKey
      )

    ).rejects.toThrow();

  });

});