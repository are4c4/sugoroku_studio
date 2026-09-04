import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sugoroku_studio/domain/board.dart';
import 'package:sugoroku_studio/domain/game_engine.dart';
import 'package:sugoroku_studio/domain/game_event.dart';
import 'package:sugoroku_studio/domain/game_state.dart';
import 'package:sugoroku_studio/domain/player.dart';

class FixedRandom implements Random {
  FixedRandom(this.value);

  final int value;

  @override
  bool nextBool() => value.isEven;

  @override
  double nextDouble() => value / 6;

  @override
  int nextInt(int max) => value.clamp(0, max - 1).toInt();
}

void main() {
  final board = Board(
    id: 'board-1',
    name: 'Test',
    squares: const [
      BoardSquare(
        id: 'start',
        label: 'Start',
        position: BoardPosition(x: 0, y: 0),
        kind: SquareKind.start,
      ),
      BoardSquare(
        id: 'one',
        label: '1',
        position: BoardPosition(x: 100, y: 0),
        kind: SquareKind.normal,
      ),
      BoardSquare(
        id: 'goal',
        label: 'Goal',
        position: BoardPosition(x: 200, y: 0),
        kind: SquareKind.goal,
      ),
    ],
    connections: const [
      BoardConnection(fromSquareId: 'start', toSquareId: 'one'),
      BoardConnection(fromSquareId: 'one', toSquareId: 'goal'),
    ],
    updatedAt: DateTime(2026, 9, 4),
  );

  test('roll moves one square at a time and clamps at goal', () {
    final engine = GameEngine(random: FixedRandom(5));
    final initial = engine.createGame(
      board: board,
      players: const [
        Player(
          id: 'p1',
          name: 'Player',
          type: PlayerType.human,
          currentSquareId: '',
        ),
      ],
    );

    final result = engine.rollCurrentPlayer(initial);

    expect(result.state.currentPlayer.currentSquareId, 'goal');
    expect(result.state.status, GameStatus.finished);
    expect(result.events.whereType<PlayerMoved>().length, 2);
    expect(result.events.whereType<GoalReached>().length, 1);
  });
}
