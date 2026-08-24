import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import '../models/producao.dart';
import '../services/ocr_service.dart';
import 'review_screen.dart';

class ConfigScreen extends StatefulWidget {
  @override
  _ConfigScreenState createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  String _maquina = '';
  DateTime _data = DateTime.now();
  int _turnos = 4;
  String _operador = '';
  File? _foto;
  bool _processando = false;
  String _statusProcessamento = '';
  double _progresso = 0.0;

  final OcrService _ocrService = OcrService();

  Future<void> _tirarFoto() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nenhuma câmera encontrada')),
      );
      return;
    }

    final camera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CameraScreen(camera: camera),
      ),
    );

    if (result != null && result is File) {
      setState(() => _foto = result);
    }
  }

  Future<void> _extrairDados() async {
    if (_maquina.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Selecione a máquina')),
      );
      return;
    }
    if (_foto == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tire a foto da tela primeiro')),
      );
      return;
    }

    setState(() {
      _processando = true;
      _statusProcessamento = 'Preparando imagem...';
      _progresso = 0.1;
    });

    try {
      setState(() {
        _statusProcessamento = 'Executando OCR com ML Kit...';
        _progresso = 0.3;
      });

      final valores = await _ocrService.extrairValores(_foto!.path);

      // Preenche o modelo
      final producao = Producao(
        maquina: _maquina,
        data: '${_data.day}/${_data.month}/${_data.year}',
        turnos: _turnos,
        operador: _operador,
      );

      for (int i = 1; i <= 6; i++) {
        final tempo = valores['pos${i}_tempo'] ?? [];
        final bobinas = valores['pos${i}_bobinas'] ?? [];
        for (int j = 0; j < 8 && j < tempo.length; j++) {
          producao.posicoes[i]!.tempoRompido[j] = tempo[j];
        }
        for (int j = 0; j < 8 && j < bobinas.length; j++) {
          producao.posicoes[i]!.bobinasCheias[j] = bobinas[j];
        }
      }

      setState(() {
        _statusProcessamento = 'Concluído!';
        _progresso = 1.0;
      });

      await Future.delayed(Duration(milliseconds: 500));

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ReviewScreen(producao: producao),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $e')),
      );
    } finally {
      setState(() => _processando = false);
    }
  }

  @override
  void dispose() {
    _ocrService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Relatório de Produção'),
        backgroundColor: Color(0xFF2563EB),
        foregroundColor: Colors.white,
      ),
      body: _processando
          ? _buildProcessamento()
          : _buildFormulario(),
      floatingActionButton: _processando
          ? null
          : FloatingActionButton.extended(
              onPressed: _extrairDados,
              icon: Icon(Icons.document_scanner),
              label: Text('Extrair Dados'),
              backgroundColor: Color(0xFF2563EB),
              foregroundColor: Colors.white,
            ),
    );
  }

  Widget _buildProcessamento() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            value: _progresso,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
          ),
          SizedBox(height: 24),
          Text(
            _statusProcessamento,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 8),
          Text(
            'ML Kit processando imagem on-device',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildFormulario() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Configuração
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CONFIGURAÇÃO',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _maquina.isEmpty ? null : _maquina,
                    decoration: InputDecoration(
                      labelText: 'Máquina',
                      border: OutlineInputBorder(),
                    ),
                    items: ['18', '19', '20', '21']
                        .map((m) => DropdownMenuItem(
                              value: m,
                              child: Text('Máquina $m'),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _maquina = v!),
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _data,
                              firstDate: DateTime(2024),
                              lastDate: DateTime(2030),
                            );
                            if (date != null) setState(() => _data = date);
                          },
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Data',
                              border: OutlineInputBorder(),
                            ),
                            child: Text(
                              '${_data.day}/${_data.month}/${_data.year}',
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: _turnos,
                          decoration: InputDecoration(
                            labelText: 'Turnos',
                            border: OutlineInputBorder(),
                          ),
                          items: [2, 3, 4]
                              .map((t) => DropdownMenuItem(
                                    value: t,
                                    child: Text('$t Turnos'),
                                  ))
                              .toList(),
                          onChanged: (v) => setState(() => _turnos = v!),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  TextField(
                    decoration: InputDecoration(
                      labelText: 'Operador',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => _operador = v,
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 16),

          // Foto
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FOTO DA TELA',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: 16),
                  if (_foto != null)
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(_foto!),
                        ),
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: FloatingActionButton.small(
                            onPressed: _tirarFoto,
                            child: Icon(Icons.refresh),
                          ),
                        ),
                      ],
                    )
                  else
                    InkWell(
                      onTap: _tirarFoto,
                      child: Container(
                        height: 200,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.grey[400]!,
                            width: 2,
                            style: BorderStyle.solid,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.camera_alt,
                                size: 48, color: Colors.grey[400]),
                            SizedBox(height: 12),
                            Text(
                              'Toque para tirar foto da tela',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SizedBox(height: 80),
        ],
      ),
    );
  }
}

