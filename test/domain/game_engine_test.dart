import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sugoroku_studio/domain/board.dart';
import 'package:sugoroku_studio/domain/cpu_strategy.dart';
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

Board createBranchBoard({
  List<SquareEffect> shortEffects = const <SquareEffect>[],
  List<SquareEffect> longEffects = const <SquareEffect>[],
}) {
  return Board(
    id: 'branch-board',
    name: 'Branch',
    squares: [
      const BoardSquare(
        id: 'start',
        label: 'Start',
        position: BoardPosition(x: 0, y: 100),
        kind: SquareKind.start,
      ),
      const BoardSquare(
        id: 'fork',
        label: 'Fork',
        position: BoardPosition(x: 100, y: 100),
        kind: SquareKind.normal,
      ),
      BoardSquare(
        id: 'short',
        label: 'Short',
        position: const BoardPosition(x: 200, y: 40),
        kind: SquareKind.normal,
        effects: shortEffects,
      ),
      BoardSquare(
        id: 'long-1',
        label: 'Long 1',
        position: const BoardPosition(x: 200, y: 160),
        kind: SquareKind.normal,
        effects: longEffects,
      ),
      const BoardSquare(
        id: 'long-2',
        label: 'Long 2',
        position: BoardPosition(x: 300, y: 160),
        kind: SquareKind.normal,
      ),
      const BoardSquare(
        id: 'goal',
        label: 'Goal',
        position: BoardPosition(x: 400, y: 100),
        kind: SquareKind.goal,
      ),
    ],
    connections: const [
      BoardConnection(fromSquareId: 'start', toSquareId: 'fork'),
      BoardConnection(fromSquareId: 'fork', toSquareId: 'short'),
      BoardConnection(fromSquareId: 'fork', toSquareId: 'long-1'),
      BoardConnection(fromSquareId: 'short', toSquareId: 'goal'),
      BoardConnection(fromSquareId: 'long-1', toSquareId: 'long-2'),
      BoardConnection(fromSquareId: 'long-2', toSquareId: 'goal'),
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
  test('createGame initializes every player at start with route history', () {
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
    expect(initial.players.first.routeHistory, ['start']);
    expect(initial.currentPlayerIndex, 0);
  });

  test('multiple players rotate in configured order', () async {
    final engine = GameEngine(random: FixedRandom(0));
    final initial = engine.createGame(
      board: createBoard(),
      players: const [human, cpu, secondHuman],
    );

    final first = await engine.rollCurrentPlayer(initial);
    expect(first.state.players[0].currentSquareId, 'one');
    expect(first.state.currentPlayerIndex, 1);
    expect(first.state.currentPlayer.type, PlayerType.cpu);

    final second = await engine.rollCurrentPlayer(first.state);
    expect(second.state.players[1].currentSquareId, 'one');
    expect(second.state.currentPlayerIndex, 2);

    final third = await engine.rollCurrentPlayer(second.state);
    expect(third.state.players[2].currentSquareId, 'one');
    expect(third.state.currentPlayerIndex, 0);
    expect(third.state.turn, 4);
  });

  test('roll moves one square at a time and clamps at goal', () async {
    final engine = GameEngine(random: FixedRandom(5));
    final initial = engine.createGame(
      board: createBoard(),
      players: const [human],
    );

    final result = await engine.rollCurrentPlayer(initial);

    expect(result.state.currentPlayer.currentSquareId, 'goal');
    expect(result.state.status, GameStatus.finished);
    expect(result.events.whereType<PlayerMoved>().length, 4);
    expect(result.events.whereType<GoalReached>().length, 1);
  });

  test('human route selector chooses a branch during movement', () async {
    final engine = GameEngine(random: FixedRandom(1));
    final initial = engine.createGame(
      board: createBranchBoard(),
      players: const [human],
    );

    final result = await engine.rollCurrentPlayer(
      initial,
      dice: 2,
      routeSelector: (context) => 'long-1',
    );

    expect(result.state.currentPlayer.currentSquareId, 'long-1');
    expect(result.events.whereType<RouteChosen>().length, 1);
    expect(result.state.currentPlayer.routeHistory, ['start', 'fork', 'long-1']);
  });

  test('shortest path CPU strategy chooses the nearer route', () async {
    const strategy = ShortestPathCpuStrategy();
    final board = createBranchBoard();
    final engine = GameEngine(random: FixedRandom(1));
    final initial = engine.createGame(board: board, players: const [cpu]);

    final result = await engine.rollCurrentPlayer(
      initial,
      dice: 2,
      routeSelector: (context) => strategy.chooseNextSquare(
        board: context.board,
        player: context.player,
        from: context.fromSquare,
        options: context.options,
      ),
    );

    expect(result.state.currentPlayer.currentSquareId, 'short');
  });

  test('moveBy positive moves forward after landing', () async {
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

    final result = await engine.rollCurrentPlayer(initial);

    expect(result.state.currentPlayer.currentSquareId, 'three');
    expect(result.events.whereType<PlayerMoved>().length, 3);
    expect(result.events.whereType<SquareEffectApplied>().length, 1);
  });

  test('moveBy negative retraces the actual selected branch', () async {
    final board = createBranchBoard(
      longEffects: const [
        SquareEffect(
          trigger: EffectTrigger.onLand,
          actionType: EffectActionType.moveBy,
          parameters: {'steps': -1},
        ),
      ],
    );
    final engine = GameEngine(random: FixedRandom(1));
    final initial = engine.createGame(board: board, players: const [human]);

    final result = await engine.rollCurrentPlayer(
      initial,
      dice: 2,
      routeSelector: (context) => 'long-1',
    );

    expect(result.state.currentPlayer.currentSquareId, 'fork');
    expect(result.state.currentPlayer.routeHistory, ['start', 'fork']);
    final moves = result.events.whereType<PlayerMoved>().toList();
    expect(moves.last.fromSquareId, 'long-1');
    expect(moves.last.toSquareId, 'fork');
  });

  test('moveToStart returns player to start', () async {
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

    final result = await engine.rollCurrentPlayer(initial);

    expect(result.state.currentPlayer.currentSquareId, 'start');
    expect(result.state.currentPlayer.routeHistory, ['start']);
    expect(result.events.whereType<PlayerMoved>().length, 2);
  });

  test('warpTo moves directly to the configured square', () async {
    final board = createBoard(
      oneEffects: const [
        SquareEffect(
          trigger: EffectTrigger.onLand,
          actionType: EffectActionType.warpTo,
          parameters: {'targetSquareId': 'three'},
        ),
      ],
    );
    final engine = GameEngine(random: FixedRandom(0));
    final initial = engine.createGame(board: board, players: const [human]);

    final result = await engine.rollCurrentPlayer(initial);

    expect(result.state.currentPlayer.currentSquareId, 'three');
    final moves = result.events.whereType<PlayerMoved>().toList();
    expect(moves.last.fromSquareId, 'one');
    expect(moves.last.toSquareId, 'three');
  });

  test('movement effects activate the destination square effect', () async {
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

    final result = await engine.rollCurrentPlayer(initial);

    expect(result.state.currentPlayer.currentSquareId, 'start');
    expect(result.events.whereType<SquareEffectApplied>().length, 2);
  });

  test('skipTurn is stored and consumes a later turn without rolling', () async {
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

    final landed = await engine.rollCurrentPlayer(initial);
    expect(landed.state.players.first.skipTurns, 1);
    expect(landed.state.currentPlayerIndex, 1);

    final playerOneTurnAgain = landed.state.copyWith(currentPlayerIndex: 0);
    final skipped = await engine.rollCurrentPlayer(playerOneTurnAgain);

    expect(skipped.state.players.first.skipTurns, 0);
    expect(skipped.state.currentPlayerIndex, 1);
    expect(skipped.events.whereType<PlayerTurnSkipped>().length, 1);
    expect(skipped.events.whereType<DiceRolled>(), isEmpty);
  });

  test('rollAgain keeps the current player and current turn', () async {
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

    final result = await engine.rollCurrentPlayer(initial);

    expect(result.state.currentPlayerIndex, 0);
    expect(result.state.turn, 1);
    expect(result.events.whereType<ExtraRollGranted>().length, 1);
  });
}
