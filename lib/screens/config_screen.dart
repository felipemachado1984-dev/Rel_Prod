import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import '../models/producao.dart';
import '../services/ocr_service.dart';
import 'review_screen.dart';

class ConfigScreen extends StatefulWidget {
  @override
  _ConfigScreenState createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  late CameraController _cameraController;
  late Future<void> _initializeControllerFuture;
  final OcrService _ocrService = OcrService();
  bool _isProcessing = false;
  bool _cameraReady = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nenhuma camera encontrada')),
      );
      return;
    }

    final backCamera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    _cameraController = CameraController(
      backCamera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    _initializeControllerFuture = _cameraController.initialize();
    await _initializeControllerFuture;

    if (mounted) {
      setState(() {
        _cameraReady = true;
      });
    }
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _ocrService.dispose();
    super.dispose();
  }

  Future<void> _tirarFotoEProcessar() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      await _initializeControllerFuture;
      final XFile foto = await _cameraController.takePicture();

      if (!mounted) return;

      final croppedPath = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (context) => CropScreen(imagePath: foto.path),
        ),
      );

      if (croppedPath == null) {
        setState(() {
          _isProcessing = false;
        });
        return;
      }

      final resultado = await _ocrService.extrairValores(croppedPath);

      if (!mounted) return;

      // Monta a producao tentando interpretar a estrutura da tabela
      final producao = Producao(
        maquina: '1',
        data: DateTime.now().toString().substring(0, 10),
        operador: 'Operador',
      );

      // O OCR retorna blocos com linhas. Cada linha da tabela tem:
      // [posicao] [tempo1] [bobina1] [tempo2] [bobina2] ... [tempo8] [bobina8]
      // Mas pode ter ruido. Vamos parsear linha por linha.
      int posicaoAtual = 1;
      for (final block in resultado.blocks) {
        for (final line in block.lines) {
          final lineText = line.text.trim();
          // Extrai apenas os numeros da linha
          final numeros = RegExp(r'\d+')
              .allMatches(lineText)
              .map((m) => m.group(0)!)
              .toList();

          // Se a linha tem pelo menos 5 numeros, provavelmente e uma linha de dados
          if (numeros.length >= 5 && posicaoAtual <= 6) {
            // Remove o primeiro numero se for o numero da posicao (1-6)
            List<String> dados = numeros;
            if (dados.isNotEmpty && int.tryParse(dados[0]) == posicaoAtual) {
              dados = dados.sublist(1);
            }

            // Separa em pares tempo/bobina
            final tempo = <String>[];
            final bobinas = <String>[];
            for (int i = 0; i < dados.length && i < 16; i++) {
              if (i % 2 == 0) {
                tempo.add(dados[i]);
              } else {
                bobinas.add(dados[i]);
              }
            }
            // Completa com vazio se faltar
            while (tempo.length < 8) tempo.add('');
            while (bobinas.length < 8) bobinas.add('');

            producao.posicoes[posicaoAtual] = PosicaoData(
              tempoRompido: tempo,
              bobinasCheias: bobinas,
            );
            posicaoAtual++;
          }
        }
      }

      // Se nao conseguiu parsear nenhuma posicao, joga tudo em sequencia
      if (producao.posicoes.isEmpty) {
        int index = 0;
        for (int pos = 1; pos <= 6; pos++) {
          final tempo = <String>[];
          final bobinas = <String>[];
          for (int col = 0; col < 8; col++) {
            tempo.add(index < resultado.allNumbers.length
                ? resultado.allNumbers[index]
                : '');
            index++;
            bobinas.add(index < resultado.allNumbers.length
                ? resultado.allNumbers[index]
                : '');
            index++;
          }
          producao.posicoes[pos] = PosicaoData(
            tempoRompido: tempo,
            bobinasCheias: bobinas,
          );
        }
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ReviewScreen(
            producao: producao,
            rawText: resultado.rawText,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
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
      body: !_cameraReady
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: CameraPreview(_cameraController),
                ),
                if (_isProcessing)
                  Container(
                    padding: EdgeInsets.all(16),
                    color: Colors.black54,
                    child: Column(
                      children: [
                        CircularProgressIndicator(color: Colors.white),
                        SizedBox(height: 8),
                        Text('Processando imagem...',
                            style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16),
                  color: Color(0xFF1E3A5F),
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing ? null : _tirarFotoEProcessar,
                    icon: Icon(Icons.camera_alt),
                    label: Text('Tirar Foto do Relatorio'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

// ===== TELA DE CROP - OVERLAY TRANSPARENTE =====
class CropScreen extends StatefulWidget {
  final String imagePath;

  CropScreen({required this.imagePath});

  @override
  _CropScreenState createState() => _CropScreenState();
}

class _CropScreenState extends State<CropScreen> {
  double _rectLeft = 0.1;
  double _rectTop = 0.15;
  double _rectRight = 0.9;
  double _rectBottom = 0.85;

  bool _isDragging = false;
  int _dragCorner = 0;
  Size _imageSize = Size.zero;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Selecionar Area'),
        backgroundColor: Color(0xFF2563EB),
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _confirmarCrop,
            child: Text('Confirmar',
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Imagem de fundo
          Positioned.fill(
            child: Image.file(
              File(widget.imagePath),
              fit: BoxFit.contain,
            ),
          ),
          // Overlay com 4 retangulos escuros (NAO cobre a area selecionada)
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                _imageSize = Size(constraints.maxWidth, constraints.maxHeight);
                return GestureDetector(
                  onPanStart: (details) {
                    final dx = details.localPosition.dx / _imageSize.width;
                    final dy = details.localPosition.dy / _imageSize.height;
                    _dragCorner = _detectarCanto(dx, dy);
                    _isDragging = true;
                  },
                  onPanUpdate: (details) {
                    if (!_isDragging) return;
                    final dx = details.localPosition.dx / _imageSize.width;
                    final dy = details.localPosition.dy / _imageSize.height;
                    setState(() {
                      _atualizarRetangulo(dx, dy);
                    });
                  },
                  onPanEnd: (_) {
                    _isDragging = false;
                  },
                  child: CustomPaint(
                    painter: CropOverlayPainter(
                      _rectLeft,
                      _rectTop,
                      _rectRight,
                      _rectBottom,
                    ),
                    child: Container(),
                  ),
                );
              },
            ),
          ),
          // Instrucoes
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Arraste para mover. Arraste os cantos para redimensionar.',
                style: TextStyle(color: Colors.white, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _detectarCanto(double dx, double dy) {
    const threshold = 0.08;
    final distSupEsq =
        ((dx - _rectLeft).abs() + (dy - _rectTop).abs());
    final distSupDir =
        ((dx - _rectRight).abs() + (dy - _rectTop).abs());
    final distInfEsq =
        ((dx - _rectLeft).abs() + (dy - _rectBottom).abs());
    final distInfDir =
        ((dx - _rectRight).abs() + (dy - _rectBottom).abs());

    if (distSupEsq < threshold) return 1;
    if (distSupDir < threshold) return 2;
    if (distInfEsq < threshold) return 3;
    if (distInfDir < threshold) return 4;
    return 0;
  }

  void _atualizarRetangulo(double dx, double dy) {
    dx = dx.clamp(0.0, 1.0);
    dy = dy.clamp(0.0, 1.0);

    switch (_dragCorner) {
      case 0:
        final w = _rectRight - _rectLeft;
        final h = _rectBottom - _rectTop;
        _rectLeft = (dx - w / 2).clamp(0.0, 1.0 - w);
        _rectRight = _rectLeft + w;
        _rectTop = (dy - h / 2).clamp(0.0, 1.0 - h);
        _rectBottom = _rectTop + h;
        break;
      case 1:
        _rectLeft = dx.clamp(0.0, _rectRight - 0.1);
        _rectTop = dy.clamp(0.0, _rectBottom - 0.1);
        break;
      case 2:
        _rectRight = dx.clamp(_rectLeft + 0.1, 1.0);
        _rectTop = dy.clamp(0.0, _rectBottom - 0.1);
        break;
      case 3:
        _rectLeft = dx.clamp(0.0, _rectRight - 0.1);
        _rectBottom = dy.clamp(_rectTop + 0.1, 1.0);
        break;
      case 4:
        _rectRight = dx.clamp(_rectLeft + 0.1, 1.0);
        _rectBottom = dy.clamp(_rectTop + 0.1, 1.0);
        break;
    }
  }

  Future<void> _confirmarCrop() async {
    try {
      final bytes = await File(widget.imagePath).readAsBytes();
      final image = img.decodeImage(bytes)!;

      final imgW = image.width;
      final imgH = image.height;

      final imageAspect = imgW / imgH;
      final screenAspect = _imageSize.width / _imageSize.height;

      int cropX, cropY, cropW, cropH;

      if (imageAspect > screenAspect) {
        final scale = imgW / _imageSize.width;
        final renderedH = _imageSize.width * imgH / imgW;
        final offsetY = (_imageSize.height - renderedH) / 2;

        cropX = (_rectLeft * _imageSize.width * scale).round();
        cropW =
            ((_rectRight - _rectLeft) * _imageSize.width * scale).round();
        cropY = ((_rectTop * _imageSize.height - offsetY) * scale).round();
        cropH = ((_rectBottom - _rectTop) * _imageSize.height * scale)
            .round();
      } else {
        final scale = imgH / _imageSize.height;
        final renderedW = _imageSize.height * imgW / imgH;
        final offsetX = (_imageSize.width - renderedW) / 2;

        cropX = ((_rectLeft * _imageSize.width - offsetX) * scale).round();
        cropW =
            ((_rectRight - _rectLeft) * _imageSize.width * scale).round();
        cropY = (_rectTop * _imageSize.height * scale).round();
        cropH = ((_rectBottom - _rectTop) * _imageSize.height * scale)
            .round();
      }

      cropX = cropX.clamp(0, imgW - 1);
      cropY = cropY.clamp(0, imgH - 1);
      cropW = cropW.clamp(1, imgW - cropX);
      cropH = cropH.clamp(1, imgH - cropY);

      final cropped =
          img.copyCrop(image, x: cropX, y: cropY, width: cropW, height: cropH);

      final tempDir = await getTemporaryDirectory();
      final cropPath =
          '${tempDir.path}/crop_${DateTime.now().millisecondsSinceEpoch}.png';
      await File(cropPath).writeAsBytes(img.encodePng(cropped));

      Navigator.pop(context, cropPath);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao recortar: $e')),
      );
    }
  }
}

// ===== PAINTER COM OVERLAY TRANSPARENTE =====
class CropOverlayPainter extends CustomPainter {
  final double left, top, right, bottom;

  CropOverlayPainter(this.left, this.top, this.right, this.bottom);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final rect = Rect.fromLTRB(left * w, top * h, right * w, bottom * h);

    // Desenha 4 retangulos escuros AO REDOR da area selecionada
    // (em vez de cobrir tudo e tentar fazer buraco)
    final darkPaint = Paint()..color = Colors.black.withAlpha(140);

    // Topo
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, rect.top),
      darkPaint,
    );
    // Base
    canvas.drawRect(
      Rect.fromLTWH(0, rect.bottom, w, h - rect.bottom),
      darkPaint,
    );
    // Esquerda
    canvas.drawRect(
      Rect.fromLTWH(0, rect.top, rect.left, rect.height),
      darkPaint,
    );
    // Direita
    canvas.drawRect(
      Rect.fromLTWH(rect.right, rect.top, w - rect.right, rect.height),
      darkPaint,
    );

    // A AREA SELECIONADA FICA TOTALMENTE TRANSPARENTE

    // Bordas do retangulo
    final borderPaint = Paint()
      ..color = Color(0xFF2563EB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRect(rect, borderPaint);

    // Cantos brancos
    final cornerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    const cornerSize = 24.0;

    canvas.drawRect(
      Rect.fromLTWH(
          rect.left - 6, rect.top - 6, cornerSize, cornerSize),
      cornerPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(rect.right - cornerSize + 6, rect.top - 6,
          cornerSize, cornerSize),
      cornerPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(rect.left - 6,
          rect.bottom - cornerSize + 6, cornerSize, cornerSize),
      cornerPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(rect.right - cornerSize + 6,
          rect.bottom - cornerSize + 6, cornerSize, cornerSize),
      cornerPaint,
    );

    // Linhas guia (tercos)
    final guidePaint = Paint()
      ..color = Colors.white.withAlpha(80)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final thirdW = rect.width / 3;
    final thirdH = rect.height / 3;
    for (int i = 1; i < 3; i++) {
      canvas.drawLine(
        Offset(rect.left + thirdW * i, rect.top),
        Offset(rect.left + thirdW * i, rect.bottom),
        guidePaint,
      );
      canvas.drawLine(
        Offset(rect.left, rect.top + thirdH * i),
        Offset(rect.right, rect.top + thirdH * i),
        guidePaint,
      );
    }
  }

  @override
  bool shouldRepaint(CropOverlayPainter old) =>
      left != old.left ||
      top != old.top ||
      right != old.right ||
      bottom != old.bottom;
}
