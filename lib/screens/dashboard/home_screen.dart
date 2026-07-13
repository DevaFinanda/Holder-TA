import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../utils/app_colors.dart';
import '../../widgets/credential_card.dart';
import '../../widgets/quick_action_button.dart';
import 'qr_scanner_screen.dart';
import 'history_screen.dart';
import 'activity_screen.dart';
import 'search_hospital_screen.dart';
import 'notification_screen.dart';
import 'all_credentials_screen.dart';
import 'jwt_viewer_screen.dart';
import '../verification/verification_detail_screen.dart';
import '../presentation/oid4vp_start_screen.dart';
import '../../models/credential_model.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final walletProvider = context.watch<WalletProvider>();
    final user = authProvider.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        color: AppColors.background,
        child: ClipRect(
          child: SafeArea(
            child: RefreshIndicator(
              onRefresh: () async {
                await context.read<WalletProvider>().refreshWalletData();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                clipBehavior: Clip.hardEdge,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          // Avatar
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              gradient: AppColors.identityCardGradient,
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Center(
                              child: Text(
                                user?.initials ?? 'U',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Greeting
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Selamat Datang,',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textMedium,
                                  ),
                                ),
                                Text(
                                  user?.firstName ?? 'Pengguna',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Notification Icon
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const NotificationScreen(),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.notifications_outlined,
                                color: AppColors.primaryBlue,
                                size: 22,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Quick Actions
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          QuickActionButton(
                            icon: Icons.history,
                            label: 'Riwayat',
                            color: AppColors.primaryBlue,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const HistoryScreen(),
                                ),
                              );
                            },
                          ),
                          QuickActionButton(
                            icon: Icons.access_time,
                            label: 'Aktivitas',
                            color: AppColors.warning,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const ActivityScreen(),
                                ),
                              );
                            },
                          ),
                          QuickActionButton(
                            icon: Icons.search,
                            label: 'Cari RS',
                            color: AppColors.secondaryTeal,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const SearchHospitalScreen(),
                                ),
                              );
                            },
                          ),
                          QuickActionButton(
                            icon: Icons.verified_user,
                            label: 'Verifikasi',
                            color: AppColors.textMedium,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const OID4VPStartScreen(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Credential Section ────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            walletProvider.credentials.isEmpty
                                ? 'Dompet Saya'
                                : 'Kredensial Saya (${walletProvider.credentials.length})',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                          if (walletProvider.credentials.isNotEmpty)
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const AllCredentialsScreen(),
                                  ),
                                );
                              },
                              child: const Text(
                                'Lihat Semua',
                                style: TextStyle(
                                  color: AppColors.primaryBlue,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Empty state atau tampilkan credential nyata
                    if (walletProvider.credentials.isEmpty)
                      _buildEmptyWalletState(context)
                    else
                      ..._buildCredentialList(walletProvider, context),

                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Widget _buildEmptyWalletState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppColors.primaryBlue.withValues(alpha: 0.12),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryBlue.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryBlue.withValues(alpha: 0.12),
                    AppColors.secondaryTeal.withValues(alpha: 0.08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.wallet_outlined,
                size: 38,
                color: AppColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Dompet Masih Kosong',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Pindai QR dari Penerbit untuk\nmendapatkan kredensial digital Anda.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textMedium,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const QRScannerScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.qr_code_scanner, size: 18),
              label: const Text('Pindai Penawaran Kredensial'),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static List<Widget> _buildCredentialList(
      WalletProvider wallet, BuildContext context) {
    // Show up to 3 credentials on HomeScreen
    final toShow = wallet.credentials.take(3).toList();
    final widgets = <Widget>[];

    for (int i = 0; i < toShow.length; i++) {
      final cred = toShow[i];
      // Alternate gradient for visual variety
      final gradient = i == 0
          ? AppColors.identityCardGradient
          : i == 1
              ? AppColors.healthCardGradient
              : AppColors.primaryGradient;

      widgets.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: CredentialCard(
            credential: cred,
            gradient: gradient,
            onTap: () => _showCredentialDetail(context, cred),
          ),
        ),
      );
    }

    if (wallet.credentials.length > 3) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Center(
            child: TextButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AllCredentialsScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.expand_more),
              label:
                  Text('+${wallet.credentials.length - 3} kredensial lainnya'),
            ),
          ),
        ),
      );
    }

    return widgets;
  }

  static void _showCredentialDetail(
      BuildContext context, CredentialModel credential) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textLight.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: AppColors.identityCardGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.verified_user,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          credential.type,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        Text(
                          credential.issuer,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _statusColor(credential).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _statusIcon(credential),
                          size: 14,
                          color: _statusColor(credential),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _statusLabel(credential),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _statusColor(credential),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Divider(),

            // Details
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildDetailRow('Nama Pemegang', credential.holderName),
                    _buildDetailRow('Nomor Dokumen', credential.documentNumber),
                    _buildDetailRow(
                        'Tanggal Terbit', credential.formattedIssuedDate),
                    _buildDetailRow(
                        'Berlaku Hingga', credential.formattedExpiryDate),
                    _buildDetailRow(
                        'Status Credential', credential.statusLabel),
                    if (credential.statusCheckedAt != null)
                      _buildDetailRow(
                        'Sinkron Terakhir',
                        credential.statusCheckedAt!.toLocal().toString(),
                      ),
                    if (credential.additionalData != null) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 16),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Informasi Tambahan',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...credential.additionalData!.entries.map(
                        (e) => _buildDetailRow(
                          e.key.replaceAll('_', ' ').toUpperCase(),
                          e.value.toString(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    // Verify JWT button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => VerificationDetailScreen(
                                  credential: credential),
                            ),
                          );
                        },
                        icon: const Icon(Icons.verified_user, size: 18),
                        label: const Text('Verifikasi Kredensial'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    // Tombol Lihat Raw JWT (hanya jika credential punya rawJwt)
                    if (credential.rawJwt != null &&
                        credential.rawJwt!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    JwtViewerScreen(credential: credential),
                              ),
                            );
                          },
                          icon: const Icon(Icons.code, size: 18),
                          label: const Text('Lihat Raw JWT'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primaryBlue,
                            side: const BorderSide(color: AppColors.primaryBlue),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textMedium,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Color _statusColor(CredentialModel credential) {
    switch (credential.status) {
      case 'ACTIVE':
        return AppColors.success;
      case 'REVOKED':
      case 'SUSPENDED':
      case 'EXPIRED':
        return AppColors.error;
      default:
        return AppColors.warning;
    }
  }

  static IconData _statusIcon(CredentialModel credential) {
    switch (credential.status) {
      case 'ACTIVE':
        return Icons.check_circle;
      case 'REVOKED':
      case 'SUSPENDED':
      case 'EXPIRED':
        return Icons.block;
      default:
        return Icons.help_outline;
    }
  }

  static String _statusLabel(CredentialModel credential) {
    if (credential.status == 'ACTIVE') {
      return 'Terverifikasi';
    }
    return credential.statusLabel;
  }
}
