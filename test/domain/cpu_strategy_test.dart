import 'package:flutter_test/flutter_test.dart';
import 'package:sugoroku_studio/domain/board.dart';
import 'package:sugoroku_studio/domain/cpu_strategy.dart';
import 'package:sugoroku_studio/domain/game_engine.dart';
import 'package:sugoroku_studio/domain/player.dart';

Board createStrategyBoard({
  List<SquareEffect> shortEffects = const <SquareEffect>[],
  List<SquareEffect> longEffects = const <SquareEffect>[],
}) {
  return Board(
    id: 'strategy-board',
    name: 'Strategy',
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

Player cpuPlayer({
  CpuStrategyType strategy = CpuStrategyType.shortestPath,
  int points = 0,
  Map<String, int> inventory = const <String, int>{},
}) {
  return Player(
    id: 'cpu',
    name: 'CPU',
    type: PlayerType.cpu,
    currentSquareId: 'fork',
    cpuStrategy: strategy,
    points: points,
    inventory: inventory,
  );
}

String choose(
  CpuStrategy strategy,
  Board board,
  Player player,
) {
  final from = board.squareById('fork')!;
  return strategy.chooseNextSquare(
    board: board,
    player: player,
    from: from,
    options: board.outgoingSquares(from.id),
  );
}

void main() {
  test('shortest path strategy chooses the closer route', () {
    final board = createStrategyBoard();

    expect(
      choose(
        const ShortestPathCpuStrategy(),
        board,
        cpuPlayer(),
      ),
      'short',
    );
  });

  test('cautious strategy avoids a shorter skip-turn route', () {
    final board = createStrategyBoard(
      shortEffects: const [
        SquareEffect(
          trigger: EffectTrigger.onLand,
          actionType: EffectActionType.skipTurn,
          parameters: {'turns': 2},
        ),
      ],
    );

    expect(
      choose(
        const CautiousCpuStrategy(),
        board,
        cpuPlayer(strategy: CpuStrategyType.cautious),
      ),
      'long-1',
    );
  });

  test('reward-seeking strategy takes a longer item-reward route', () {
    final board = createStrategyBoard(
      longEffects: const [
        SquareEffect(
          trigger: EffectTrigger.onLand,
          actionType: EffectActionType.grantItem,
          parameters: {'itemName': 'Treasure', 'quantity': 1},
        ),
      ],
    );

    expect(
      choose(
        const RewardSeekingCpuStrategy(),
        board,
        cpuPlayer(strategy: CpuStrategyType.rewardSeeking),
      ),
      'long-1',
    );
  });

  test('reward strategy evaluates only point conditions the player satisfies', () {
    final board = createStrategyBoard(
      longEffects: const [
        SquareEffect(
          trigger: EffectTrigger.onLand,
          actionType: EffectActionType.changePoints,
          parameters: {'points': 10},
          condition: EffectCondition(
            type: EffectConditionType.pointsAtLeast,
            parameters: {'points': 5},
          ),
        ),
      ],
    );
    const strategy = RewardSeekingCpuStrategy();

    expect(choose(strategy, board, cpuPlayer(points: 0)), 'short');
    expect(choose(strategy, board, cpuPlayer(points: 5)), 'long-1');
  });

  test('reward strategy evaluates item conditions from inventory', () {
    final board = createStrategyBoard(
      longEffects: const [
        SquareEffect(
          trigger: EffectTrigger.onLand,
          actionType: EffectActionType.changePoints,
          parameters: {'points': 10},
          condition: EffectCondition(
            type: EffectConditionType.hasItem,
            parameters: {'itemName': 'Key'},
          ),
        ),
      ],
    );
    const strategy = RewardSeekingCpuStrategy();

    expect(choose(strategy, board, cpuPlayer()), 'short');
    expect(
      choose(
        strategy,
        board,
        cpuPlayer(inventory: const {'Key': 1}),
      ),
      'long-1',
    );
  });

  test('reward strategy evaluates missing-item conditions from inventory', () {
    final board = createStrategyBoard(
      longEffects: const [
        SquareEffect(
          trigger: EffectTrigger.onLand,
          actionType: EffectActionType.changePoints,
          parameters: {'points': 10},
          condition: EffectCondition(
            type: EffectConditionType.notHasItem,
            parameters: {'itemName': 'Pass'},
          ),
        ),
      ],
    );
    const strategy = RewardSeekingCpuStrategy();

    expect(choose(strategy, board, cpuPlayer()), 'long-1');
    expect(
      choose(
        strategy,
        board,
        cpuPlayer(inventory: const {'Pass': 1}),
      ),
      'short',
    );
  });

  test('createGame preserves the configured CPU strategy', () {
    final board = createStrategyBoard();
    final initial = GameEngine().createGame(
      board: board,
      players: [cpuPlayer(strategy: CpuStrategyType.cautious)],
    );

    expect(initial.players.single.cpuStrategy, CpuStrategyType.cautious);
    expect(cpuStrategyFor(initial.players.single.cpuStrategy), isA<CautiousCpuStrategy>());
  });
}
