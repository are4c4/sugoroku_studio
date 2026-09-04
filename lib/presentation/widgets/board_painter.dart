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
      ..strokeCap = StrokeCap.round;
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
      canvas.drawLine(fromCenter, toCenter, paint);
    }
  }

  @override
  bool shouldRepaint(covariant BoardConnectionPainter oldDelegate) {
    return oldDelegate.board != board;
  }
}
