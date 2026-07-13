import 'package:intl/intl.dart';

class CredentialModel {
  final String id;
  final String type;
  final String issuer;
  final String holderName;
  final String documentNumber;
  final DateTime issuedDate;
  final DateTime? expiryDate;
  final bool isVerified;
  final Map<String, dynamic>? additionalData;
  final String? signature;
  final String? publicKey;

  // OID4VCI / JWT fields
  final String? rawJwt; // Raw JWT VC or SD-JWT string
  final String? format; // 'jwt_vc_json' | 'vc+sd-jwt'
  final String? issuerDid; // Resolved issuer DID
  final String? credentialStatusUrl;
  final String? syncedStatus;
  final bool? statusActive;
  final DateTime? statusCheckedAt;

  CredentialModel({
    required this.id,
    required this.type,
    required this.issuer,
    required this.holderName,
    required this.documentNumber,
    required this.issuedDate,
    this.expiryDate,
    this.isVerified = false,
    this.additionalData,
    this.signature,
    this.publicKey,
    this.rawJwt,
    this.format,
    this.issuerDid,
    this.credentialStatusUrl,
    this.syncedStatus,
    this.statusActive,
    this.statusCheckedAt,
  });

  factory CredentialModel.fromJson(Map<String, dynamic> json) {
    return CredentialModel(
      id: json['id'] ?? '',
      type: json['type'] ?? '',
      issuer: json['issuer'] ?? '',
      holderName: json['holder_name'] ?? '',
      documentNumber: json['document_number'] ?? '',
      issuedDate:
          DateTime.tryParse(json['issued_date'] ?? '') ?? DateTime.now(),
      expiryDate: json['expiry_date'] != null
          ? DateTime.tryParse(json['expiry_date'])
          : null,
      isVerified: json['is_verified'] ?? false,
      additionalData: json['additional_data'] is Map
          ? Map<String, dynamic>.from(json['additional_data'] as Map)
          : null,
      signature: json['signature'],
      publicKey: json['public_key'],
      rawJwt: json['raw_jwt'],
      format: json['format'],
      issuerDid: json['issuer_did'],
      credentialStatusUrl: json['credential_status_url'],
      syncedStatus: json['synced_status'],
      statusActive: json['status_active'],
      statusCheckedAt: json['status_checked_at'] != null
          ? DateTime.tryParse(json['status_checked_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'issuer': issuer,
      'holder_name': holderName,
      'document_number': documentNumber,
      'issued_date': issuedDate.toIso8601String(),
      'expiry_date': expiryDate?.toIso8601String(),
      'is_verified': isVerified,
      'additional_data': additionalData,
      'signature': signature,
      'public_key': publicKey,
      'raw_jwt': rawJwt,
      'format': format,
      'issuer_did': issuerDid,
      'credential_status_url': credentialStatusUrl,
      'synced_status': syncedStatus,
      'status_active': statusActive,
      'status_checked_at': statusCheckedAt?.toIso8601String(),
    };
  }

  /// Create a copy with updated fields
  CredentialModel copyWith({
    String? id,
    bool? isVerified,
    String? rawJwt,
    String? format,
    String? issuerDid,
    Map<String, dynamic>? additionalData,
    String? credentialStatusUrl,
    String? syncedStatus,
    bool? statusActive,
    DateTime? statusCheckedAt,
  }) {
    return CredentialModel(
      id: id ?? this.id,
      type: type,
      issuer: issuer,
      holderName: holderName,
      documentNumber: documentNumber,
      issuedDate: issuedDate,
      expiryDate: expiryDate,
      isVerified: isVerified ?? this.isVerified,
      additionalData: additionalData ?? this.additionalData,
      signature: signature,
      publicKey: publicKey,
      rawJwt: rawJwt ?? this.rawJwt,
      format: format ?? this.format,
      issuerDid: issuerDid ?? this.issuerDid,
      credentialStatusUrl: credentialStatusUrl ?? this.credentialStatusUrl,
      syncedStatus: syncedStatus ?? this.syncedStatus,
      statusActive: statusActive ?? this.statusActive,
      statusCheckedAt: statusCheckedAt ?? this.statusCheckedAt,
    );
  }

  String get formattedIssuedDate {
    try {
      return DateFormat('dd MMMM yyyy', 'id_ID').format(issuedDate);
    } catch (e) {
      return DateFormat('dd MMM yyyy').format(issuedDate);
    }
  }

  String get formattedExpiryDate {
    if (expiryDate == null) return 'Seumur Hidup';
    try {
      return DateFormat('dd MMMM yyyy', 'id_ID').format(expiryDate!);
    } catch (e) {
      return DateFormat('dd MMM yyyy').format(expiryDate!);
    }
  }

  bool get isExpired {
    if (expiryDate == null) return false;
    return DateTime.now().isAfter(expiryDate!);
  }

  String get status {
    if (isExpired) return 'EXPIRED';
    if (syncedStatus != null && syncedStatus!.trim().isNotEmpty) {
      return syncedStatus!.trim().toUpperCase();
    }
    return isVerified ? 'ACTIVE' : 'UNKNOWN';
  }

  String get statusLabel {
    switch (status) {
      case 'ACTIVE':
        return 'Aktif';
      case 'REVOKED':
        return 'Revoked';
      case 'SUSPENDED':
        return 'Suspended';
      case 'EXPIRED':
        return 'Expired';
      default:
        return 'Unknown';
    }
  }

  bool get isActive {
    if (!isVerified || isExpired) return false;
    final normalizedStatus = status;
    if (normalizedStatus == 'REVOKED' ||
        normalizedStatus == 'SUSPENDED' ||
        normalizedStatus == 'EXPIRED') {
      return false;
    }
    if (statusActive == false) return false;
    return true;
  }

  /// Format type: determine display label for credential format
  String get formatLabel {
    switch (format) {
      case 'vc+sd-jwt':
        return 'SD-JWT';
      case 'jwt_vc_json':
        return 'JWT VC';
      default:
        return rawJwt != null ? 'JWT VC' : 'Local';
    }
  }

  /// Whether this credential came from an OID4VCI flow
  bool get isFromIssuance => rawJwt != null;
}
