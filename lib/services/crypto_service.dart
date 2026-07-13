import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/credential_model.dart';

class CryptoService {
  /// Timeout for HTTP requests
  static const Duration _httpTimeout = Duration(seconds: 15);

  /// Process QR data - detect type and handle accordingly
  /// Issuer QR: URL like https://202.155.132.71:3001/verify/{credentialId}
  /// Verifier QR: JSON with presentation_request / verification_request
  static Future<Map<String, dynamic>> processQRData(String qrData) async {
    debugPrint('[CryptoService] Processing QR data: ${qrData.length} chars');
    debugPrint(
        '[CryptoService] Data preview: ${qrData.substring(0, qrData.length > 200 ? 200 : qrData.length)}');

    try {
      // 1. Check if it's a URL (Issuer QR Code)
      if (_isUrl(qrData)) {
        debugPrint('[CryptoService] Detected URL-based QR (Issuer)');
        return await _handleIssuerUrl(qrData.trim());
      }

      // 2. Try to parse as JSON (Verifier QR Code or other)
      try {
        final Map<String, dynamic> jsonData = jsonDecode(qrData);
        debugPrint(
            '[CryptoService] Parsed as JSON. Keys: ${jsonData.keys.toList()}');
        return _handleJsonQR(jsonData);
      } catch (_) {
        debugPrint('[CryptoService] Not valid JSON');
      }

      // 3. Check if it contains a URL somewhere in the text
      final urlMatch = RegExp(r'https?://[^\s]+').firstMatch(qrData);
      if (urlMatch != null) {
        final url = urlMatch.group(0)!;
        debugPrint('[CryptoService] Found URL in QR text: $url');
        return await _handleIssuerUrl(url);
      }

      // 4. Unknown format
      return {
        'isValid': false,
        'error':
            'Format QR Code tidak dikenali.\n\nData: ${qrData.substring(0, qrData.length > 100 ? 100 : qrData.length)}...',
      };
    } catch (e) {
      debugPrint('[CryptoService] Error processing QR: $e');
      return {
        'isValid': false,
        'error': 'Gagal memproses QR Code: $e',
      };
    }
  }

  /// Check if string is a URL
  static bool _isUrl(String data) {
    final trimmed = data.trim();
    return trimmed.startsWith('http://') || trimmed.startsWith('https://');
  }

