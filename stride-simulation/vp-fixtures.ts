import fs from 'fs';
import path from 'path';
import axios from 'axios';
import { decodeJwt, decodeProtectedHeader, importJWK, jwtVerify, type JWK } from 'jose';

const VP_TOKEN_PATH = path.resolve(process.cwd(), '..', 'verifier', 'vp_token.txt');
const DEFAULT_JWT_VC =
  'eyJraWQiOiJkaWQ6d2ViOmlzc3Vlci5pZGVudGlhLm15LmlkI2tleS0xIiwiYWxnIjoiRWREU0EiLCJ0eXAiOiJKV1QifQ.eyJ2YyI6eyJAY29udGV4dCI6WyJodHRwczovL3d3dy53My5vcmcvMjAxOC9jcmVkZW50aWFscy92MSJdLCJ0eXBlIjpbIlZlcmlmaWFibGVDcmVkZW50aWFsIiwiS2FydHVCUEpTS2VzZWhhdGFuIl0sImlkIjoidXJuOnV1aWQ6MDVhNDkzMTktY2MzNy00MThjLWIxNzEtZWY0NWE2ZDg5Mjk5IiwiaXNzdWVyIjoiZGlkOndlYjppc3N1ZXIuaWRlbnRpYS5teS5pZCIsImlzc3VhbmNlRGF0ZSI6IjIwMjYtMDctMDVUMDM6Mzk6MzIuMDAwWiIsImNyZWRlbnRpYWxTdWJqZWN0Ijp7ImlkIjoiZGlkOmp3azpleUpyZEhraU9pSlBTMUFpTENKamNuWWlPaUpGWkRJMU5URTVJaXdpZUNJNklucGZlVkp0U0ZSNVJGRm9lRTFaV0VKQlMxOURXRU5LY2xCWk9EazNkall5VVZkR2VuaElhekZETW1zaWZRIiwiY3JlZGVudGlhbE5hbWUiOiJLYXJ0dSBCUEpTIEtlc2VoYXRhbiIsImhvbGRlck5hbWUiOiJEZXZhIEZpbmFuZGEgU2FwdXRyYSIsIm5payI6IjMyMDEwMTAyMDMwNTAwMDEiLCJub0JQSlMiOiIzMjAxMDEwMjAzMDUwIiwidGFuZ2dhbExhaGlyIjoiMjAwNS0wMi0wMyJ9fSwic3ViIjoiZGlkOmp3azpleUpyZEhraU9pSlBTMUFpTENKamNuWWlPaUpGWkRJMU5URTVJaXdpZUNJNklucGZlVkp0U0ZSNVJGRm9lRTFaV0VKQlMxOURXRU5LY2xCWk9EazNkall5VVZkR2VuaElhekZETW1zaWZRIiwibmJmIjoxNzgzMjIyNzcyLCJqdGkiOiJ1cm46dXVpZDowNWE0OTMxOS1jYzM3LTQxOGMtYjE3MS1lZjQ1YTZkODkyOTkiLCJpc3MiOiJkaWQ6d2ViOmlzc3Vlci5pZGVudGlhLm15LmlkIn0.MCpfVugLALCaRPdBp2IBxF5LSnwy6MxHGKrxFl_H7SgaUP05u4C9vHcE73MsaO-KFQY7ZkRC6jD9GCw4kaPWAg';
