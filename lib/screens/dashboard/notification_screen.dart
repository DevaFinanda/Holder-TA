import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../utils/app_colors.dart';
import '../../utils/wib_time.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final Set<String> _readIds = <String>{};
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
    final notifications = _buildNotifications(auth, wallet);

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
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                for (final item in notifications) {
                  _readIds.add(item.id);
                }
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Semua notifikasi ditandai sudah dibaca'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Tandai Semua Dibaca'),
          ),
        ],
      ),
      body: notifications.isEmpty
          ? const Center(
              child: Text(
                'Belum ada notifikasi.',
                style: TextStyle(color: AppColors.textMedium),
              ),
            )
          : ListView.builder(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notification = notifications[index];
                final isRead = _readIds.contains(notification.id);

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: isRead
                        ? Colors.white
                        : AppColors.primaryBlue.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isRead
                          ? Colors.transparent
                          : AppColors.primaryBlue.withValues(alpha: 0.1),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        setState(() {
                          _readIds.add(notification.id);
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Membuka: ${notification.title}'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color:
                                    notification.color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                notification.icon,
                                color: notification.color,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          notification.title,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: isRead
                                                ? FontWeight.w600
                                                : FontWeight.bold,
                                            color: AppColors.textDark,
                                          ),
                                        ),
                                      ),
                                      if (!isRead)
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            color: AppColors.primaryBlue,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    notification.message,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textMedium,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${WibTime.relative(notification.timestamp)} • ${WibTime.clock(notification.timestamp)}',
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
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  List<_NotificationItem> _buildNotifications(
    AuthProvider auth,
    WalletProvider wallet,
  ) {
    final list = <_NotificationItem>[];

    for (final credential in wallet.credentials) {
      final isRevoked = credential.status == 'REVOKED';
      list.add(
        _NotificationItem(
          id: 'credential-${credential.id}',
          title: isRevoked
              ? 'Kredensial dicabut penerbit'
              : 'Kredensial baru ditambahkan',
          message: isRevoked
              ? '${credential.type} sudah dicabut oleh penerbit'
              : '${credential.type} berhasil ditambahkan ke dompet Anda',
          timestamp: credential.statusCheckedAt ?? credential.issuedDate,
          icon: isRevoked ? Icons.block : Icons.add_card,
          color: isRevoked ? AppColors.error : AppColors.primaryBlue,
        ),
      );
    }

    for (final event in auth.loginHistory.where((e) => !e.success)) {
      list.add(
        _NotificationItem(
          id: 'login-failed-${event.timestamp.millisecondsSinceEpoch}',
          title: 'Login gagal',
          message: 'Percobaan login gagal melalui ${event.method}.',
          timestamp: event.timestamp,
          icon: Icons.warning_amber_rounded,
          color: AppColors.warning,
        ),
      );
    }

    if (wallet.lastStatusSyncAt != null) {
      list.add(
        _NotificationItem(
          id: 'status-sync-${wallet.lastStatusSyncAt!.millisecondsSinceEpoch}',
          title: 'Sinkronisasi kredensial',
          message: 'Status kredensial telah diperbarui dari penerbit.',
          timestamp: wallet.lastStatusSyncAt!,
          icon: Icons.sync,
          color: AppColors.secondaryTeal,
        ),
      );
    }

    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  }
}

class _NotificationItem {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final IconData icon;
  final Color color;

  const _NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.icon,
    required this.color,
  });
}
