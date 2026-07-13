/// OpenID Credential Issuer Metadata
class IssuerMetadata {
  final String credentialIssuer;
  final String authorizationEndpoint;
  final String tokenEndpoint;
  final String credentialEndpoint;
  final String ssiNativeCredentialEndpoint;
  final Map<String, dynamic> credentialConfigurationsSupported;

  IssuerMetadata({
    required this.credentialIssuer,
    required this.authorizationEndpoint,
    required this.tokenEndpoint,
    required this.credentialEndpoint,
    required this.ssiNativeCredentialEndpoint,
    required this.credentialConfigurationsSupported,
  });

  factory IssuerMetadata.fromJson(Map<String, dynamic> json) {
    return IssuerMetadata(
      credentialIssuer: json['credential_issuer'] ?? json['issuer'] ?? '',
      authorizationEndpoint: json['authorization_endpoint'] ?? '',
      tokenEndpoint: json['token_endpoint'] ?? '',
      credentialEndpoint: json['credential_endpoint'] ?? '',
      ssiNativeCredentialEndpoint: json['credential_ssi_native_endpoint'] ??
          json['ssi_native_credential_endpoint'] ??
          '',
      credentialConfigurationsSupported:
          json['credential_configurations_supported'] is Map
              ? Map<String, dynamic>.from(
                  json['credential_configurations_supported'] as Map)
              : {},
    );
  }
}
