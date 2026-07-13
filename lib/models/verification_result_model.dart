/// Result of JWT / SD-JWT / VC verification
class VerificationResult {
  final bool signatureValid;
  final bool issuerTrusted;
  final bool claimsValid;
  final bool timingValid;
  final String? issuerDid;
  final String? algorithm;
  final List<String> errors;
  final Map<String, dynamic>? claims;

  VerificationResult({
    required this.signatureValid,
    required this.issuerTrusted,
    required this.claimsValid,
    required this.timingValid,
    this.issuerDid,
    this.algorithm,
    List<String>? errors,
    this.claims,
  }) : errors = errors ?? [];

  bool get isFullyValid =>
      signatureValid && issuerTrusted && claimsValid && timingValid && errors.isEmpty;

  /// Overall verification status description
  String get statusMessage {
    if (isFullyValid) return 'Credential valid dan terverifikasi';
    final msgs = <String>[];
    if (!signatureValid) msgs.add('Tanda tangan tidak valid');
    if (!issuerTrusted) msgs.add('Issuer tidak dapat diverifikasi');
    if (!claimsValid) msgs.add('Struktur klaim tidak valid');
    if (!timingValid) msgs.add('Credential kedaluwarsa atau belum berlaku');
    msgs.addAll(errors);
    return msgs.join('\n');
  }

  factory VerificationResult.failure(String error) {
    return VerificationResult(
      signatureValid: false,
      issuerTrusted: false,
      claimsValid: false,
      timingValid: false,
      errors: [error],
    );
  }
}