// ============================================
// TELA DE CÂMERA COM MIRA
// ============================================
class CameraScreen extends StatefulWidget {
  final CameraDescription camera;

  CameraScreen({required this.camera});

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.high,
      enableAudio: false,
    );
    _controller.initialize().then((_) {
      setState(() => _ready = true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _capturar() async {
    final xFile = await _controller.takePicture();
    Navigator.pop(context, File(xFile.path));
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Câmera
          CameraPreview(_controller),

          // Overlay com mira
          Positioned.fill(
            child: CustomPaint(
              painter: MiraPainter(),
            ),
          ),

          // Indicador
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Enquadre a tela dentro da mira',
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ),
          ),

          // Botão fechar
          Positioned(
            top: 40,
            left: 16,
            child: FloatingActionButton.small(
              backgroundColor: Colors.black54,
              onPressed: () => Navigator.pop(context),
              child: Icon(Icons.close),
            ),
          ),

          // Botão capturar
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(35),
                    onTap: _capturar,
                    child: Container(
                      margin: EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================
// PINTOR DA MIRA
// ============================================
class MiraPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    // Retângulo da mira (15% margem)
    final rect = Rect.fromLTWH(
      size.width * 0.05,
      size.height * 0.15,
      size.width * 0.9,
      size.height * 0.7,
    );

    // Desenha retângulo
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(8)),
      paint,
    );

    // Cantos destacados
    final cornerPaint = Paint()
      ..color = Color(0xFF06B6D4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    final cornerLength = 30.0;
    // Top-left
    canvas.drawLine(rect.topLeft, rect.topLeft + Offset(cornerLength, 0), cornerPaint);
    canvas.drawLine(rect.topLeft, rect.topLeft + Offset(0, cornerLength), cornerPaint);
    // Top-right
    canvas.drawLine(rect.topRight, rect.topRight + Offset(-cornerLength, 0), cornerPaint);
    canvas.drawLine(rect.topRight, rect.topRight + Offset(0, cornerLength), cornerPaint);
    // Bottom-left
    canvas.drawLine(rect.bottomLeft, rect.bottomLeft + Offset(cornerLength, 0), cornerPaint);
    canvas.drawLine(rect.bottomLeft, rect.bottomLeft + Offset(0, -cornerLength), cornerPaint);
    // Bottom-right
    canvas.drawLine(rect.bottomRight, rect.bottomRight + Offset(-cornerLength, 0), cornerPaint);
    canvas.drawLine(rect.bottomRight, rect.bottomRight + Offset(0, -cornerLength), cornerPaint);

    // Linhas guias centrais
    final guidePaint = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(rect.left + rect.width / 2, rect.top),
      Offset(rect.left + rect.width / 2, rect.bottom),
      guidePaint,
    );
    canvas.drawLine(
      Offset(rect.left, rect.top + rect.height / 2),
      Offset(rect.right, rect.top + rect.height / 2),
      guidePaint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
