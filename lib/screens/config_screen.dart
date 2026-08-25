import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/producao.dart';
import '../services/ocr_service.dart';
import '../widgets/ocr_overlay.dart';
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
      final rotation = InputImageRotation.values.firstWhere(
        (r) => r.rawValue == (_camDesc?.sensorOrientation ?? 0),
        orElse: () => InputImageRotation.rotation0deg,
      );

      if (rotation == InputImageRotation.rotation90deg ||
          rotation == InputImageRotation.rotation270deg) {
        _rotatedSize = Size(image.height.toDouble(), image.width.toDouble());
      } else {
        _rotatedSize = Size(image.width.toDouble(), image.height.toDouble());
      }

      final inputImage = InputImage.fromBytes(
        bytes: image.planes[0].bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );

      final result = await _recognizer.processImage(inputImage);

      // === Calcular a caixa 332x332 no espaco da imagem ===
      final sx = _screenSize.width / _rotatedSize.width;
      final sy = _screenSize.height / _rotatedSize.height;
      final scale = sx > sy ? sx : sy;

      final rw = _rotatedSize.width * scale;
      final rh = _rotatedSize.height * scale;
      final ox = (_screenSize.width - rw) / 2;
      final oy = (_screenSize.height - rh) / 2;

      // Caixa na tela (centralizada)
      final screenBoxLeft = (_screenSize.width - boxSize) / 2;
      final screenBoxTop = (_screenSize.height - boxSize) / 2;
      final screenBoxRight = screenBoxLeft + boxSize;
      final screenBoxBottom = screenBoxTop + boxSize;

      // Converter para coordenadas da imagem
      final imgBoxLeft = (screenBoxLeft - ox) / scale;
      final imgBoxTop = (screenBoxTop - oy) / scale;
      final imgBoxRight = (screenBoxRight - ox) / scale;
      final imgBoxBottom = (screenBoxBottom - oy) / scale;

      int count = 0;
      final newOverlays = <OcrLineData>[];

      for (final block in result.blocks) {
        for (final line in block.lines) {
          final nums = RegExp(r'\d+').allMatches(line.text).length;
          if (nums == 0) continue;

          // Centro da linha OCR
          final cx = (line.boundingBox.left + line.boundingBox.right) / 2;
          final cy = (line.boundingBox.top + line.boundingBox.bottom) / 2;

          // Verifica se o centro esta dentro da caixa
          if (cx >= imgBoxLeft && cx <= imgBoxRight &&
              cy >= imgBoxTop && cy <= imgBoxBottom) {
            count += nums;
            newOverlays.add(OcrLineData(line.boundingBox, line.text));
          }
        }
      }

      if (mounted) {
        setState(() {
          _numDetected = count;
          _overlays = newOverlays;
        });

        // AUTO-CAPTURA: exatamente 48 dentro da caixa
        if (count == 48 && !_autoCaptureDone && !_busy) {
          _autoCaptureDone = true;
          _foto();
        }
      }
    } catch (e) {
      // ignora
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

      final prod = Producao(
        maquina: '1',
        data: DateTime.now().toString().substring(0, 10),
        operador: '',
      );

      final cleanNums = <String>[];
      for (final block in res.blocks) {
        for (final line in block.lines) {
          final lineNums = RegExp(r'\d+')
              .allMatches(line.text)
              .map((m) => m.group(0)!)
              .toList();
          if (lineNums.isEmpty) continue;

          if (lineNums.length >= 12) {
            final first = int.tryParse(lineNums[0]);
            if (first != null && first >= 1 && first <= 4 && lineNums.length == 13) {
              cleanNums.addAll(lineNums.sublist(1));
            } else {
              cleanNums.addAll(lineNums);
            }
          } else if (lineNums.length >= 6) {
            cleanNums.addAll(lineNums);
          } else if (lineNums.length <= 2 && cleanNums.isNotEmpty) {
            final first = int.tryParse(lineNums[0]);
            if (!(lineNums.length == 1 && first != null && first >= 1 && first <= 6)) {
              cleanNums.addAll(lineNums);
            }
          } else {
            cleanNums.addAll(lineNums);
          }
        }
      }

      for (int pos = 1; pos <= 6; pos++) {
        final tempo = List<String>.filled(4, '');
        final bob = List<String>.filled(4, '');
        for (int turno = 0; turno < 4; turno++) {
          int i = turno * 12 + (pos - 1) * 2;
          if (i < cleanNums.length) tempo[turno] = cleanNums[i];
          if (i + 1 < cleanNums.length) bob[turno] = cleanNums[i + 1];
        }
        prod.posicoes[pos] = PosicaoData(tempoRompido: tempo, bobinasCheias: bob);
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (c) => ReviewScreen(
            producao: prod,
            rawText: res.rawText,
            debugNums: cleanNums,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
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

                    // Overlay estilo Google Lens + Caixa guia
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

                    // Badge de contagem
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

                    // Dica
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
                      
