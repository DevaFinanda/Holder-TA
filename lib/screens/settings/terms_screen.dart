import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Syarat & Ketentuan',
          style: TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        clipBehavior: Clip.hardEdge,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Last Updated
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Terakhir Diperbarui',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMedium,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '20 Januari 2026',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Introduction
            _buildSection(
              'Pendahuluan',
              'Selamat datang di IDentia. Dengan menggunakan aplikasi ini, Anda menyetujui syarat dan ketentuan yang berlaku. Mohon baca dengan seksama sebelum menggunakan layanan kami.',
            ),

            _buildSection(
              '1. Penerimaan Ketentuan',
              'Dengan mengakses dan menggunakan aplikasi IDentia, Anda menyatakan bahwa Anda telah membaca, memahami, dan menyetujui untuk terikat dengan syarat dan ketentuan ini. Jika Anda tidak setuju dengan ketentuan ini, harap jangan gunakan aplikasi ini.',
            ),

            _buildSection(
              '2. Definisi Layanan',
              'IDentia adalah platform dompet identitas digital yang memungkinkan pengguna untuk:\n'
                  '• Menyimpan dan mengelola kredensial digital\n'
                  '• Melakukan verifikasi identitas\n'
                  '• Berbagi informasi dengan pihak ketiga secara aman\n'
                  '• Mengakses layanan kesehatan terintegrasi',
            ),

            _buildSection(
              '3. Kewajiban Pengguna',
              'Sebagai pengguna, Anda wajib:\n'
                  '• Memberikan informasi yang akurat dan lengkap\n'
                  '• Menjaga kerahasiaan akun dan password\n'
                  '• Tidak menyalahgunakan layanan\n'
                  '• Mematuhi semua peraturan yang berlaku\n'
                  '• Melaporkan aktivitas mencurigakan',
            ),

            _buildSection(
              '4. Keamanan Akun',
              'Anda bertanggung jawab penuh atas keamanan akun Anda. Kami menyarankan untuk:\n'
                  '• Menggunakan password yang kuat\n'
                  '• Mengaktifkan autentikasi dua faktor\n'
                  '• Tidak membagikan kredensial login\n'
                  '• Segera melaporkan jika terjadi akses tidak sah',
            ),

            _buildSection(
              '5. Privasi Data',
              'Kami berkomitmen untuk melindungi privasi Anda. Data pribadi Anda akan:\n'
                  '• Dienkripsi dengan standar keamanan tinggi\n'
                  '• Tidak dibagikan tanpa persetujuan Anda\n'
                  '• Disimpan sesuai regulasi yang berlaku\n'
                  '• Dapat dihapus atas permintaan Anda',
            ),

            _buildSection(
              '6. Hak Kekayaan Intelektual',
              'Semua konten dalam aplikasi IDentia, termasuk teks, grafik, logo, dan perangkat lunak, adalah hak milik IDentia dan dilindungi oleh undang-undang hak cipta.',
            ),

            _buildSection(
              '7. Pembatasan Tanggung Jawab',
              'IDentia tidak bertanggung jawab atas:\n'
                  '• Kerugian akibat penyalahgunaan akun\n'
                  '• Gangguan layanan di luar kendali kami\n'
                  '• Kesalahan informasi dari pihak ketiga\n'
                  '• Kerusakan perangkat pengguna',
            ),

            _buildSection(
              '8. Perubahan Ketentuan',
              'Kami berhak untuk mengubah syarat dan ketentuan ini sewaktu-waktu. Perubahan akan diinformasikan melalui aplikasi dan dianggap diterima jika Anda terus menggunakan layanan.',
            ),

            _buildSection(
              '9. Penghentian Layanan',
              'Kami berhak menghentikan atau membatasi akses Anda jika:\n'
                  '• Melanggar ketentuan penggunaan\n'
                  '• Menggunakan layanan untuk tujuan ilegal\n'
                  '• Merusak sistem atau data\n'
                  '• Atas permintaan otoritas hukum',
            ),

            _buildSection(
              '10. Hukum yang Berlaku',
              'Syarat dan ketentuan ini diatur oleh hukum Republik Indonesia. Setiap perselisihan akan diselesaikan melalui jalur hukum yang berlaku di Indonesia.',
            ),

            const SizedBox(height: 24),

            // Contact
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hubungi Kami',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Jika Anda memiliki pertanyaan tentang Syarat & Ketentuan ini, silakan hubungi kami:',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textMedium,
                    ),
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(
                        Icons.email,
                        size: 18,
                        color: AppColors.primaryBlue,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'legal@identia.id',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.primaryBlue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textMedium,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
