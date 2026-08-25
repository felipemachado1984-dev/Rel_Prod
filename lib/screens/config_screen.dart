import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/producao.dart';
import '../services/ocr_service.dart';
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
  int _numDetected = 0;
  CameraDescription? _camDesc;
  int _lastProcessTime = 0;

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
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    _initFuture = _cam.initialize();
    await _initFuture;
    if (mounted) {
      setState(() => _ready = true);
      _cam.startImageStream(_processFrame);
    }
  }

  Future<void> _processFrame(CameraImage image) async {
    if (_isDetecting || _busy) return;

    // Throttle: processa 1 frame a cada 800ms
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastProcessTime < 800) return;
    _lastProcessTime = now;

    _isDetecting = true;
    try {
      final inputImage = _toInputImage(image);
      if (inputImage == null) {
        _isDetecting = false;
        return;
      }

      final result = await _recognizer.processImage(inputImage);

      int count = 0;
      for (final block in result.blocks) {
        for (final line in block.lines) {
          count += RegExp(r'\d+').allMatches(line.text).length;
        }
      }

      if (mounted) {
        setState(() {
          _numDetected = count;
        });
      }
    } catch (e) {
      // ignora erros de frame
    } finally {
      _isDetecting = false;
    }
  }

  InputImage? _toInputImage(CameraImage image) {
    try {
      final WriteBuffer buffer = WriteBuffer();
      for (final plane in image.planes) {
        buffer.putUint8List(plane.bytes);
      }
      final bytes = buffer.done().buffer.asUint8List();

      final rotation = InputImageRotation.values.firstWhere(
        (r) => r.rawValue == (_camDesc?.sensorOrientation ?? 0),
        orElse: () => InputImageRotation.rotation0deg,
      );

      return InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.yuv_420,
          planeData: image.planes.map((plane) {
            return InputImagePlaneMetadata(
              bytesPerRow: plane.bytesPerRow,
              height: plane.height ?? image.height,
              width: plane.width ?? image.width,
            );
          }).toList(),
        ),
      );
    } catch (e) {
      return null;
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

    // Para o stream antes de tirar a foto
    try {
      await _cam.stopImageStream();
    } catch (e) {
      // ignora
    }

    try {
      final XFile f = await _cam.takePicture();
      if (!mounted) return;

      final cropped = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (c) => CropScreen(imagePath: f.path)),
      );

      if (cropped == null) {
        if (mounted) {
          setState(() => _busy = false);
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
            if (first != null &&
                first >= 1 &&
                first <= 4 &&
                lineNums.length == 13) {
              cleanNums.addAll(lineNums.sublist(1));
            } else {
              cleanNums.addAll(lineNums);
            }
          } else if (lineNums.length >= 6) {
            cleanNums.addAll(lineNums);
          } else if (lineNums.length <= 2 && cleanNums.isNotEmpty) {
            final first = int.tryParse(lineNums[0]);
            if (!(lineNums.length == 1 &&
                first != null &&
                first >= 1 &&
                first <= 6)) {
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
        prod.posicoes[pos] =
            PosicaoData(tempoRompido: tempo, bobinasCheias: bob);
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
        try {
          _cam.startImageStream(_processFrame);
        } catch (e) {
          // ignora
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pronto = _numDetected >= 48;

    return Scaffold(
      appBar: AppBar(
        title: Text('Capturar Relatorio'),
        backgroundColor: Color(0xFF2563EB),
        foregroundColor: Colors.white,
      ),
      body: !_ready
          ? Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // Camera preview
                Positioned.fill(child: CameraPreview(_cam)),

                // Badge de numeros detectados (topo)
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
                              ? 'PRONTO! $_numDetected numeros detectados'
                              : '$_numDetected de 48 numeros detectados',
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

                // Dica no centro inferior
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
                          ? 'Foto pronta para captura! Todos os numeros foram reconhecidos.'
                          : 'Aproxime a camera ate detectar todos os 48 numeros.',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),

                // Loading overlay
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
                                style: TextStyle(
                                    color: Colors.white, fontSize: 16)),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(16),
          color: Color(0xFF1E3A5F),
          child: ElevatedButton.icon(
            onPressed: _busy ? null : _foto,
            icon: Icon(pronto ? Icons.check : Icons.camera_alt),
            label: Text(
              pronto ? 'Tirar Foto (Pronto!)' : 'Tirar Foto',
              style: TextStyle(fontSize: 16),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: pronto ? Colors.green : Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ),
    );
  }
}
