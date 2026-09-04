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
        effects: [
          SquareEffect(
            trigger: EffectTrigger.onLand,
            actionType: EffectActionType.moveBy,
            parameters: {'steps': -3},
          ),
        ],
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

  Board createBranchBoard() {
    const squares = [
      BoardSquare(
        id: 'start',
        label: 'Start',
        position: BoardPosition(x: 0, y: 0),
        kind: SquareKind.start,
      ),
      BoardSquare(
        id: 'fork',
        label: 'Fork',
        position: BoardPosition(x: 100, y: 0),
        kind: SquareKind.normal,
      ),
      BoardSquare(
        id: 'short',
        label: 'Short',
        position: BoardPosition(x: 200, y: -50),
        kind: SquareKind.normal,
      ),
      BoardSquare(
        id: 'long',
        label: 'Long',
        position: BoardPosition(x: 200, y: 50),
        kind: SquareKind.normal,
      ),
      BoardSquare(
        id: 'long-2',
        label: 'Long 2',
        position: BoardPosition(x: 300, y: 50),
        kind: SquareKind.normal,
      ),
      BoardSquare(
        id: 'goal',
        label: 'Goal',
        position: BoardPosition(x: 400, y: 0),
        kind: SquareKind.goal,
      ),
    ];
    return Board(
      id: 'branch-board',
      name: 'Branch',
      squares: squares,
      connections: const [
        BoardConnection(fromSquareId: 'start', toSquareId: 'fork'),
        BoardConnection(fromSquareId: 'fork', toSquareId: 'short'),
        BoardConnection(fromSquareId: 'fork', toSquareId: 'long'),
        BoardConnection(fromSquareId: 'short', toSquareId: 'goal'),
        BoardConnection(fromSquareId: 'long', toSquareId: 'long-2'),
        BoardConnection(fromSquareId: 'long-2', toSquareId: 'goal'),
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

  test('branch graph exposes outgoing options and shortest goal distance', () {
    final board = createBranchBoard();

    expect(
      board.outgoingSquares('fork').map((square) => square.id),
      ['short', 'long'],
    );
    expect(board.shortestDistanceToGoal('short'), 1);
    expect(board.shortestDistanceToGoal('long'), 2);
    expect(board.shortestDistanceToGoal('fork'), 2);
    expect(board.isPlayable, isTrue);
  });

  test('board JSON round-trip preserves structural data and effects', () {
    final original = createBoard();
    final restored = Board.fromJson(original.toJson());

    expect(restored.id, original.id);
    expect(restored.name, original.name);
    expect(restored.squares.length, original.squares.length);
    expect(restored.connections.length, original.connections.length);
    expect(restored.orderedPath().last.kind, SquareKind.goal);

    final effect = restored.squares[1].effects.single;
    expect(effect.trigger, EffectTrigger.onLand);
    expect(effect.actionType, EffectActionType.moveBy);
    expect(effect.parameters['steps'], -3);
  });
}
