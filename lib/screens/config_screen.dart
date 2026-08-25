import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
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
  final OcrService _ocr = OcrService();
  bool _busy = false;
  bool _ready = false;

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
    _cam = CameraController(back, ResolutionPreset.high, enableAudio: false);
    _initFuture = _cam.initialize();
    await _initFuture;
    if (mounted) setState(() => _ready = true);
  }

  @override
  void dispose() {
    _cam.dispose();
    _ocr.dispose();
    super.dispose();
  }

  Future<void> _foto() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _initFuture;
      final XFile f = await _cam.takePicture();
      if (!mounted) return;
      final cropped = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (c) => CropScreen(imagePath: f.path)),
      );
      if (cropped == null) {
        setState(() => _busy = false);
        return;
      }
      final res = await _ocr.extrairValores(cropped);
      if (!mounted) return;
      final nums = res.allNumbers;
      final prod = Producao(
        maquina: '1',
        data: DateTime.now().toString().substring(0, 10),
        operador: 'Operador',
      );
      for (int pos = 1; pos <= 6; pos++) {
        final tempo = List<String>.filled(8, '');
        final bob = List<String>.filled(8, '');
        for (int turno = 0; turno < 8; turno++) {
          int i = turno * 12 + (pos - 1) * 2;
          if (i < nums.length) tempo[turno] = nums[i];
          if (i + 1 < nums.length) bob[turno] = nums[i + 1];
        }
        prod.posicoes[pos] = PosicaoData(tempoRompido: tempo, bobinasCheias: bob);
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (c) => ReviewScreen(producao: prod, rawText: res.rawText),
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Capturar Relatorio'),
        backgroundColor: Color(0xFF2563EB),
        foregroundColor: Colors.white,
      ),
      body: !_ready
          ? Center(child: CircularProgressIndicator())
          : Column(children: [
              Expanded(child: CameraPreview(_cam)),
              if (_busy)
                Container(
                  padding: EdgeInsets.all(16),
                  color: Colors.black54,
                  child: Column(children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 8),
                    Text('Processando...', style: TextStyle(color: Colors.white)),
                  ]),
                ),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                color: Color(0xFF1E3A5F),
                child: ElevatedButton.icon(
                  onPressed: _busy ? null : _foto,
                  icon: Icon(Icons.camera_alt),
                  label: Text('Tirar Foto'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ]),
    );
  }
}