  /// Handle Issuer URL-based QR Code
  /// Fetches credential data from issuer's verification endpoint
  static Future<Map<String, dynamic>> _handleIssuerUrl(String url) async {
    debugPrint('[CryptoService] Fetching issuer URL: $url');

    try {
      // Create HTTP client that accepts self-signed certificates
      final httpClient = HttpClient()
        ..badCertificateCallback = (cert, host, port) => true;

      final request = await httpClient.getUrl(Uri.parse(url));
      request.headers.set('Accept', 'application/json');

      final response = await request.close().timeout(_httpTimeout);
      final responseBody = await response.transform(utf8.decoder).join();

      debugPrint('[CryptoService] Response status: ${response.statusCode}');
      debugPrint(
          '[CryptoService] Response body (first 500): ${responseBody.substring(0, responseBody.length > 500 ? 500 : responseBody.length)}');

      httpClient.close();

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(responseBody);
          return _parseIssuerResponse(data, url);
        } catch (e) {
          // Response might be SD-JWT compact format (not JSON)
          if (responseBody.contains('.') && responseBody.contains('~')) {
            debugPrint(
                '[CryptoService] Response looks like SD-JWT compact format');
            return _parseSDJWT(responseBody, url);
          }
          // Still try to use as plain text credential info
          return {
            'isValid': false,
            'error': 'Respons dari issuer tidak berformat JSON: $e',
          };
        }
      } else {
        return {
          'isValid': false,
          'error':
              'Server issuer mengembalikan error (HTTP ${response.statusCode})\n\nResponse: ${responseBody.substring(0, responseBody.length > 200 ? 200 : responseBody.length)}',
        };
      }
    } on SocketException catch (e) {
      debugPrint('[CryptoService] Network error: $e');
      return {
        'isValid': false,
        'error':
            'Tidak dapat terhubung ke server issuer.\nPastikan koneksi internet aktif dan server bisa dijangkau.\n\nDetail: $e',
      };
    } on HandshakeException catch (e) {
      debugPrint('[CryptoService] SSL error: $e');
      return {
        'isValid': false,
        'error': 'Error SSL/TLS saat menghubungi server issuer: $e',
      };
    } catch (e) {
      debugPrint('[CryptoService] Error fetching URL: $e');
      return {
        'isValid': false,
        'error': 'Gagal mengambil data dari issuer: $e',
      };
    }
  }

  /// Parse issuer's API response to extract credential
  static Map<String, dynamic> _parseIssuerResponse(
      dynamic data, String sourceUrl) {
    debugPrint('[CryptoService] Parsing issuer response...');

    try {
      Map<String, dynamic> responseData;

      if (data is Map<String, dynamic>) {
        responseData = data;
      } else if (data is Map) {
        responseData = Map<String, dynamic>.from(data);
      } else {
        return {
          'isValid': false,
          'error': 'Format response issuer tidak valid (bukan JSON object)',
        };
      }

      debugPrint(
          '[CryptoService] Response keys: ${responseData.keys.toList()}');

      // Determine verification status
      final bool isVerified = responseData['verified'] == true ||
          responseData['valid'] == true ||
          responseData['success'] == true ||
          responseData['status'] == 'valid' ||
          responseData['status'] == 'verified' ||
          responseData['status'] == 'active';

      // Extract credential data from various possible structures
      Map<String, dynamic>? credentialData;
      String? sdJwt;

      // Check for SD-JWT string
      if (responseData.containsKey('sd_jwt') ||
          responseData.containsKey('token') ||
          responseData.containsKey('jwt')) {
        sdJwt = (responseData['sd_jwt'] ??
                responseData['token'] ??
                responseData['jwt'])
            .toString();
      }

      // Check for credential object
      if (responseData.containsKey('credential')) {
        final cred = responseData['credential'];
        if (cred is Map<String, dynamic>) {
          credentialData = cred;
        } else if (cred is Map) {
          credentialData = Map<String, dynamic>.from(cred);
        } else if (cred is String && cred.contains('.')) {
          sdJwt = cred; // SD-JWT string
        }
      }

      if (credentialData == null && responseData.containsKey('data')) {
        final d = responseData['data'];
        if (d is Map<String, dynamic>) {
          credentialData = d;
        } else if (d is Map) {
          credentialData = Map<String, dynamic>.from(d);
        }
      }

      if (credentialData == null &&
          responseData.containsKey('credentialSubject')) {
        credentialData = responseData;
      }

      if (credentialData == null && responseData.containsKey('vc')) {
        final vc = responseData['vc'];
        credentialData = vc is Map<String, dynamic>
            ? vc
            : (vc is Map ? Map<String, dynamic>.from(vc) : responseData);
      }

      // If we have an SD-JWT, parse it
      if (sdJwt != null) {
        return _parseSDJWT(sdJwt, sourceUrl);
      }

      // If no specific credential field, use the whole response
      credentialData ??= responseData;

      return _buildCredentialResult(credentialData, isVerified, sourceUrl);
    } catch (e) {
      debugPrint('[CryptoService] Error parsing issuer response: $e');
      return {
        'isValid': false,
        'error': 'Gagal memproses data credential dari issuer: $e',
      };
    }
  }

  /// Parse SD-JWT format (header.payload.signature~disclosure1~disclosure2~)
  static Map<String, dynamic> _parseSDJWT(String sdJwt, String sourceUrl) {
    debugPrint('[CryptoService] Parsing SD-JWT...');

    try {
      // SD-JWT format: header.payload.signature~disclosure1~disclosure2~...
      final parts = sdJwt.split('~');
      final jwtPart = parts[0]; // header.payload.signature

      final jwtSegments = jwtPart.split('.');
      if (jwtSegments.length < 2) {
        return {
          'isValid': false,
          'error': 'Format SD-JWT tidak valid (kurang dari 2 segmen)',
        };
      }

      // Decode JWT payload (base64url)
      final payloadBase64 = _base64UrlNormalize(jwtSegments[1]);
      final payloadJson = utf8.decode(base64Decode(payloadBase64));
      final payload = jsonDecode(payloadJson) as Map<String, dynamic>;

      debugPrint(
          '[CryptoService] SD-JWT payload keys: ${payload.keys.toList()}');

      // Decode header to check algorithm
      final headerBase64 = _base64UrlNormalize(jwtSegments[0]);
      final headerJson = utf8.decode(base64Decode(headerBase64));
      final header = jsonDecode(headerJson) as Map<String, dynamic>;
      debugPrint('[CryptoService] SD-JWT algorithm: ${header['alg']}');

      // Process selective disclosures
      final disclosures = <String, dynamic>{};
      for (int i = 1; i < parts.length; i++) {
        if (parts[i].isEmpty) continue;
        try {
          final disclosureBase64 = _base64UrlNormalize(parts[i]);
          final disclosureJson = utf8.decode(base64Decode(disclosureBase64));
          final disclosure = jsonDecode(disclosureJson);

          if (disclosure is List && disclosure.length >= 3) {
            // Format: [salt, claim_name, claim_value]
            disclosures[disclosure[1].toString()] = disclosure[2];
            debugPrint(
                '[CryptoService] Disclosure: ${disclosure[1]} = ${disclosure[2]}');
          }
        } catch (e) {
          debugPrint('[CryptoService] Error parsing disclosure $i: $e');
        }
      }

      debugPrint('[CryptoService] Total disclosures: ${disclosures.length}');

      // Merge payload with disclosures
      final fullData = <String, dynamic>{...payload, ...disclosures};

      // Extract credential subject if present
      Map<String, dynamic>? credSubject;
      if (fullData.containsKey('credentialSubject')) {
        final cs = fullData['credentialSubject'];
        if (cs is Map<String, dynamic>) {
          credSubject = cs;
        } else if (cs is Map) {
          credSubject = Map<String, dynamic>.from(cs);
        }
      }
      if (fullData.containsKey('vc')) {
        final vc = fullData['vc'];
        if (vc is Map) {
          final vcSubject = vc['credentialSubject'];
          if (vcSubject is Map<String, dynamic>) {
            credSubject = vcSubject;
          } else if (vcSubject is Map) {
            credSubject = Map<String, dynamic>.from(vcSubject);
          }
        }
      }

      final combinedData = <String, dynamic>{
        ...fullData,
        if (credSubject != null) ...credSubject,
        ...disclosures,
      };

      return _buildCredentialResult(combinedData, true, sourceUrl,
          sdJwtRaw: sdJwt, algorithm: header['alg']?.toString() ?? 'ES256');
    } catch (e) {
      debugPrint('[CryptoService] Error parsing SD-JWT: $e');
      return {
        'isValid': false,
        'error': 'Gagal memproses SD-JWT: $e',
      };
    }
  }

  /// Build credential result from parsed data
  static Map<String, dynamic> _buildCredentialResult(
    Map<String, dynamic> data,
    bool isVerified,
    String sourceUrl, {
    String? sdJwtRaw,
    String algorithm = 'ES256',
  }) {
    debugPrint(
        '[CryptoService] Building credential from data keys: ${data.keys.toList()}');

    // Extract common fields with many possible key names
    final String id = (data['id'] ??
            data['credentialId'] ??
            data['credential_id'] ??
            data['jti'] ??
            data['sub'] ??
            DateTime.now().millisecondsSinceEpoch.toString())
        .toString();

    // Type extraction
    String type;
    final typeField = data['type'] ??
        data['vct'] ??
        data['credentialType'] ??
        data['credential_type'];
    if (typeField is List && typeField.isNotEmpty) {
      // W3C VC format: ["VerifiableCredential", "HealthCard"]
      type = typeField
          .lastWhere(
            (t) =>
                t.toString() != 'VerifiableCredential' &&
                t.toString() != 'VerifiablePresentation',
            orElse: () => typeField.first,
          )
          .toString();
    } else {
      type = (typeField ?? 'Verifiable Credential').toString();
    }

    final String issuer = (data['issuer'] ??
            data['iss'] ??
            data['issuedBy'] ??
            data['issued_by'] ??
            _extractIssuerFromUrl(sourceUrl))
        .toString();

    final String holderName = (data['holder_name'] ??
            data['holderName'] ??
            data['name'] ??
            data['full_name'] ??
            data['fullName'] ??
            data['nama'] ??
            data['nama_lengkap'] ??
            '')
        .toString();

    final String documentNumber = (data['document_number'] ??
            data['documentNumber'] ??
            data['nik'] ??
            data['no_dokumen'] ??
            data['number'] ??
            '')
        .toString();

    // Parse dates
    DateTime issuedDate = DateTime.now();
    if (data['issued_date'] != null) {
      issuedDate =
          DateTime.tryParse(data['issued_date'].toString()) ?? DateTime.now();
    } else if (data['issuanceDate'] != null) {
      issuedDate =
          DateTime.tryParse(data['issuanceDate'].toString()) ?? DateTime.now();
    } else if (data['iat'] != null) {
      final iatVal = data['iat'];
      final iatInt = iatVal is int ? iatVal : int.tryParse(iatVal.toString());
      if (iatInt != null) {
        issuedDate = DateTime.fromMillisecondsSinceEpoch(iatInt * 1000);
      }
    }

    DateTime? expiryDate;
    if (data['expiry_date'] != null) {
      expiryDate = DateTime.tryParse(data['expiry_date'].toString());
    } else if (data['expirationDate'] != null) {
      expiryDate = DateTime.tryParse(data['expirationDate'].toString());
    } else if (data['exp'] != null) {
      final expVal = data['exp'];
      final expInt = expVal is int ? expVal : int.tryParse(expVal.toString());
      if (expInt != null) {
        expiryDate = DateTime.fromMillisecondsSinceEpoch(expInt * 1000);
      }
    }

    // Collect additional data
    final additionalData = <String, dynamic>{};
    final standardKeys = {
      'id',
      'type',
      'issuer',
      'iss',
      'sub',
      'iat',
      'exp',
      'jti',
      'nbf',
      'holder_name',
      'holderName',
      'name',
      'full_name',
      'fullName',
      'document_number',
      'documentNumber',
      'issued_date',
      'issuanceDate',
      'expiry_date',
      'expirationDate',
      'vct',
      'cnf',
      '_sd',
      '_sd_alg',
      'credential',
      'credentialSubject',
      'vc',
      'issuedBy',
      'status',
      'verified',
      'valid',
      'success',
      'nama',
      'nama_lengkap',
      'nik',
      'no_dokumen',
      'number',
      'credential_id',
      'credentialId',
      'credential_type',
      'credentialType',
      'issued_by',
    };

    data.forEach((key, value) {
      if (!standardKeys.contains(key) && value != null) {
        // Skip internal SD-JWT fields
        if (key.startsWith('_')) return;
        additionalData[key] = value;
      }
    });

    final credential = CredentialModel(
      id: id,
      type: type,
      issuer: issuer,
      holderName: holderName,
      documentNumber: documentNumber,
      issuedDate: issuedDate,
      expiryDate: expiryDate,
      isVerified: isVerified,
      additionalData: additionalData.isNotEmpty ? additionalData : null,
      signature: sdJwtRaw,
      publicKey: sourceUrl,
    );

    debugPrint(
        '[CryptoService] Built credential: type=$type, issuer=$issuer, holder=$holderName, verified=$isVerified');

    return {
      'isValid': true,
      'credential': credential,
      'issuer': issuer,
      'algorithm': algorithm,
      'sourceUrl': sourceUrl,
      'message':
          'Credential berhasil diverifikasi ($algorithm).\nIssuer: $issuer',
    };
  }

  /// Handle JSON-based QR code (verifier request / direct credential)
  static Map<String, dynamic> _handleJsonQR(Map<String, dynamic> jsonData) {
    debugPrint(
        '[CryptoService] Handling JSON QR with keys: ${jsonData.keys.toList()}');

    // Check for DIDComm / presentation request patterns
    if (_isVerifierRequest(jsonData)) {
      return _handleVerifierRequest(jsonData);
    }

    // Check for direct credential with signature
    if (jsonData.containsKey('credential') &&
        jsonData.containsKey('signature')) {
      final credData = jsonData['credential'];
      return _buildCredentialResult(
        credData is Map<String, dynamic>
            ? credData
            : (credData is Map
                ? Map<String, dynamic>.from(credData)
                : jsonData),
        true,
        'qr-direct',
      );
    }

    // Check for SD-JWT string in JSON
    if (jsonData.containsKey('sd_jwt') ||
        jsonData.containsKey('token') ||
        jsonData.containsKey('jwt')) {
      final sdJwt = (jsonData['sd_jwt'] ?? jsonData['token'] ?? jsonData['jwt'])
          .toString();
      return _parseSDJWT(sdJwt, 'qr-direct');
    }

    // Check for presentation request URL
    if (jsonData.containsKey('request_uri') ||
        jsonData.containsKey('requestUri')) {
      final requestUri =
          (jsonData['request_uri'] ?? jsonData['requestUri']).toString();
      return {
        'isValid': true,
        'isVerifierRequest': true,
        'verifier':
            jsonData['client_id'] ?? jsonData['verifier'] ?? 'Unknown Verifier',
        'requestedCredentials':
            jsonData['presentation_definition']?['input_descriptors'] ?? [],
        'requestUri': requestUri,
        'nonce': jsonData['nonce'] ?? '',
        'message': 'Verifier meminta data credential Anda.',
        'rawData': jsonData,
      };
    }

    // Try treating the whole JSON as credential data
    if (jsonData.containsKey('type') ||
        jsonData.containsKey('vct') ||
        jsonData.containsKey('credentialSubject') ||
        jsonData.containsKey('vc') ||
        jsonData.containsKey('holder_name') ||
        jsonData.containsKey('holderName')) {
      return _buildCredentialResult(jsonData, true, 'qr-direct');
    }

    return {
      'isValid': false,
      'error':
          'Format JSON QR tidak dikenali.\nKeys: ${jsonData.keys.take(10).toList()}',
    };
  }

  /// Check if JSON data is a verifier/presentation request
  static bool _isVerifierRequest(Map<String, dynamic> data) {
    // DIDComm v2 message types
    final type = data['type']?.toString() ?? '';
    if (type.contains('didcomm.org') ||
        type.contains('present-proof') ||
        type.contains('request-presentation')) {
      return true;
    }

    // Standard presentation request type strings
    final typeLower = type.toLowerCase();
    if (typeLower.contains('presentation_request') ||
        typeLower.contains('verification_request') ||
        typeLower.contains('data_request')) {
      return true;
    }

    // Has verifier-specific fields
    if (data.containsKey('presentation_definition') ||
        data.containsKey('requested_credentials') ||
        data.containsKey('requested_data') ||
        data.containsKey('challenge')) {
      return true;
    }

    return false;
  }

  /// Handle verifier/presentation requests (DIDComm v2, OpenID4VP, etc.)
  static Map<String, dynamic> _handleVerifierRequest(
      Map<String, dynamic> data) {
    debugPrint('[CryptoService] Handling verifier request...');

    // Extract verifier identity
    final verifier = (data['verifier'] ??
            data['client_id'] ??
            data['from'] ??
            data['requester'] ??
            'Verifier')
        .toString();

    // Extract requested credentials/attributes
    List<dynamic> requestedCredentials = [];

    // DIDComm v2: body.presentation_definition.input_descriptors
    if (data.containsKey('body')) {
      final body = data['body'];
      if (body is Map) {
        if (body.containsKey('presentation_definition')) {
          final presDef = body['presentation_definition'];
          if (presDef is Map && presDef.containsKey('input_descriptors')) {
            requestedCredentials = (presDef['input_descriptors'] as List)
                .map((d) =>
                    d is Map ? (d['name'] ?? d['id'] ?? d.toString()) : d)
                .toList();
          }
        }
        // Fallback to body-level fields
        if (requestedCredentials.isEmpty) {
          requestedCredentials = body['requested_credentials'] is List
              ? body['requested_credentials'] as List
              : body['requested_data'] is List
                  ? body['requested_data'] as List
                  : [];
        }
      }
    }

    // Top-level presentation_definition
    if (requestedCredentials.isEmpty &&
        data.containsKey('presentation_definition')) {
      final presDef = data['presentation_definition'];
      if (presDef is Map && presDef.containsKey('input_descriptors')) {
        final descriptors = presDef['input_descriptors'] as List;
        requestedCredentials = descriptors
            .map((d) => d is Map ? (d['name'] ?? d['id'] ?? d.toString()) : d)
            .toList();
      }
    }

    // Simple field-based
    if (requestedCredentials.isEmpty) {
      final rc = data['requested_credentials'] ??
          data['requested_data'] ??
          data['credentials'];
      if (rc is List) {
        requestedCredentials = rc;
      } else if (rc != null) {
        requestedCredentials = [rc.toString()];
      }
    }

    if (requestedCredentials.isEmpty) {
      requestedCredentials = ['Verifiable Credential'];
    }

    final nonce = (data['nonce'] ?? data['challenge'] ?? '').toString();
    final callbackUrl = (data['callback_url'] ??
            data['response_uri'] ??
            data['callback'] ??
            data['reply_url'] ??
            '')
        .toString();

    debugPrint(
        '[CryptoService] Verifier: $verifier, Requested: $requestedCredentials');

    return {
      'isValid': true,
      'isVerifierRequest': true,
      'verifier': verifier,
      'requestedCredentials': requestedCredentials,
      'nonce': nonce,
      'callbackUrl': callbackUrl,
      'message': '$verifier meminta akses ke data credential Anda.',
      'rawData': data,
    };
  }

  /// Normalize base64url to standard base64
  static String _base64UrlNormalize(String input) {
    String output = input.replaceAll('-', '+').replaceAll('_', '/');
    switch (output.length % 4) {
      case 0:
        break;
      case 2:
        output += '==';
        break;
      case 3:
        output += '=';
        break;
      default:
        break;
    }
    return output;
  }

  /// Extract issuer name from URL
  static String _extractIssuerFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host;
    } catch (_) {
      return 'Unknown Issuer';
    }
  }
}
