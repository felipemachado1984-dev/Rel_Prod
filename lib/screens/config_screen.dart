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

      // ===== PARSER LINHA POR LINHA =====
      // O OCR le a tabela linha por linha (esquerda -> direita, cima -> baixo)
      // Cada linha da tabela tem: [numero_da_posicao] [t1_tempo] [t1_bobina] [t2_tempo] [t2_bobina] ... [t8_tempo] [t8_bobina]
      // O numero da posicao (1-6) precisa ser removido dos dados

      int posicaoAtual = 0;
      List<String> dadosAcumulados = [];

      for (final block in res.blocks) {
        for (final line in block.lines) {
          final nums = RegExp(r'\d+')
              .allMatches(line.text)
              .map((m) => m.group(0)!)
              .toList();

          if (nums.isEmpty) continue;

          // Verifica se o primeiro numero e um rotulo de posicao (1-6)
          final primeiro = int.tryParse(nums[0]);

          if (primeiro != null && primeiro >= 1 && primeiro <= 6) {
            // Se ja estava acumulando dados da posicao anterior, salva
            if (posicaoAtual >= 1 && dadosAcumulados.isNotEmpty) {
              _atribuirDados(prod, posicaoAtual, dadosAcumulados);
            }
            // Inicia nova posicao
            posicaoAtual = primeiro;
            dadosAcumulados = nums.sublist(1); // remove o rotulo
          } else if (posicaoAtual >= 1) {
            // Continuacao da linha atual (OCR quebrou a linha)
            dadosAcumulados.addAll(nums);
          }
          // Se posicaoAtual == 0, e cabecalho - ignora
        }
      }

      // Salva a ultima posicao
      if (posicaoAtual >= 1 && dadosAcumulados.isNotEmpty) {
        _atribuirDados(prod, posicaoAtual, dadosAcumulados);
      }

      // Fallback: se nao detectou posicoes, joga em sequencia
      if (prod.posicoes.isEmpty) {
        final allNums = res.allNumbers;
        for (int pos = 1; pos <= 6; pos++) {
          final tempo = List<String>.filled(8, '');
          final bob = List<String>.filled(8, '');
          for (int t = 0; t < 8; t++) {
            int i = t * 12 + (pos - 1) * 2;
            if (i < allNums.length) tempo[t] = allNums[i];
            if (i + 1 < allNums.length) bob[t] = allNums[i + 1];
          }
          prod.posicoes[pos] = PosicaoData(tempoRompido: tempo, bobinasCheias: bob);
        }
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

  void _atribuirDados(Producao prod, int posicao, List<String> dados) {
    final tempo = List<String>.filled(8, '');
    final bobinas = List<String>.filled(8, '');

    // Os dados vem em pares: tempo, bobina, tempo, bobina...
    for (int t = 0; t < 8; t++) {
      int i = t * 2;
      if (i < dados.length) tempo[t] = dados[i];
      if (i + 1 < dados.length) bobinas[t] = dados[i + 1];
    }

    prod.posicoes[posicao] = PosicaoData(
      tempoRompido: tempo,
      bobinasCheias: bobinas,
    );
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
