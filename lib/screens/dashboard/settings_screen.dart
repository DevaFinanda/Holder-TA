import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../utils/app_localizations.dart';
import '../../utils/app_colors.dart';
import '../auth/welcome_screen.dart';
import '../settings/edit_profile_screen.dart';
import '../settings/security_screen.dart';
import '../settings/verification_status_screen.dart';
import '../settings/language_screen.dart';
import '../settings/notification_settings_screen.dart';
import '../settings/display_settings_screen.dart';
import '../settings/help_screen.dart';
import '../settings/about_screen.dart';
import '../settings/terms_screen.dart';
import '../settings/privacy_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final settings = context.watch<AppSettingsProvider>();
    final walletProvider = context.watch<WalletProvider>();
    final user = authProvider.currentUser;
    final verifiedNik = walletProvider.preferredVerifiedNik;
    final displayNik = (verifiedNik != null && verifiedNik.isNotEmpty)
        ? verifiedNik
        : ((user?.nik.isNotEmpty ?? false) ? user!.nik : '-');
    final activeCredentialCount = walletProvider.credentials
        .where((credential) => credential.isActive)
        .length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        color: AppColors.background,
        child: ClipRect(
          child: SafeArea(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              clipBehavior: Clip.hardEdge,
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: EdgeInsets.all(20),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        context.tr('settings'),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                  ),

                  // Profile Card
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryBlue.withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Avatar
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Center(
                            child: user?.photoUrl != null &&
                                    user!.photoUrl!.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(20),
                                    child: Image.file(
                                      File(user.photoUrl!),
                                      width: 70,
                                      height: 70,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Text(
                                        user.initials,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 28,
                                        ),
                                      ),
                                    ),
                                  )
                                : Text(
                                    user?.initials ?? 'U',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 28,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // User Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.name ?? 'User',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                user?.email ?? '',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'NIK: $displayNik',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Edit Button
                        IconButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const EditProfileScreen(),
                              ),
                            );
                          },
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.edit_outlined,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Settings Sections
                  _buildSection(
                    context,
                    'Akun',
                    [
                      _SettingsItem(
                        icon: Icons.person_outline,
                        title: 'Edit Profil',
                        subtitle: 'Ubah informasi pribadi Anda',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const EditProfileScreen(),
                            ),
                          );
                        },
                      ),
                      _SettingsItem(
                        icon: Icons.security_outlined,
                        title: 'Keamanan',
                        subtitle: 'Password, biometrik, PIN',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const SecurityScreen(),
                            ),
                          );
                        },
                      ),
                      _SettingsItem(
                        icon: Icons.verified_user_outlined,
                        title: 'Verifikasi Identitas',
                        subtitle: activeCredentialCount > 0
                            ? '$activeCredentialCount kredensial aktif'
                            : 'Belum ada kredensial aktif',
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            activeCredentialCount > 0 ? 'Aktif' : 'Perlu cek',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.success,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const VerificationStatusScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),

                  _buildSection(
                    context,
                    'Preferensi',
                    [
                      _SettingsItem(
                        icon: Icons.language_outlined,
                        title: 'Bahasa',
                        subtitle: settings.languageLabel(
                            Localizations.localeOf(context).languageCode),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const LanguageScreen(),
                            ),
                          );
                        },
                      ),
                      _SettingsItem(
                        icon: Icons.notifications_outlined,
                        title: 'Notifikasi',
                        subtitle: 'Atur preferensi notifikasi',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  const NotificationSettingsScreen(),
                            ),
                          );
                        },
                      ),
                      _SettingsItem(
                        icon: Icons.dark_mode_outlined,
                        title: 'Tampilan',
                        subtitle:
                            '${settings.themeLabel(Localizations.localeOf(context).languageCode)} • Teks ${(settings.fontScale * 100).round()}%',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const DisplaySettingsScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),

                  _buildSection(
                    context,
                    'Lainnya',
                    [
                      _SettingsItem(
                        icon: Icons.help_outline,
                        title: 'Bantuan',
                        subtitle: 'FAQ & Pusat bantuan',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const HelpScreen(),
                            ),
                          );
                        },
                      ),
                      _SettingsItem(
                        icon: Icons.info_outline,
                        title: 'Tentang Aplikasi',
                        subtitle: 'Versi 1.0.0',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const AboutScreen(),
                            ),
                          );
                        },
                      ),
                      _SettingsItem(
                        icon: Icons.description_outlined,
                        title: 'Syarat & Ketentuan',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const TermsScreen(),
                            ),
                          );
                        },
                      ),
                      _SettingsItem(
                        icon: Icons.privacy_tip_outlined,
                        title: 'Kebijakan Privasi',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const PrivacyScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),

                  // Logout Button
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: () => _showLogoutDialog(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              AppColors.error.withValues(alpha: 0.1),
                          foregroundColor: AppColors.error,
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.logout),
                        label: const Text(
                          'Keluar',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Footer
                  const Padding(
                    padding: EdgeInsets.only(bottom: 100),
                    child: Text(
                      'IDentia v1.0.0',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textLight,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    List<_SettingsItem> items,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textMedium,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Column(
              children: items.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return Column(
                  children: [
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          item.icon,
                          color: AppColors.primaryBlue,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        item.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textDark,
                        ),
                      ),
                      subtitle: item.subtitle != null
                          ? Text(
                              item.subtitle!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMedium,
                              ),
                            )
                          : null,
                      trailing: item.trailing ??
                          const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: AppColors.textLight,
                          ),
                      onTap: item.onTap,
                    ),
                    if (index < items.length - 1)
                      Divider(
                        height: 1,
                        indent: 60,
                        color: AppColors.textLight.withValues(alpha: 0.2),
                      ),
                  ],
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Row(
          children: [
            Icon(
              Icons.logout,
              color: AppColors.error,
            ),
            SizedBox(width: 12),
            Text('Keluar'),
          ],
        ),
        content: const Text(
          'Apakah Anda yakin ingin keluar dari akun Anda?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await context.read<AuthProvider>().logout();
              context.read<WalletProvider>().clearWalletSession();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
  }
}

class _SettingsItem {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  _SettingsItem({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.onTap,
  });
}