const DEFAULT_JWT_VP =
  'eyJhbGciOiJFZERTQSIsInR5cCI6InZwK2p3dCIsImtpZCI6ImRpZDpqd2s6ZXlKcmRIa2lPaUpQUzFBaUxDSmpjbllpT2lKRlpESTFOVEU1SWl3aWVDSTZJbnBmZVZKdFNGUjVSRkZvZUUxWldFSkJTMTlEV0VOS2NsQlpPRGszZGpZeVVWZEdlbmhJYXpGRE1tc2lmUSMwIn0.eyJpc3MiOiJkaWQ6andrOmV5SnJkSGtpT2lKUFMxQWlMQ0pqY25ZaU9pSkZaREkxTlRFNUlpd2llQ0k2SW5wZmVWSnRTRlI1UkZGb2VFMVpXRUpCUzE5RFdFTktjbEJaT0RrM2RqWXlVVmRHZW5oSWF6RkRNbXNpZlEiLCJzdWIiOiJkaWQ6andrOmV5SnJkSGtpT2lKUFMxQWlMQ0pqY25ZaU9pSkZaREkxTlRFNUlpd2llQ0k2SW5wZmVWSnRTRlI1UkZGb2VFMVpXRUpCUzE5RFdFTktjbEJaT0RrM2RqWXlVVmRHZW5oSWF6RkRNbXNpZlEiLCJhdWQiOiJkaWQ6d2ViOnZlcmlmaWVyLmlkZW50aWEubXkuaWQiLCJub25jZSI6IlowWWJFQjVZOHRhUVA3R0VOOWVTNWh5dGdLM00zOXhuNHUwell1MjFka2MiLCJpYXQiOjE3ODMyMjkyNTIsIm5iZiI6MTc4MzIyOTI1MiwiZXhwIjoxNzgzMjI5MzcyLCJqdGkiOiJ1cm46dXVpZDo1OGVhOGFkNy02MDg3LTRhM2UtOGU3YS1hY2IwYWEwZmU5YjAiLCJ2cCI6eyJpZCI6InVybjp1dWlkOjU4ZWE4YWQ3LTYwODctNGEzZS04ZTdhLWFjYjBhYTBmZTliMCIsIkBjb250ZXh0IjpbImh0dHBzOi8vd3d3LnczLm9yZy8yMDE4L2NyZWRlbnRpYWxzL3YxIl0sInR5cGUiOlsiVmVyaWZpYWJsZVByZXNlbnRhdGlvbiJdLCJob2xkZXIiOiJkaWQ6andrOmV5SnJkSGtpT2lKUFMxQWlMQ0pqY25ZaU9pSkZaREkxTlRFNUlpd2llQ0k2SW5wZmVWSnRTRlI1UkZGb2VFMVpXRUpCUzE5RFdFTktjbEJaT0RrM2RqWXlVVmRHZW5oSWF6RkRNbXNpZlEiLCJ2ZXJpZmlhYmxlQ3JlZGVudGlhbCI6WyJleUpyYVdRaU9pSmthV1E2ZDJWaU9tbHpjM1ZsY2k1cFpHVnVkR2xoTG0xNUxtbGtJMnRsZVMweElpd2lZV3huSWpvaVJXUkVVMEVpTENKMGVYQWlPaUpLVjFRaWZRLmV5SjJZeUk2ZXlKQVkyOXVkR1Y0ZENJNld5Sm9kSFJ3Y3pvdkwzZDNkeTUzTXk1dmNtY3ZNakF4T0M5amNtVmtaVzUwYVdGc2N5OTJNU0pkTENKMGVYQmxJanBiSWxabGNtbG1hV0ZpYkdWRGNtVmtaVzUwYVdGc0lpd2lTMkZ5ZEhWQ1VFcFRTMlZ6WldoaGRHRnVJbDBzSW1sa0lqb2lkWEp1T25WMWFXUTZNRFZoTkRrek1Ua3RZMk16TnkwME1UaGpMV0l4TnpFdFpXWTBOV0UyWkRnNU1qazVJaXdpYVhOemRXVnlJam9pWkdsa09uZGxZanBwYzNOMVpYSXVhV1JsYm5ScFlTNXRlUzVwWkNJc0ltbHpjM1ZoYm1ObFJHRjBaU0k2SWpJd01qWXRNRGN0TURWVU1ETTZNems2TXpJdU1EQXdXaUlzSW1OeVpXUmxiblJwWVd4VGRXSnFaV04wSWpwN0ltbGtJam9pWkdsa09tcDNhenBsZVVweVpFaHJhVTlwU2xCVE1VRnBURU5LYW1OdVdXbFBhVXBHV2tSSk1VNVVSVFZKYVhkcFpVTkpOa2x1Y0dabFZrcDBVMFpTTlZKR1JtOWxSVEZhVjBWS1FsTXhPVVJYUlU1TFkyeENXazlFYXpOa2FsbDVWVlprUjJWdWFFbGhla1pFVFcxemFXWlJJaXdpWTNKbFpHVnVkR2xoYkU1aGJXVWlPaUpMWVhKMGRTQkNVRXBUSUV0bGMyVm9ZWFJoYmlJc0ltaHZiR1JsY2s1aGJXVWlPaUpFWlhaaElFWnBibUZ1WkdFZ1UyRndkWFJ5WVNJc0ltNXBheUk2SWpNeU1ERXdNVEF5TURNd05UQXdNREVpTENKdWIwSlFTbE1pT2lJek1qQXhNREV3TWpBek1EVXdJaXdpZEdGdVoyZGhiRXhoYUdseUlqb2lNakF3TlMwd01pMHdNeUo5ZlN3aWMzVmlJam9pWkdsa09tcDNhenBsZVVweVpFaHJhVTlwU2xCVE1VRnBURU5LYW1OdVdXbFBhVXBHV2tSSk1VNVVSVFZKYVhkcFpVTkpOa2x1Y0dabFZrcDBVMFpTTlZKR1JtOWxSVEZhVjBWS1FsTXhPVVJYUlU1TFkyeENXazlFYXpOa2FsbDVWVlprUjJWdWFFbGhla1pFVFcxemFXWlJJaXdpYm1KbUlqb3hOemd6TWpJeU56Y3lMQ0pxZEdraU9pSjFjbTQ2ZFhWcFpEb3dOV0UwT1RNeE9TMWpZek0zTFRReE9HTXRZakUzTVMxbFpqUTFZVFprT0RreU9Ua2lMQ0pwYzNNaU9pSmthV1E2ZDJWaU9tbHpjM1ZsY2k1cFpHVnVkR2xoTG0xNUxtbGtJbjAuTUNwZlZ1Z0xBTENhUlBkQnAySUJ4RjVMU253eTZNeEhHS3J4RmxfSDdTZ2FVUDA1dTRDOXZIY0U3M01zYU8tS0ZRWTdaa1JDNmpEOUdDdzRrYVBXQWciXX19.zuvm4M3BbdiKg3lxcNhD4weHykCpAspWBLkrfBv-G3f0Y-FJGjGABHX8UXpKRrBGdDfH2GEnYmgzkN4Mp-ZMDQ';
