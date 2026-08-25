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
  final double boxSize;

  OcrOverlayPainter({
    required this.lines,
    required this.imageSize,
    this.pronto = false,
    this.boxSize = 332,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // === Caixa guia 332x332 centralizada ===
    final boxLeft = (size.width - boxSize) / 2;
    final boxTop = (size.height - boxSize) / 2;
    final guideRect = Rect.fromLTWH(boxLeft, boxTop, boxSize, boxSize);

    // Fundo semi-transparente dentro da caixa
    final boxBgPaint = Paint()
      ..color = pronto ? Colors.green.withAlpha(30) : Colors.white.withAlpha(15);
    canvas.drawRect(guideRect, boxBgPaint);

    // Borda da caixa
    final boxBorderPaint = Paint()
      ..color = pronto ? Colors.green : Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = pronto ? 4 : 3;
    canvas.drawRect(guideRect, boxBorderPaint);

    // Cantos da caixa (estilo viewfinder)
    final cornerPaint = Paint()
      ..color = pronto ? Colors.green : Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;
    const cl = 30.0; // corner length
    // Sup-esq
    canvas.drawLine(Offset(boxLeft, boxTop), Offset(boxLeft + cl, boxTop), cornerPaint);
    canvas.drawLine(Offset(boxLeft, boxTop), Offset(boxLeft, boxTop + cl), cornerPaint);
    // Sup-dir
    canvas.drawLine(Offset(boxLeft + boxSize, boxTop), Offset(boxLeft + boxSize - cl, boxTop), cornerPaint);
    canvas.drawLine(Offset(boxLeft + boxSize, boxTop), Offset(boxLeft + boxSize, boxTop + cl), cornerPaint);
    // Inf-esq
    canvas.drawLine(Offset(boxLeft, boxTop + boxSize), Offset(boxLeft + cl, boxTop + boxSize), cornerPaint);
    canvas.drawLine(Offset(boxLeft, boxTop + boxSize), Offset(boxLeft, boxTop + boxSize - cl), cornerPaint);
    // Inf-dir
    canvas.drawLine(Offset(boxLeft + boxSize, boxTop + boxSize), Offset(boxLeft + boxSize - cl, boxTop + boxSize), cornerPaint);
    canvas.drawLine(Offset(boxLeft + boxSize, boxTop + boxSize), Offset(boxLeft + boxSize, boxTop + boxSize - cl), cornerPaint);

    // === Overlays dos numeros (estilo Google Lens) ===
    if (imageSize == Size.zero || lines.isEmpty) return;

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
      final nums = RegExp(r'\d+').allMatches(line.text).map((m) => m.group(0)!).join(' ');
      if (nums.isEmpty) continue;

      final rect = Rect.fromLTRB(
        ox + line.box.left * scale,
        oy + line.box.top * scale,
        ox + line.box.right * scale,
        oy + line.box.bottom * scale,
      );

      canvas.drawRect(rect, boxPaint);
      canvas.drawRect(rect, borderPaint);

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
