import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/credential_model.dart';
import '../../utils/app_colors.dart';

/// Screen untuk menampilkan raw JWT VC / JWT VP yang tersimpan di wallet IDentia.
/// Menampilkan:
///   - Raw JWT string (bisa di-copy)
///   - Decoded Header (JSON)
///   - Decoded Payload (JSON)
///   - Untuk SD-JWT: daftar disclosures
class JwtViewerScreen extends StatefulWidget {
  final CredentialModel credential;

  const JwtViewerScreen({super.key, required this.credential});

  @override
  State<JwtViewerScreen> createState() => _JwtViewerScreenState();
}

class _JwtViewerScreenState extends State<JwtViewerScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // Parsed parts
  String _rawJwt = '';
  bool _isSdJwt = false;
  String _jwtPart = '';
  List<String> _disclosures = [];
  String _kbJwt = '';

  Map<String, dynamic> _header = {};
  Map<String, dynamic> _payload = {};
  String _headerJson = '';
  String _payloadJson = '';
  String _parseError = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabCount, vsync: this);
    _parse();
  }

  int get _tabCount => _isSdJwt ? 4 : 3;

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _parse() {
    _rawJwt = widget.credential.rawJwt ?? '';
    if (_rawJwt.isEmpty) {
      _parseError = 'Tidak ada raw JWT yang tersimpan untuk credential ini.';
      return;
    }

    try {
      _isSdJwt = _rawJwt.contains('~');

      if (_isSdJwt) {
        final parts = _rawJwt.split('~');
        _jwtPart = parts.first;
        // disclosures are the middle parts (non-empty, not the last KB-JWT)
        final middle = parts.sublist(1);
        // Last part can be KB-JWT (3 segments) or empty
        if (middle.isNotEmpty) {
          final last = middle.last;
          if (last.isNotEmpty && last.split('.').length == 3) {
            _kbJwt = last;
            _disclosures = middle.sublist(0, middle.length - 1)
                .where((d) => d.isNotEmpty)
                .toList();
          } else {
            _disclosures =
                middle.where((d) => d.isNotEmpty).toList();
          }
        }
      } else {
        _jwtPart = _rawJwt.trim();
      }

      // Decode header & payload from _jwtPart
      final segments = _jwtPart.split('.');
      if (segments.length >= 2) {
        _header = _decodeSegment(segments[0]);
        _payload = _decodeSegment(segments[1]);
        _headerJson = _prettyJson(_header);
        _payloadJson = _prettyJson(_payload);
      } else {
        _parseError = 'Format JWT tidak valid (segmen < 2).';
      }
    } catch (e) {
      _parseError = 'Gagal parse JWT: $e';
    }
  }

  Map<String, dynamic> _decodeSegment(String segment) {
    String padded = segment.replaceAll('-', '+').replaceAll('_', '/');
    while (padded.length % 4 != 0) {
      padded += '=';
    }
    final decoded = utf8.decode(base64.decode(padded));
    final json = jsonDecode(decoded);
    if (json is Map<String, dynamic>) return json;
    return {'value': json};
  }

  String _prettyJson(Map<String, dynamic> map) {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(map);
  }

  String _decodeDisclosure(String disclosure) {
    try {
      String padded =
          disclosure.replaceAll('-', '+').replaceAll('_', '/');
      while (padded.length % 4 != 0) {
        padded += '=';
      }
      final decoded = utf8.decode(base64.decode(padded));
      final json = jsonDecode(decoded);
      if (json is List && json.length >= 3) {
        return '🔑 ${json[1]}: ${json[2]}';
      }
      return decoded;
    } catch (_) {
      return disclosure;
    }
  }

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label berhasil disalin ke clipboard'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final credential = widget.credential;
    final tabs = [
      const Tab(icon: Icon(Icons.code, size: 16), text: 'Raw JWT'),
      const Tab(icon: Icon(Icons.article_outlined, size: 16), text: 'Header'),
      const Tab(icon: Icon(Icons.data_object, size: 16), text: 'Payload'),
      if (_isSdJwt)
        const Tab(
            icon: Icon(Icons.lock_open_outlined, size: 16),
            text: 'Disclosures'),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1D2E),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              credential.type,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            Text(
              _isSdJwt ? 'SD-JWT VC' : 'JWT VC',
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.6)),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Salin Raw JWT',
            icon: const Icon(Icons.copy_all, color: Colors.white),
            onPressed: _rawJwt.isNotEmpty
                ? () => _copyToClipboard(context, _rawJwt, 'Raw JWT')
                : null,
          ),
        ],
        bottom: _parseError.isNotEmpty
            ? null
            : TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: AppColors.primaryBlue,
                unselectedLabelColor: Colors.white54,
                indicatorColor: AppColors.primaryBlue,
                tabs: tabs,
              ),
      ),
      body: _parseError.isNotEmpty
          ? _buildError()
          : TabBarView(
              controller: _tabController,
              children: [
                _buildRawTab(),
                _buildJsonTab('JWT Header', _headerJson),
                _buildJsonTab('JWT Payload', _payloadJson),
                if (_isSdJwt) _buildDisclosuresTab(),
              ],
            ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            Text(
              _parseError,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRawTab() {
    return Column(
      children: [
        // Info strip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: const Color(0xFF1A1D2E),
          child: Row(
            children: [
              _badgeWidget(
                  _isSdJwt ? 'vc+sd-jwt' : (widget.credential.format ?? 'jwt_vc_json'),
                  AppColors.primaryBlue),
              const SizedBox(width: 8),
              _badgeWidget(
                  '${_rawJwt.length} chars',
                  const Color(0xFF4A5568)),
              if (_isSdJwt) ...[
                const SizedBox(width: 8),
                _badgeWidget('${_disclosures.length} disclosures',
                    const Color(0xFF38A169)),
                if (_kbJwt.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  _badgeWidget('KB-JWT ✓', const Color(0xFFD69E2E)),
                ],
              ],
              const Spacer(),
              GestureDetector(
                onTap: () => _copyToClipboard(context, _rawJwt, 'Raw JWT'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.copy, size: 13, color: AppColors.primaryBlue),
                      SizedBox(width: 4),
                      Text('Salin',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.primaryBlue)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // Raw JWT display
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SelectableText(
              _rawJwt,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: Color(0xFFE2E8F0),
                height: 1.6,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildJsonTab(String title, String jsonText) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: const Color(0xFF1A1D2E),
          child: Row(
            children: [
              Text(title,
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              GestureDetector(
                onTap: () => _copyToClipboard(context, jsonText, title),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.copy, size: 13, color: AppColors.primaryBlue),
                      SizedBox(width: 4),
                      Text('Salin',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.primaryBlue)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SelectableText(
              jsonText,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: Color(0xFFE2E8F0),
                height: 1.7,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDisclosuresTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _disclosures.length + (_kbJwt.isNotEmpty ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _disclosures.length && _kbJwt.isNotEmpty) {
          // KB-JWT section
          return _buildKbJwtCard();
        }

        final disclosure = _disclosures[index];
        final decoded = _decodeDisclosure(disclosure);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1D2E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF38A169).withValues(alpha: 0.3),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _badgeWidget('Disclosure ${index + 1}',
                        const Color(0xFF38A169)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => _copyToClipboard(
                          context, disclosure, 'Disclosure ${index + 1}'),
                      child: const Icon(Icons.copy,
                          size: 16, color: Colors.white38),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  decoded,
                  style: const TextStyle(
                    color: Color(0xFF68D391),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  disclosure,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    color: Colors.white38,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildKbJwtCard() {
    Map<String, dynamic> kbPayload = {};
    try {
      final parts = _kbJwt.split('.');
      if (parts.length == 3) kbPayload = _decodeSegment(parts[1]);
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFD69E2E).withValues(alpha: 0.4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _badgeWidget('Key Binding JWT (KB-JWT)',
                    const Color(0xFFD69E2E)),
                const Spacer(),
                GestureDetector(
                  onTap: () =>
                      _copyToClipboard(context, _kbJwt, 'KB-JWT'),
                  child: const Icon(Icons.copy,
                      size: 16, color: Colors.white38),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (kbPayload.isNotEmpty)
              SelectableText(
                _prettyJson(kbPayload),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: Color(0xFFFBD38D),
                  height: 1.6,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _badgeWidget(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3)),
    );
  }
}
