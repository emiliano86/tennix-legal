import 'package:flutter/material.dart';
import 'dart:math';

/// Widget che disegna una G multicolore simile al logo Google.
/// Parametri:
/// - size: dimensione (larghezza/altezza) del quadrato che contiene la G
/// - background: colore di sfondo della superficie su cui disegnare (usato per il "foro" interno)
class GoogleLogoWidget extends StatelessWidget {
  final double size;
  final Color background;

  const GoogleLogoWidget({
    Key? key,
    this.size = 40,
    this.background = Colors.transparent,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GoogleGpainter(background: background)),
    );
  }
}

class _GoogleGpainter extends CustomPainter {
  final Color background;
  _GoogleGpainter({required this.background});

  @override
  void paint(Canvas canvas, Size size) {
    final double stroke = size.width * 0.165; // spessore "g"
    final Rect rect = Offset.zero & size;
    final Offset center = Offset(size.width / 2, size.height / 2);

    // disegniamo gli archi con stroke paint
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    // Parametri base arco
    final Rect arcRect = Rect.fromCircle(
      center: center,
      radius: size.width * 0.42,
    );

    // NOTE: gli angoli sono in radianti; 0 è a destra, + verso il basso (senso orario).
    // Qui disegniamo 4 segmenti che approssimano i colori del logo Google.
    // 1) Blue (top-left -> top)
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(arcRect, -pi * 0.75, pi * 0.5, false, paint);

    // 2) Red (top-right)
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(arcRect, -pi * 0.25, pi * 0.45, false, paint);

    // 3) Yellow (bottom-right)
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(arcRect, pi * 0.25, pi * 0.32, false, paint);

    // 4) Green (bottom-left / tail)
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(arcRect, pi * 0.57, pi * 0.52, false, paint);

    // Creiamo il "foro" interno cancellando con blendMode.clear su un layer
    // per ottenere l'effetto di stroke ben visibile con centro trasparente.
    canvas.saveLayer(rect, Paint());
    final double innerRadius = size.width * 0.22;
    final Paint clearPaint = Paint()
      ..blendMode = BlendMode.clear
      ..isAntiAlias = true;
    canvas.drawCircle(center, innerRadius, clearPaint);

    // Infine disegniamo il piccolo "taglio" della G (la barretta interna)
    // Lo disegniamo con colore background per creare la forma della barra.
    final Paint bgPaint = Paint()
      ..color = background
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // Rettangolo obliquo che simula la barra interna della "G"
    final double w = size.width * 0.22;
    final double h = size.height * 0.09;
    final RRect notch = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(
          center.dx + size.width * 0.18,
          center.dy - size.height * 0.02,
        ),
        width: w,
        height: h,
      ),
      Radius.circular(4),
    );
    canvas.drawRRect(notch, bgPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
