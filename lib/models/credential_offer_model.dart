/// OID4VCI Credential Offer model
class CredentialOffer {
  final String credentialIssuer;
  final List<String> credentialConfigurationIds;
  final Map<String, dynamic>? grants;

  CredentialOffer({
    required this.credentialIssuer,
    required this.credentialConfigurationIds,
    this.grants,
  });

  factory CredentialOffer.fromJson(Map<String, dynamic> json) {
    List<String> configIds = [];
    if (json['credential_configuration_ids'] is List) {
      configIds = List<String>.from(json['credential_configuration_ids']);
    } else if (json['credentials'] is List) {
      // legacy format
      for (final c in json['credentials'] as List) {
        if (c is String) {
          configIds.add(c);
        } else if (c is Map) {
          configIds.add(c['type'] ?? c['id'] ?? 'Unknown');
        }
      }
    }
    return CredentialOffer(
      credentialIssuer: json['credential_issuer'] ?? '',
      credentialConfigurationIds: configIds,
      grants: json['grants'] is Map
          ? Map<String, dynamic>.from(json['grants'] as Map)
          : null,
    );
  }

  /// Extract issuer_state from grants if present
  String? get issuerState {
    final authCode = grants?['authorization_code'];
    if (authCode is Map) {
      return authCode['issuer_state']?.toString();
    }
    return null;
  }

  /// Check if pre-authorized code flow is available
  bool get hasPreAuthorizedCode {
    return grants?.containsKey(
            'urn:ietf:params:oauth:grant-type:pre-authorized_code') ??
        false;
  }

  /// Check if authorization_code flow is available.
  bool get hasAuthorizationCode {
    return grants?.containsKey('authorization_code') ?? false;
  }

  /// Extract pre-authorized code if provided in offer grants.
  String? get preAuthorizedCode {
    final preAuth =
        grants?['urn:ietf:params:oauth:grant-type:pre-authorized_code'];
    if (preAuth is Map) {
      return preAuth['pre-authorized_code']?.toString();
    }
    return null;
  }

  /// Whether a user PIN is required by pre-authorized_code flow.
  bool get userPinRequired {
    final preAuth =
        grants?['urn:ietf:params:oauth:grant-type:pre-authorized_code'];
    if (preAuth is Map) {
      final pin = preAuth['user_pin_required'];
      return pin == true || pin?.toString().toLowerCase() == 'true';
    }
    return false;
  }
}