const DEFAULT_HOLDER_DID =
  'did:jwk:eyJrdHkiOiJPS1AiLCJjcnYiOiJFZDI1NTE5IiwieCI6InpfeVJtSFR5RFFoeE1ZWEJBS19DWENKclBZODk3djYyUVdGenhIazFDMmsifQ';
const DEFAULT_HOLDER_PUBLIC_KEY_MULTIBASE = 'z_yRmHTyDQhxMYXBAK_CXCJrPY897v62QWFzxHk1C2k';
const DEFAULT_ISSUER_PUBLIC_KEY_MULTIBASE = 'z6MkhyKruKxbzoUegAD4s7x8hzwbahsKa2q5rwAtK9CZ86dU';
const DEFAULT_ISSUER_DID = 'did:web:issuer.identia.my.id';

export function loadVpToken(): string {
  const envVp = process.env.STRIDE_JWT_VP?.trim();
  if (envVp) {
    return envVp.replace(/^JWT VP\s*=\s*/i, '').trim();
  }

  if (!fs.existsSync(VP_TOKEN_PATH)) {
    return DEFAULT_JWT_VP;
  }

  return fs.readFileSync(VP_TOKEN_PATH, 'utf8').trim().replace(/^JWT VP\s*=\s*/i, '').trim();
}

export function loadVcToken(): string {
  return process.env.STRIDE_JWT_VC?.trim() || DEFAULT_JWT_VC;
}

export function decodeJwtPayload(token: string): Record<string, any> {
  return decodeJwt(token) as Record<string, any>;
}

export function decodeJwtHeader(token: string): ReturnType<typeof decodeProtectedHeader> {
  return decodeProtectedHeader(token);
}

export function didJwkToJwk(didJwk: string): JWK {
  const prefix = 'did:jwk:';
  if (!didJwk.startsWith(prefix)) {
    throw new Error(`DID bukan did:jwk: ${didJwk}`);
  }

  const encodedJwk = didJwk.slice(prefix.length);
  const jwkJson = Buffer.from(encodedJwk, 'base64url').toString('utf8');
  return JSON.parse(jwkJson) as JWK;
}

export function base58Decode(input: string): Uint8Array {
  const alphabet = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
  let value = 0n;

  for (const char of input) {
    const index = alphabet.indexOf(char);
    if (index === -1) {
      throw new Error(`Karakter base58 tidak valid: ${char}`);
    }
    value = value * 58n + BigInt(index);
  }

  const decoded: number[] = [];
  while (value > 0n) {
    decoded.unshift(Number(value % 256n));
    value /= 256n;
  }

  for (const char of input) {
    if (char !== '1') {
      break;
    }
    decoded.unshift(0);
  }

  return Uint8Array.from(decoded);
}

export function multibaseEd25519ToRawPublicKey(multibase: string): Uint8Array {
  if (!multibase.startsWith('z')) {
    throw new Error(`Unsupported multibase prefix: ${multibase}`);
  }

  const decoded = base58Decode(multibase.slice(1));
  if (decoded.length > 2 && decoded[0] === 0xed && decoded[1] === 0x01) {
    return decoded.slice(2);
  }

  return decoded;
}

export async function importEd25519PublicKeyFromMultibase(multibase: string): Promise<CryptoKey> {
  const rawKey = multibaseEd25519ToRawPublicKey(multibase);
  const rawKeyBuffer = rawKey.buffer.slice(rawKey.byteOffset, rawKey.byteOffset + rawKey.byteLength) as ArrayBuffer;
  return crypto.subtle.importKey('raw', rawKeyBuffer, { name: 'Ed25519' }, true, ['verify']);
}

export function didWebToDidJsonUrl(didWeb: string): string {
  const prefix = 'did:web:';
  if (!didWeb.startsWith(prefix)) {
    throw new Error(`DID bukan did:web: ${didWeb}`);
  }

  const didWebValue = didWeb.slice(prefix.length);
  return `https://${didWebValue.replace(/:/g, '/')}/.well-known/did.json`;
}

