import { generateKeyPair, exportJWK } from "jose";

describe("Performance Test - T1", () => {

    it("Ed25519 Key Pair Generation", async () => {

        const ITERATION = 10;

        let success = 0;
        let failed = 0;

        console.log("\n================================");
        console.log("T1 - Ed25519 Key Pair Generation");
        console.log("================================");

        for (let i = 1; i <= ITERATION; i++) {

            try {

                const start = performance.now();

                const { publicKey, privateKey } =
                    await generateKeyPair("EdDSA");

                const end = performance.now();

                const publicJwk = await exportJWK(publicKey);
                const privateJwk = await exportJWK(privateKey);

                if (!publicJwk.x) throw new Error("Public key gagal");
                if (!privateJwk.d) throw new Error("Private key gagal");

                success++;

                console.log(
                    `[${i}] SUCCESS | ${(end-start).toFixed(3)} ms`
                );

            } catch (err:any) {

                failed++;

                console.log(
                    `[${i}] FAILED : ${err.message}`
                );

            }

        }

        const rate =
            success / ITERATION * 100;

        console.table({
            Iteration: ITERATION,
            Success: success,
            Failed: failed,
            SuccessRate: rate.toFixed(2) + "%"
        });

        expect(success).toBe(ITERATION);

    });

});