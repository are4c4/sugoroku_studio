import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/board.dart';

class BoardConnectionPainter extends CustomPainter {
  BoardConnectionPainter({required this.board});

  final Board board;

  static const double squareSize = 72;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blueGrey.shade400
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final byId = <String, BoardSquare>{
      for (final square in board.squares) square.id: square,
    };

    for (final connection in board.connections) {
      final from = byId[connection.fromSquareId];
      final to = byId[connection.toSquareId];
      if (from == null || to == null) continue;

      final fromCenter = Offset(
        from.position.x + squareSize / 2,
        from.position.y + squareSize / 2,
      );
      final toCenter = Offset(
        to.position.x + squareSize / 2,
        to.position.y + squareSize / 2,
      );
      final delta = toCenter - fromCenter;
      if (delta.distance == 0) continue;

      final unit = delta / delta.distance;
      final lineStart = fromCenter + unit * (squareSize / 2 - 4);
      final lineEnd = toCenter - unit * (squareSize / 2 + 3);
      canvas.drawLine(lineStart, lineEnd, paint);

      final angle = math.atan2(delta.dy, delta.dx);
      const arrowLength = 13.0;
      const spread = math.pi / 6;
      final left = lineEnd -
          Offset(
            math.cos(angle - spread) * arrowLength,
            math.sin(angle - spread) * arrowLength,
          );
      final right = lineEnd -
          Offset(
            math.cos(angle + spread) * arrowLength,
            math.sin(angle + spread) * arrowLength,
          );
      canvas.drawLine(lineEnd, left, paint);
      canvas.drawLine(lineEnd, right, paint);
    }
  }

  @override
  bool shouldRepaint(covariant BoardConnectionPainter oldDelegate) {
    return oldDelegate.board != board;
  }
}
