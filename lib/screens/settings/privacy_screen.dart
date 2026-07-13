import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

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
          'Kebijakan Privasi',
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
                gradient: LinearGradient(
                  colors: [
                    AppColors.success.withOpacity(0.1),
                    AppColors.primaryBlue.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.shield_outlined,
                    color: AppColors.primaryBlue,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Privasi Anda Terlindungi',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Terakhir diperbarui: 20 Januari 2026',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Introduction
            _buildSection(
              'Pendahuluan',
              'IDentia berkomitmen untuk melindungi privasi dan keamanan data pribadi Anda. Kebijakan privasi ini menjelaskan bagaimana kami mengumpulkan, menggunakan, dan melindungi informasi Anda.',
            ),

            _buildSection(
              '1. Informasi yang Kami Kumpulkan',
              'Kami mengumpulkan informasi berikut:\n\n'
                  'Informasi Pribadi:\n'
                  '• Nama lengkap\n'
                  '• Nomor Induk Kependudukan (NIK)\n'
                  '• Tanggal dan tempat lahir\n'
                  '• Alamat email dan nomor telepon\n'
                  '• Alamat tempat tinggal\n\n'
                  'Informasi Teknis:\n'
                  '• Informasi perangkat\n'
                  '• Alamat IP\n'
                  '• Log aktivitas aplikasi\n'
                  '• Data biometrik (sidik jari/wajah)',
            ),

            _buildSection(
              '2. Cara Kami Menggunakan Informasi',
              'Informasi Anda digunakan untuk:\n'
                  '• Verifikasi identitas dan autentikasi\n'
                  '• Penyediaan layanan dompet digital\n'
                  '• Keamanan dan pencegahan fraud\n'
                  '• Peningkatan layanan\n'
                  '• Komunikasi terkait layanan\n'
                  '• Kepatuhan regulasi',
            ),

            _buildSection(
              '3. Keamanan Data',
              'Kami menerapkan langkah-langkah keamanan tingkat tinggi:\n\n'
                  'Enkripsi:\n'
                  '• Data dienkripsi end-to-end\n'
                  '• Menggunakan standar AES-256\n'
                  '• Komunikasi melalui protokol SSL/TLS\n\n'
                  'Penyimpanan:\n'
                  '• Server aman di Indonesia\n'
                  '• Backup terenkripsi\n'
                  '• Akses terbatas dan teraudit\n\n'
                  'Autentikasi:\n'
                  '• Multi-factor authentication\n'
                  '• Biometrik\n'
                  '• Session management',
            ),

            _buildSection(
              '4. Berbagi Informasi',
              'Kami TIDAK akan menjual data Anda. Informasi hanya dibagikan:\n\n'
                  '• Dengan persetujuan eksplisit Anda\n'
                  '• Kepada penyedia layanan kesehatan yang Anda pilih\n'
                  '• Jika diwajibkan oleh hukum\n'
                  '• Untuk mencegah fraud atau ancaman keamanan\n\n'
                  'Semua pembagian data dicatat dan dapat Anda lihat di riwayat aktivitas.',
            ),

            _buildSection(
              '5. Hak Anda',
              'Anda memiliki hak untuk:\n\n'
                  '• Mengakses data pribadi Anda\n'
                  '• Memperbaiki data yang tidak akurat\n'
                  '• Menghapus data Anda (right to be forgotten)\n'
                  '• Membatasi pemrosesan data\n'
                  '• Portabilitas data\n'
                  '• Menarik persetujuan kapan saja\n'
                  '• Mengajukan keluhan ke otoritas',
            ),

            _buildSection(
              '6. Penyimpanan Data',
              'Kami menyimpan data Anda:\n'
                  '• Selama akun aktif\n'
                  '• Sesuai dengan ketentuan hukum yang berlaku\n'
                  '• Minimal 5 tahun untuk keperluan audit\n\n'
                  'Setelah penghapusan akun:\n'
                  '• Data dihapus dalam 90 hari\n'
                  '• Backup dihapus dalam 180 hari\n'
                  '• Data audit tetap disimpan sesuai regulasi',
            ),

            _buildSection(
              '7. Cookies dan Teknologi Pelacakan',
              'Kami menggunakan:\n'
                  '• Session cookies untuk autentikasi\n'
                  '• Cookies fungsional untuk pengalaman pengguna\n'
                  '• Analytics untuk peningkatan layanan\n\n'
                  'Anda dapat mengelola preferensi cookies di pengaturan aplikasi.',
            ),

            _buildSection(
              '8. Privasi Anak',
              'Aplikasi ini tidak ditujukan untuk anak di bawah 17 tahun. Kami tidak dengan sengaja mengumpulkan informasi dari anak-anak. Jika Anda mengetahui adanya data anak, hubungi kami segera.',
            ),

            _buildSection(
              '9. Perubahan Kebijakan',
              'Kami dapat memperbarui kebijakan privasi ini. Perubahan signifikan akan diberitahukan melalui:\n'
                  '• Notifikasi aplikasi\n'
                  '• Email ke alamat terdaftar\n'
                  '• Pop-up saat login\n\n'
                  'Penggunaan berkelanjutan berarti Anda menerima perubahan tersebut.',
            ),

            _buildSection(
              '10. Dasar Hukum',
              'Pemrosesan data Anda didasarkan pada:\n'
                  '• Persetujuan eksplisit Anda\n'
                  '• Pemenuhan kontrak layanan\n'
                  '• Kewajiban hukum\n'
                  '• Kepentingan sah kami\n\n'
                  'Sesuai dengan:\n'
                  '• UU ITE No. 11 Tahun 2008\n'
                  '• UU Perlindungan Data Pribadi\n'
                  '• Peraturan BSSN',
            ),

            const SizedBox(height: 24),

            // Your Rights Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryBlue.withOpacity(0.1),
                    AppColors.secondaryTeal.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Kelola Data Anda',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildActionButton(
                    context,
                    'Lihat Data Saya',
                    Icons.visibility,
                  ),
                  const SizedBox(height: 8),
                  _buildActionButton(
                    context,
                    'Unduh Data Saya',
                    Icons.download,
                  ),
                  const SizedBox(height: 8),
                  _buildActionButton(
                    context,
                    'Hapus Akun Saya',
                    Icons.delete_forever,
                    isDestructive: true,
                  ),
                ],
              ),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Hubungi Data Protection Officer',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Untuk pertanyaan terkait privasi dan data:',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textMedium,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildContactInfo(Icons.email, 'privacy@identia.id'),
                  const SizedBox(height: 8),
                  _buildContactInfo(Icons.phone, '+62 21 1500-123'),
                  const SizedBox(height: 8),
                  _buildContactInfo(
                    Icons.location_on,
                    'Jakarta, Indonesia',
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

  Widget _buildActionButton(
    BuildContext context,
    String text,
    IconData icon, {
    bool isDestructive = false,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          if (isDestructive) {
            _showDeleteAccountDialog(context);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$text...')),
            );
          }
        },
        icon: Icon(icon),
        label: Text(text),
        style: OutlinedButton.styleFrom(
          foregroundColor:
              isDestructive ? AppColors.error : AppColors.primaryBlue,
          side: BorderSide(
            color: isDestructive ? AppColors.error : AppColors.primaryBlue,
          ),
        ),
      ),
    );
  }

  Widget _buildContactInfo(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primaryBlue),
        const SizedBox(width: 12),
        Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textDark,
          ),
        ),
      ],
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning, color: AppColors.error),
            SizedBox(width: 12),
            Text('Hapus Akun?'),
          ],
        ),
        content: const Text(
          'Tindakan ini tidak dapat dibatalkan. Semua data Anda akan dihapus secara permanen dalam 90 hari.\n\n'
          'Anda yakin ingin menghapus akun Anda?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Permintaan penghapusan akun telah dikirim'),
                  backgroundColor: AppColors.error,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Hapus Akun'),
          ),
        ],
      ),
    );
  }
}
