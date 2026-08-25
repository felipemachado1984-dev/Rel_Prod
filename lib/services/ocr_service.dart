import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrResult {
  final List<String> allNumbers;
  final String rawText;

  OcrResult({required this.allNumbers, required this.rawText});
}

class OcrService {
  final TextRecognizer _recognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  Future<OcrResult> extrairValores(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final result = await _recognizer.processImage(inputImage);

    final rawText = result.text;
    final allNumbers = <String>[];

    for (final block in result.blocks) {
      for (final line in block.lines) {
        final lineText = line.text.trim();
        final numbers = RegExp(r'\d+').allMatches(lineText);
        for (final match in numbers) {
          allNumbers.add(match.group(0)!);
        }
      }
    }

    return OcrResult(allNumbers: allNumbers, rawText: rawText);
  }

  void dispose() {
    _recognizer.close();
  }
}
