import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/producao.dart';
import '../services/ocr_service.dart';
import '../services/parser_service.dart';
import '../widgets/ocr_overlay.dart';
import 'camera_helper.dart';
import 'review_screen.dart';
import 'crop_screen.dart';

class ConfigScreen extends StatefulWidget {
  @override
  _ConfigScreenState createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  late CameraController _cam;
  late Future<void> _initFuture;
  final TextRecognizer _recognizer =
      TextRecognizer(script: TextRecognitionScript.latin);
  final OcrService _ocr = OcrService();
  bool _busy = false;
  bool _ready = false;
  bool _isDetecting = false;
  bool _autoCaptureDone = false;
  int _numDetected = 0;
  CameraDescription? _camDesc;
  int _lastProcessTime = 0;
  List<OcrLineData> _overlays = [];
  Size _rotatedSize = Size.zero;
  Size _screenSize = Size.zero;
  static const double boxSize = 332;

  @override
  void initState() {
    super.initState();
    _startCam();
  }

  Future<void> _startCam() async {
    final cams = await availableCameras();
    if (cams.isEmpty) return;
    final back = cams.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cams.first,
    );
    _camDesc = back;
    _cam = CameraController(
      back,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21,
    );
    _initFuture = _cam.initialize();
    await _initFuture;
    if (mounted) {
      setState(() => _ready = true);
      _cam.startImageStream(_processFrame);
    }
  }

  Future<void> _processFrame(CameraImage image) async {
    if (_isDetecting || _busy || _autoCaptureDone) return;
    if (_screenSize == Size.zero) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastProcessTime < 700) return;
    _lastProcessTime = now;

    _isDetecting = true;
    try {
      _rotatedSize = CameraHelper.getRotatedSize(image, _camDesc);
      final inputImage = CameraHelper.toInputImage(image, _camDesc);
      if (inputImage == null) return;

      final result = await _recognizer.processImage(inputImage);
      final fr = CameraHelper.processFrame(
          result, _rotatedSize, _screenSize, boxSize);

      final newOverlays = <OcrLineData>[];
      for (int i = 0; i < fr.boxes.length; i++) {
        newOverlays.add(OcrLineData(fr.boxes[i], fr.texts[i]));
      }

      if (mounted) {
        setState(() {
          _numDetected = fr.numDetected;
          _overlays = newOverlays;
        });

        if (fr.numDetected == 48 && !_autoCaptureDone && !_busy) {
          _autoCaptureDone = true;
          _foto();
        }
      }
    } catch (e) {
    } finally {
      _isDetecting = false;
    }
  }

  @override
  void dispose() {
    _cam.dispose();
    _recognizer.close();
    _ocr.dispose();
    super.dispose();
  }

  Future<void> _foto() async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      await _cam.stopImageStream();
    } catch (e) {}

    try {
      final XFile f = await _cam.takePicture();
      if (!mounted) return;

      final pronto = _numDetected == 48;
      String? cropped;

      if (pronto) {
        cropped = f.path;
      } else {
        cropped = await Navigator.push<String>(
          context,
          MaterialPageRoute(builder: (c) => CropScreen(imagePath: f.path)),
        );
      }

      if (cropped == null) {
        if (mounted) {
          setState(() {
            _busy = false;
            _autoCaptureDone = false;
          });
          _cam.startImageStream(_processFrame);
        }
        return;
      }

      final res = await _ocr.extrairValores(cropped);
      if (!mounted) return;

      final prod = ParserService.parse(res);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (c) => ReviewScreen(
            producao: prod,
            rawText: res.rawText,
            debugNums: res.allNumbers,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pronto = _numDetected == 48;

    return Scaffold(
      appBar: AppBar(
        title: Text('Capturar Relatorio'),
        backgroundColor: Color(0xFF2563EB),
        foregroundColor: Colors.white,
      ),
      body: !_ready
          ? Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                _screenSize = Size(constraints.maxWidth, constraints.maxHeight);
                return Stack(
                  children: [
                    Positioned.fill(child: CameraPreview(_cam)),
                    Positioned.fill(
                      child: CustomPaint(
                        painter: OcrOverlayPainter(
                          lines: _overlays,
                          imageSize: _rotatedSize,
                          pronto: pronto,
                          boxSize: boxSize,
                        ),
                        child: Container(),
                      ),
                    ),
                    Positioned(
                      top: 16,
                      left: 16,
                      right: 16,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        decoration: BoxDecoration(
                          color: pronto
                              ? Colors.green.withAlpha(220)
                              : Colors.orange.withAlpha(220),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              pronto ? Icons.check_circle : Icons.search,
                              color: Colors.white,
                              size: 22,
                            ),
                            SizedBox(width: 10),
                            Text(
                              pronto
                                  ? 'PRONTO! 48 numeros - capturando...'
                                  : '$_numDetected de 48 na caixa',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 100,
                      left: 16,
                      right: 16,
                      child: Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          pronto
                              ? 'Captura automatica! Aguarde...'
                              : 'Encaixe o relatorio dentro da caixa branca.',
                          style: TextStyle(color: Colors.white, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    if (_busy)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black54,
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(color: Colors.white),
                                SizedBox(height: 12),
                                Text('Processando...',
                                    style: TextStyle(color: Colors.white, fontSize: 16)),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
      bottomNavigationBar: SafeArea(
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(16),
          color: Color(0xFF1E3A5F),
          child: ElevatedButton.icon(
            onPressed: (_busy || pronto) ? null : _foto,
            icon: Icon(Icons.camera_alt),
            label: Text(
              pronto ? 'Capturando automaticamente...' : 'Tirar Foto Manual',
              style: TextStyle(fontSize: 16),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ),
    );
  }
}
