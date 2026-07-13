import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_settings_provider.dart';
import '../../utils/app_colors.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();

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
          'Notifikasi',
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
            // Channel Settings
            const Text(
              'Saluran Notifikasi',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 12),

            _buildToggleCard(
              icon: Icons.notifications_active,
              title: 'Push Notification',
              subtitle: 'Notifikasi pada perangkat',
              value: settings.pushNotifications,
              onChanged: (value) => context
                  .read<AppSettingsProvider>()
                  .setPushNotifications(value),
            ),
            const SizedBox(height: 12),

            _buildToggleCard(
              icon: Icons.email,
              title: 'Email',
              subtitle: 'Terima notifikasi via email',
              value: settings.emailNotifications,
              onChanged: (value) => context
                  .read<AppSettingsProvider>()
                  .setEmailNotifications(value),
            ),
            const SizedBox(height: 12),

            _buildToggleCard(
              icon: Icons.sms,
              title: 'SMS',
              subtitle: 'Terima notifikasi via SMS',
              value: settings.smsNotifications,
              onChanged: (value) => context
                  .read<AppSettingsProvider>()
                  .setSmsNotifications(value),
            ),

            const SizedBox(height: 32),

            // Notification Types
            const Text(
              'Jenis Notifikasi',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 12),

            _buildToggleCard(
              icon: Icons.update,
              title: 'Update Kredensial',
              subtitle: 'Perubahan pada kredensial Anda',
              value: settings.credentialUpdates,
              onChanged: (value) => context
                  .read<AppSettingsProvider>()
                  .setCredentialUpdates(value),
            ),
            const SizedBox(height: 12),

            _buildToggleCard(
              icon: Icons.security,
              title: 'Alert Keamanan',
              subtitle: 'Aktivitas mencurigakan',
              value: settings.securityAlerts,
              onChanged: (value) =>
                  context.read<AppSettingsProvider>().setSecurityAlerts(value),
            ),
            const SizedBox(height: 12),

            _buildToggleCard(
              icon: Icons.receipt,
              title: 'Transaksi',
              subtitle: 'Notifikasi transaksi dan akses',
              value: settings.transactionNotif,
              onChanged: (value) => context
                  .read<AppSettingsProvider>()
                  .setTransactionNotif(value),
            ),
            const SizedBox(height: 12),

            _buildToggleCard(
              icon: Icons.campaign,
              title: 'Promosi & Berita',
              subtitle: 'Info promo dan update aplikasi',
              value: settings.promotions,
              onChanged: (value) =>
                  context.read<AppSettingsProvider>().setPromotions(value),
            ),

            const SizedBox(height: 32),

            // Info Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppColors.primaryBlue,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Notifikasi penting untuk keamanan tidak dapat dinonaktifkan',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primaryBlue, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textMedium,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primaryBlue,
          ),
        ],
      ),
    );
  }
}
