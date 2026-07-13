import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/credential_model.dart';
import '../../models/verification_result_model.dart';
import '../../services/jwt_verifier_service.dart';
import '../../utils/app_colors.dart';

/// Screen showing full JWT verification details for a credential
class VerificationDetailScreen extends StatefulWidget {
  final CredentialModel credential;

  const VerificationDetailScreen({super.key, required this.credential});

  @override
  State<VerificationDetailScreen> createState() => _VerificationDetailScreenState();
}

class _VerificationDetailScreenState extends State<VerificationDetailScreen> {
  VerificationResult? _result;
  bool _loading = true;
  bool _showRawJwt = false;

  @override
  void initState() {
    super.initState();
    _verify();
  }

  Future<void> _verify() async {
    setState(() => _loading = true);
    try {
      VerificationResult result;
      if (widget.credential.rawJwt != null) {
        final jwt = widget.credential.rawJwt!.split('~')[0]; // Base JWT only
        result = await JWTVerifierService.verifyJWT(jwt);
      } else {
        result = VerificationResult(
          signatureValid: false,
          issuerTrusted: false,
          claimsValid: true,
          timingValid: true,
          errors: ['Credential tidak memiliki JWT (demo lokal, verifikasi offline tidak tersedia)'],
          claims: widget.credential.additionalData,
        );
      }
      if (mounted) setState(() { _result = result; _loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() {
          _result = VerificationResult.failure('Error: $e');
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Verifikasi Credential'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _verify,
            tooltip: 'Verifikasi ulang',
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Memverifikasi tanda tangan...', style: TextStyle(color: AppColors.textMedium)),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildOverallStatus(),
                  const SizedBox(height: 20),
                  _buildChecklist(),
                  const SizedBox(height: 20),
                  if (_result?.issuerDid != null) _buildIssuerCard(),
                  const SizedBox(height: 20),
                  if (_result?.claims != null && _result!.claims!.isNotEmpty)
                    _buildClaimsCard(),
                  const SizedBox(height: 20),
                  if (widget.credential.rawJwt != null) _buildRawJwtCard(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
    );
  }

  Widget _buildOverallStatus() {
    final ok = _result?.isFullyValid ?? false;
    final partial = (_result?.signatureValid != true) && (_result?.claimsValid == true);
    final color = ok ? AppColors.success : partial ? AppColors.warning : AppColors.error;
    final icon = ok ? Icons.verified : partial ? Icons.warning_amber : Icons.dangerous;
    final label = ok ? 'Terverifikasi Penuh' : partial ? 'Terverifikasi Sebagian' : 'Verifikasi Gagal';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.15), color.withValues(alpha: 0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 56),
          const SizedBox(height: 12),
          Text(label, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 6),
          Text(
            widget.credential.type,
            style: const TextStyle(fontSize: 14, color: AppColors.textMedium),
          ),
          if (_result?.algorithm != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Algoritma: ${_result!.algorithm}',
                style: const TextStyle(fontSize: 12, color: AppColors.primaryBlue, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChecklist() {
    final checks = [
      _Check('Tanda Tangan Digital', _result?.signatureValid, Icons.draw),
      _Check('Issuer Dapat Diverifikasi', _result?.issuerTrusted, Icons.business),
      _Check('Struktur Klaim Valid', _result?.claimsValid, Icons.list_alt),
      _Check('Waktu Berlaku Valid', _result?.timingValid, Icons.access_time),
    ];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Hasil Pemeriksaan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textDark)),
            const SizedBox(height: 12),
            ...checks.map((c) => _buildCheckRow(c)),
            if (_result?.errors.isNotEmpty == true) ...[
              const Divider(height: 24),
              ...(_result!.errors.map((e) => _buildErrorRow(e))),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCheckRow(_Check check) {
    final ok = check.value == true;
    final unknown = check.value == null;
    final color = ok ? AppColors.success : unknown ? AppColors.textLight : AppColors.error;
    final icon = ok ? Icons.check_circle : unknown ? Icons.help_outline : Icons.cancel;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(check.icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(check.label, style: const TextStyle(fontSize: 14, color: AppColors.textDark))),
          Icon(icon, color: color, size: 22),
        ],
      ),
    );
  }

  Widget _buildErrorRow(String error) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: AppColors.error, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(error, style: const TextStyle(fontSize: 12, color: AppColors.error))),
        ],
      ),
    );
  }

  Widget _buildIssuerCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Informasi Issuer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textDark)),
            const SizedBox(height: 12),
            _infoRow('DID', _result!.issuerDid!, selectable: true),
            _infoRow('Format', widget.credential.formatLabel),
          ],
        ),
      ),
    );
  }

  Widget _buildClaimsCard() {
    final claims = _result!.claims!;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Klaim Credential', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textDark)),
            const SizedBox(height: 12),
            ...claims.entries.map((e) => _infoRow(
              e.key.replaceAll('_', ' ').toUpperCase(),
              e.value?.toString() ?? '-',
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildRawJwtCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.code, color: AppColors.primaryBlue),
            title: const Text('Raw JWT', style: TextStyle(fontWeight: FontWeight.w600)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: widget.credential.rawJwt!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('JWT disalin ke clipboard')),
                    );
                  },
                ),
                IconButton(
                  icon: Icon(_showRawJwt ? Icons.expand_less : Icons.expand_more),
                  onPressed: () => setState(() => _showRawJwt = !_showRawJwt),
                ),
              ],
            ),
            onTap: () => setState(() => _showRawJwt = !_showRawJwt),
          ),
          if (_showRawJwt)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  widget.credential.rawJwt!,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: AppColors.textMedium),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, {bool selectable = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textLight, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          selectable
              ? SelectableText(value, style: const TextStyle(fontSize: 13, color: AppColors.textDark))
              : Text(value, style: const TextStyle(fontSize: 13, color: AppColors.textDark)),
        ],
      ),
    );
  }
}

class _Check {
  final String label;
  final bool? value;
  final IconData icon;
  _Check(this.label, this.value, this.icon);
}
