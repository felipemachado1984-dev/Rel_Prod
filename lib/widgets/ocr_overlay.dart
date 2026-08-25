import 'package:flutter/material.dart';

class OcrLineData {
  final Rect box;
  final String text;
  OcrLineData(this.box, this.text);
}

class OcrOverlayPainter extends CustomPainter {
  final List<OcrLineData> lines;
  final Size imageSize;
  final bool pronto;

  OcrOverlayPainter({
    required this.lines,
    required this.imageSize,
    this.pronto = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (imageSize == Size.zero || lines.isEmpty) return;

    // BoxFit.cover: escala pra preencher tudo (corta o excesso)
    final sx = size.width / imageSize.width;
    final sy = size.height / imageSize.height;
    final scale = sx > sy ? sx : sy;

    final rw = imageSize.width * scale;
    final rh = imageSize.height * scale;
    final ox = (size.width - rw) / 2;
    final oy = (size.height - rh) / 2;

    final boxPaint = Paint()
      ..color = pronto ? Colors.green.withAlpha(160) : Colors.cyan.withAlpha(140)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = pronto ? Colors.green : Colors.cyan
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (final line in lines) {
      // Extrai apenas numeros da linha
      final nums = RegExp(r'\d+').allMatches(line.text).map((m) => m.group(0)!).join(' ');
      if (nums.isEmpty) continue;

      final rect = Rect.fromLTRB(
        ox + line.box.left * scale,
        oy + line.box.top * scale,
        ox + line.box.right * scale,
        oy + line.box.bottom * scale,
      );

      // Caixa semi-transparente
      canvas.drawRect(rect, boxPaint);
      canvas.drawRect(rect, borderPaint);

      // Label com os numeros
      final tp = TextPainter(
        text: TextSpan(
          text: nums,
          style: TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            backgroundColor: pronto ? Colors.green.withAlpha(200) : Colors.cyan.withAlpha(200),
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '...',
      );
      tp.layout();
      tp.paint(canvas, Offset(rect.left, rect.top - tp.height));
    }
  }

  @override
  bool shouldRepaint(OcrOverlayPainter old) =>
      old.pronto != pronto || old.lines != lines || old.imageSize != imageSize;
}
