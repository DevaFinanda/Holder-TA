import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/wallet_provider.dart';
import '../../utils/app_colors.dart';

/// IDentia Credential Issuance — Step 2: Progress Screen
///
/// Displays a 5-step animated progress flow:
///   Get Holder DID → Request Credential → Receive VC → Validate VC → Save Credential
class IdentiaIssuanceScreen extends StatefulWidget {
  final String issuerBaseUrl;
  final String sessionToken;
  final String holderDid;

  const IdentiaIssuanceScreen({
    super.key,
    required this.issuerBaseUrl,
    required this.sessionToken,
    required this.holderDid,
  });

  @override
  State<IdentiaIssuanceScreen> createState() => _IdentiaIssuanceScreenState();
}

class _IdentiaIssuanceScreenState extends State<IdentiaIssuanceScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _started = false;

  static const _steps = [
    _IssuanceStep(
      label: 'Ambil Holder DID',
      icon: Icons.fingerprint,
      status: IdentiaFlowStatus.gettingHolderDid,
    ),
    _IssuanceStep(
      label: 'Request Credential',
      icon: Icons.send_outlined,
      status: IdentiaFlowStatus.requestingCredential,
    ),
    _IssuanceStep(
      label: 'Terima Credential',
      icon: Icons.download_outlined,
      status: IdentiaFlowStatus.receivingCredential,
    ),
    _IssuanceStep(
      label: 'Validasi Credential',
      icon: Icons.verified_user_outlined,
      status: IdentiaFlowStatus.validatingCredential,
    ),
    _IssuanceStep(
      label: 'Simpan ke Wallet',
      icon: Icons.check_circle_outline,
      status: IdentiaFlowStatus.saving,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) => _startFlow());
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _startFlow() {
    if (_started) return;
    _started = true;
    context.read<WalletProvider>().startIdentiaIssuanceFlow(
          issuerBaseUrl: widget.issuerBaseUrl,
          sessionToken: widget.sessionToken,
          holderDid: widget.holderDid,
        );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WalletProvider>(
      builder: (context, wallet, _) {
        final status = wallet.identiaFlowStatus;
        final isDone = status == IdentiaFlowStatus.done;
        final isError = status == IdentiaFlowStatus.error;

        return PopScope(
          canPop: isDone || isError,
          child: Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              title: const Text('Mendapatkan Credential'),
              backgroundColor: Colors.transparent,
              elevation: 0,
              foregroundColor: AppColors.textDark,
              automaticallyImplyLeading: isDone || isError,
            ),
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 16),

                    // Animated top icon
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (_, child) => Transform.scale(
                        scale: isDone || isError
                            ? 1.0
                            : 1.0 + _pulseController.value * 0.07,
                        child: child,
                      ),
                      child: Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: isDone
                              ? const LinearGradient(
                                  colors: [AppColors.success, AppColors.secondaryTeal])
                              : isError
                                  ? const LinearGradient(
                                      colors: [AppColors.error, Color(0xFFFF6B6B)])
                                  : AppColors.primaryGradient,
                          boxShadow: [
                            BoxShadow(
                              color: (isDone
                                      ? AppColors.success
                                      : isError
                                          ? AppColors.error
                                          : AppColors.primaryBlue)
                                  .withValues(alpha: 0.25),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            )
                          ],
                        ),
                        child: Icon(
                          isDone
                              ? Icons.verified
                              : isError
                                  ? Icons.error_outline
                                  : Icons.sync,
                          color: Colors.white,
                          size: 48,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    Text(
                      isDone
                          ? 'Credential Diterima!'
                          : isError
                              ? 'Terjadi Kesalahan'
                              : 'Memproses Credential...',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isDone
                                ? AppColors.success
                                : isError
                                    ? AppColors.error
                                    : AppColors.textDark,
                          ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      wallet.identiaFlowMessage,
                      textAlign: TextAlign.center,
                      style:
                          const TextStyle(color: AppColors.textMedium, fontSize: 14),
                    ),

                    const SizedBox(height: 28),

                    // Step list
                    Expanded(
                      child: ListView.builder(
                        itemCount: _steps.length,
                        itemBuilder: (_, i) {
                          final step = _steps[i];
                          final isLast = i == _steps.length - 1;
                          final currentIdx = _currentStepIndex(status);
                          final stepState = _resolveStepState(i, currentIdx, isError);
                          return _buildStepTile(step, stepState, isLast);
                        },
                      ),
                    ),

                    // Error card
                    if (isError && wallet.identiaFlowError != null) ...[
                      _buildErrorCard(context, wallet.identiaFlowError!),
                      const SizedBox(height: 16),
                    ],

                    // Action buttons
                    if (isDone || isError) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () {
                            wallet.resetIdentiaFlowStatus();
                            Navigator.of(context).pop();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                isDone ? AppColors.success : AppColors.primaryBlue,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Text(
                            isDone ? 'Lihat Wallet' : 'Tutup',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      if (isError) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton(
                            onPressed: () {
                              wallet.resetIdentiaFlowStatus();
                              _started = false;
                              _startFlow();
                            },
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            child: const Text('Coba Lagi'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton(
                            onPressed: () {
                              wallet.resetIdentiaFlowStatus();
                              Navigator.of(context).pop();
                            },
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              side: const BorderSide(color: AppColors.error),
                            ),
                            child: const Text(
                              'Batal',
                              style: TextStyle(color: AppColors.error),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  int _currentStepIndex(IdentiaFlowStatus status) {
    switch (status) {
      case IdentiaFlowStatus.gettingHolderDid:
        return 0;
      case IdentiaFlowStatus.requestingCredential:
        return 1;
      case IdentiaFlowStatus.receivingCredential:
        return 2;
      case IdentiaFlowStatus.validatingCredential:
        return 3;
      case IdentiaFlowStatus.saving:
      case IdentiaFlowStatus.done:
        return 4;
      case IdentiaFlowStatus.error:
        return _steps.indexWhere((s) => s.status == IdentiaFlowStatus.validatingCredential);
      default:
        return 0;
    }
  }

  _StepState _resolveStepState(int i, int currentIdx, bool isError) {
    if (isError && i == currentIdx) return _StepState.error;
    if (i < currentIdx) return _StepState.done;
    if (i == currentIdx) return _StepState.active;
    return _StepState.pending;
  }

  Widget _buildStepTile(_IssuanceStep step, _StepState state, bool isLast) {
    late Color color;
    late IconData icon;
    switch (state) {
      case _StepState.done:
        color = AppColors.success;
        icon = Icons.check_circle;
      case _StepState.active:
        color = AppColors.primaryBlue;
        icon = step.icon;
      case _StepState.error:
        color = AppColors.error;
        icon = Icons.error;
      case _StepState.pending:
        color = AppColors.textLight;
        icon = step.icon;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: state == _StepState.pending
                    ? AppColors.background
                    : color.withValues(alpha: 0.12),
                border: Border.all(
                  color: state == _StepState.pending
                      ? AppColors.textLight.withValues(alpha: 0.3)
                      : color,
                  width: 2,
                ),
              ),
              child: state == _StepState.active
                  ? Padding(
                      padding: const EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation(color),
                      ),
                    )
                  : Icon(icon, color: color, size: 21),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 28,
                color: state == _StepState.done
                    ? AppColors.success.withValues(alpha: 0.4)
                    : AppColors.textLight.withValues(alpha: 0.2),
              ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(top: 10, bottom: isLast ? 0 : 28),
            child: Text(
              step.label,
              style: TextStyle(
                fontSize: 14,
                fontWeight:
                    state == _StepState.active ? FontWeight.w600 : FontWeight.normal,
                color: state == _StepState.pending ? AppColors.textLight : color,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorCard(BuildContext context, String errorMsg) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 180),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 0),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: AppColors.error, size: 17),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Detail Error',
                    style: TextStyle(
                        color: AppColors.error,
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, color: AppColors.error, size: 17),
                  tooltip: 'Salin pesan error',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: errorMsg));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Pesan error disalin'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
              child: Text(
                errorMsg,
                style:
                    const TextStyle(color: AppColors.error, fontSize: 12, height: 1.4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Internal data types ────────────────────────────────────────────────────

class _IssuanceStep {
  final String label;
  final IconData icon;
  final IdentiaFlowStatus status;
  const _IssuanceStep(
      {required this.label, required this.icon, required this.status});
}

enum _StepState { pending, active, done, error }
