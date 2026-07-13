import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/wallet_provider.dart';
import '../../utils/app_colors.dart';
import '../../widgets/credential_card.dart';
import '../../models/credential_model.dart';
import 'qr_scanner_screen.dart';
import '../verification/verification_detail_screen.dart';
import 'jwt_viewer_screen.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final walletProvider = context.watch<WalletProvider>();
    final credentials = walletProvider.credentials;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        color: AppColors.background,
        child: ClipRect(
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Dompet Digital',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.verified,
                                size: 16,
                                color: AppColors.primaryBlue,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  '${credentials.length} Kredensial',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primaryBlue,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip: 'Sinkron status kredensial',
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints.tightFor(
                            width: 36, height: 36),
                        icon: walletProvider.isSyncingStatuses
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.sync,
                                color: AppColors.primaryBlue),
                        onPressed: walletProvider.isSyncingStatuses
                            ? null
                            : () async {
                                final updated = await context
                                    .read<WalletProvider>()
                                    .syncCredentialStatuses();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Sinkronisasi selesai: $updated kredensial diperbarui',
                                      ),
                                    ),
                                  );
                                }
                              },
                      ),
                    ],
                  ),
                ),

                // Add Credential Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const QRScannerScreen(),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.primaryBlue.withValues(alpha: 0.3),
                          width: 2,
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color:
                                  AppColors.primaryBlue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.qr_code_scanner,
                              color: AppColors.primaryBlue,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tambah Kredensial Baru',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textDark,
                                ),
                              ),
                              Text(
                                'Scan QR Code dari Issuer',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMedium,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: AppColors.textLight,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Credentials List Header
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Kredensial Tersimpan',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Credentials List
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      await context.read<WalletProvider>().refreshWalletData();
                    },
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: credentials.isEmpty ? 1 : credentials.length,
                      itemBuilder: (context, index) {
                        if (credentials.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 120),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.folder_open_outlined,
                                  size: 80,
                                  color: AppColors.textLight
                                      .withValues(alpha: 0.5),
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
                              ],
                            ),
                          );
                        }

                        final credential = credentials[index];
                        final gradient = index % 2 == 0
                            ? AppColors.identityCardGradient
                            : AppColors.healthCardGradient;

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
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: const Text('Batal')),
                                  TextButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Hapus',
                                          style: TextStyle(
                                              color: AppColors.error))),
                                ],
                              ),
                            );
                          },
                          onDismissed: (direction) {
                            context
                                .read<WalletProvider>()
                                .removeCredential(credential.id);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Kredensial berhasil dihapus')),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: CredentialCard(
                              credential: credential,
                              gradient: gradient,
                              onTap: () =>
                                  _showCredentialDetail(context, credential),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
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
                    // View JWT VC button
                    if (credential.rawJwt != null && credential.rawJwt!.isNotEmpty)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => JwtViewerScreen(
                                    credential: credential),
                              ),
                            );
                          },
                          icon: const Icon(Icons.code, size: 18,
                              color: AppColors.primaryBlue),
                          label: Text(
                            credential.format == 'vc+sd-jwt'
                                ? 'Lihat SD-JWT VC'
                                : 'Lihat JWT VC',
                            style:
                                const TextStyle(color: AppColors.primaryBlue),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(color: AppColors.primaryBlue),
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
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
                    const SizedBox(height: 12),
                    // Delete Credential button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Hapus Kredensial?'),
                              content: const Text(
                                  'Apakah Anda yakin ingin menghapus kredensial ini dari Wallet?'),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Batal')),
                                TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Hapus',
                                        style: TextStyle(color: Colors.red))),
                              ],
                            ),
                          );
                          if (confirm == true && context.mounted) {
                            await context
                                .read<WalletProvider>()
                                .removeCredential(credential.id);
                            if (context.mounted) Navigator.pop(context);
                          }
                        },
                        icon: const Icon(Icons.delete_outline,
                            size: 18, color: AppColors.error),
                        label: const Text('Hapus Kredensial',
                            style: TextStyle(color: AppColors.error)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: AppColors.error),
                        ),
                      ),
                    ),
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
