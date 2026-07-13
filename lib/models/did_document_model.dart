/// DID Document model for did:web, did:key resolution
class DIDDocument {
  final String id;
  final List<VerificationMethod> verificationMethods;

  DIDDocument({
    required this.id,
    required this.verificationMethods,
  });

  factory DIDDocument.fromJson(Map<String, dynamic> json) {
    final List<VerificationMethod> methods = [];

    // Parse verificationMethod array
    final vmList = json['verificationMethod'];
    if (vmList is List) {
      for (final vm in vmList) {
        if (vm is Map<String, dynamic>) {
          methods.add(VerificationMethod.fromJson(vm));
        }
      }
    }

    // Also check assertionMethod and authentication arrays for embedded methods
    for (final key in ['assertionMethod', 'authentication', 'keyAgreement']) {
      final arr = json[key];
      if (arr is List) {
        for (final item in arr) {
          if (item is Map<String, dynamic> &&
              item.containsKey('publicKeyJwk')) {
            final vm = VerificationMethod.fromJson(item);
            if (!methods.any((m) => m.id == vm.id)) {
              methods.add(vm);
            }
          }
        }
      }
    }

    return DIDDocument(
      id: json['id']?.toString() ?? '',
      verificationMethods: methods,
    );
  }

  /// Find a verification method by kid (key ID)
  VerificationMethod? findByKid(String kid) {
    final normalizedKid = _normalizeKid(kid);
    final kidFragment = _extractFragment(normalizedKid);
    final kidDid = _extractDid(normalizedKid);

    // Exact match
    for (final vm in verificationMethods) {
      final vmId = _normalizeKid(vm.id);
      if (vmId == normalizedKid) return vm;

      // Handle fragment-only kid (e.g., "#key-1" matches "did:web:example.com#key-1")
      if (normalizedKid.startsWith('#') && vmId.endsWith(normalizedKid))
        return vm;

      final vmFragment = _extractFragment(vmId);
      final vmDid = _extractDid(vmId);
      if (kidFragment != null &&
          vmFragment == kidFragment &&
          kidDid != null &&
          vmDid != null &&
          kidDid == vmDid) {
        return vm;
      }

      // Handle URL kid that only differs by did:web canonical form.
      final kidFromUrl = _urlKidToDidWeb(normalizedKid);
      if (kidFromUrl != null && vmId == kidFromUrl) return vm;
    }
    return null;
  }

  static String? _extractDid(String value) {
    final idx = value.indexOf('#');
    if (idx == -1) {
      return value.startsWith('did:') ? value : null;
    }
    final didPart = value.substring(0, idx);
    return didPart.startsWith('did:') ? didPart : null;
  }

  static String _normalizeKid(String kid) {
    return Uri.decodeFull(kid.trim());
  }

  static String? _extractFragment(String value) {
    final idx = value.indexOf('#');
    if (idx == -1 || idx == value.length - 1) return null;
    return value.substring(idx + 1);
  }

  static String? _urlKidToDidWeb(String kid) {
    if (!kid.startsWith('https://')) return null;
    final uri = Uri.tryParse(kid);
    if (uri == null || uri.fragment.isEmpty) return null;

    final host = uri.host;
    final path = uri.pathSegments.where((s) => s.isNotEmpty).toList();

    if (path.isEmpty || (path.length == 1 && path.first == '.well-known')) {
      return 'did:web:$host#${uri.fragment}';
    }

    if (path.last == 'did.json') {
      path.removeLast();
    }

    final didPath = path.isEmpty ? '' : ':${path.join(':')}';
    return 'did:web:$host$didPath#${uri.fragment}';
  }
}

class VerificationMethod {
  final String id;
  final String type;
  final String? controller;
  final String? publicKeyBase58;
  final Map<String, dynamic>? publicKeyJwk;
  final String? publicKeyMultibase;

  VerificationMethod({
    required this.id,
    required this.type,
    this.controller,
    this.publicKeyBase58,
    this.publicKeyJwk,
    this.publicKeyMultibase,
  });

  factory VerificationMethod.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? jwk;
    final rawJwk = json['publicKeyJwk'];
    if (rawJwk is Map) {
      jwk = Map<String, dynamic>.from(rawJwk);
    }
    return VerificationMethod(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      controller: json['controller']?.toString(),
      publicKeyBase58: json['publicKeyBase58']?.toString(),
      publicKeyJwk: jwk,
      publicKeyMultibase: json['publicKeyMultibase']?.toString(),
    );
  }
}
