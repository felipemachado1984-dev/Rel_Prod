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

      // Roda OCR pra verificar quantos numeros detectou
      final res = await _ocr.extrairValores(cropped);
      if (!mounted) return;

      final numCount = res.allNumbers.length;

      // Mostra tela de verificacao
      final confirmar = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (c) => VerificacaoScreen(
            imagePath: cropped,
            numDetectados: numCount,
            rawText: res.rawText,
          ),
        ),
      );

      if (confirmar != true) {
        // Usuario quer refazer a foto
        setState(() => _busy = false);
        return;
      }

      // Usuario confirmou - monta a producao
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
          : Stack(
              children: [
                Positioned.fill(child: CameraPreview(_cam)),
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
                      'Tire a foto do relatorio. Depois voce seleciona a area e verifica se todos os numeros foram lidos.',
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
            icon: Icon(Icons.camera_alt),
            label: Text('Tirar Foto', style: TextStyle(fontSize: 16)),
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

// ===== TELA DE VERIFICACAO =====
class VerificacaoScreen extends StatelessWidget {
  final String imagePath;
  final int numDetectados;
  final String rawText;

  VerificacaoScreen({
    required this.imagePath,
    required this.numDetectados,
    required this.rawText,
  });

  @override
  Widget build(BuildContext context) {
    final pronto = numDetectados >= 48;

    return Scaffold(
      appBar: AppBar(
        title: Text('Verificar Foto'),
        backgroundColor: Color(0xFF2563EB),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Imagem recortada
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              margin: EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[400]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(imagePath),
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          // Badge de numeros detectados
          Container(
            width: double.infinity,
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: pronto
                  ? Colors.green.withAlpha(220)
                  : Colors.orange.withAlpha(220),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  pronto ? Icons.check_circle : Icons.warning,
                  color: Colors.white,
                  size: 28,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    pronto
                        ? 'PRONTO! $numDetectados numeros detectados'
                        : '$numDetectados de 48 numeros detectados',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (!pronto)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                'Dica: aproxime mais a camera ou melhore a iluminacao.',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ),
          // Botoes
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context, false),
                    icon: Icon(Icons.refresh),
                    label: Text('Refazer Foto', style: TextStyle(fontSize: 15)),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      foregroundColor: Color(0xFF2563EB),
                      side: BorderSide(color: Color(0xFF2563EB)),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context, true),
                    icon: Icon(pronto ? Icons.check : Icons.arrow_forward),
                    label: Text(
                      pronto ? 'Confirmar' : 'Usar Mesmo Assim',
                      style: TextStyle(fontSize: 15),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: pronto ? Colors.green : Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
