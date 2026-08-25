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

      final nums = resultado.allNumbers;

      final producao = Producao(
        maquina: '1',
        data: DateTime.now().toString().substring(0, 10),
        operador: 'Operador',
      );

      // PARSER: os numeros vem em pares sequenciais
      // Par 1 -> Posicao 1 Turno 1 (tempo, bobina)
      // Par 2 -> Posicao 2 Turno 1
      // ...ate Posicao 6 Turno 1
      // Par 7 -> Posicao 1 Turno 2
      // ...ate Posicao 6 Turno 8
      // Total: 48 pares = 96 numeros (6 posicoes x 8 turnos x 2 valores)

      for (int pos = 1; pos <=
