import 'dart:io';
import 'dart:typed_data';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;

class OcrService {
  final TextRecognizer _recognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  Future<Map<String, List<String>>> extrairValores(String imagePath) async {
    final bytes = await File(imagePath).readAsBytes();
    final image = img.decodeImage(bytes)!;

    final imgW = image.width;
    final imgH = image.height;

    const baseY = 0.35;
    const espacamentoY = 0.075;
    const offsetBobinas = 0.035;
    const colunasX = [0.15, 0.21, 0.27, 0.33, 0.45, 0.51, 0.57, 0.63];
    const larguraCol = 0.055;
    const alturaCampo = 0.028;

    final resultado = <String, List<String>>{};

    for (int pos = 1; pos <= 6; pos++) {
      final y = baseY + espacamentoY * (pos - 1);

      final tempoValores = <String>[];
      for (int col = 0; col < 8; col++) {
        final valor = await _reconhecerRegiao(
          image, imgW, imgH,
          colunasX[col], y, larguraCol, alturaCampo,
        );
        tempoValores.add(valor);
      }
      resultado['pos${pos}_tempo'] = tempoValores;

      final bobinasValores = <String>[];
      for (int col = 0; col < 8; col++) {
        final valor = await _reconhecerRegiao(
          image, imgW, imgH,
          colunasX[col], y + offsetBobinas, larguraCol, alturaCampo,
        );
        bobinasValores.add(valor);
      }
      resultado['pos${pos}_bobinas'] = bobinasValores;
    }

    return resultado;
  }

  Future<String> _reconhecerRegiao(
    img.Image fullImage, int imgW, int imgH,
    double xPercent, double yPercent, double wPercent, double hPercent,
  ) async {
    const margin = 8;

    final sx = (xPercent * imgW - margin).clamp(0, imgW).toInt();
    final sy = (yPercent * imgH - margin).clamp(0, imgH).toInt();
    final sw = (wPercent * imgW + margin * 2).clamp(1, imgW - sx).toInt();
    final sh = (hPercent * imgH + margin * 2).clamp(1, imgH - sy).toInt();

    final cropped = img.copyCrop(
      fullImage, x: sx, y: sy, width: sw, height: sh,
    );

    final upscaled = img.copyResize(cropped, width: sw * 3, height: sh * 3);

    final pngBytes = Uint8List.fromList(img.encodePng(upscaled));

    final inputImage = InputImage.fromBytes(
      bytes: pngBytes,
      metadata: InputImageMetadata(
        size: Size(upscaled.width.toDouble(), upscaled.height.toDouble()),
        rotation: InputImageRotation.rotation0deg,
        format: InputImageFormat.png,
        planeData: [],
      ),
    );

    final result = await _recognizer.processImage(inputImage);

    final texto = result.text.trim();
    final numeros = texto.replaceAll(RegExp(r'[^0-9]'), '');

    return numeros;
  }

  void dispose() {
    _recognizer.close();
  }
}
