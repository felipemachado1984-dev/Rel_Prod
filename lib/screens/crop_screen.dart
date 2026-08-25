import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;

class CropScreen extends StatefulWidget {
  final String imagePath;
  CropScreen({required this.imagePath});
  @override
  _CropScreenState createState() => _CropScreenState();
}

class _CropScreenState extends State<CropScreen> {
  double _left = 0.1, _top = 0.15, _right = 0.9, _bottom = 0.85;
  bool _drag = false;
  int _corner = 0;
  Size _sz = Size.zero;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Selecionar Area'),
        backgroundColor: Color(0xFF2563EB),
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _crop,
            child: Text('Confirmar',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Stack(children: [
        Positioned.fill(
          child: Image.file(File(widget.imagePath), fit: BoxFit.contain),
        ),
        Positioned.fill(
          child: LayoutBuilder(builder: (context, c) {
            _sz = Size(c.maxWidth, c.maxHeight);
            return GestureDetector(
              onPanStart: (d) {
                double dx = d.localPosition.dx / _sz.width;
                double dy = d.localPosition.dy / _sz.height;
                _corner = _detect(dx, dy);
                _drag = true;
              },
              onPanUpdate: (d) {
                if (!_drag) return;
                double dx = d.localPosition.dx / _sz.width;
                double dy = d.localPosition.dy / _sz.height;
                setState(() => _move(dx, dy));
              },
              onPanEnd: (_) => _drag = false,
              child: CustomPaint(
                painter: OverlayPainter(_left, _top, _right, _bottom),
                child: Container(),
              ),
            );
          }),
        ),
        Positioned(
          bottom: 16, left: 16, right: 16,
          child: Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('Arraste para mover. Cantos para redimensionar.',
              style: TextStyle(color: Colors.white, fontSize: 13),
              textAlign: TextAlign.center),
          ),
        ),
      ]),
    );
  }

  int _detect(double dx, double dy) {
    double se = (dx - _left).abs() + (dy - _top).abs();
    double sd = (dx - _right).abs() + (dy - _top).abs();
    double ie = (dx - _left).abs() + (dy - _bottom).abs();
    double id = (dx - _right).abs() + (dy - _bottom).abs();
    if (se < 0.08) return 1;
    if (sd < 0.08) return 2;
    if (ie < 0.08) return 3;
    if (id < 0.08) return 4;
    return 0;
  }

  void _move(double dx, double dy) {
    dx = dx.clamp(0.0, 1.0);
    dy = dy.clamp(0.0, 1.0);
    switch (_corner) {
      case 0:
        double w = _right - _left, h = _bottom - _top;
        _left = (dx - w / 2).clamp(0.0, 1.0 - w);
        _right = _left + w;
        _top = (dy - h / 2).clamp(0.0, 1.0 - h);
        _bottom = _top + h;
        break;
      case 1:
        _left = dx.clamp(0.0, _right - 0.1);
        _top = dy.clamp(0.0, _bottom - 0.1);
        break;
      case 2:
        _right = dx.clamp(_left + 0.1, 1.0);
        _top = dy.clamp(0.0, _bottom - 0.1);
        break;
      case 3:
        _left = dx.clamp(0.0, _right - 0.1);
        _bottom = dy.clamp(_top + 0.1, 1.0);
        break;
      case 4:
        _right = dx.clamp(_left + 0.1, 1.0);
        _bottom = dy.clamp(_top + 0.1, 1.0);
        break;
    }
  }

  Future<void> _crop() async {
    try {
      final bytes = await File(widget.imagePath).readAsBytes();
      final image = img.decodeImage(bytes)!;
      int iw = image.width, ih = image.height;
      double ia = iw / ih, sa = _sz.width / _sz.height;
      int cx, cy, cw, ch;
      if (ia > sa) {
        double sc = iw / _sz.width;
        double rh = _sz.width * ih / iw;
        double oy = (_sz.height - rh) / 2;
        cx = (_left * _sz.width * sc).round();
        cw = ((_right - _left) * _sz.width * sc).round();
        cy = ((_top * _sz.height - oy) * sc).round();
        ch = ((_bottom - _top) * _sz.height * sc).round();
      } else {
        double sc = ih / _sz.height;
        double rw = _sz.height * iw / ih;
        double ox = (_sz.width - rw) / 2;
        cx = ((_left * _sz.width - ox) * sc).round();
        cw = ((_right - _left) * _sz.width * sc).round();
        cy = (_top * _sz.height * sc).round();
        ch = ((_bottom - _top) * _sz.height * sc).round();
      }
      cx = cx.clamp(0, iw - 1);
      cy = cy.clamp(0, ih - 1);
      cw = cw.clamp(1, iw - cx);
      ch = ch.clamp(1, ih - cy);
      final cr = img.copyCrop(image, x: cx, y: cy, width: cw, height: ch);
      final dir = await getTemporaryDirectory();
      final p = '${dir.path}/crop_${DateTime.now().millisecondsSinceEpoch}.png';
      await File(p).writeAsBytes(img.encodePng(cr));
      Navigator.pop(context, p);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $e')),
      );
    }
  }
}

class OverlayPainter extends CustomPainter {
  final double l, t, r, b;
  OverlayPainter(this.l, this.t, this.r, this.b);
  @override
  void paint(Canvas canvas, Size size) {
    double w = size.width, h = size.height;
    Rect rect = Rect.fromLTRB(l * w, t * h, r * w, b * h);
    Paint dp = Paint()..color = Colors.black.withAlpha(140);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, rect.top), dp);
    canvas.drawRect(Rect.fromLTWH(0, rect.bottom, w, h - rect.bottom), dp);
    canvas.drawRect(Rect.fromLTWH(0, rect.top, rect.left, rect.height), dp);
    canvas.drawRect(Rect.fromLTWH(rect.right, rect.top, w - rect.right, rect.height), dp);
    Paint bp = Paint()
      ..color = Color(0xFF2563EB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRect(rect, bp);
    Paint cp = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    double cs = 24;
    canvas.drawRect(Rect.fromLTWH(rect.left - 6, rect.top - 6, cs, cs), cp);
    canvas.drawRect(Rect.fromLTWH(rect.right - cs + 6, rect.top - 6, cs, cs), cp);
    canvas.drawRect(Rect.fromLTWH(rect.left - 6, rect.bottom - cs + 6, cs, cs), cp);
    canvas.drawRect(Rect.fromLTWH(rect.right - cs + 6, rect.bottom - cs + 6, cs, cs), cp);
    Paint gp = Paint()
      ..color = Colors.white.withAlpha(80)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    double tw = rect.width / 3, th = rect.height / 3;
    for (int i = 1; i < 3; i++) {
      canvas.drawLine(Offset(rect.left + tw * i, rect.top), Offset(rect.left + tw * i, rect.bottom), gp);
      canvas.drawLine(Offset(rect.left, rect.top + th * i), Offset(rect.right, rect.top + th * i), gp);
    }
  }
  @override
  bool shouldRepaint(OverlayPainter o) =>
      l != o.l || t != o.t || r != o.r || b != o.b;
}
