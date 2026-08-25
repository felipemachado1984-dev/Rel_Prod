import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
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

      final resultado = await _ocrService.extrairValores(foto.path);

      if (!mounted) return;

      // Preenche a producao com os numeros encontrados
      final producao = Producao(
        maquina: '1',
        data: DateTime.now().toString().substring(0, 10),
        operador: 'Operador',
      );

      // Distribui os numeros encontrados nas posicoes
      int index = 0;
      for (int pos = 1; pos <= 6; pos++) {
        final tempo = <String>[];
        final bobinas = <String>[];
        for (int col = 0; col < 8; col++) {
          tempo.add(index < resultado.allNumbers.length ? resultado.allNumbers[index] : '');
          index++;
          bobinas.add(index < resultado.allNumbers.length ? resultado.allNumbers[index] : '');
          index++;
        }
        producao.posicoes[pos] = PosicaoData(
          tempoRompido: tempo,
          bobinasCheias: bobinas,
        );
      }

      Navigator.push(
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
