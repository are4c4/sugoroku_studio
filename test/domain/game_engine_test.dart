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

Board createBoard({
  List<SquareEffect> oneEffects = const <SquareEffect>[],
  List<SquareEffect> twoEffects = const <SquareEffect>[],
}) {
  return Board(
    id: 'board-1',
    name: 'Test',
    squares: [
      const BoardSquare(
        id: 'start',
        label: 'Start',
        position: BoardPosition(x: 0, y: 0),
        kind: SquareKind.start,
      ),
      BoardSquare(
        id: 'one',
        label: '1',
        position: const BoardPosition(x: 100, y: 0),
        kind: SquareKind.normal,
        effects: oneEffects,
      ),
      BoardSquare(
        id: 'two',
        label: '2',
        position: const BoardPosition(x: 200, y: 0),
        kind: SquareKind.normal,
        effects: twoEffects,
      ),
      const BoardSquare(
        id: 'three',
        label: '3',
        position: BoardPosition(x: 300, y: 0),
        kind: SquareKind.normal,
      ),
      const BoardSquare(
        id: 'goal',
        label: 'Goal',
        position: BoardPosition(x: 400, y: 0),
        kind: SquareKind.goal,
      ),
    ],
    connections: const [
      BoardConnection(fromSquareId: 'start', toSquareId: 'one'),
      BoardConnection(fromSquareId: 'one', toSquareId: 'two'),
      BoardConnection(fromSquareId: 'two', toSquareId: 'three'),
      BoardConnection(fromSquareId: 'three', toSquareId: 'goal'),
    ],
    updatedAt: DateTime(2026, 9, 4),
  );
}

const human = Player(
  id: 'p1',
  name: 'Player 1',
  type: PlayerType.human,
  currentSquareId: '',
);

const secondHuman = Player(
  id: 'p2',
  name: 'Player 2',
  type: PlayerType.human,
  currentSquareId: '',
);

const cpu = Player(
  id: 'cpu-1',
  name: 'CPU 1',
  type: PlayerType.cpu,
  currentSquareId: '',
);

