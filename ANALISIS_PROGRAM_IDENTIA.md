# 📱 ANALISIS PROGRAM IDENTIA - UNTUK ACTIVITY & SEQUENCE DIAGRAM

## **📖 OVERVIEW PROGRAM**

**IDentia** adalah aplikasi mobile Flutter untuk manajemen **Dompet Identitas Digital** yang mendukung:
- ✅ **OID4VCI** (OpenID for Verifiable Credential Issuance) - Menerima kredensial
- ✅ **OID4VP** (OpenID for Verifiable Presentation) - Presentasi kredensial
- ✅ **JWT VC & SD-JWT** - Format kredensial digital
- ✅ **Deep Linking** - Integrasi dengan sistem eksternal
- ✅ **Biometrik & Local Auth** - Keamanan lokal

**Nama Aplikasi:** IDentia
**Deskripsi:** Dompet Identitas Digital untuk layanan kesehatan
**Target SDK:** Flutter 3.0.0+

---

## **🏗️ STRUKTUR ARSITEKTUR**

### **1. LAYER PROVIDERS (State Management)**

```
providers/
├── AuthProvider          → Auth & login history (user + password)
├── WalletProvider        → Kelola kredensial & proses issuance/presentation
└── AppSettingsProvider   → Pengaturan aplikasi global
```

#### **AuthProvider**
- Fungsi: Manajemen autentikasi pengguna
- Key Classes:
  - `LoginHistoryItem`: Tracking login dengan timestamp, success status, method, device
  - `_StoredAccount`: Menyimpan user + password terenkripsi
- Fitur:
  - Simpan/load akun
  - History login
  - Validasi password

#### **WalletProvider**
- Fungsi: Kelola seluruh proses credential lifecycle
- Key Attributes:
  - `_credentials`: List CredentialModel
  - `_activeUserScope`: User context
  - `_isLoading`, `_isSyncingStatuses`: Loading states
  
- **Issuance Status Enum:**
  ```
  idle → parsingOffer → fetchingMetadata → authorizing 
  → exchangingToken → buildingProof → requestingCredential 
  → saved / error
  ```

- **Identia Flow Status Enum:**
  ```
  idle → gettingHolderDid → requestingCredential 
  → receivingCredential → validatingCredential → saving 
  → done / error
  ```

- **Presentation Status Enum:**
  ```
  idle → parsingRequest → matchingCredentials → buildingVP 
  → submitting → done / error
  ```

- **Fitur Polling:**
  - `_statusRealtimeTimer`: Interval 20 detik
  - Update status kredensial secara berkala

#### **AppSettingsProvider**
- Fungsi: Kelola pengaturan global aplikasi

---

### **2. LAYER SERVICES (Business Logic)**

```
services/
├── oid4vci_service.dart           → Credential issuance flow
├── oid4vp_service.dart            → Presentation flow  
├── oid4vp_start_service.dart      → Start presentation session
├── crypto_service.dart            → Enkripsi/dekripsi
├── secure_storage_service.dart    → Simpan key & data sensitif
├── jwt_verifier_service.dart      → Verifikasi JWT signature
├── sd_jwt_service.dart            → Parse SD-JWT
├── identia_issuance_service.dart  → REST-based issuance
├── credential_status_service.dart → Check status kredensial
├── map_service.dart               → Geocoding
└── app_links.dart                 → Deep linking handler
```

#### **OID4VCIService**
- **Tujuan:** Handle keseluruhan OID4VCI issuance flow
- **Key Methods:**
  - `_loadValidatedHolderIdentity()`: Load DID + keypair dari storage
  - `_loadValidatedIdentityOrRegenerate()`: Load atau regenerate DID jika needed
  - `_parseCredentialOffer()`: Parse credential offer dari deep link
  - `fetchIssuerMetadata()`: GET metadata dari issuer
  - `authorize()`: Redirect ke issuer untuk auth (browser)
  - `exchangeAuthorizationCode()`: POST code untuk dapatkan access token
  - `_buildProof()`: Generate JWT proof dengan Holder DID
  - `requestCredential()`: POST request credential dengan proof

- **Holder DID Management:**
  - Format: DID-jwk dari Ed25519 public key
  - Generated: Otomatis saat first issuance
  - Storage: SecureStorageService (encrypted)
  - Validation: Diverifikasi saat load

- **HTTP Timeout:** 30 detik
- **Default Format:** `jwt_vc_json`

