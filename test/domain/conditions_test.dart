import 'package:flutter_test/flutter_test.dart';
import 'package:sugoroku_studio/domain/board.dart';
import 'package:sugoroku_studio/domain/game_engine.dart';
import 'package:sugoroku_studio/domain/game_event.dart';
import 'package:sugoroku_studio/domain/player.dart';

Board createConditionalBoard(List<SquareEffect> effects) {
  return Board(
    id: 'conditional-board',
    name: 'Conditional Board',
    squares: [
      const BoardSquare(
        id: 'start',
        label: 'Start',
        position: BoardPosition(x: 0, y: 0),
        kind: SquareKind.start,
      ),
      BoardSquare(
        id: 'event',
        label: 'Event',
        position: const BoardPosition(x: 100, y: 0),
        kind: SquareKind.normal,
        effects: effects,
      ),
      const BoardSquare(
        id: 'goal',
        label: 'Goal',
        position: BoardPosition(x: 200, y: 0),
        kind: SquareKind.goal,
      ),
    ],
    connections: const [
      BoardConnection(fromSquareId: 'start', toSquareId: 'event'),
      BoardConnection(fromSquareId: 'event', toSquareId: 'goal'),
    ],
    updatedAt: DateTime.utc(2026, 9, 4),
  );
}

Player playerWithPoints(int points) => Player(
      id: 'player',
      name: 'Player',
      type: PlayerType.human,
      currentSquareId: '',
      points: points,
    );

Player playerWithInventory(Map<String, int> inventory) => Player(
      id: 'player',
      name: 'Player',
      type: PlayerType.human,
      currentSquareId: '',
      inventory: inventory,
    );

