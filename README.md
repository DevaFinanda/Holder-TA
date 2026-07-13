# IDentia

> Aplikasi dompet identitas terdesentralisasi (Self-Sovereign Identity) berbasis **Flutter** yang mengimplementasikan **W3C Verifiable Credentials** dengan alur **OID4VCI** dan **OID4VP**.

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

---

## Deskripsi

**IDentia** adalah aplikasi mobile yang memungkinkan pengguna menyimpan, mengelola, dan mempresentasikan **Verifiable Credentials (VC)** secara mandiri tanpa bergantung pada otoritas terpusat. Setiap pengguna memiliki pasangan kunci kriptografis sendiri (**Ed25519**) dan identitas terdesentralisasi berbasis **DID:JWK**, sehingga kendali penuh atas data identitas berada di tangan pemilik (*self-sovereign identity*).

Aplikasi ini mendukung dua alur utama dalam ekosistem identitas terdesentralisasi:

- **OID4VCI** (OpenID for Verifiable Credential Issuance) — penerbitan kredensial dari *Issuer* ke dompet pengguna.
- **OID4VP** (OpenID for Verifiable Presentations) — presentasi kredensial dari dompet pengguna ke *Verifier*.

---

## Fitur Utama

- 🔐 **Manajemen kunci kriptografis** — pembuatan dan penyimpanan pasangan kunci **Ed25519** secara aman di perangkat.
- 🆔 **Identitas terdesentralisasi** — pembuatan dan pengelolaan **DID:JWK** milik pengguna.
- 📥 **Penerbitan kredensial (OID4VCI)** — menerima *Credential Offer* dari Issuer dan menyimpan **JWT Verifiable Credential**.
- 📤 **Presentasi kredensial (OID4VP)** — menyusun **JWT Verifiable Presentation** dan mengirimkannya ke Verifier.
- ✅ **Verifikasi tanda tangan** — validasi keaslian dan integritas kredensial menggunakan tanda tangan digital.
- 💾 **Penyimpanan kredensial** — menyimpan koleksi VC milik pengguna secara lokal.
- 📱 **Antarmuka lintas platform** — dibangun dengan Flutter (Android & iOS).

---

## Standar & Spesifikasi yang Didukung

| Standar | Keterangan |
|---|---|
| **W3C Verifiable Credentials 1.0** | Model data kredensial yang dapat diverifikasi |
| **OID4VCI** | OpenID for Verifiable Credential Issuance |
| **OID4VP** | OpenID for Verifiable Presentations |
| **DID:JWK** | Metode Decentralized Identifier berbasis JSON Web Key |
| **Ed25519 (EdDSA)** | Algoritma tanda tangan digital berbasis kurva eliptik |
| **JWT (JWS)** | Format kontainer untuk VC/VP yang ditandatangani |

---

## Arsitektur & Teknologi

- **Framework:** Flutter (Dart)
- **Kriptografi:** package [`cryptography`](https://pub.dev/packages/cryptography) untuk operasi Ed25519
- **Format kredensial:** JWT VC / JWT VP (JOSE / JWS)
- **Backend terkait:**
  - **Issuer** — menerbitkan Verifiable Credentials melalui endpoint OID4VCI
  - **Verifier** — meminta dan memverifikasi Verifiable Presentations melalui endpoint OID4VP

### Alur Sistem (ringkas)

```
  Issuer  ──(OID4VCI)──▶  Dompet IDentia  ──(OID4VP)──▶  Verifier
     │                         │                            │
  Menerbitkan VC          Menyimpan VC                Memverifikasi VP
  (JWT VC)                Menandatangani VP           (validasi tanda tangan)
```

---

## Prasyarat

- [Flutter SDK](https://docs.flutter.dev/get-started/install) 3.x atau lebih baru
- Dart SDK 3.x (sudah termasuk dalam Flutter)
- Android Studio / Xcode untuk emulator atau perangkat fisik
- Akses ke endpoint **Issuer** dan **Verifier** IDentia

Cek kesiapan lingkungan pengembangan:

```bash
flutter doctor
```

---

## Instalasi & Menjalankan

1. **Klon repositori**

   ```bash
   git clone <url-repositori-anda>
   cd identia
   ```

2. **Pasang dependensi**

   ```bash
   flutter pub get
   ```

3. **Jalankan aplikasi**

   ```bash
   flutter run
   ```

4. **Build rilis (opsional)**

   ```bash
   # Android
   flutter build apk --release

   # iOS
   flutter build ios --release
   ```

---

## Konfigurasi

Endpoint Issuer dan Verifier didefinisikan sebagai konstanta di dalam kode. Sesuaikan nilainya dengan lingkungan Anda:

```dart
const String kBaseUrlIssuer   = 'https://issuer.identia.my.id';
const String kBaseUrlVerifier = 'https://verifier.identia.my.id';
const String kPathCredentialOffer = '/.well-known/openid-credential-issuer';
```

> **Catatan keamanan:** gunakan HTTPS untuk seluruh endpoint pada lingkungan produksi dan jangan menyimpan kunci privat di luar penyimpanan aman perangkat.

---

## Struktur Proyek

```
identia/
├── android/            # Konfigurasi platform Android
├── ios/                # Konfigurasi platform iOS
├── lib/                # Kode sumber utama aplikasi
│   ├── main.dart       # Titik masuk aplikasi
│   ├── models/         # Model data (VC, VP, DID, dsb.)
│   ├── services/       # Layanan kriptografi, OID4VCI, OID4VP
│   ├── screens/        # Halaman antarmuka pengguna
│   └── widgets/        # Komponen UI yang dapat digunakan ulang
├── test/               # Pengujian unit & widget
├── pubspec.yaml        # Definisi dependensi
└── README.md
```

---

## Pengujian

Jalankan pengujian otomatis:

```bash
flutter test
```

Pengujian mencakup:

- **Pengujian fungsional (black box)** atas skenario alur OID4VCI dan OID4VP (kasus positif dan negatif).
- **Pengujian kinerja** terhadap operasi kritis seperti pembuatan pasangan kunci, encoding DID:JWK, penyusunan JWT VC/VP, serta verifikasi tanda tangan — menggunakan implementasi Ed25519 yang sama dengan aplikasi (package `cryptography`).

---

## Kontribusi

Kontribusi sangat diterima. Silakan buka *issue* untuk mendiskusikan perubahan yang diinginkan, lalu ajukan *pull request*.

1. Fork repositori ini
2. Buat branch fitur (`git checkout -b fitur/nama-fitur`)
3. Commit perubahan Anda (`git commit -m 'Menambahkan fitur X'`)
4. Push ke branch (`git push origin fitur/nama-fitur`)
5. Buka Pull Request

---

## Lisensi

Distribusikan di bawah lisensi MIT. Lihat berkas `LICENSE` untuk detail.

---

<p align="center">Dibuat dengan ❤️ menggunakan Flutter</p>
