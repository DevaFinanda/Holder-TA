import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/credential_model.dart';
import '../../models/presentation_models.dart';
import '../../providers/wallet_provider.dart';
import '../../utils/app_colors.dart';
import 'presentation_result_screen.dart';

/// Consent screen for OID4VP: shows what claims will be shared and asks for approval
class PresentationConsentScreen extends StatefulWidget {
  final String qrData;

  const PresentationConsentScreen({super.key, required this.qrData});

  @override
  State<PresentationConsentScreen> createState() => _PresentationConsentScreenState();
}

class _PresentationConsentScreenState extends State<PresentationConsentScreen> {
  PresentationRequest? _request;
  CredentialModel? _selectedCredential;
  List<String> _selectedClaims = [];
  bool _loading = true;
  String? _error;
  String _descriptorId = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prepareRequest();
    });
  }

  Future<void> _prepareRequest() async {
    setState(() { _loading = true; _error = null; });
    final wallet = context.read<WalletProvider>();
    final request = await wallet.preparePresentationRequest(widget.qrData);
    
    if (!mounted) return;
    
    if (request == null) {
      setState(() {
        _loading = false;
        _error = wallet.presentationError ?? 'Gagal memproses request verifikasi';
      });
      return;
    }

    // Pre-select first matched credential
    final matches = wallet.matchedCredentials;
    CredentialModel? cred;
    if (matches.isNotEmpty) {
      cred = matches.first.credential;
      _descriptorId = matches.first.descriptorId;
      // Pre-select all requested fields
      _selectedClaims = matches.first.requestedFields;
    } else if (wallet.credentials.isNotEmpty) {
      cred = wallet.credentials.first;
    }

    // If no explicit fields requested, use all available claims
    if (_selectedClaims.isEmpty && cred?.additionalData != null) {
      _selectedClaims = cred!.additionalData!.keys.toList();
    }

    setState(() {
      _request = request;
      _selectedCredential = cred;
      _loading = false;
    });
  }

  List<String> _getAvailableClaims() {
    if (_selectedCredential == null) return [];
    final claims = <String>[
      if (_selectedCredential!.holderName.isNotEmpty) 'holderName',
      if (_selectedCredential!.documentNumber.isNotEmpty) 'nik',
      ..._selectedCredential!.additionalData?.keys.toList() ?? [],
    ];
    return claims.toSet().toList();
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Permintaan Data'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Memuat permintaan verifikasi...', style: TextStyle(color: AppColors.textMedium)),
              ],
            ))
          : _error != null
              ? _buildErrorState()
              : _buildConsentContent(wallet),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppColors.error),
            const SizedBox(height: 16),
            const Text('Gagal Memuat Permintaan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark)),
            const SizedBox(height: 8),
            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMedium)),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _prepareRequest, child: const Text('Coba Lagi')),
            const SizedBox(height: 12),
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Batal')),
          ],
        ),
      ),
    );
  }

  Widget _buildConsentContent(WalletProvider wallet) {
    final verifier = _request?.clientId ?? 'Verifier';
    final purpose = _request?.presentationDefinition?.purpose ??
        _request?.presentationDefinition?.name ??
        'Verifikasi identitas';

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Verifier card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primaryBlue.withValues(alpha: 0.12), AppColors.primaryBlue.withValues(alpha: 0.04)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 56, height: 56,
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.verified_user, color: Colors.white, size: 28),
                      ),
                      const SizedBox(height: 12),
                      Text(verifier, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark), textAlign: TextAlign.center),
                      const SizedBox(height: 6),
                      Text(purpose, style: const TextStyle(fontSize: 13, color: AppColors.textMedium), textAlign: TextAlign.center),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                const Text('Credential yang Digunakan', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                const SizedBox(height: 10),

                // Credential selector
                if (wallet.credentials.isNotEmpty)
                  ...wallet.credentials.map((cred) => _buildCredentialOption(cred)),

                const SizedBox(height: 20),
                const Text('Data yang Akan Dibagikan', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                const SizedBox(height: 4),
                const Text('Pilih data yang ingin Anda bagikan:', style: TextStyle(fontSize: 12, color: AppColors.textMedium)),
                const SizedBox(height: 10),

                // Claims selector
                ..._getAvailableClaims().map((claim) => _buildClaimCheckbox(claim)),

                if (_request?.nonce != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.security, color: AppColors.info, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Anti-replay nonce disertakan untuk keamanan sesi',
                            style: const TextStyle(fontSize: 11, color: AppColors.info),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // Bottom buttons
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, -5))],
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Tolak'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _selectedCredential == null ? null : _submitPresentation,
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: const Text('Setujui & Kirim'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCredentialOption(CredentialModel cred) {
    final selected = _selectedCredential?.id == cred.id;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCredential = cred;
          _selectedClaims = cred.additionalData?.keys.toList() ?? [];
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryBlue.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primaryBlue : AppColors.textLight.withValues(alpha: 0.3),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: selected ? AppColors.primaryBlue.withValues(alpha: 0.12) : AppColors.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.credit_card, color: selected ? AppColors.primaryBlue : AppColors.textLight, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cred.type, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: selected ? AppColors.primaryBlue : AppColors.textDark)),
                Text(cred.issuer, style: const TextStyle(fontSize: 12, color: AppColors.textMedium)),
              ],
            )),
            if (selected) const Icon(Icons.check_circle, color: AppColors.primaryBlue),
          ],
        ),
      ),
    );
  }

  Widget _buildClaimCheckbox(String claim) {
    final isSelected = _selectedClaims.contains(claim);
    final displayName = claim.replaceAll('_', ' ').replaceAll(RegExp(r'(?<=[a-z])(?=[A-Z])'), ' ');
    return CheckboxListTile(
      value: isSelected,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      title: Text(displayName.toUpperCase(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textDark)),
      activeColor: AppColors.primaryBlue,
      onChanged: (val) {
        setState(() {
          if (val == true) {
            _selectedClaims.add(claim);
          } else {
            _selectedClaims.remove(claim);
          }
        });
      },
    );
  }

  Future<void> _submitPresentation() async {
    if (_selectedCredential == null || !mounted) return;
    
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => PresentationResultScreen(
          credential: _selectedCredential!,
          selectedClaims: _selectedClaims,
          descriptorId: _descriptorId,
          verifierName: _request?.clientId ?? 'Verifier',
        ),
      ),
    );
  }
}
