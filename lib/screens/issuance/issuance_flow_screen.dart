import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../utils/app_colors.dart';
import '../dashboard/main_screen.dart';

// ignore_for_file: unused_import

/// Screen showing step-by-step progress of OID4VCI credential issuance
class IssuanceFlowScreen extends StatefulWidget {
  final String deepLink;
  final String clientId;
  final String redirectUri;

  const IssuanceFlowScreen({
    super.key,
    required this.deepLink,
    this.clientId = '',
    this.redirectUri = 'identia://callback',
  });

  @override
  State<IssuanceFlowScreen> createState() => _IssuanceFlowScreenState();
}

class _IssuanceFlowScreenState extends State<IssuanceFlowScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _started = false;

  final List<_IssuanceStep> _steps = [
    _IssuanceStep(
        label: 'Memproses Offer',
        icon: Icons.qr_code,
        status: IssuanceStatus.parsingOffer),
    _IssuanceStep(
        label: 'Metadata Issuer',
        icon: Icons.cloud_download,
        status: IssuanceStatus.fetchingMetadata),
    _IssuanceStep(
        label: 'Proses Autentikasi',
        icon: Icons.login,
        status: IssuanceStatus.authorizing),
    _IssuanceStep(
        label: 'Tukar Token',
        icon: Icons.swap_horiz,
        status: IssuanceStatus.exchangingToken),
    _IssuanceStep(
        label: 'Buat Proof JWT',
        icon: Icons.vpn_key,
        status: IssuanceStatus.buildingProof),
    _IssuanceStep(
        label: 'Ambil Credential',
        icon: Icons.credit_card,
        status: IssuanceStatus.requestingCredential),
    _IssuanceStep(
        label: 'Simpan',
        icon: Icons.check_circle,
        status: IssuanceStatus.saved),
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Always start from a clean state for each new credential offer session.
      context.read<WalletProvider>().resetIssuanceStatus();
      _startFlow();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _startFlow() {
    if (_started) return;
    _started = true;
    final provider = context.read<WalletProvider>();
    final auth = context.read<AuthProvider>();
    provider.startIssuanceFlow(
      widget.deepLink,
      clientId: widget.clientId,
      redirectUri: widget.redirectUri,
      authIdentifier: auth.currentUser?.nik,
      authPassword: auth.currentAccountPassword,
      userNik: auth.currentUser?.nik,
    );
  }

  void _cancelToHome(WalletProvider wallet) {
    wallet.resetIssuanceStatus();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WalletProvider>(
      builder: (context, wallet, _) {
        final status = wallet.issuanceStatus;
        final isDone = status == IssuanceStatus.saved;
        final isError = status == IssuanceStatus.error;

        return PopScope(
          canPop: isDone || isError,
          child: Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              title: const Text('Mendapatkan Credential'),
              backgroundColor: Colors.transparent,
              automaticallyImplyLeading: isDone || isError,
            ),
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),

                    // Top icon
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (_, child) => Transform.scale(
                        scale: isDone || isError
                            ? 1.0
                            : 1.0 + _pulseController.value * 0.08,
                        child: child,
                      ),
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: isDone
                              ? const LinearGradient(colors: [
                                  AppColors.success,
                                  AppColors.secondaryTeal
                                ])
                              : isError
                                  ? const LinearGradient(colors: [
                                      AppColors.error,
                                      Color(0xFFFF6B6B)
                                    ])
                                  : AppColors.primaryGradient,
                        ),
                        child: Icon(
                          isDone
                              ? Icons.verified
                              : isError
                                  ? Icons.error
                                  : Icons.sync,
                          color: Colors.white,
                          size: 50,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    Text(
                      isDone
                          ? 'Credential Diterima!'
                          : isError
                              ? 'Terjadi Kesalahan'
                              : 'Memproses Issuance...',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isDone
                                    ? AppColors.success
                                    : isError
                                        ? AppColors.error
                                        : AppColors.textDark,
                              ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      wallet.issuanceMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: AppColors.textMedium, fontSize: 14),
                    ),

                    const SizedBox(height: 32),

                    // Steps list
                    Expanded(
                      child: ListView.separated(
                        itemCount: _steps.length,
                        separatorBuilder: (_, i) => const SizedBox(height: 0),
                        itemBuilder: (_, i) {
                          final step = _steps[i];
                          final stepIndex =
                              _steps.indexWhere((s) => s.status == status);
                          final currentIndex = stepIndex == -1 ? 0 : stepIndex;

                          _StepState stepState;
                          if (isError && i == currentIndex) {
                            stepState = _StepState.error;
                          } else if (isDone || i < currentIndex) {
                            stepState = _StepState.done;
                          } else if (i == currentIndex) {
                            stepState = _StepState.active;
                          } else {
                            stepState = _StepState.pending;
                          }

                          return _buildStepTile(
                              step, stepState, i == _steps.length - 1);
                        },
                      ),
                    ),

                    // Error message box - scrollable, max height capped
                    if (isError && wallet.issuanceError != null) ...[
                      _buildErrorCard(context, wallet.issuanceError!),
                      const SizedBox(height: 16),
                    ],

                    // Action buttons
                    if (isDone || isError) ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            wallet.resetIssuanceStatus();
                            Navigator.of(context).pop();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDone
                                ? AppColors.success
                                : AppColors.primaryBlue,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: Text(isDone ? 'Lihat Wallet' : 'Tutup'),
                        ),
                      ),
                      if (isError) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () {
                              wallet.resetIssuanceStatus();
                              _started = false;
                              _startFlow();
                            },
                            child: const Text('Coba Lagi'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () {
                              _cancelToHome(wallet);
                            },
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.error),
                            ),
                            child: const Text(
                              'Batal',
                              style: TextStyle(color: AppColors.error),
                            ),
                          ),
                        ),
                      ],
                    ] else if (status == IssuanceStatus.authorizing) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () {
                            _cancelToHome(wallet);
                          },
                          style: OutlinedButton.styleFrom(
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
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorCard(BuildContext context, String errorMsg) {
    // Auto-diagnosis hint based on error content
    String? hint;
    if (errorMsg.contains('404') ||
        errorMsg.contains('kedaluwarsa') ||
        errorMsg.contains('tidak ditemukan')) {
      hint =
          '⏱ Credential Offer biasanya hanya berlaku 10 menit. Minta QR Code baru dari Issuer.';
    } else if (errorMsg.contains('HTML') || errorMsg.contains('endpoint')) {
      hint = '⚠️ Kemungkinan masalah di sisi Issuer — endpoint belum tersedia.';
    } else if (errorMsg.contains('SocketException') ||
        errorMsg.contains('TimeoutException') ||
        errorMsg.contains('HandshakeException')) {
      hint = '🌐 Periksa koneksi internet atau sertifikat HTTPS Issuer.';
    } else if (errorMsg.contains('401') || errorMsg.contains('403')) {
      hint = '🔑 Sesi login Issuer mungkin sudah berakhir.';
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 0),
            child: Row(
              children: [
                const Icon(Icons.error_outline,
                    color: AppColors.error, size: 18),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text('Detail Error',
                      style: TextStyle(
                          color: AppColors.error,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                ),
                IconButton(
                  icon:
                      const Icon(Icons.copy, color: AppColors.error, size: 18),
                  tooltip: 'Salin pesan error',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: errorMsg));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Pesan error disalin'),
                          duration: Duration(seconds: 1)),
                    );
                  },
                ),
              ],
            ),
          ),
          // Scrollable error message
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Text(
                errorMsg,
                style: const TextStyle(
                    color: AppColors.error, fontSize: 12, height: 1.4),
              ),
            ),
          ),
          // Diagnosis hint
          if (hint != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.08),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(11),
                  bottomRight: Radius.circular(11),
                ),
              ),
              child: Text(hint,
                  style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.warning,
                      fontWeight: FontWeight.w500)),
            ),
        ],
      ),
    );
  }

  Widget _buildStepTile(_IssuanceStep step, _StepState state, bool isLast) {
    final Color color;
    final IconData icon;
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
                  ? CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(color),
                    )
                  : Icon(icon, color: color, size: 22),
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
        const SizedBox(width: 16),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 28),
            child: Text(
              step.label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: state == _StepState.active
                    ? FontWeight.w600
                    : FontWeight.normal,
                color:
                    state == _StepState.pending ? AppColors.textLight : color,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _IssuanceStep {
  final String label;
  final IconData icon;
  final IssuanceStatus status;
  _IssuanceStep(
      {required this.label, required this.icon, required this.status});
}

enum _StepState { pending, active, done, error }
