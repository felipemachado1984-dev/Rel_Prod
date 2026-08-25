import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class FrameResult {
  final int numDetected;
  final List<Rect> boxes;
  final List<String> texts;
  final Size rotatedSize;
  FrameResult(this.numDetected, this.boxes, this.texts, this.rotatedSize);
}

class CameraHelper {
  static InputImage? toInputImage(CameraImage image, CameraDescription? cam) {
    try {
      final rotation = InputImageRotation.values.firstWhere(
        (r) => r.rawValue == (cam?.sensorOrientation ?? 0),
        orElse: () => InputImageRotation.rotation0deg,
      );
      return InputImage.fromBytes(
        bytes: image.planes[0].bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );
    } catch (e) {
      return null;
    }
  }

  static Size getRotatedSize(CameraImage image, CameraDescription? cam) {
    final rotation = InputImageRotation.values.firstWhere(
      (r) => r.rawValue == (cam?.sensorOrientation ?? 0),
      orElse: () => InputImageRotation.rotation0deg,
    );
    if (rotation == InputImageRotation.rotation90deg ||
        rotation == InputImageRotation.rotation270deg) {
      return Size(image.height.toDouble(), image.width.toDouble());
    }
    return Size(image.width.toDouble(), image.height.toDouble());
  }

  static FrameResult processFrame(
    RecognizedText result,
    Size rotatedSize,
    Size screenSize,
    double boxSize,
  ) {
    final sx = screenSize.width / rotatedSize.width;
    final sy = screenSize.height / rotatedSize.height;
    final scale = sx > sy ? sx : sy;
    final rw = rotatedSize.width * scale;
    final rh = rotatedSize.height * scale;
    final ox = (screenSize.width - rw) / 2;
    final oy = (screenSize.height - rh) / 2;

    final screenBoxLeft = (screenSize.width - boxSize) / 2;
    final screenBoxTop = (screenSize.height - boxSize) / 2;
    final screenBoxRight = screenBoxLeft + boxSize;
    final screenBoxBottom = screenBoxTop + boxSize;

    final imgBoxLeft = (screenBoxLeft - ox) / scale;
    final imgBoxTop = (screenBoxTop - oy) / scale;
    final imgBoxRight = (screenBoxRight - ox) / scale;
    final imgBoxBottom = (screenBoxBottom - oy) / scale;

    int count = 0;
    final boxes = <Rect>[];
    final texts = <String>[];

    for (final block in result.blocks) {
      for (final line in block.lines) {
        final nums = RegExp(r'\d+').allMatches(line.text).length;
        if (nums == 0) continue;

        final cx = (line.boundingBox.left + line.boundingBox.right) / 2;
        final cy = (line.boundingBox.top + line.boundingBox.bottom) / 2;

        if (cx >= imgBoxLeft && cx <= imgBoxRight &&
            cy >= imgBoxTop && cy <= imgBoxBottom) {
          count += nums;
          boxes.add(line.boundingBox);
          texts.add(line.text);
        }
      }
    }

    return FrameResult(count, boxes, texts, rotatedSize);
  }
}
