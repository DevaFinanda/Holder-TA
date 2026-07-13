import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/identia_issuance_service.dart';
import '../../utils/app_colors.dart';
import '../../providers/auth_provider.dart';
import 'identia_issuance_screen.dart';

/// IDentia Credential Issuance — Step 1: Login
///
/// Authenticates the user against the issuer REST API before
/// proceeding to retrieve the holder DID and request the credential.
class IdentiaLoginScreen extends StatefulWidget {
  /// Full QR URL, e.g. https://issuer.identia.my.id/credential-offer?offerId=123
  final String qrUrl;

  const IdentiaLoginScreen({super.key, required this.qrUrl});

  @override
  State<IdentiaLoginScreen> createState() => _IdentiaLoginScreenState();
}

class _IdentiaLoginScreenState extends State<IdentiaLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  late final String _issuerBaseUrl;
  late final String _offerId;

  @override
  void initState() {
    super.initState();
    try {
      _issuerBaseUrl = IdentiaIssuanceService.parseIssuerBaseUrl(widget.qrUrl);
      _offerId = IdentiaIssuanceService.parseOfferId(widget.qrUrl);
    } catch (e) {
      _issuerBaseUrl = '';
      _offerId = '';
      _errorMessage = 'URL tidak valid: $e';
    }
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _onLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = await IdentiaIssuanceService.login(
        _issuerBaseUrl,
        _usernameCtrl.text.trim(),
        _passwordCtrl.text,
      );
      final userId = context.read<AuthProvider>().currentUser?.id ?? '';
      if (userId.isEmpty) {
        throw Exception('active_user_required: User wallet belum login');
      }
      final holderDid = await IdentiaIssuanceService.getHolderDid(userId);

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => IdentiaIssuanceScreen(
            issuerBaseUrl: _issuerBaseUrl,
            sessionToken: token,
            holderDid: holderDid,
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Login Issuer'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textDark,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header illustration
              Center(
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.primaryGradient,
                  ),
                  child: const Icon(Icons.login, color: Colors.white, size: 44),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  'Autentikasi Issuer',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold, color: AppColors.textDark),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  _issuerBaseUrl.isNotEmpty ? _issuerBaseUrl : '-',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMedium,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              if (_offerId.isNotEmpty) ...[
                const SizedBox(height: 4),
                Center(
                  child: Chip(
                    labelStyle: const TextStyle(fontSize: 11),
                    label: Text('Offer ID: $_offerId'),
                    backgroundColor:
                        AppColors.primaryBlue.withValues(alpha: 0.08),
                  ),
                ),
              ],
              const SizedBox(height: 32),

              // Error banner
              if (_errorMessage != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppColors.error, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                              color: AppColors.error, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Form
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Username'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _usernameCtrl,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: _inputDecoration(
                        hint: 'contoh: student01',
                        icon: Icons.person_outline,
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Username tidak boleh kosong'
                          : null,
                    ),
                    const SizedBox(height: 20),
                    _buildLabel('Password'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _isLoading ? null : _onLogin(),
                      decoration: _inputDecoration(
                        hint: '••••••••',
                        icon: Icons.lock_outline,
                        suffix: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: AppColors.textMedium,
                            size: 20,
                          ),
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Password tidak boleh kosong'
                          : null,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 36),

              // Login button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _onLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Text(
                          'Login',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 16),

              // Cancel
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed:
                      _isLoading ? null : () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                        color: AppColors.textLight.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Batal',
                      style: TextStyle(color: AppColors.textMedium)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textDark,
        ),
      );

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textLight, fontSize: 14),
      prefixIcon: Icon(icon, color: AppColors.textMedium, size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            BorderSide(color: AppColors.textLight.withValues(alpha: 0.3)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            BorderSide(color: AppColors.textLight.withValues(alpha: 0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
    );
  }
}
