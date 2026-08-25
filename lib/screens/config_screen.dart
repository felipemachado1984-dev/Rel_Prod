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
        operador: 'Operador',
      );

      // ===== PARSER: filtra rotulos e mapeia por turno =====
      // Estrutura da tabela (cada linha = 1 turno):
      // [turno_label] [P1tempo P1bob] [P2tempo P2bob] ... [P6tempo P6bob]
      // = 1 rotulo + 12 dados = 13 numeros por linha
      // Ou sem rotulo: 12 numeros por linha

      final cleanNums = <String>[];

      for (final block in res.blocks) {
        for (final line in block.lines) {
          final lineNums = RegExp(r'\d+')
              .allMatches(line.text)
              .map((m) => m.group(0)!)
              .toList();

          if (lineNums.isEmpty) continue;

          // Se a linha tem 13 numeros e o primeiro e 1-8, remove o rotulo de turno
          if (lineNums.length == 13) {
            final first = int.tryParse(lineNums[0]);
            if (first != null && first >= 1 && first <= 8) {
              cleanNums.addAll(lineNums.sublist(1));
            } else {
              cleanNums.addAll(lineNums);
            }
          } else if (lineNums.length == 12) {
            // 12 numeros = dados sem rotulo
            cleanNums.addAll(lineNums);
          } else if (lineNums.length > 13) {
            // Linha mesclada - tenta quebrar em chunks de 12
            // Primeiro remove o rotulo se existir
            int start = 0;
            final first = int.tryParse(lineNums[0]);
            if (first != null && first >= 1 && first <= 8) {
              start = 1;
            }
            // Pega de 12 em 12
            for (int i = start; i + 12 <= lineNums.length; i += 12) {
              cleanNums.addAll(lineNums.sublist(i, i + 12));
            }
            // Sobra
            final remaining = (lineNums.length - start) % 12;
            if (remaining > 0) {
              final offset = lineNums.length - remaining;
              cleanNums.addAll(lineNums.sublist(offset));
            }
          } else if (lineNums.length >= 10) {
            // Linha quase completa, adiciona
            cleanNums.addAll(lineNums);
          } else if (lineNums.length <= 4 && cleanNums.isNotEmpty) {
            // Linha curta - pode ser rotulo de posicao ou cabecalho
            // So adiciona se for continuacao de dados
            final first = int.tryParse(lineNums[0]);
            if (first != null && first >= 1 && first <= 6 && lineNums.length == 1) {
              // Rotulo de posicao isolado - ignora
            } else {
              cleanNums.addAll(lineNums);
            }
          } else {
            cleanNums.addAll(lineNums);
          }
        }
      }

      // Se cleanNums tem mais de 96, trunca
      // Se tem menos, usa o que tem
      // Mapeia: turno * 12 + (pos-1) * 2
      for (int pos = 1; pos <= 6; pos++) {
        final tempo = List<String>.filled(8, '');
        final bob = List<String>.filled(8, '');
        for (int turno = 0; turno < 8; turno++) {
          int i = turno * 12 + (pos - 1) * 2;
          if (i < cleanNums.length) tempo[turno] = cleanNums[i];
          if (i + 1 < cleanNums.length) bob[turno] = cleanNums[i + 1];
        }
        prod.posicoes[pos] =
            PosicaoData(tempoRompido: tempo, bobinasCheias: bob);
      }

      // Debug info: passa a lista de numeros extraidos pra tela de revisao
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
