import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../utils/app_colors.dart';
import '../../utils/wib_time.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
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
    final activities = _buildActivities(auth, wallet);

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
          'Aktivitas',
          style: TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: activities.isEmpty
          ? const Center(
              child: Text(
                'Belum ada aktivitas terbaru.',
                style: TextStyle(color: AppColors.textMedium),
              ),
            )
          : ListView.builder(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              itemCount: activities.length,
              itemBuilder: (context, index) {
                final activity = activities[index];

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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        margin: const EdgeInsets.only(top: 5),
                        decoration: BoxDecoration(
                          color: activity.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    activity.title,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                ),
                                Text(
                                  WibTime.clock(activity.timestamp),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textLight,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              activity.subtitle,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textMedium,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${WibTime.dateLabel(activity.timestamp, nowWib: nowWib)} • ${WibTime.relative(activity.timestamp, nowWib: nowWib)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textLight,
                                fontWeight: FontWeight.w500,
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

  List<_ActivityItem> _buildActivities(
      AuthProvider auth, WalletProvider wallet) {
    final items = <_ActivityItem>[];

    for (final credential in wallet.credentials) {
      final isRevoked = credential.status == 'REVOKED';
      items.add(
        _ActivityItem(
          title: isRevoked ? 'Kredensial dicabut' : 'Tambah kredensial',
          subtitle: isRevoked
              ? '${credential.type} dicabut oleh penerbit'
              : '${credential.type} ditambahkan ke dompet',
          timestamp: credential.statusCheckedAt ?? credential.issuedDate,
          color: isRevoked ? AppColors.error : AppColors.success,
        ),
      );
    }

    for (final event in auth.loginHistory) {
      final ok = event.success;
      items.add(
        _ActivityItem(
          title: ok ? 'Login berhasil' : 'Login gagal',
          subtitle: 'Metode: ${event.method}',
          timestamp: event.timestamp,
          color: ok ? AppColors.success : AppColors.error,
        ),
      );
    }

    items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return items;
  }
}

class _ActivityItem {
  final String title;
  final String subtitle;
  final DateTime timestamp;
  final Color color;

  const _ActivityItem({
    required this.title,
    required this.subtitle,
    required this.timestamp,
    required this.color,
  });
}
