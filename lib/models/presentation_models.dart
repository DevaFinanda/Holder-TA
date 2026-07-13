/// OID4VP Presentation models

/// Represents a complete OID4VP Authorization Request
class PresentationRequest {
  final String clientId;
  final String? nonce;
  final String? state;
  final String? requestUri;
  final String? responseUri; // redirect_uri or response_uri for direct_post
  final String responseMode; // direct_post, direct_post.jwt, etc.
  final PresentationDefinition? presentationDefinition;
  final String? presentationDefinitionUri;
  final String? clientMetadata; // raw JSON

  PresentationRequest({
    required this.clientId,
    this.nonce,
    this.state,
    this.requestUri,
    this.responseUri,
    this.responseMode = 'direct_post',
    this.presentationDefinition,
    this.presentationDefinitionUri,
    this.clientMetadata,
  });

  factory PresentationRequest.fromJson(Map<String, dynamic> json) {
    PresentationDefinition? presDef;
    final pd = json['presentation_definition'];
    if (pd is Map<String, dynamic>) {
      presDef = PresentationDefinition.fromJson(pd);
    }

    return PresentationRequest(
      clientId: json['client_id']?.toString() ?? '',
      nonce: json['nonce']?.toString(),
      state: json['state']?.toString(),
      requestUri: json['request_uri']?.toString(),
      responseUri: (json['response_uri'] ?? json['redirect_uri'])?.toString(),
      responseMode: json['response_mode']?.toString() ?? 'direct_post',
      presentationDefinition: presDef,
      presentationDefinitionUri:
          json['presentation_definition_uri']?.toString(),
      clientMetadata: json['client_metadata']?.toString(),
    );
  }

  PresentationRequest copyWith({
    String? clientId,
    String? nonce,
    String? state,
    String? requestUri,
    String? responseUri,
    String? responseMode,
    PresentationDefinition? presentationDefinition,
    String? presentationDefinitionUri,
    String? clientMetadata,
  }) {
    return PresentationRequest(
      clientId: clientId ?? this.clientId,
      nonce: nonce ?? this.nonce,
      state: state ?? this.state,
      requestUri: requestUri ?? this.requestUri,
      responseUri: responseUri ?? this.responseUri,
      responseMode: responseMode ?? this.responseMode,
      presentationDefinition:
          presentationDefinition ?? this.presentationDefinition,
      presentationDefinitionUri:
          presentationDefinitionUri ?? this.presentationDefinitionUri,
      clientMetadata: clientMetadata ?? this.clientMetadata,
    );
  }
}

/// Presentation Definition (PE spec)
class PresentationDefinition {
  final String id;
  final String? name;
  final String? purpose;
  final List<InputDescriptor> inputDescriptors;

  PresentationDefinition({
    required this.id,
    this.name,
    this.purpose,
    required this.inputDescriptors,
  });

  factory PresentationDefinition.fromJson(Map<String, dynamic> json) {
    final descriptors = <InputDescriptor>[];
    final raw = json['input_descriptors'];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map<String, dynamic>) {
          descriptors.add(InputDescriptor.fromJson(item));
        }
      }
    }
    return PresentationDefinition(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString(),
      purpose: json['purpose']?.toString(),
      inputDescriptors: descriptors,
    );
  }
}

/// Single input descriptor within a presentation definition
class InputDescriptor {
  final String id;
  final String? name;
  final String? purpose;
  final List<FieldConstraint> fields;
  final String? limitDisclosure; // 'required' or 'preferred'
  final List<String>? formats; // e.g. ['jwt_vc_json', 'vc+sd-jwt']

  InputDescriptor({
    required this.id,
    this.name,
    this.purpose,
    required this.fields,
    this.limitDisclosure,
    this.formats,
  });

  factory InputDescriptor.fromJson(Map<String, dynamic> json) {
    final fields = <FieldConstraint>[];
    final constraints = json['constraints'];
    if (constraints is Map) {
      final rawFields = constraints['fields'];
      if (rawFields is List) {
        for (final f in rawFields) {
          if (f is Map<String, dynamic>) {
            fields.add(FieldConstraint.fromJson(f));
          }
        }
      }
    }
    final limitDisc =
        constraints is Map ? constraints['limit_disclosure']?.toString() : null;

    List<String>? formats;
    final fmtRaw = json['format'];
    if (fmtRaw is Map) {
      formats = fmtRaw.keys.map((k) => k.toString()).toList();
    }

    return InputDescriptor(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString(),
      purpose: json['purpose']?.toString(),
      fields: fields,
      limitDisclosure: limitDisc,
      formats: formats,
    );
  }

  bool get requiresLimitedDisclosure => limitDisclosure == 'required';
}

/// A single field constraint in an input descriptor
class FieldConstraint {
  final List<String> path; // JSONPath like ["$.vc.credentialSubject.nik"]
  final String? filter; // JSON Schema filter (raw JSON string)
  final bool optional;

  FieldConstraint({
    required this.path,
    this.filter,
    this.optional = false,
  });

  factory FieldConstraint.fromJson(Map<String, dynamic> json) {
    final paths = <String>[];
    final rawPath = json['path'];
    if (rawPath is List) {
      paths.addAll(rawPath.map((p) => p.toString()));
    }
    return FieldConstraint(
      path: paths,
      filter: json['filter']?.toString(),
      optional: json['optional'] == true,
    );
  }

  /// The claim name extracted from path (e.g. "nik" from "$.vc.credentialSubject.nik")
  String get claimName {
    if (path.isEmpty) return '';
    final lastSegment = path.first.split('.').last.replaceAll(r'$', '');
    return lastSegment;
  }
}

/// Presentation Submission - matches VP to presentation definition
class PresentationSubmission {
  final String id;
  final String definitionId;
  final List<DescriptorMap> descriptorMap;

  PresentationSubmission({
    required this.id,
    required this.definitionId,
    required this.descriptorMap,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'definition_id': definitionId,
        'descriptor_map': descriptorMap.map((d) => d.toJson()).toList(),
      };
}

class DescriptorMap {
  final String id;
  final String format;
  final String path;
  final DescriptorMap? pathNested;

  DescriptorMap({
    required this.id,
    required this.format,
    required this.path,
    this.pathNested,
  });

  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{
      'id': id,
      'format': format,
      'path': path,
    };
    if (pathNested != null) {
      m['path_nested'] = pathNested!.toJson();
    }
    return m;
  }
}
