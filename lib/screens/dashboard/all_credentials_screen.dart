import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/wallet_provider.dart';
import '../../utils/app_colors.dart';
import '../../widgets/credential_card.dart';
import '../../models/credential_model.dart';
import 'qr_scanner_screen.dart';
import 'jwt_viewer_screen.dart';
import '../verification/verification_detail_screen.dart';

class AllCredentialsScreen extends StatelessWidget {
  const AllCredentialsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final walletProvider = context.watch<WalletProvider>();

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
          'Semua Kredensial',
          style: TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await context.read<WalletProvider>().refreshWalletData();
        },
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          itemCount: walletProvider.credentials.isEmpty
              ? 1
              : walletProvider.credentials.length,
          itemBuilder: (context, index) {
            if (walletProvider.credentials.isEmpty) {
              return Padding(
                padding: const EdgeInsets.only(top: 140),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 80,
                      color: AppColors.textLight,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Belum ada kredensial',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMedium,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Tarik untuk refresh atau scan QR Code\nuntuk menambahkan kredensial',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textLight,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const QRScannerScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('Scan QR Code'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            final credential = walletProvider.credentials[index];
            final gradients = [
              AppColors.identityCardGradient,
              AppColors.healthCardGradient,
              AppColors.primaryGradient,
            ];

            return Dismissible(
              key: Key(credential.id),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.delete_outline,
                    color: Colors.white, size: 32),
              ),
              confirmDismiss: (direction) async {
                return await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Hapus Kredensial?'),
                    content: const Text(
                        'Apakah Anda yakin ingin menghapus kredensial ini?'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Batal')),
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Hapus',
                              style: TextStyle(color: AppColors.error))),
                    ],
                  ),
                );
              },
              onDismissed: (direction) {
                context.read<WalletProvider>().removeCredential(credential.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Kredensial berhasil dihapus')),
                );
              },
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: CredentialCard(
                  credential: credential,
                  gradient: gradients[index % gradients.length],
                  onTap: () => _showCredentialDetail(context, credential),
                ),
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const QRScannerScreen(),
            ),
          );
        },
        backgroundColor: AppColors.primaryBlue,
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('Scan QR'),
      ),
    );
  }

  void _showCredentialDetail(BuildContext context, CredentialModel credential) {
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
                          credential.statusLabel,
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
                    // Format badge
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Format: ${credential.formatLabel}',
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.primaryBlue,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
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

  Widget _buildDetailRow(String label, String value) {
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

  Color _statusColor(CredentialModel credential) {
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

  IconData _statusIcon(CredentialModel credential) {
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
}
