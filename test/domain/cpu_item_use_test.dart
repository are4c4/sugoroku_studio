import 'package:flutter_test/flutter_test.dart';
import 'package:sugoroku_studio/domain/board.dart';
import 'package:sugoroku_studio/domain/cpu_item_use_policy.dart';
import 'package:sugoroku_studio/domain/game_engine.dart';
import 'package:sugoroku_studio/domain/game_event.dart';
import 'package:sugoroku_studio/domain/item_definition.dart';
import 'package:sugoroku_studio/domain/player.dart';

Board createBoard({List<ItemDefinition> itemDefinitions = const []}) {
  return Board(
    id: 'board',
    name: 'CPU item board',
    squares: const [
      BoardSquare(
        id: 'start',
        label: 'Start',
        position: BoardPosition(x: 0, y: 0),
        kind: SquareKind.start,
      ),
      BoardSquare(
        id: 'middle',
        label: 'Middle',
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
      BoardConnection(fromSquareId: 'start', toSquareId: 'middle'),
      BoardConnection(fromSquareId: 'middle', toSquareId: 'goal'),
    ],
    itemDefinitions: itemDefinitions,
    updatedAt: DateTime(2026, 9, 5),
  );
}

const smallBoost = ItemDefinition(
  name: 'Small Boost',
  actionType: ItemUseActionType.changePoints,
  parameters: {'points': 5},
);

const bigBoost = ItemDefinition(
  name: 'Big Boost',
  actionType: ItemUseActionType.changePoints,
  parameters: {'points': 12},
);

const penalty = ItemDefinition(
  name: 'Penalty',
  actionType: ItemUseActionType.changePoints,
  parameters: {'points': -20},
);

void main() {
  test('CPU policy chooses the strongest owned positive item', () {
    final board = createBoard(
      itemDefinitions: const [smallBoost, penalty, bigBoost],
    );
    const player = Player(
      id: 'cpu',
      name: 'CPU',
      type: PlayerType.cpu,
      currentSquareId: 'start',
      inventory: {'Small Boost': 1, 'Big Boost': 2, 'Penalty': 1},
    );

    expect(
      chooseAutomaticCpuItem(board: board, player: player),
      'Big Boost',
    );
  });

  test('CPU policy ignores non-positive, unowned, and human items', () {
    final board = createBoard(
      itemDefinitions: const [smallBoost, penalty, bigBoost],
    );
    const cpu = Player(
      id: 'cpu',
      name: 'CPU',
      type: PlayerType.cpu,
      currentSquareId: 'start',
      inventory: {'Penalty': 1, 'Unknown': 3},
    );
    const human = Player(
      id: 'human',
      name: 'Human',
      type: PlayerType.human,
      currentSquareId: 'start',
      inventory: {'Big Boost': 1},
    );

    expect(chooseAutomaticCpuItem(board: board, player: cpu), isNull);
    expect(chooseAutomaticCpuItem(board: board, player: human), isNull);
  });

  test('CPU automatically consumes one best item before movement', () async {
    final board = createBoard(
      itemDefinitions: const [smallBoost, bigBoost, penalty],
    );
    final engine = GameEngine();
    final state = engine.createGame(
      board: board,
      players: const [
        Player(
          id: 'cpu',
          name: 'CPU',
          type: PlayerType.cpu,
          currentSquareId: '',
          inventory: {'Big Boost': 2, 'Small Boost': 1, 'Penalty': 1},
        ),
      ],
    );

    final result = await engine.rollCurrentPlayer(state, dice: 1);
    final player = result.state.currentPlayer;

    expect(player.points, 12);
    expect(player.itemQuantity('Big Boost'), 1);
    expect(player.itemQuantity('Small Boost'), 1);
    expect(player.itemQuantity('Penalty'), 1);
    expect(result.events[0], isA<PlayerItemConsumed>());
    expect((result.events[0] as PlayerItemConsumed).itemName, 'Big Boost');
    expect(result.events[1], isA<PlayerPointsChanged>());
    expect((result.events[1] as PlayerPointsChanged).delta, 12);
    expect(result.events[2], isA<DiceRolled>());
  });

  test('route selector sees points after automatic CPU item use', () async {
    final board = Board(
      id: 'branch',
      name: 'Branch',
      squares: const [
        BoardSquare(
          id: 'start',
          label: 'Start',
          position: BoardPosition(x: 0, y: 0),
          kind: SquareKind.start,
        ),
        BoardSquare(
          id: 'a',
          label: 'A',
          position: BoardPosition(x: 100, y: -50),
          kind: SquareKind.normal,
        ),
        BoardSquare(
          id: 'b',
          label: 'B',
          position: BoardPosition(x: 100, y: 50),
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
        BoardConnection(fromSquareId: 'start', toSquareId: 'a'),
        BoardConnection(fromSquareId: 'start', toSquareId: 'b'),
        BoardConnection(fromSquareId: 'a', toSquareId: 'goal'),
        BoardConnection(fromSquareId: 'b', toSquareId: 'goal'),
      ],
      itemDefinitions: const [bigBoost],
      updatedAt: DateTime(2026, 9, 5),
    );
    final engine = GameEngine();
    final state = engine.createGame(
      board: board,
      players: const [
        Player(
          id: 'cpu',
          name: 'CPU',
          type: PlayerType.cpu,
          currentSquareId: '',
          inventory: {'Big Boost': 1},
        ),
      ],
    );
    var pointsSeenBySelector = -1;

    await engine.rollCurrentPlayer(
      state,
      dice: 1,
      routeSelector: (context) {
        pointsSeenBySelector = context.player.points;
        return context.options.first.id;
      },
    );

    expect(pointsSeenBySelector, 12);
  });

  test('skipping CPU does not use an item', () async {
    final board = createBoard(itemDefinitions: const [bigBoost]);
    final engine = GameEngine();
    final state = engine.createGame(
      board: board,
      players: const [
        Player(
          id: 'cpu',
          name: 'CPU',
          type: PlayerType.cpu,
          currentSquareId: '',
          skipTurns: 1,
          inventory: {'Big Boost': 1},
        ),
      ],
    );

    final result = await engine.rollCurrentPlayer(state, dice: 1);
    final player = result.state.currentPlayer;

    expect(player.points, 0);
    expect(player.itemQuantity('Big Boost'), 1);
    expect(result.events, hasLength(1));
    expect(result.events.single, isA<PlayerTurnSkipped>());
  });
}
