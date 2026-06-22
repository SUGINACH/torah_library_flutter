// lib/widgets/texture_painter.dart
// שיפור #2: הוספת CustomPaint למימוש מרקמים בפועל

import 'package:flutter/material.dart';

class TexturePainter extends CustomPainter {
  final String pattern;
  final Color baseColor;
  final Color? overlayColor;
  final double brightness;
  final double contrast;

  TexturePainter({
    required this.pattern,
    required this.baseColor,
    this.overlayColor,
    this.brightness = 1.0,
    this.contrast = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = baseColor;
    
    // ציור רקע בסיסי
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    // ציור המרקם לפי סוג
    switch (pattern) {
      case 'paper':
        _drawPaperTexture(canvas, size);
        break;
      case 'parchment':
        _drawParchmentTexture(canvas, size);
        break;
      case 'grid':
        _drawGridTexture(canvas, size);
        break;
      case 'dots':
        _drawDotsTexture(canvas, size);
        break;
      case 'stripes':
        _drawStripesTexture(canvas, size);
        break;
      case 'smooth':
      default:
        // אין מרקם נוסף
        break;
    }

    // החלת בהירות וניגודיות
    if (brightness != 1.0 || contrast != 1.0) {
      final colorFilter = ColorFilter.matrix(_generateColorMatrix(brightness, contrast));
      canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());
      canvas.drawColorFilter(colorFilter);
      canvas.restore();
    }
  }

  void _drawPaperTexture(Canvas canvas, Size size) {
    final random = (baseColor.value % 1000).toInt();
    final paint = Paint()
      ..color = (overlayColor ?? baseColor).withValues(alpha: 0.03)
      ..strokeWidth = 0.5;

    for (int i = 0; i < 200; i++) {
      final x = ((random * (i + 1)) % size.width.toInt()).toDouble();
      final y = ((random * (i + 7)) % size.height.toInt()).toDouble();
      canvas.drawCircle(Offset(x, y), 0.5, paint);
    }
  }

  void _drawParchmentTexture(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF8B7355).withValues(alpha: 0.05)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // קווים עדינים לאורך הדף
    for (double y = 0; y < size.height; y += 15) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // כתמים עדינים
    final random = (baseColor.value % 500).toInt();
    for (int i = 0; i < 50; i++) {
      final x = ((random * (i + 3)) % size.width.toInt()).toDouble();
      final y = ((random * (i + 11)) % size.height.toInt()).toDouble();
      canvas.drawCircle(Offset(x, y), 2 + (i % 3), paint..color = paint.color.withValues(alpha: 0.02));
    }
  }

  void _drawGridTexture(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = (overlayColor ?? baseColor).withValues(alpha: 0.15)
      ..strokeWidth = 1.0;

    const spacing = 20.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _drawDotsTexture(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = (overlayColor ?? baseColor).withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;

    const spacing = 12.0;
    for (double x = 6; x < size.width; x += spacing) {
      for (double y = 6; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.5, paint);
      }
    }
  }

  void _drawStripesTexture(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = (overlayColor ?? baseColor).withValues(alpha: 0.1);

    const spacing = 8.0;
    for (double y = 0; y < size.height; y += spacing * 2) {
      canvas.drawRect(
        Rect.fromLTWH(0, y, size.width, spacing),
        paint,
      );
    }
  }

  List<double> _generateColorMatrix(double brightness, double contrast) {
    // יצירת מטריצת צבע לכוונון בהירות וניגודיות
    final b = brightness;
    final c = contrast;
    
    return [
      c, 0, 0, 0, (1 - c) * 0.5 * 255 * b,
      0, c, 0, 0, (1 - c) * 0.5 * 255 * b,
      0, 0, c, 0, (1 - c) * 0.5 * 255 * b,
      0, 0, 0, 1, 0,
    ];
  }

  @override
  bool shouldRepaint(TexturePainter oldDelegate) {
    return oldDelegate.pattern != pattern ||
           oldDelegate.baseColor != baseColor ||
           oldDelegate.overlayColor != overlayColor ||
           oldDelegate.brightness != brightness ||
           oldDelegate.contrast != contrast;
  }
}

class TexturedContainer extends StatelessWidget {
  final Widget child;
  final String pattern;
  final Color backgroundColor;
  final Color? overlayColor;
  final double brightness;
  final double contrast;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;

  const TexturedContainer({
    super.key,
    required this.child,
    required this.pattern,
    required this.backgroundColor,
    this.overlayColor,
    this.brightness = 1.0,
    this.contrast = 1.0,
    this.borderRadius,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: Stack(
        children: [
          CustomPaint(
            size: Size.infinite,
            painter: TexturePainter(
              pattern: pattern,
              baseColor: backgroundColor,
              overlayColor: overlayColor,
              brightness: brightness,
              contrast: contrast,
            ),
          ),
          Padding(
            padding: padding ?? EdgeInsets.zero,
            child: child,
          ),
        ],
      ),
    );
  }
}