export async function getVpHolderPublicKey(jwtVp: string): Promise<any> {
  const payload = decodeJwtPayload(jwtVp);
  const holderDid = payload.iss?.toString();

  if (holderDid?.startsWith('did:jwk:')) {
    return importJWK(didJwkToJwk(holderDid), 'EdDSA');
  }

  return importJWK(didJwkToJwk(DEFAULT_HOLDER_DID), 'EdDSA');
}

export function getVpVerificationDate(jwtVp: string): Date {
  const payload = decodeJwtPayload(jwtVp);
  const issuedAt = typeof payload.iat === 'number' ? payload.iat : Math.floor(Date.now() / 1000);
  return new Date((issuedAt + 1) * 1000);
}

export async function verifyVp(jwtVp: string, keyLike: any, audience?: string) {
  const payload = decodeJwtPayload(jwtVp);
  const expectedAudience = audience ?? payload.aud?.toString();

  return jwtVerify(jwtVp, keyLike, {
    algorithms: ['EdDSA'],
    audience: expectedAudience,
    currentDate: getVpVerificationDate(jwtVp),
  });
}

export function tamperJwtPayload(token: string, mutator: (payload: Record<string, any>) => void): string {
  const parts = token.split('.');
  if (parts.length !== 3) {
    throw new Error('Format JWT tidak valid');
  }

  const payload = JSON.parse(Buffer.from(parts[1], 'base64url').toString('utf8')) as Record<string, any>;
  mutator(payload);

  const tamperedPayload = Buffer.from(JSON.stringify(payload)).toString('base64url');
  return `${parts[0]}.${tamperedPayload}.${parts[2]}`;
}

export function getNestedVcToken(jwtVp: string): string {
  const payload = decodeJwtPayload(jwtVp);
  const credential = payload.vp?.verifiableCredential?.[0];

  if (typeof credential !== 'string') {
    return loadVcToken();
  }

  return credential;
}

export async function getNestedVcIssuerPublicKey(jwtVp: string): Promise<any> {
  const nestedVcToken = getNestedVcToken(jwtVp);
  const nestedVcPayload = decodeJwtPayload(nestedVcToken);
  const issuerDid = nestedVcPayload.iss?.toString();

  if (!issuerDid) {
    throw new Error('Nested JWT VC tidak memiliki iss');
  }

  if (issuerDid.startsWith('did:jwk:')) {
    return importJWK(didJwkToJwk(issuerDid), 'EdDSA');
  }

  if (issuerDid === DEFAULT_ISSUER_DID) {
    return importEd25519PublicKeyFromMultibase(DEFAULT_ISSUER_PUBLIC_KEY_MULTIBASE);
  }

  if (issuerDid.startsWith('did:web:')) {
    const didJsonUrl = didWebToDidJsonUrl(issuerDid);
    try {
      const response = await axios.get(didJsonUrl, { timeout: 3000 });
      const verificationMethod = response.data?.verificationMethod?.[0];
      const publicKeyJwk = verificationMethod?.publicKeyJwk;

      if (publicKeyJwk) {
        return importJWK(publicKeyJwk, 'EdDSA');
      }

      const publicKeyMultibase = verificationMethod?.publicKeyMultibase;
      if (publicKeyMultibase) {
        return importEd25519PublicKeyFromMultibase(publicKeyMultibase);
      }
    } catch (error) {
      if (issuerDid === DEFAULT_ISSUER_DID) {
        return importEd25519PublicKeyFromMultibase(DEFAULT_ISSUER_PUBLIC_KEY_MULTIBASE);
      }

      throw error;
    }
  }

  throw new Error(`Unsupported issuer DID for nested JWT VC: ${issuerDid}`);
}

export async function verifyJwtAtIssuedTime(
  token: string,
  keyLike: any,
  audience?: string,
) {
  const payload = decodeJwtPayload(token);
  const issuedAt = typeof payload.iat === 'number' ? payload.iat : Math.floor(Date.now() / 1000);
  const options: Record<string, any> = {
    algorithms: ['EdDSA'],
    currentDate: new Date((issuedAt + 1) * 1000),
  };

  if (audience) {
    options.audience = audience;
  }

  return jwtVerify(token, keyLike, options);
}

export function getNestedVcIssuerDid(jwtVp: string): string {
  const nestedVcToken = getNestedVcToken(jwtVp);
  const nestedVcPayload = decodeJwtPayload(nestedVcToken);
  const issuerDid = nestedVcPayload.iss?.toString();

  if (!issuerDid) {
    throw new Error('Nested JWT VC tidak memiliki iss');
  }

  return issuerDid;
}
