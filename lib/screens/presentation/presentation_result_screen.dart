import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/credential_model.dart';
import '../../providers/wallet_provider.dart';
import '../../utils/app_colors.dart';

/// Result screen after VP is submitted to verifier
class PresentationResultScreen extends StatefulWidget {
  final CredentialModel credential;
  final List<String> selectedClaims;
  final String descriptorId;
  final String verifierName;

  const PresentationResultScreen({
    super.key,
    required this.credential,
    required this.selectedClaims,
    required this.descriptorId,
    required this.verifierName,
  });

  @override
  State<PresentationResultScreen> createState() =>
      _PresentationResultScreenState();
}

class _PresentationResultScreenState extends State<PresentationResultScreen>
    with SingleTickerProviderStateMixin {
  bool _submitting = true;
  bool _success = false;
  String _statusMessage = 'Membangun Verifiable Presentation...';
  late AnimationController _animController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _scaleAnim =
        CurvedAnimation(parent: _animController, curve: Curves.elasticOut);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _submit();
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _statusMessage = 'Membangun Verifiable Presentation...';
    });

    final wallet = context.read<WalletProvider>();

    // Step progress via status stream
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted)
        setState(() => _statusMessage = 'Mengirim presentasi ke verifier...');
    });

    final success = await wallet.submitPresentation(
      credential: widget.credential,
      selectedClaims: widget.selectedClaims,
      descriptorId: widget.descriptorId,
    );

    if (!mounted) return;

    setState(() {
      _submitting = false;
      _success = success;
      _statusMessage = success
          ? 'Presentasi berhasil dikirim!'
          : wallet.presentationError ?? 'Gagal mengirim presentasi';
    });

    _animController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => !_submitting,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (_submitting) ...[
                        const SizedBox(
                          width: 100,
                          height: 100,
                          child: CircularProgressIndicator(
                            strokeWidth: 6,
                            valueColor:
                                AlwaysStoppedAnimation(AppColors.primaryBlue),
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          _statusMessage,
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        const Text('Mohon tunggu...',
                            style: TextStyle(color: AppColors.textMedium)),
                      ] else ...[
                        // Animated result icon
                        ScaleTransition(
                          scale: _scaleAnim,
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: _success
                                    ? [
                                        AppColors.success,
                                        AppColors.secondaryTeal
                                      ]
                                    : [
                                        AppColors.error,
                                        const Color(0xFFFF6B6B)
                                      ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: (_success
                                          ? AppColors.success
                                          : AppColors.error)
                                      .withValues(alpha: 0.3),
                                  blurRadius: 30,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: Icon(
                              _success
                                  ? Icons.check_circle_outline
                                  : Icons.error_outline,
                              color: Colors.white,
                              size: 60,
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),

                        Text(
                          _success
                              ? 'Verifikasi Berhasil!'
                              : 'Verifikasi Gagal',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color:
                                _success ? AppColors.success : AppColors.error,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 12),

                        Text(
                          _statusMessage,
                          style: const TextStyle(
                              fontSize: 15, color: AppColors.textMedium),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 32),

                        // Summary card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 12)
                            ],
                          ),
                          child: Column(
                            children: [
                              _summaryRow(Icons.business, 'Verifier',
                                  widget.verifierName),
                              const Divider(height: 20),
                              _summaryRow(Icons.credit_card, 'Credential',
                                  widget.credential.type),
                              const Divider(height: 20),
                              _summaryRow(
                                Icons.share,
                                'Data dibagikan',
                                '${widget.selectedClaims.length} field',
                              ),
                              const Divider(height: 20),
                              _summaryRow(
                                Icons.access_time,
                                'Waktu',
                                _formatTime(DateTime.now()),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Action buttons
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              // Pop all the way to main screen
                              Navigator.of(context).popUntil((r) => r.isFirst);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _success
                                  ? AppColors.success
                                  : AppColors.primaryBlue,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text('Kembali ke Beranda',
                                style: TextStyle(fontSize: 16)),
                          ),
                        ),

                        if (!_success) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: _submit,
                              style: OutlinedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14)),
                              child: const Text('Coba Lagi'),
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _summaryRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primaryBlue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.primaryBlue, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textLight,
                      fontWeight: FontWeight.w600)),
              Text(value,
                  style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textDark,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime t) {
    return '${t.day.toString().padLeft(2, '0')}/${t.month.toString().padLeft(2, '0')}/${t.year} '
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }
}
