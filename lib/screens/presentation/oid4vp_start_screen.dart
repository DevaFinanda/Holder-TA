import 'package:flutter/material.dart';

import '../../services/oid4vp_start_service.dart';
import '../../utils/app_colors.dart';

class OID4VPStartScreen extends StatefulWidget {
  const OID4VPStartScreen({super.key});

  @override
  State<OID4VPStartScreen> createState() => _OID4VPStartScreenState();
}

class _OID4VPStartScreenState extends State<OID4VPStartScreen> {
  final TextEditingController _backendController =
      TextEditingController(text: 'https://verifier.identia.my.id');

  bool _loading = false;
  String? _error;
  OID4VPStartResult? _result;

  @override
  void dispose() {
    _backendController.dispose();
    super.dispose();
  }

  Future<void> _startAndOpen() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });

    try {
      final result = await OID4VPStartService.startVerification(
        backendBaseUrl: _backendController.text,
      );

      final opened = await OID4VPStartService.launchRequestLink(result);
      if (!opened) {
        throw Exception(
            'Tidak dapat membuka deepLink/requestUri dari verifier');
      }

      if (!mounted) return;
      setState(() {
        _result = result;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OID4VP request berhasil dibuka.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mulai Verifikasi OID4VP')),
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Backend Verifier URL',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _backendController,
              decoration: const InputDecoration(
                hintText: 'https://verifier.identia.my.id',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _startAndOpen,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Start OID4VP'),
              ),
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppColors.error),
                ),
              ),
            if (_result != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Berhasil memulai verifikasi',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text('requestUri: ${_result!.requestUri}'),
                    Text('deepLink: ${_result!.deepLink ?? '-'}'),
                  ],
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
