import 'package:flutter_test/flutter_test.dart';
import 'package:sugoroku_studio/domain/board.dart';

void main() {
  Board createBoard() {
    const squares = [
      BoardSquare(
        id: 'start',
        label: 'Start',
        position: BoardPosition(x: 0, y: 0),
        kind: SquareKind.start,
      ),
      BoardSquare(
        id: 'normal',
        label: 'Normal',
        position: BoardPosition(x: 100, y: 0),
        kind: SquareKind.normal,
      ),
      BoardSquare(
        id: 'goal',
        label: 'Goal',
        position: BoardPosition(x: 200, y: 0),
        kind: SquareKind.goal,
      ),
    ];
    return Board(
      id: 'board-1',
      name: 'Test',
      squares: squares,
      connections: const [
        BoardConnection(fromSquareId: 'start', toSquareId: 'normal'),
        BoardConnection(fromSquareId: 'normal', toSquareId: 'goal'),
      ],
      updatedAt: DateTime.utc(2026, 9, 4),
    );
  }

  test('orderedPath follows connection data rather than positions', () {
    final board = createBoard();

    expect(
      board.orderedPath().map((square) => square.id),
      ['start', 'normal', 'goal'],
    );
    expect(board.isPlayable, isTrue);
  });

  test('board JSON round-trip preserves structural data', () {
    final original = createBoard();
    final restored = Board.fromJson(original.toJson());

    expect(restored.id, original.id);
    expect(restored.name, original.name);
    expect(restored.squares.length, original.squares.length);
    expect(restored.connections.length, original.connections.length);
    expect(restored.orderedPath().last.kind, SquareKind.goal);
  });
}