void main() {
  test('pointsAtLeast includes the threshold and skips below it', () async {
    const effect = SquareEffect(
      trigger: EffectTrigger.onLand,
      actionType: EffectActionType.changePoints,
      parameters: {'points': 3},
      condition: EffectCondition(
        type: EffectConditionType.pointsAtLeast,
        parameters: {'points': 10},
      ),
    );
    final engine = GameEngine();

    final below = engine.createGame(
      board: createConditionalBoard(const [effect]),
      players: [playerWithPoints(9)],
    );
    final belowResult = await engine.rollCurrentPlayer(below, dice: 1);

    expect(belowResult.state.currentPlayer.points, 9);
    expect(belowResult.events.whereType<PlayerPointsChanged>(), isEmpty);
    expect(belowResult.events.whereType<SquareEffectApplied>(), isEmpty);

    final atThreshold = engine.createGame(
      board: createConditionalBoard(const [effect]),
      players: [playerWithPoints(10)],
    );
    final thresholdResult =
        await engine.rollCurrentPlayer(atThreshold, dice: 1);

    expect(thresholdResult.state.currentPlayer.points, 13);
    expect(thresholdResult.events.whereType<PlayerPointsChanged>().single.delta, 3);
  });

  test('pointsAtMost includes the threshold and skips above it', () async {
    const effect = SquareEffect(
      trigger: EffectTrigger.onLand,
      actionType: EffectActionType.showMessage,
      parameters: {'message': 'low points bonus'},
      condition: EffectCondition(
        type: EffectConditionType.pointsAtMost,
        parameters: {'points': 5},
      ),
    );
    final engine = GameEngine();

    final atThreshold = engine.createGame(
      board: createConditionalBoard(const [effect]),
      players: [playerWithPoints(5)],
    );
    final thresholdResult =
        await engine.rollCurrentPlayer(atThreshold, dice: 1);
    expect(
      thresholdResult.events.whereType<SquareEffectApplied>().single.effect,
      same(effect),
    );

    final above = engine.createGame(
      board: createConditionalBoard(const [effect]),
      players: [playerWithPoints(6)],
    );
    final aboveResult = await engine.rollCurrentPlayer(above, dice: 1);
    expect(aboveResult.events.whereType<SquareEffectApplied>(), isEmpty);
  });

  test('pointsBetween includes both boundaries and normalizes reversed bounds',
      () async {
    const effect = SquareEffect(
      trigger: EffectTrigger.onLand,
      actionType: EffectActionType.showMessage,
      parameters: {'message': 'middle range'},
      condition: EffectCondition(
        type: EffectConditionType.pointsBetween,
        parameters: {'minPoints': 10, 'maxPoints': 5},
      ),
    );
    final engine = GameEngine();

    for (final points in [5, 7, 10]) {
      final state = engine.createGame(
        board: createConditionalBoard(const [effect]),
        players: [playerWithPoints(points)],
      );
      final result = await engine.rollCurrentPlayer(state, dice: 1);
      expect(
        result.events.whereType<SquareEffectApplied>(),
        hasLength(1),
        reason: '$points should be inside the inclusive range',
      );
    }

    for (final points in [4, 11]) {
      final state = engine.createGame(
        board: createConditionalBoard(const [effect]),
        players: [playerWithPoints(points)],
      );
      final result = await engine.rollCurrentPlayer(state, dice: 1);
      expect(result.events.whereType<SquareEffectApplied>(), isEmpty);
    }
  });

  test('later conditions see point changes from earlier actions', () async {
    const gain = SquareEffect(
      trigger: EffectTrigger.onLand,
      actionType: EffectActionType.changePoints,
      parameters: {'points': 5},
    );
    const conditionalGain = SquareEffect(
      trigger: EffectTrigger.onLand,
      actionType: EffectActionType.changePoints,
      parameters: {'points': 7},
      condition: EffectCondition(
        type: EffectConditionType.pointsAtLeast,
        parameters: {'points': 5},
      ),
    );
    final engine = GameEngine();
    final state = engine.createGame(
      board: createConditionalBoard(const [gain, conditionalGain]),
      players: [playerWithPoints(0)],
    );

    final result = await engine.rollCurrentPlayer(state, dice: 1);
    final changes = result.events.whereType<PlayerPointsChanged>().toList();

    expect(result.state.currentPlayer.points, 12);
    expect(changes.map((event) => event.delta), [5, 7]);
    expect(changes.map((event) => event.points), [5, 12]);
  });

  test('hasItem fires only when the named item is owned', () async {
    const effect = SquareEffect(
      trigger: EffectTrigger.onLand,
      actionType: EffectActionType.changePoints,
      parameters: {'points': 4},
      condition: EffectCondition(
        type: EffectConditionType.hasItem,
        parameters: {'itemName': 'Key'},
      ),
    );
    final engine = GameEngine();

    final missing = engine.createGame(
      board: createConditionalBoard(const [effect]),
      players: [playerWithInventory(const {})],
    );
    final missingResult = await engine.rollCurrentPlayer(missing, dice: 1);
    expect(missingResult.state.currentPlayer.points, 0);
    expect(missingResult.events.whereType<PlayerPointsChanged>(), isEmpty);

    final owned = engine.createGame(
      board: createConditionalBoard(const [effect]),
      players: [playerWithInventory(const {'Key': 1})],
    );
    final ownedResult = await engine.rollCurrentPlayer(owned, dice: 1);
    expect(ownedResult.state.currentPlayer.points, 4);
  });

  test('notHasItem fires only when the named item is missing', () async {
    const effect = SquareEffect(
      trigger: EffectTrigger.onLand,
      actionType: EffectActionType.changePoints,
      parameters: {'points': 6},
      condition: EffectCondition(
        type: EffectConditionType.notHasItem,
        parameters: {'itemName': 'Pass'},
      ),
    );
    final engine = GameEngine();

    final missing = engine.createGame(
      board: createConditionalBoard(const [effect]),
      players: [playerWithInventory(const {})],
    );
    final missingResult = await engine.rollCurrentPlayer(missing, dice: 1);
    expect(missingResult.state.currentPlayer.points, 6);

    final owned = engine.createGame(
      board: createConditionalBoard(const [effect]),
      players: [playerWithInventory(const {'Pass': 1})],
    );
    final ownedResult = await engine.rollCurrentPlayer(owned, dice: 1);
    expect(ownedResult.state.currentPlayer.points, 0);
    expect(ownedResult.events.whereType<PlayerPointsChanged>(), isEmpty);
  });

  test('itemQuantityAtLeast includes the threshold and skips below it', () async {
    const effect = SquareEffect(
      trigger: EffectTrigger.onLand,
      actionType: EffectActionType.showMessage,
      parameters: {'message': 'three keys'},
      condition: EffectCondition(
        type: EffectConditionType.itemQuantityAtLeast,
        parameters: {'itemName': 'Key', 'quantity': 3},
      ),
    );
    final engine = GameEngine();

    final below = engine.createGame(
      board: createConditionalBoard(const [effect]),
      players: [playerWithInventory(const {'Key': 2})],
    );
    final belowResult = await engine.rollCurrentPlayer(below, dice: 1);
    expect(belowResult.events.whereType<SquareEffectApplied>(), isEmpty);

    final threshold = engine.createGame(
      board: createConditionalBoard(const [effect]),
      players: [playerWithInventory(const {'Key': 3})],
    );
    final thresholdResult = await engine.rollCurrentPlayer(threshold, dice: 1);
    expect(thresholdResult.events.whereType<SquareEffectApplied>(), hasLength(1));
  });

  test('later item conditions see items granted by earlier actions', () async {
    const grant = SquareEffect(
      trigger: EffectTrigger.onLand,
      actionType: EffectActionType.grantItem,
      parameters: {'itemName': 'Key', 'quantity': 1},
    );
    const conditionalGain = SquareEffect(
      trigger: EffectTrigger.onLand,
      actionType: EffectActionType.changePoints,
      parameters: {'points': 9},
      condition: EffectCondition(
        type: EffectConditionType.hasItem,
        parameters: {'itemName': 'Key'},
      ),
    );
    final engine = GameEngine();
    final state = engine.createGame(
      board: createConditionalBoard(const [grant, conditionalGain]),
      players: [playerWithInventory(const {})],
    );

    final result = await engine.rollCurrentPlayer(state, dice: 1);

    expect(result.state.currentPlayer.itemQuantity('Key'), 1);
    expect(result.state.currentPlayer.points, 9);
    expect(result.events.whereType<PlayerItemGranted>(), hasLength(1));
    expect(result.events.whereType<PlayerPointsChanged>(), hasLength(1));
  });

  test('notHasItem sees an item removed by an earlier consumption action', () async {
    const consume = SquareEffect(
      trigger: EffectTrigger.onLand,
      actionType: EffectActionType.consumeItem,
      parameters: {'itemName': 'Pass', 'quantity': 1},
    );
    const reward = SquareEffect(
      trigger: EffectTrigger.onLand,
      actionType: EffectActionType.changePoints,
      parameters: {'points': 8},
      condition: EffectCondition(
        type: EffectConditionType.notHasItem,
        parameters: {'itemName': 'Pass'},
      ),
    );
    final engine = GameEngine();
    final state = engine.createGame(
      board: createConditionalBoard(const [consume, reward]),
      players: [playerWithInventory(const {'Pass': 1})],
    );

    final result = await engine.rollCurrentPlayer(state, dice: 1);

    expect(result.state.currentPlayer.itemQuantity('Pass'), 0);
    expect(result.state.currentPlayer.points, 8);
    expect(result.events.whereType<PlayerItemConsumed>(), hasLength(1));
    expect(result.events.whereType<PlayerPointsChanged>(), hasLength(1));
  });

  test('JSON round-trip preserves range and item conditions', () {
    const pointCondition = SquareEffect(
      trigger: EffectTrigger.onLand,
      actionType: EffectActionType.showMessage,
      parameters: {'message': 'range'},
      condition: EffectCondition(
        type: EffectConditionType.pointsBetween,
        parameters: {'minPoints': 5, 'maxPoints': 15},
      ),
    );
    const itemCondition = SquareEffect(
      trigger: EffectTrigger.onLand,
      actionType: EffectActionType.showMessage,
      parameters: {'message': 'missing pass'},
      condition: EffectCondition(
        type: EffectConditionType.notHasItem,
        parameters: {'itemName': 'Pass'},
      ),
    );
    const unconditionalEffect = SquareEffect(
      trigger: EffectTrigger.onLand,
      actionType: EffectActionType.showMessage,
      parameters: {'message': 'always'},
    );

    final restored = Board.fromJson(
      createConditionalBoard(
        const [pointCondition, itemCondition, unconditionalEffect],
      ).toJson(),
    );
    final effects = restored.squareById('event')!.effects;

    expect(effects[0].condition?.type, EffectConditionType.pointsBetween);
    expect(effects[0].condition?.parameters['minPoints'], 5);
    expect(effects[0].condition?.parameters['maxPoints'], 15);
    expect(effects[1].condition?.type, EffectConditionType.notHasItem);
    expect(effects[1].condition?.parameters['itemName'], 'Pass');
    expect(effects[2].condition, isNull);
  });
}
