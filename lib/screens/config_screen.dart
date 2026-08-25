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

      final prod = Producao(
        maquina: '1',
        data: DateTime.now().toString().substring(0, 10),
        operador: '',
      );

      // ===== PARSER: 4 turnos x 6 posicoes x 2 valores = 48 numeros =====
      // Cada linha da tabela = 1 turno
      // Estrutura: [turno_label] [P1t P1b] [P2t P2b] ... [P6t P6b]
      // = 1 rotulo + 12 dados = 13 numeros por linha (ou 12 sem rotulo)

      final cleanNums = <String>[];

      for (final block in res.blocks) {
        for (final line in block.lines) {
          final lineNums = RegExp(r'\d+')
              .allMatches(line.text)
              .map((m) => m.group(0)!)
              .toList();

          if (lineNums.isEmpty) continue;

          // Tenta remover rotulo de turno (1-4) se for o primeiro numero
          // e a linha tiver 13 numeros (1 rotulo + 12 dados)
          if (lineNums.length >= 12) {
            final first = int.tryParse(lineNums[0]);
            if (first != null && first >= 1 && first <= 4 && lineNums.length == 13) {
              cleanNums.addAll(lineNums.sublist(1));
            } else {
              cleanNums.addAll(lineNums);
            }
          } else if (lineNums.length >= 6) {
            // Linha parcial, adiciona
            cleanNums.addAll(lineNums);
          } else if (lineNums.length <= 2 && cleanNums.isNotEmpty) {
            // Pode ser rotulo de posicao isolado - so adiciona se nao for 1-6 sozinho
            if (!(lineNums.length == 1 && int.tryParse(lineNums[0]) != null && int.tryParse(lineNums[0])! >= 1 && int.tryParse(lineNums[0])! <= 6)) {
              cleanNums.addAll(lineNums);
            }
          } else {
            cleanNums.addAll(lineNums);
          }
        }
      }

      // Mapeia: 4 turnos x 12 valores por turno
      // turno t (0-3), posicao p (1-6): index = t * 12 + (p-1) * 2
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
