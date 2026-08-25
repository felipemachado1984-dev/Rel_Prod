import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrResult {
  final List<String> allNumbers;
  final String rawText;
  final List<OcrBlock> blocks;

  OcrResult({
    required this.allNumbers,
    required this.rawText,
    required this.blocks,
  });
}

class OcrBlock {
  final List<OcrLine> lines;
  OcrBlock({required this.lines});
}

class OcrLine {
  final String text;
  OcrLine({required this.text});
}

class OcrService {
  final TextRecognizer _recognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  Future<OcrResult> extrairValores(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final result = await _recognizer.processImage(inputImage);

    final rawText = result.text;
    final allNumbers = <String>[];
    final blocks = <OcrBlock>[];

    for (final block in result.blocks) {
      final lines = <OcrLine>[];
      for (final line in block.lines) {
        final lineText = line.text.trim();
        lines.add(OcrLine(text: lineText));

        final numbers = RegExp(r'\d+').allMatches(lineText);
        for (final match in numbers) {
          allNumbers.add(match.group(0)!);
        }
      }
      blocks.add(OcrBlock(lines: lines));
    }

    return OcrResult(
      allNumbers: allNumbers,
      rawText: rawText,
      blocks: blocks,
    );
  }

  void dispose() {
    _recognizer.close();
  }
}
