import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../providers/wallet_provider.dart';
import '../../utils/app_colors.dart';
import '../issuance/issuance_flow_screen.dart';
import '../issuance/identia_login_screen.dart';
import '../presentation/presentation_consent_screen.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  MobileScannerController? _scannerController;
  bool _isFlashOn = false;
  bool _isProcessing = false;
  bool _isFrontCamera = false;

  @override
  void initState() {
    super.initState();
    _initScanner();
  }

  void _initScanner() {
    _scannerController = MobileScannerController(
      facing: CameraFacing.back,
      torchEnabled: false,
      detectionSpeed: DetectionSpeed.normal,
      formats: [BarcodeFormat.qrCode],
    );
  }

  @override
  void dispose() {
    _scannerController?.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final barcode = barcodes.first;
    String? scannedData = barcode.rawValue;

    if (scannedData == null || scannedData.isEmpty) {
      scannedData = barcode.displayValue;
    }

    if ((scannedData == null || scannedData.isEmpty) &&
        barcode.rawBytes != null &&
        barcode.rawBytes!.isNotEmpty) {
      try {
        scannedData = utf8.decode(barcode.rawBytes!, allowMalformed: true);
      } catch (e) {
        try {
          scannedData = String.fromCharCodes(barcode.rawBytes!);
        } catch (_) {}
      }
    }

    if (scannedData == null || scannedData.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('QR Code terdeteksi tetapi data tidak dapat dibaca. Coba dekatkan kamera.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    debugPrint('QR Scanner: Data detected, length: ${scannedData.length}');

    setState(() => _isProcessing = true);

    try {
      await _scannerController?.stop();
    } catch (e) {
      debugPrint('QR Scanner: Error stopping scanner: $e');
    }

    // Route based on QR scheme
    await _routeQRData(scannedData);
  }

  Future<void> _routeQRData(String qrData) async {
    final trimmed = qrData.trim();

    // OID4VCI: openid-credential-offer://
    if (trimmed.startsWith('openid-credential-offer://')) {
      if (mounted) {
        await _scannerController?.stop();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => IssuanceFlowScreen(deepLink: trimmed),
          ),
        );
      }
      return;
    }

    // OID4VP: openid4vp:// or similar
    if (trimmed.startsWith('openid4vp://') ||
        trimmed.startsWith('haip://') ||
        trimmed.startsWith('mdoc-openid4vp://')) {
      if (mounted) {
        await _scannerController?.stop();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => PresentationConsentScreen(qrData: trimmed),
          ),
        );
      }
      return;
    }

    // IDentia custom HTTPS credential offer → internal login screen
    if (trimmed.startsWith('https://') &&
        trimmed.contains('/credential-offer')) {
      if (mounted) {
        await _scannerController?.stop();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => IdentiaLoginScreen(qrUrl: trimmed),
          ),
        );
      }
      return;
    }

    // Try JSON - check for request_uri (OID4VP) or credential_offer (OID4VCI)
    try {
      final json = jsonDecode(trimmed) as Map<String, dynamic>;
      if (json.containsKey('request_uri') ||
          json.containsKey('presentation_definition') ||
          json.containsKey('response_uri')) {
        if (mounted) {
          await _scannerController?.stop();
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => PresentationConsentScreen(qrData: trimmed),
            ),
          );
        }
        return;
      }
      if (json.containsKey('credential_offer') ||
          json.containsKey('credential_offer_uri')) {
        if (mounted) {
          await _scannerController?.stop();
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => IssuanceFlowScreen(deepLink: trimmed),
            ),
          );
        }
        return;
      }
    } catch (_) {}

    // Fallback to existing behavior
    try {
      final walletProvider = context.read<WalletProvider>();
      final result = await walletProvider.scanAndVerifyQR(trimmed);
      if (mounted) {
        _showResultDialog(result);
      }
    } catch (e) {
      if (mounted) {
        _showResultDialog({'isValid': false, 'error': 'Terjadi kesalahan: $e'});
      }
    }
  }

  void _showResultDialog(Map<String, dynamic> result) {
    final isValid = result['isValid'] == true;
    final isVerifierRequest = result['isVerifierRequest'] == true;
    final screenContext = context; // Capture State's context to avoid shadowing

    showDialog(
      context: screenContext,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            // Result Icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: isValid
                    ? (isVerifierRequest
                        ? AppColors.primaryBlue.withValues(alpha: 0.1)
                        : AppColors.success.withValues(alpha: 0.1))
                    : AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isValid
                    ? (isVerifierRequest
                        ? Icons.verified_user
                        : Icons.check_circle)
                    : Icons.error,
                size: 50,
                color: isValid
                    ? (isVerifierRequest
                        ? AppColors.primaryBlue
                        : AppColors.success)
                    : AppColors.error,
              ),
            ),

            const SizedBox(height: 20),

            // Title
            Text(
              isValid
                  ? (isVerifierRequest
                      ? 'Permintaan Data Diterima'
                      : 'Verifikasi Berhasil!')
                  : 'Verifikasi Gagal',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isValid
                    ? (isVerifierRequest
                        ? AppColors.primaryBlue
                        : AppColors.success)
                    : AppColors.error,
              ),
            ),

            const SizedBox(height: 12),

            // Message
            Text(
              isValid
                  ? result['message'] ??
                      (isVerifierRequest
                          ? 'Verifier meminta akses ke kredensial Anda.'
                          : 'Kredensial telah diverifikasi dan ditambahkan ke dompet Anda.')
                  : result['error'] ??
                      'Tanda tangan digital tidak valid atau QR Code tidak dikenali.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textMedium,
              ),
            ),

            // Show credential info for issuer QR
            if (isValid &&
                !isVerifierRequest &&
                result['credential'] != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildInfoRow('Tipe', result['credential'].type),
                    _buildInfoRow('Penerbit', result['credential'].issuer),
                    _buildInfoRow('Pemegang', result['credential'].holderName),
                  ],
                ),
              ),
            ],

            // Show verifier request info
            if (isValid && isVerifierRequest) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primaryBlue.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  children: [
                    if (result['verifier'] != null)
                      _buildInfoRow('Verifier', result['verifier'].toString()),
                    if (result['requestedCredentials'] != null)
                      _buildInfoRow(
                        'Data Diminta',
                        (result['requestedCredentials'] as List).join(', '),
                      ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Buttons
            if (isVerifierRequest && isValid) ...[
              // Verifier request: Approve/Deny buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                        _resumeScanning();
                        if (mounted) {
                          ScaffoldMessenger.of(screenContext).showSnackBar(
                            const SnackBar(
                              content: Text('Permintaan data ditolak'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                      ),
                      child: const Text('Tolak'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                        Navigator.of(screenContext).pop(result);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                      ),
                      child: const Text('Setujui'),
                    ),
                  ),
                ],
              ),
            ] else ...[
              // Normal: Single button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    if (isValid) {
                      Navigator.of(screenContext)
                          .pop(); // Go back to previous screen
                    } else {
                      _resumeScanning();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isValid ? AppColors.success : AppColors.primaryBlue,
                  ),
                  child: Text(
                    isValid ? 'Lihat di Dompet' : 'Coba Lagi',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _resumeScanning() {
    setState(() {
      _isProcessing = false;
    });
    try {
      _scannerController?.start();
    } catch (e) {
      debugPrint('QR Scanner: Error restarting scanner: $e');
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textMedium,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera View
          if (_scannerController != null)
            MobileScanner(
              controller: _scannerController!,
              onDetect: _onDetect,
              errorBuilder: (context, error, child) {
                debugPrint('QR Scanner Widget Error: ${error.errorCode}');
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, color: Colors.white, size: 64),
                      const SizedBox(height: 16),
                      Text(
                        'Kamera Error: ${error.errorCode.name}',
                        style: const TextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          _scannerController?.dispose();
                          _initScanner();
                          setState(() {});
                        },
                        child: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                );
              },
            ),

          // Overlay with cutout for scan area
          IgnorePointer(
            child: CustomPaint(
              size: Size.infinite,
              painter: _ScanOverlayPainter(
                scanAreaSize: 280,
                borderRadius: 24,
              ),
            ),
          ),

          // Scan Area
          Center(
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.5),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Stack(
                children: [
                  // Corner decorations
                  ..._buildCorners(),

                  // Scanning line indicator (simplified)
                  if (!_isProcessing)
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color:
                                  AppColors.primaryBlue.withValues(alpha: 0.5),
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(22),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Top Controls
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Back Button
                    _buildControlButton(
                      icon: Icons.arrow_back,
                      onTap: () => Navigator.of(context).pop(),
                    ),

                    // Title
                    const Text(
                      'Scan QR Code',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    // Flash Button
                    _buildControlButton(
                      icon: _isFlashOn ? Icons.flash_on : Icons.flash_off,
                      onTap: () {
                        setState(() {
                          _isFlashOn = !_isFlashOn;
                        });
                        _scannerController?.toggleTorch();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Info
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(30),
                child: Column(
                  children: [
                    // Camera Switch
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildControlButton(
                          icon: Icons.cameraswitch,
                          onTap: () {
                            setState(() {
                              _isFrontCamera = !_isFrontCamera;
                            });
                            _scannerController?.switchCamera();
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Instructions
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        _isProcessing
                            ? 'Sedang memproses data QR Code...'
                            : 'Arahkan kamera ke QR Code dari Issuer atau Verifier untuk memproses credential',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Processing Indicator
          if (_isProcessing)
            Container(
              color: Colors.black.withValues(alpha: 0.7),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primaryBlue,
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Menghubungi server dan\nmemverifikasi credential...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }

  List<Widget> _buildCorners() {
    const cornerSize = 30.0;
    const cornerWidth = 4.0;
    const cornerColor = AppColors.primaryBlue;

    return [
      // Top Left
      Positioned(
        top: 0,
        left: 0,
        child: Container(
          width: cornerSize,
          height: cornerSize,
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: cornerColor, width: cornerWidth),
              left: BorderSide(color: cornerColor, width: cornerWidth),
            ),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
            ),
          ),
        ),
      ),
      // Top Right
      Positioned(
        top: 0,
        right: 0,
        child: Container(
          width: cornerSize,
          height: cornerSize,
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: cornerColor, width: cornerWidth),
              right: BorderSide(color: cornerColor, width: cornerWidth),
            ),
            borderRadius: BorderRadius.only(
              topRight: Radius.circular(24),
            ),
          ),
        ),
      ),
      // Bottom Left
      Positioned(
        bottom: 0,
        left: 0,
        child: Container(
          width: cornerSize,
          height: cornerSize,
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: cornerColor, width: cornerWidth),
              left: BorderSide(color: cornerColor, width: cornerWidth),
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(24),
            ),
          ),
        ),
      ),
      // Bottom Right
      Positioned(
        bottom: 0,
        right: 0,
        child: Container(
          width: cornerSize,
          height: cornerSize,
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: cornerColor, width: cornerWidth),
              right: BorderSide(color: cornerColor, width: cornerWidth),
            ),
            borderRadius: BorderRadius.only(
              bottomRight: Radius.circular(24),
            ),
          ),
        ),
      ),
    ];
  }
}

/// Custom painter that draws a dark overlay with a transparent cutout
/// for the scan area. This ensures the camera can detect QR codes
/// in the cutout area without the overlay interfering.
class _ScanOverlayPainter extends CustomPainter {
  final double scanAreaSize;
  final double borderRadius;

  _ScanOverlayPainter({
    required this.scanAreaSize,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    final scanRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: scanAreaSize,
        height: scanAreaSize,
      ),
      Radius.circular(borderRadius),
    );

    // Draw overlay with cutout
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(scanRect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
