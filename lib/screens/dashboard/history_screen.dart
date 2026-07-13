import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../utils/app_colors.dart';
import '../../utils/wib_time.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final wallet = context.watch<WalletProvider>();
    final nowWib = WibTime.now();
    final historyItems = _buildHistory(auth, wallet);

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
          'Riwayat',
          style: TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: historyItems.isEmpty
          ? const Center(
              child: Text(
                'Belum ada riwayat aktivitas.',
                style: TextStyle(color: AppColors.textMedium),
              ),
            )
          : ListView.builder(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              itemCount: historyItems.length,
              itemBuilder: (context, index) {
                final item = historyItems[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: item.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          item.icon,
                          color: item.color,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.subtitle,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textMedium,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${WibTime.relative(item.timestamp, nowWib: nowWib)} • ${WibTime.clock(item.timestamp)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  List<_HistoryEntry> _buildHistory(AuthProvider auth, WalletProvider wallet) {
    final items = <_HistoryEntry>[];

    for (final event in auth.loginHistory) {
      final method = event.method.trim().toLowerCase();
      final title = method == 'logout'
          ? 'Keluar akun'
          : method == 'register'
              ? 'Registrasi akun'
              : method == 'biometric'
                  ? 'Login biometrik'
                  : 'Login akun';
      final subtitle = event.success
          ? 'Berhasil melalui ${event.method}'
          : 'Gagal melalui ${event.method}';
      final icon = method == 'biometric' ? Icons.fingerprint : Icons.login;

      items.add(
        _HistoryEntry(
          id: 'login-${event.timestamp.millisecondsSinceEpoch}-$method',
          title: title,
          subtitle: subtitle,
          timestamp: event.timestamp,
          icon: icon,
          color: event.success ? AppColors.success : AppColors.error,
        ),
      );
    }

    for (final credential in wallet.credentials) {
      final isRevoked = credential.status == 'REVOKED';
      items.add(
        _HistoryEntry(
          id: 'credential-${credential.id}',
          title: isRevoked ? 'Kredensial dicabut' : 'Kredensial tersimpan',
          subtitle: isRevoked
              ? '${credential.type} dicabut oleh penerbit'
              : '${credential.type} dari ${credential.issuer}',
          timestamp: credential.statusCheckedAt ?? credential.issuedDate,
          icon: isRevoked ? Icons.block : Icons.badge_outlined,
          color: isRevoked ? AppColors.error : AppColors.primaryBlue,
        ),
      );
    }

    items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return items;
  }
}

class _HistoryEntry {
  final String id;
  final String title;
  final String subtitle;
  final DateTime timestamp;
  final IconData icon;
  final Color color;

  const _HistoryEntry({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.timestamp,
    required this.icon,
    required this.color,
  });
}