void main() {
  test('createGame initializes every player at start', () {
    final engine = GameEngine(random: FixedRandom(0));
    final initial = engine.createGame(
      board: createBoard(),
      players: const [human, cpu, secondHuman],
    );

    expect(initial.players.map((player) => player.currentSquareId), [
      'start',
      'start',
      'start',
    ]);
    expect(initial.currentPlayerIndex, 0);
  });

  test('multiple players rotate in configured order', () {
    final engine = GameEngine(random: FixedRandom(0));
    final initial = engine.createGame(
      board: createBoard(),
      players: const [human, cpu, secondHuman],
    );

    final first = engine.rollCurrentPlayer(initial);
    expect(first.state.players[0].currentSquareId, 'one');
    expect(first.state.currentPlayerIndex, 1);
    expect(first.state.currentPlayer.type, PlayerType.cpu);

    final second = engine.rollCurrentPlayer(first.state);
    expect(second.state.players[1].currentSquareId, 'one');
    expect(second.state.currentPlayerIndex, 2);

    final third = engine.rollCurrentPlayer(second.state);
    expect(third.state.players[2].currentSquareId, 'one');
    expect(third.state.currentPlayerIndex, 0);
    expect(third.state.turn, 4);
  });

  test('roll moves one square at a time and clamps at goal', () {
    final engine = GameEngine(random: FixedRandom(5));
    final initial = engine.createGame(
      board: createBoard(),
      players: const [human],
    );

    final result = engine.rollCurrentPlayer(initial);

    expect(result.state.currentPlayer.currentSquareId, 'goal');
    expect(result.state.status, GameStatus.finished);
    expect(result.events.whereType<PlayerMoved>().length, 4);
    expect(result.events.whereType<GoalReached>().length, 1);
  });

  test('moveBy positive moves forward after landing', () {
    final board = createBoard(
      oneEffects: const [
        SquareEffect(
          trigger: EffectTrigger.onLand,
          actionType: EffectActionType.moveBy,
          parameters: {'steps': 2},
        ),
      ],
    );
    final engine = GameEngine(random: FixedRandom(0));
    final initial = engine.createGame(board: board, players: const [human]);

    final result = engine.rollCurrentPlayer(initial);

    expect(result.state.currentPlayer.currentSquareId, 'three');
    expect(result.events.whereType<PlayerMoved>().length, 3);
    expect(result.events.whereType<SquareEffectApplied>().length, 1);
  });

  test('moveBy negative moves backward after landing', () {
    final board = createBoard(
      twoEffects: const [
        SquareEffect(
          trigger: EffectTrigger.onLand,
          actionType: EffectActionType.moveBy,
          parameters: {'steps': -1},
        ),
      ],
    );
    final engine = GameEngine(random: FixedRandom(1));
    final initial = engine.createGame(board: board, players: const [human]);

    final result = engine.rollCurrentPlayer(initial);

    expect(result.state.currentPlayer.currentSquareId, 'one');
    final moves = result.events.whereType<PlayerMoved>().toList();
    expect(moves.last.fromSquareId, 'two');
    expect(moves.last.toSquareId, 'one');
  });

  test('moveToStart returns player to start', () {
    final board = createBoard(
      oneEffects: const [
        SquareEffect(
          trigger: EffectTrigger.onLand,
          actionType: EffectActionType.moveToStart,
        ),
      ],
    );
    final engine = GameEngine(random: FixedRandom(0));
    final initial = engine.createGame(board: board, players: const [human]);

    final result = engine.rollCurrentPlayer(initial);

    expect(result.state.currentPlayer.currentSquareId, 'start');
    expect(result.events.whereType<PlayerMoved>().length, 2);
  });

  test('movement effects activate the destination square effect', () {
    final board = createBoard(
      oneEffects: const [
        SquareEffect(
          trigger: EffectTrigger.onLand,
          actionType: EffectActionType.moveBy,
          parameters: {'steps': 1},
        ),
      ],
      twoEffects: const [
        SquareEffect(
          trigger: EffectTrigger.onLand,
          actionType: EffectActionType.moveToStart,
        ),
      ],
    );
    final engine = GameEngine(random: FixedRandom(0));
    final initial = engine.createGame(board: board, players: const [human]);

    final result = engine.rollCurrentPlayer(initial);

    expect(result.state.currentPlayer.currentSquareId, 'start');
    expect(result.events.whereType<SquareEffectApplied>().length, 2);
  });

  test('skipTurn is stored and consumes a later turn without rolling', () {
    final board = createBoard(
      oneEffects: const [
        SquareEffect(
          trigger: EffectTrigger.onLand,
          actionType: EffectActionType.skipTurn,
          parameters: {'turns': 1},
        ),
      ],
    );
    final engine = GameEngine(random: FixedRandom(0));
    final initial = engine.createGame(
      board: board,
      players: const [human, secondHuman],
    );

    final landed = engine.rollCurrentPlayer(initial);
    expect(landed.state.players.first.skipTurns, 1);
    expect(landed.state.currentPlayerIndex, 1);

    final playerOneTurnAgain = landed.state.copyWith(currentPlayerIndex: 0);
    final skipped = engine.rollCurrentPlayer(playerOneTurnAgain);

    expect(skipped.state.players.first.skipTurns, 0);
    expect(skipped.state.currentPlayerIndex, 1);
    expect(skipped.events.whereType<PlayerTurnSkipped>().length, 1);
    expect(skipped.events.whereType<DiceRolled>(), isEmpty);
  });

  test('rollAgain keeps the current player and current turn', () {
    final board = createBoard(
      oneEffects: const [
        SquareEffect(
          trigger: EffectTrigger.onLand,
          actionType: EffectActionType.rollAgain,
        ),
      ],
    );
    final engine = GameEngine(random: FixedRandom(0));
    final initial = engine.createGame(
      board: board,
      players: const [human, secondHuman],
    );

    final result = engine.rollCurrentPlayer(initial);

    expect(result.state.currentPlayerIndex, 0);
    expect(result.state.turn, 1);
    expect(result.events.whereType<ExtraRollGranted>().length, 1);
  });
}