#### **OID4VPService**
- **Tujuan:** Handle keseluruhan OID4VP presentation flow
- **Key Methods:**
  - `parseRequest()`: Parse QR data (openid4vp://, haip://, mdoc-openid4vp://)
  - `_parseOID4VPUrl()`: Parse URL dengan query params
  - `_parseFromJson()`: Parse dari JSON
  - `_fetchRequestUri()`: Fetch request object dari URI
  - `matchCredentialsToRequest()`: Match credentials dengan requirements
  - `buildPresentation()`: Build VP (Verifiable Presentation)
  - `submitPresentation()`: POST VP ke verifier

- **Request Resolution:**
  - Fetch presentation_definition jika ada URI
  - Resolve format requirements (jwt_vc, jwt_vc_json, vc+sd-jwt)

- **HTTP Timeout:** 30 detik

#### **OID4VPStartService**
- Fungsi: Initialize presentation session
- Digunakan untuk memulai flow presentation secara programmatic

#### **CryptoService**
- Fungsi: Enkripsi/dekripsi data
- Digunakan untuk melindungi data sensitif

#### **SecureStorageService**
- **Storage untuk:**
  - Holder DID
  - Holder Private Key (Ed25519)
  - Holder Public Key
- **Key Methods:**
  - `loadHolderDid(userId)`
  - `loadHolderPrivateKey(userId)`
  - `loadHolderPublicKey(userId)`
  - `assertUniqueHolderDidForUser()` - Prevent duplicate DIDs
- **Platform:** flutter_secure_storage

#### **JwtVerifierService**
- Fungsi: Verifikasi signature JWT
- Validate issuer credentials
- Extract claims dari JWT

#### **SDJWTService**
- Fungsi: Parse Selective Disclosure JWT
- Extract disclosed claims
- Validate SD-JWT structure

#### **IdentiaIssuanceService**
- Fungsi: REST-based credential issuance (alternatif OID4VCI)
- Untuk sistem yang bukan OID4VCI compliant

#### **CredentialStatusService**
- **Fungsi:** Check status kredensial apakah masih valid
- **Polling:** Dijalankan oleh WalletProvider setiap 20 detik
- **Update Fields:**
  - `statusActive`
  - `statusCheckedAt`
  - `syncedStatus`

#### **MapService**
- Fungsi: Geocoding (Location services)

---

### **3. LAYER MODELS (Data Structures)**

```
models/
├── CredentialModel              → Data struktur kredensial
├── CredentialOfferModel         → Penawaran issuance
├── PresentationModels           → PresentationRequest, Response, VP
├── IssuerMetadataModel          → Metadata issuer
├── DidDocumentModel             → DID structure
├── UserModel                    → Data user/holder
└── VerificationResultModel      → Hasil verifikasi
```

#### **CredentialModel**
```dart
{
  id: String,
  type: String,                      // e.g., "HealthInsurance"
  issuer: String,                    // Issuer name
  holderName: String,
  documentNumber: String,
  issuedDate: DateTime,
  expiryDate: DateTime?,
  isVerified: bool,
  additionalData: Map<String, dynamic>?,
  signature: String?,
  publicKey: String?,
  
  // OID4VCI / JWT fields
  rawJwt: String?,                   // Raw JWT VC atau SD-JWT string
  format: String?,                   // 'jwt_vc_json' atau 'vc+sd-jwt'
  issuerDid: String?,                // Resolved issuer DID
  credentialStatusUrl: String?,
  syncedStatus: String?,
  statusActive: bool?,
  statusCheckedAt: DateTime?
}
```

#### **CredentialOfferModel**
- Fields:
  - `credentialIssuer`: URL issuer
  - `credentials`: List format/type yang ditawarkan
  - `grants`: Authorization grants (authorization_code, urn:ietf:params:oauth:grant-type:pre-authorized_code)

#### **PresentationModels**
- `PresentationRequest`: Request dari verifier
  - `presentationDefinition`: Requirement apa saja
  - `clientId`, `responseUri`, `responseMode`
  - `state`, `nonce`

- `PresentationResponse`: Response dari holder
  - `vpToken`: VP token
  - `presentationSubmission`: Mapping credentials ke definition

- `VP (Verifiable Presentation)`: Struktur presentasi
  - `verifiableCredential[]`: Array of credentials
  - `proof`: Proof JWT

#### **IssuerMetadataModel**
- Fields:
  - `authorizationServerUrl`
  - `tokenEndpoint`
  - `credentialEndpoint`
  - `credentialConfigurationsSupported`: Format support

#### **DidDocumentModel**
- Struktur DID Document
- Public key references
- Service endpoints

#### **UserModel**
```dart
{
  id: String,
  name: String,
  email: String?,
  phone: String?,
  createdAt: DateTime,
  lastLogin: DateTime?
}
```

#### **VerificationResultModel**
- Result dari verification process
- Status: verified / failed
- Error messages jika ada

---

### **4. LAYER SCREENS (UI)**

```
screens/
├── splash_screen.dart                          
│   └── Loading initial + init DID
│
├── auth/
│   └── (Login & Register screens)
│
├── issuance/
│   ├── issuance_flow_screen.dart              
│   │   └── Handle deep link openid-credential-offer://
│   │       Coordinate seluruh OID4VCI flow
│   │
│   ├── identia_login_screen.dart              
│   │   └── Login untuk issuance REST API
│   │
│   └── identia_issuance_screen.dart           
│       └── Form issuance untuk REST-based flow
│
├── presentation/
│   ├── presentation_consent_screen.dart       
│   │   └── Show credentials matched + user confirmation
│   │
│   ├── oid4vp_start_screen.dart               
│   │   └── Start presentation flow
│   │
│   └── presentation_result_screen.dart        
│       └── Show result (success/error)
│
├── dashboard/
│   └── List all credentials dengan status
│
├── verification/
│   └── Verify credential manually
│
└── settings/
    └── App settings & account management
```

#### **SplashScreen**
- Fungsi: Initial loading
- Inisialisasi: Localization, DID loading, Deep link setup
- Duration: Show splash selama aset loading

#### **IssuanceFlowScreen**
- **Input:** deepLink (openid-credential-offer://)
- **Proses:**
  1. Parse credential offer
  2. Fetch issuer metadata
  3. Determine auth method (authorization_code / pre-authorized_code)
  4. If authorization_code: launch browser
  5. Listen untuk redirect callback
  6. Exchange code for token
  7. Build & submit proof
  8. Receive & validate credential
  9. Save ke wallet
- **State Updates:** Via WalletProvider.issuanceStatus

#### **PresentationConsentScreen**
- **Input:** qrData (openid4vp://)
- **Proses:**
  1. Parse presentation request
  2. Match dengan stored credentials
  3. Show credentials to user
  4. User select credentials untuk share
  5. Get user consent
  6. Call OID4VPService.buildPresentation()
  7. Submit VP
- **State Updates:** Via WalletProvider.presentationStatus

#### **PresentationResultScreen**
- Show: Success dengan submission ID atau Error message

---

## **🔄 MAIN FLOWS**

### **FLOW 1: CREDENTIAL ISSUANCE (OID4VCI)**

```
┌─────────────────────────────────────────────────────────────┐
│ USER SCANS QR CODE or RECEIVES DEEP LINK                   │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ main.dart → _IDentiaApp._handleDeepLink()                  │
│ URL: openid-credential-offer://...                         │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ Navigate → IssuanceFlowScreen(deepLink: link)              │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ IssuanceFlowScreen._parseOffer()                            │
│ Status: parsingOffer                                         │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ OID4VCIService._parseCredentialOffer()                     │
│ Extract: credentialIssuer, credentials[], grants           │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ WalletProvider.issuanceStatus = IssuanceStatus.fetchingMeta │
│ OID4VCIService.fetchIssuerMetadata()                       │
│ GET /metadata/openid-credential-issuer                     │
└─────────────────────────────────────────────────────────────┘
                           ↓
                    ┌──────┴──────┐
                    ↓             ↓
        ┌─────────────────┐  ┌──────────────────┐
        │ Pre-authorized  │  │ Authorization    │
        │ Code Grant      │  │ Code Grant       │
        └─────────────────┘  └──────────────────┘
                    ↓             ↓
                    │    ┌────────┘
                    ↓    ↓
        ┌─────────────────────────────┐
        │ Launch Browser Auth         │
        │ POST /authorize             │
        │ Status: authorizing         │
        └─────────────────────────────┘
                      ↓
        ┌─────────────────────────────┐
        │ User Login to Issuer        │
        │ Grant Consent               │
        └─────────────────────────────┘
                      ↓
        ┌─────────────────────────────┐
        │ Redirect: identia://callback│
        │ + authorization_code        │
        └─────────────────────────────┘
                      ↓
        ┌─────────────────────────────┐
        │ AppLinks.uriLinkStream      │
        │ Capture callback URI        │
        └─────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────────────────┐
│ WalletProvider.issuanceStatus = IssuanceStatus.exchanging   │
│ OID4VCIService.exchangeAuthorizationCode()                 │
│ POST /token {code, client_id, redirect_uri}                │
│ ← access_token, c_nonce                                    │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ Load or Generate Holder DID (Ed25519)                       │
│ SecureStorageService.loadHolderDid(userId)                 │
│ Or: generateNewHolderDid() if first time                   │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ WalletProvider.issuanceStatus = IssuanceStatus.buildingProof│
│ OID4VCIService._buildProof()                               │
│ Create JWT with:                                            │
│   Header: {alg: "EdDSA", kid: holderDid#key-1}             │
│   Payload: {iss: holderDid, aud: issuer, c_nonce}          │
│   Signature: Sign with holder private key                  │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ WalletProvider.issuanceStatus = IssuanceStatus.requesting   │
│ OID4VCIService.requestCredential()                         │
│ POST /credential {credential_format, proof_jwt}            │
│ ← credential (JWT VC or SD-JWT)                            │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ Validate Credential:                                        │
│ JwtVerifierService.verify()                                │
│ Check: issuer signature, expiry, format                    │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ WalletProvider.issuanceStatus = IssuanceStatus.saved        │
│ WalletProvider.saveCredential(credentialModel)             │
│ SecureStorageService.saveCredential()                      │
│ SharedPreferences.save()                                    │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ UI: Show Success + Navigate to Dashboard                    │
│ Display: Issuer, Credential Type, Issue Date               │
└─────────────────────────────────────────────────────────────┘
```

**Status Progression:**
```
IDLE 
  ↓
PARSING_OFFER 
  ↓
FETCHING_METADATA 
  ↓
AUTHORIZING (if auth code flow)
  ↓
EXCHANGING_TOKEN 
  ↓
BUILDING_PROOF 
  ↓
REQUESTING_CREDENTIAL 
  ↓
SAVED / ERROR
```

---

### **FLOW 2: CREDENTIAL PRESENTATION (OID4VP)**

```
┌─────────────────────────────────────────────────────────────┐
│ USER SCANS QR CODE from VERIFIER                            │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ main.dart → _IDentiaApp._handleDeepLink()                  │
│ URL: openid4vp://, haip://, atau mdoc-openid4vp://         │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ Navigate → PresentationConsentScreen(qrData: link)         │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ WalletProvider.presentationStatus = PresentationStatus.idle │
│ PresentationConsentScreen.initState()                      │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ WalletProvider.presentationStatus = PARSING_REQUEST         │
│ OID4VPService.parseRequest(qrData)                         │
│ Check: openid4vp://, haip://, mdoc-openid4vp:// scheme     │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ Parse QR URL components:                                    │
│   - client_id                                               │
│   - response_type, response_mode                            │
│   - request_uri atau inline request_object                 │
│   - presentation_definition                                │
│   - nonce, state                                            │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ If request_uri present:                                     │
│   OID4VPService._fetchRequestUri(request_uri)              │
│   GET /request_object                                       │
│   ← PresentationRequest (complete)                          │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ If presentation_definition_uri present:                     │
│   Fetch presentation definition                             │
│   Parse: input_descriptors[], required claims              │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ WalletProvider.presentationStatus = MATCHING_CREDENTIALS    │
│ OID4VPService.matchCredentialsToRequest()                  │
│ For each input_descriptor:                                  │
│   - Check path expressions                                  │
│   - Match stored credentials                                │
│   - Extract matching credentials                            │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ UI: PresentationConsentScreen                              │
│ Show: Credentials matched + claims required                │
│ Show: Verifier details + request purpose                   │
└─────────────────────────────────────────────────────────────┘
                           ↓
         ┌────────────────┬─────────────────┐
         ↓                ↓                 ↓
    ┌─────────┐    ┌──────────┐    ┌──────────────┐
    │ REJECT  │    │ CONFIRM  │    │ TIMEOUT      │
    └─────────┘    └──────────┘    └──────────────┘
         ↓                ↓                 ↓
         └────────────────┼─────────────────┘
                          ↓
              ┌──────────────────────────┐
              │ User SELECT credentials  │
              │ User CONFIRM presentation│
              └──────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ WalletProvider.presentationStatus = BUILDING_VP             │
│ OID4VPService.buildPresentation()                          │
│ Create VP with:                                             │
│   - verifiableCredential[]: Selected credentials            │
│   - holder: Holder DID                                      │
│   - proof: JWT signed by holder                             │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ Create PresentationSubmission:                              │
│ Map credentials ke input_descriptors                        │
│ Descriptor map: jwt_vc, jwt_vc_json, vc+sd-jwt             │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ WalletProvider.presentationStatus = SUBMITTING              │
│ OID4VPService.submitPresentation()                         │
│ POST /direct_post {vp_token, presentation_submission}      │
│ ← {status: "ok"} atau error                                │
└─────────────────────────────────────────────────────────────┘
                           ↓
         ┌───────────────┬──────────────┐
         ↓               ↓              ↓
    ┌────────┐     ┌─────────┐    ┌────────┐
    │ SUCCESS│     │ FAILURE │    │ TIMEOUT│
    └────────┘     └─────────┘    └────────┘
         ↓               ↓              ↓
         └───────────────┼──────────────┘
                         ↓
┌─────────────────────────────────────────────────────────────┐
│ WalletProvider.presentationStatus = DONE / ERROR            │
│ Navigate → PresentationResultScreen                         │
│ Show: Result message, submission ID (if success)            │
└─────────────────────────────────────────────────────────────┘
```

**Status Progression:**
```
IDLE 
  ↓
PARSING_REQUEST 
  ↓
MATCHING_CREDENTIALS 
  ↓
BUILDING_VP 
  ↓
SUBMITTING 
  ↓
DONE / ERROR
```

---

### **FLOW 3: AUTHENTICATION**

```
┌─────────────────────────────────────────────────────────────┐
│ User Navigate to Login Screen                               │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ AuthScreen.initState()                                      │
│ Load stored accounts:                                        │
│ AuthProvider.loadStoredAccounts()                          │
│ ← List of _StoredAccount from SharedPreferences             │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ User SELECT account dari list                               │
│ User ENTER password                                          │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ AuthProvider.authenticate(userId, password)                 │
│ Validate: password vs stored hash                           │
└─────────────────────────────────────────────────────────────┘
                           ↓
         ┌────────────────┬──────────┐
         ↓                ↓          ↓
    ┌────────┐    ┌──────────┐  ┌────────┐
    │ VALID  │    │ INVALID  │  │ TIMEOUT│
    └────────┘    └──────────┘  └────────┘
         ↓                ↓          ↓
         │                └──────────┴─→ Error message
         ↓
┌─────────────────────────────────────────────────────────────┐
│ Create LoginHistoryItem:                                     │
│ {timestamp, success: true, method, device}                  │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ AuthProvider.saveLoginHistory(historyItem)                 │
│ SharedPreferences.save()                                    │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ Load Holder DID:                                             │
│ SecureStorageService.loadHolderDid(userId)                 │
│ If null: Generate new DID                                  │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ AuthProvider._currentUser = UserModel                       │
│ WalletProvider._activeUserScope = userId                    │
│ notifyListeners()                                            │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ Navigate → Dashboard                                         │
│ Show: User credentials + actions                            │
└─────────────────────────────────────────────────────────────┘
```

---

### **FLOW 4: CREDENTIAL STATUS CHECK (POLLING)**

```
┌─────────────────────────────────────────────────────────────┐
│ WalletProvider._statusRealtimeTimer.init()                 │
│ Interval: 20 seconds                                         │
└─────────────────────────────────────────────────────────────┘
                           ↓
              ┌────────────────────────┐
              ↓                        ↑
┌─────────────────────────────────────────────────────────────┐
│ Every 20 seconds:                                            │
│ For each credential in _credentials:                         │
│   Check: credentialStatusUrl != null?                        │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ CredentialStatusService.checkCredentialStatus()            │
│ GET credentialStatusUrl                                      │
│ Parse response (StatusList2021, etc.)                       │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ Update CredentialModel:                                      │
│   statusActive = boolean                                     │
│   statusCheckedAt = DateTime.now()                           │
│   syncedStatus = parsed_status                               │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ WalletProvider.notifyListeners()                            │
│ Trigger UI rebuild dengan status terbaru                    │
└─────────────────────────────────────────────────────────────┘
                           ↓
              └────────────────────────┘
                   (repeat every 20s)
```

---

## **🔐 KEY COMPONENTS & RESPONSIBILITIES**

### **Holder DID Management**

**What is DID:**
- Decentralized Identifier
- Format: `did:jwk:...` (from public key)
- Used to sign proofs di OID4VCI flow

**Generation:**
```
1. Generate Ed25519 keypair
2. Extract public key bytes
3. Build DID from public key: did:jwk:...
4. Save: private key, public key, DID ke SecureStorageService
```

**Validation:**
```
1. Load private key from storage
2. Regenerate keypair dari private key
3. Derive public key dari keypair
4. Verify: derived public key == stored public key
5. Verify: derived DID == stored DID
6. If mismatch: Regenerate everything
```

**Storage:**
- **Private Key:** Base64 encoded (32 bytes Ed25519 seed)
- **Public Key:** Base64 encoded (32 bytes public key)
- **DID:** String format (did:jwk:...)
- **Encryption:** flutter_secure_storage (platform-level encryption)

**Uniqueness Check:**
- `assertUniqueHolderDidForUser()` - Prevent multiple DIDs per user
- Prevents duplicate identity issues

---

### **Credential Storage**

**Location:**
- `CredentialModel` instances di memory (`_credentials` list)
- Persisted via SharedPreferences + SecureStorageService

**Lifecycle:**
```
1. Receive from issuer (JWT or SD-JWT string)
2. Validate: signature, issuer, expiry
3. Parse: extract claims, metadata
4. Create CredentialModel object
5. Store: SharedPreferences + SecureStorageService
6. Load saat app start atau user login
```

**Data:**
```dart
CredentialModel {
  // Identity
  id: UUID,
  type: "HealthInsurance" / "Passport" / etc,
  issuer: "Ministry of Health",
  
  // Holder Info
  holderName: "John Doe",
  documentNumber: "123456789",
  
  // Validity
  issuedDate: DateTime,
  expiryDate: DateTime?,
  
  // Verification
  isVerified: boolean,
  signature: String? (hex),
  publicKey: String? (base64),
  
  // JWT/OID4VCI
  rawJwt: String (JWT string),
  format: "jwt_vc_json" / "vc+sd-jwt",
  issuerDid: "did:...",
  
  // Status
  credentialStatusUrl: String?,
  statusActive: boolean?,
  statusCheckedAt: DateTime?,
  syncedStatus: String?
}
```

---

### **Deep Link Routing**

**Initialization:**
```dart
main.dart
  ↓
_IDentiaApp.initState()
  ↓
_initDeepLinks()
  ↓
_appLinks = AppLinks()
```

**Cold Start (App tidak running):**
```dart
_appLinks.getInitialLink()
  ↓
_handleDeepLink(uri)
  ↓
Route to appropriate screen
```

**Warm Deep Links (App sudah running):**
```dart
_appLinks.uriLinkStream.listen()
  ↓
When URI received → _handleDeepLink()
  ↓
Route to appropriate screen
```

**Route Logic:**
```dart
if (link.startsWith('openid-credential-offer://')) {
  → IssuanceFlowScreen(deepLink: link)
}
else if (link.startsWith('openid4vp://') || 
         link.startsWith('haip://') ||
         link.startsWith('mdoc-openid4vp://')) {
  → PresentationConsentScreen(qrData: link)
}
else if (link.startsWith('identia://callback')) {
  → Handled internally by OID4VCIService
}
```

**Manifest Configuration (Android):**
- Deep link schemes registered di AndroidManifest.xml
- App shortcuts untuk deep link handling

**UPI Scheme (iOS):**
- Universal Links configuration
- App associating file for domain verification

---

### **Status Polling**

**Initialization:**
```dart
WalletProvider.initStatusPolling()
  ↓
_statusRealtimeTimer = Timer.periodic(
  Duration(seconds: 20),
  (_) => _pollCredentialStatuses()
)
```

**Polling Logic:**
```dart
_pollCredentialStatuses() {
  for (credential in _credentials) {
    if (credential.credentialStatusUrl != null) {
      CredentialStatusService.checkStatus()
        .then((status) {
          credential.statusActive = status.active
          credential.statusCheckedAt = DateTime.now()
        })
    }
  }
  notifyListeners() // UI update
}
```

**Cleanup:**
```dart
WalletProvider.dispose()
  ↓
_statusRealtimeTimer?.cancel()
```

**Status Formats Supported:**
- StatusList2021Entry
- JWT Status (custom)
- Bitstring status checks

---

## **📐 ANALISIS KLM (Keystroke-Level Model)**

Bagian ini memodelkan waktu interaksi pengguna untuk semua skenario utama aplikasi IDentia. Nilai KLM bersifat parametrik agar akurat untuk berbagai perangkat. Gunakan nilai operator default di bawah, lalu ganti $R$ dengan waktu respons sistem nyata (hasil pengukuran).

### **Asumsi & Operator**

- **Target perangkat:** mobile layar sentuh, satu tangan, pengguna terlatih.
- **Operator KLM (detik):**
  - $K$ = tap/tekan (default $0.20$s)
  - $H$ = pindah posisi tangan/jari (default $0.40$s)
  - $P$ = mencari/menemukan target visual (default $1.10$s)
  - $M$ = persiapan mental/keputusan (default $1.35$s)
  - $R$ = waktu respons sistem (ukur di perangkat; bervariasi)
- **Variabel:**
  - $n_{pw}$ = jumlah karakter password
  - $n_{id}$ = jumlah karakter userId/username (jika diminta)
  - $n_{cred}$ = jumlah kredensial yang dipilih untuk presentasi
  - $n_f$ = jumlah field input pada verifikasi manual
  - $n_i$ = jumlah karakter pada field ke-$i$

Catatan: untuk input teks, gunakan $K$ per karakter. Untuk scanning QR, aktivitas visual pengguna dimodelkan sebagai $P$ dan $M$, sementara deteksi kamera masuk ke $R$.

---

### **Skenario 1: Authentication (Login)**

**Deskripsi:** user memilih akun tersimpan, memasukkan password, lalu login.

**Urutan KLM (parametrik):**
```
M + P + K                     // memilih akun
P + K                         // fokus ke field password
K * n_pw                      // mengetik password
M + P + K                     // tekan tombol Login
R_login                       // validasi dan masuk dashboard
```

**Total waktu:**
$$T_{login} = 2M + 3P + 3K + K \cdot n_{pw} + R_{login}$$

---

### **Skenario 2: Issuance OID4VCI via QR/Deep Link**

Skenario ini terbagi dua jalur sesuai grant: **pre-authorized** atau **authorization code**.

#### **2A. Masuk dari QR (scan) atau deep link**

```
M + P + K                     // buka fitur scan/terima link
R_open_camera                 // kamera siap (jika scan)
P + M                         // arahkan kamera ke QR
R_qr_detect                   // QR terdeteksi dan deep link diproses
```

**Total waktu (entry):**
$$T_{entry} = 2M + 2P + K + R_{open\_camera} + R_{qr\_detect}$$

#### **2B. Pre-authorized Code Flow (tanpa login di issuer)**

```
M                              // pahami proses issuance
R_issue_processing             // parsing offer hingga menerima credential
M + P + K                      // konfirmasi/OK saat selesai (jika ada)
```

**Total waktu:**
$$T_{preauth} = 2M + P + K + R_{issue\_processing}$$

#### **2C. Authorization Code Flow (login & consent di issuer)**

Bagian ini termasuk interaksi di browser/issuer. Karena UI issuer dapat berbeda, modelnya parametrik.

```
M + P + K                      // tap tombol Authorize
R_browser_open                 // browser terbuka
P + K + K*n_id                 // fokus dan input userId (jika diminta)
P + K + K*n_pw                 // fokus dan input password
M + P + K                      // tap tombol Login/Continue
M + P + K                      // consent/Allow
R_issue_processing             // tukar token hingga credential tersimpan
```

**Total waktu (issuer auth):**
$$T_{auth} = 3M + 5P + 5K + K\cdot n_{id} + K\cdot n_{pw} + R_{browser\_open} + R_{issue\_processing}$$

---

### **Skenario 3: Presentation OID4VP (QR dari Verifier)**

**Deskripsi:** user scan QR, memilih kredensial yang cocok, lalu mengirim presentasi.

**Urutan KLM (parametrik):**
```
M + P + K                      // buka scan
R_open_camera
P + M                          // arahkan kamera
R_qr_detect                    // request parsed
M + P + K                      // buka detail/layar consent
(P + K) * n_cred               // pilih kredensial
M + P + K                      // konfirmasi kirim
R_submit                       // submit presentasi
```

**Total waktu:**
$$T_{present} = 3M + (2 + n_{cred})P + (2 + n_{cred})K + R_{open\_camera} + R_{qr\_detect} + R_{submit}$$

---

### **Skenario 4: Verifikasi Kredensial Manual**

UI verifikasi manual tidak dijabarkan rinci di dokumen ini, sehingga model dibuat parametrik berdasarkan jumlah field.

**Asumsi:** user membuka menu verifikasi, memasukkan $n_f$ field, lalu menekan Verify.

```
M + P + K                      // buka menu verifikasi
For each field (n_f):
  P + K + K*n_i                 // fokus field + input karakter
M + P + K                      // tap Verify
R_verify                       // hasil verifikasi
```

**Total waktu:**
$$T_{verify} = 2M + (n_f+2)P + (n_f+2)K + K\cdot \sum n_i + R_{verify}$$

---

### **Skenario 5: Credential Status Check (Polling)**

Skenario ini **tanpa interaksi pengguna**, sehingga **KLM tidak berlaku**. Waktu proses masuk ke $R$ (sistem) dan ditangani oleh timer internal.

---

### **Cara Menggunakan Hasil KLM**

1. Gunakan rumus di atas, substitusi $n$ sesuai konteks nyata.
2. Ukur $R$ di perangkat target (mis. time to open camera, time to submit).
3. Jika pengguna pemula, tingkatkan $M$ dan $P$ (mis. +20% sampai +50%).

Jika Anda ingin saya hitung angka final, kirimkan nilai $R$ aktual dan panjang input rata-rata.

---

## **📊 DATA MODELS - RELASI**

```
┌─────────────────────────────────────────────────────┐
│ UserModel (Holder Identity)                         │
│ {id, name, email, phone, createdAt, lastLogin}    │
└─────────────────────────────────────────────────────┘
         ↓
         ├── Multiple CredentialModel
         │   └──────────────────────────────────────────┐
         │       {id, type, issuer, holderName,        │
         │        documentNumber, issuedDate,          │
         │        expiryDate, rawJwt, format,          │
         │        issuerDid, statusActive, ...}        │
         │                   ↓                          │
         │   ┌───────────────┼───────────────┐        │
         │   ↓               ↓               ↓        │
         │   issuerDid →  IssuerMetadataModel         │
         │   (references   {authServerUrl,             │
         │    issuer's     tokenEndpoint,              │
         │    DID & config credentialEndpoint,         │
         │    )            credentialConfigs}          │
         │                                              │
         │   rawJwt →  JwtVerifierService.verify()     │
         │   (decode &     Check: signature, exp, iss  │
         │    validate)    Extract claims              │
         │                                              │
         │   credentialStatusUrl →                      │
         │   CredentialStatusService.check()            │
         │   (periodic polling)                         │
         │
         ├── Holder DID (Ed25519 keypair)
         │   {did: "did:jwk:...",
         │    privateKey: base64,
         │    publicKey: base64}
         │         ↓
         │   Used in OID4VCIService.buildProof()
         │   Create JWT proof with Holder DID
         │
         └── PresentationRequest (from QR)
             {client_id, presentation_definition,
              input_descriptors[], ...)
                     ↓
             ┌───────┴────────────────────────┐
             ↓                                ↓
             presentation_definition          input_descriptors
             {id, input_descriptors[]}       [{id, constraints,
                                               format: {jwt_vc,
                                               jwt_vc_json, ...}
                                               path, ...}]
                     ↓
             Match dengan stored CredentialModel
             Build PresentationSubmission
             └───────┬────────────────────────┘
                     ↓
             VerifiablePresentation (VP)
             {verifiableCredential[],
              holder: holderDid,
              proof: jwtProof}
```

---

## **🔗 DEPENDENCIES KEY**

| Package | Purpose | Version |
|---------|---------|---------|
| `flutter` | Framework | SDK |
| `flutter_localizations` | i18n | SDK |
| `google_fonts` | Custom fonts | ^6.1.0 |
| `mobile_scanner` | QR code scanning | ^3.5.5 |
| `cryptography` | Crypto operations (Ed25519) | ^2.7.0 |
| `shared_preferences` | Local storage (simple) | ^2.2.2 |
| `provider` | State management | ^6.1.1 |
| `flutter_animate` | Animations | ^4.3.0 |
| `intl` | Localization (i18n) | ^0.20.2 |
| `geolocator` | Location services | ^10.1.0 |
| `http` | HTTP client | ^1.1.0 |
| `permission_handler` | Permission management | ^11.1.0 |
| `url_launcher` | Launch URLs/apps | ^6.2.0 |
| `dart_jsonwebtoken` | JWT operations | ^2.8.0 |
| `flutter_secure_storage` | Secure key storage | ^9.0.0 |
| `app_links` | Deep linking | ^6.3.4 |
| `pointycastle` | Cryptography library | ^3.7.3 |
| `image_picker` | Image selection | ^1.1.2 |
| `local_auth` | Biometric auth | ^2.3.0 |

---

## **📝 UNTUK MEMBUAT DIAGRAM**

### **Activity Diagram - Gunakan:**
- **States dari Enum:**
  - `IssuanceStatus` (8 states)
  - `IdentiaFlowStatus` (7 states)
  - `PresentationStatus` (7 states)

- **Decision Points:**
  - Authorization method (pre-authorized vs auth code)
  - Credential matching result (found vs not found)
  - User consent (confirm vs reject)

- **Transitions:**
  - Status changes antara states
  - Conditional flows based on conditions

### **Sequence Diagram - Gunakan:**
- **Actors/Objects:**
  - User
  - UI Screen
  - WalletProvider
  - OID4VCIService / OID4VPService
  - SecureStorageService
  - HTTP Endpoints (Issuer/Verifier)
  - Device Storage

- **Message Flows:**
  - User actions
  - Screen → Provider calls
  - Provider → Service calls
  - Service → Network/Storage calls
  - Responses back up the chain

- **Key Sequences:**
  1. Issuance Flow (9 major steps)
  2. Presentation Flow (8 major steps)
  3. Authentication Flow (6 major steps)
  4. Status Polling (periodic)

---

## **⚙️ SPESIFIKASI LINGKUNGAN DEVELOPMENT HOLDER**

| Komponen | Teknologi | Versi | Fungsi Utama |
|----------|-----------|-------|--------------|
| **Runtime** | Dart/Flutter | >=3.0.0 <4.0.0 | Framework development aplikasi mobile |
| **State Management** | Provider | ^6.1.1 | Kelola state & notifikasi real-time |
| **Secure Storage** | flutter_secure_storage | ^9.0.0 | Simpan DID, private key, credentials terenkripsi |
| **QR Scanner** | mobile_scanner | ^3.5.5 | Scan credential offer & presentation request QR |
| **Cryptography** | cryptography | ^2.7.0 | Enkripsi/dekripsi data sensitif |
| **JWT Handler** | dart_jsonwebtoken | ^2.8.0 | Sign & verify JWT credentials |
| **Asymmetric Crypto** | pointycastle | ^3.7.3 | Ed25519 keypair untuk DID generation |
| **HTTP Client** | http | ^1.1.0 | Network requests ke issuer & verifier |
| **Biometric Auth** | local_auth | ^2.3.0 | Autentikasi biometric & PIN |
| **Local Storage** | shared_preferences | ^2.2.2 | Simpan app settings & data non-sensitif |
| **Deep Linking** | app_links | ^6.3.4 | Handle deep links (credential offer, presentation) |
| **Image Picker** | image_picker | ^1.1.2 | Ambil foto dari gallery/camera |
| **Localization** | intl | ^0.20.2 | Support multi-bahasa |
| **Location Services** | geolocator | ^10.1.0 | Geocoding & location data |
| **UI Animation** | flutter_animate | ^4.3.0 | UI animation effects |
| **Custom Fonts** | google_fonts | ^6.1.0 | Fonts custom dari Google Fonts |
| **URL Launcher** | url_launcher | ^6.2.0 | Buka external URLs |
| **Permissions** | permission_handler | ^11.1.0 | Request device permissions |

---

## **📌 CATATAN PENTING**

1. **DID Generation:** Otomatis saat first issuance, stored secara aman
2. **JWT Proof:** Mandatory untuk OID4VCI requests (signed dengan holder private key)
3. **Credential Format:** Mendukung `jwt_vc_json` dan `vc+sd-jwt`
4. **Status Polling:** Aktif di background setiap 20 detik
5. **Deep Linking:** Handle cold & warm starts dengan AppLinks
6. **Error Handling:** Status `error` di setiap flow dengan error messages
7. **User Context:** `_activeUserScope` untuk multi-user support

---

**File Created:** `ANALISIS_PROGRAM_IDENTIA.md`
**Gunakan informasi ini untuk membuat Activity & Sequence Diagram yang detail!** 🎯

