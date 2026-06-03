import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/database_service.dart';
import '../services/plate_parser.dart';
import '../theme/app_theme.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with SingleTickerProviderStateMixin {
  CameraController? _controller;
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  final _manual = TextEditingController();
  late final AnimationController _pulse;
  bool _initializing = true;
  bool _processing = false;
  String? _detectedPlate;
  String _detectedText = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 950))..repeat(reverse: true);
    _initCamera();
  }

  Future<void> _initCamera() async {
    final permission = await Permission.camera.request();
    if (!permission.isGranted) {
      setState(() {
        _initializing = false;
        _error = 'Camera permission is needed to scan number plates.';
      });
      return;
    }
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _initializing = false;
          _error = 'No camera found on this device.';
        });
        return;
      }
      final camera = cameras.firstWhere(
        (item) => item.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(camera, ResolutionPreset.high, enableAudio: false);
      await controller.initialize();
      if (!mounted) return;
      setState(() {
        _controller = controller;
        _initializing = false;
      });
    } catch (error) {
      setState(() {
        _initializing = false;
        _error = 'Camera could not start: $error';
      });
    }
  }

  Future<void> _scanStillFrame() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _processing) return;
    setState(() => _processing = true);
    try {
      final photo = await controller.takePicture();
      final result = await _recognizer.processImage(InputImage.fromFilePath(photo.path));
      final plate = PlateParser.extract(result.text);
      if (!mounted) return;
      setState(() {
        _detectedText = result.text;
        _detectedPlate = plate;
      });
      if (plate != null) HapticFeedback.mediumImpact();
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  void _confirm(String plate) {
    final cleaned = DatabaseService.normalizePlate(plate);
    if (cleaned.isEmpty) return;
    Navigator.of(context).pop(cleaned);
  }

  @override
  void dispose() {
    _controller?.dispose();
    _recognizer.close();
    _manual.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Scan Vehicle Plate'),
      ),
      body: Stack(
        children: [
          if (_initializing)
            const Center(child: CircularProgressIndicator(color: AppColors.amber))
          else if (controller != null && controller.value.isInitialized)
            Center(child: CameraPreview(controller))
          else
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error ?? 'Camera unavailable', textAlign: TextAlign.center),
              ),
            ),
          _GuideOverlay(pulse: _pulse),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Column(
              children: [
                if (_detectedPlate != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.72),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.green),
                    ),
                    child: Column(
                      children: [
                        const Text('Detected Plate', style: TextStyle(color: Colors.white70)),
                        const SizedBox(height: 6),
                        Text(
                          _detectedPlate!,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 34,
                            letterSpacing: 2,
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _processing ? null : _scanStillFrame,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(56),
                          backgroundColor: AppColors.amber,
                          foregroundColor: Colors.black,
                        ),
                        icon: _processing
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 3))
                            : const Icon(Icons.center_focus_strong),
                        label: Text(_processing ? 'Scanning...' : 'Scan Frame'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _detectedPlate == null ? null : () => _confirm(_detectedPlate!),
                        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56), backgroundColor: AppColors.green),
                        icon: const Icon(Icons.check_circle),
                        label: const Text('Confirm Plate'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _manual,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9 -]')),
                    TextInputFormatter.withFunction((oldValue, newValue) {
                      return newValue.copyWith(text: newValue.text.toUpperCase());
                    }),
                  ],
                  decoration: InputDecoration(
                    hintText: _detectedText.isEmpty ? 'Manual override plate' : 'Manual override plate',
                    suffixIcon: IconButton(
                      onPressed: () => _confirm(_manual.text),
                      icon: const Icon(Icons.arrow_forward),
                    ),
                  ),
                  onSubmitted: _confirm,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideOverlay extends StatelessWidget {
  const _GuideOverlay({required this.pulse});

  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: pulse,
        builder: (context, _) {
          final alpha = 0.55 + (pulse.value * 0.45);
          return CustomPaint(
            size: Size.infinite,
            painter: _GuidePainter(color: AppColors.amber.withOpacity(alpha)),
          );
        },
      ),
    );
  }
}

class _GuidePainter extends CustomPainter {
  _GuidePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final overlay = Paint()..color = Colors.black.withOpacity(0.42);
    final guide = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.42),
      width: size.width * 0.82,
      height: size.height * 0.18,
    );
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRect(guide);
    canvas.drawPath(path, overlay..style = PaintingStyle.fill);

    final paint = Paint()
      ..color = color
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const corner = 42.0;
    for (final start in [
      guide.topLeft,
      guide.topRight,
      guide.bottomLeft,
      guide.bottomRight,
    ]) {
      final xSign = start.dx == guide.left ? 1.0 : -1.0;
      final ySign = start.dy == guide.top ? 1.0 : -1.0;
      canvas.drawLine(start, Offset(start.dx + corner * xSign, start.dy), paint);
      canvas.drawLine(start, Offset(start.dx, start.dy + corner * ySign), paint);
    }
  }

  @override
  bool shouldRepaint(_GuidePainter oldDelegate) => oldDelegate.color != color;
}
