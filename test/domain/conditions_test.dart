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

Player playerWithState({
  int points = 0,
  Map<String, int> inventory = const <String, int>{},
}) => Player(
      id: 'player',
      name: 'Player',
      type: PlayerType.human,
      currentSquareId: '',
      points: points,
      inventory: inventory,
    );

Player playerWithInventory(Map<String, int> inventory) =>
    playerWithState(inventory: inventory);

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

  test('allOf requires every child condition', () async {
    const effect = SquareEffect(
      trigger: EffectTrigger.onLand,
      actionType: EffectActionType.changePoints,
      parameters: {'points': 10},
      condition: EffectCondition(
        type: EffectConditionType.allOf,
        parameters: {
          'conditions': [
            {
              'type': 'pointsAtLeast',
              'parameters': {'points': 5},
            },
            {
              'type': 'hasItem',
              'parameters': {'itemName': 'Key'},
            },
          ],
        },
      ),
    );
    final engine = GameEngine();

    final matching = engine.createGame(
      board: createConditionalBoard(const [effect]),
      players: [playerWithState(points: 5, inventory: const {'Key': 1})],
    );
    final matchingResult = await engine.rollCurrentPlayer(matching, dice: 1);
    expect(matchingResult.state.currentPlayer.points, 15);

    final missingItem = engine.createGame(
      board: createConditionalBoard(const [effect]),
      players: [playerWithState(points: 5)],
    );
    final missingItemResult =
        await engine.rollCurrentPlayer(missingItem, dice: 1);
    expect(missingItemResult.state.currentPlayer.points, 5);
    expect(missingItemResult.events.whereType<PlayerPointsChanged>(), isEmpty);
  });

  test('anyOf fires when at least one child condition matches', () async {
    const effect = SquareEffect(
      trigger: EffectTrigger.onLand,
      actionType: EffectActionType.showMessage,
      parameters: {'message': 'one condition matched'},
      condition: EffectCondition(
        type: EffectConditionType.anyOf,
        parameters: {
          'conditions': [
            {
              'type': 'pointsAtLeast',
              'parameters': {'points': 10},
            },
            {
              'type': 'hasItem',
              'parameters': {'itemName': 'Pass'},
            },
          ],
        },
      ),
    );
    final engine = GameEngine();

    for (final player in [
      playerWithState(points: 10),
      playerWithState(inventory: const {'Pass': 1}),
    ]) {
      final state = engine.createGame(
        board: createConditionalBoard(const [effect]),
        players: [player],
      );
      final result = await engine.rollCurrentPlayer(state, dice: 1);
      expect(result.events.whereType<SquareEffectApplied>(), hasLength(1));
    }

    final neither = engine.createGame(
      board: createConditionalBoard(const [effect]),
      players: [playerWithState(points: 3)],
    );
    final neitherResult = await engine.rollCurrentPlayer(neither, dice: 1);
    expect(neitherResult.events.whereType<SquareEffectApplied>(), isEmpty);
  });

  test('nested compound conditions evaluate recursively', () async {
    const effect = SquareEffect(
      trigger: EffectTrigger.onLand,
      actionType: EffectActionType.changePoints,
      parameters: {'points': 12},
      condition: EffectCondition(
        type: EffectConditionType.allOf,
        parameters: {
          'conditions': [
            {
              'type': 'pointsAtLeast',
              'parameters': {'points': 5},
            },
            {
              'type': 'anyOf',
              'parameters': {
                'conditions': [
                  {
                    'type': 'hasItem',
                    'parameters': {'itemName': 'Key'},
                  },
                  {
                    'type': 'notHasItem',
                    'parameters': {'itemName': 'Pass'},
                  },
                ],
              },
            },
          ],
        },
      ),
    );
    final engine = GameEngine();

    final matchesNestedOr = engine.createGame(
      board: createConditionalBoard(const [effect]),
      players: [
        playerWithState(points: 5, inventory: const {'Pass': 1, 'Key': 1}),
      ],
    );
    final matchResult =
        await engine.rollCurrentPlayer(matchesNestedOr, dice: 1);
    expect(matchResult.state.currentPlayer.points, 17);

    final matchesMissingPass = engine.createGame(
      board: createConditionalBoard(const [effect]),
      players: [playerWithState(points: 5)],
    );
    final missingPassResult =
        await engine.rollCurrentPlayer(matchesMissingPass, dice: 1);
    expect(missingPassResult.state.currentPlayer.points, 17);

    final failsNestedOr = engine.createGame(
      board: createConditionalBoard(const [effect]),
      players: [playerWithState(points: 5, inventory: const {'Pass': 1})],
    );
    final failResult = await engine.rollCurrentPlayer(failsNestedOr, dice: 1);
    expect(failResult.state.currentPlayer.points, 5);
  });

  test('empty compound conditions are safe false', () async {
    final engine = GameEngine();
    for (final type in [EffectConditionType.allOf, EffectConditionType.anyOf]) {
      final effect = SquareEffect(
        trigger: EffectTrigger.onLand,
        actionType: EffectActionType.changePoints,
        parameters: const {'points': 20},
        condition: EffectCondition(
          type: type,
          parameters: const {'conditions': <Map<String, dynamic>>[]},
        ),
      );
      final state = engine.createGame(
        board: createConditionalBoard([effect]),
        players: [playerWithState()],
      );
      final result = await engine.rollCurrentPlayer(state, dice: 1);
      expect(result.state.currentPlayer.points, 0);
      expect(result.events.whereType<PlayerPointsChanged>(), isEmpty);
    }
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

  test('JSON round-trip preserves nested compound conditions', () {
    const compoundEffect = SquareEffect(
      trigger: EffectTrigger.onLand,
      actionType: EffectActionType.showMessage,
      parameters: {'message': 'compound'},
      condition: EffectCondition(
        type: EffectConditionType.allOf,
        parameters: {
          'conditions': [
            {
              'type': 'pointsBetween',
              'parameters': {'minPoints': 5, 'maxPoints': 15},
            },
            {
              'type': 'anyOf',
              'parameters': {
                'conditions': [
                  {
                    'type': 'hasItem',
                    'parameters': {'itemName': 'Key'},
                  },
                  {
                    'type': 'notHasItem',
                    'parameters': {'itemName': 'Pass'},
                  },
                ],
              },
            },
          ],
        },
      ),
    );
    const unconditionalEffect = SquareEffect(
      trigger: EffectTrigger.onLand,
      actionType: EffectActionType.showMessage,
      parameters: {'message': 'always'},
    );

    final restored = Board.fromJson(
      createConditionalBoard(const [compoundEffect, unconditionalEffect]).toJson(),
    );
    final condition = restored.squareById('event')!.effects.first.condition!;

    expect(condition.type, EffectConditionType.allOf);
    expect(condition.childConditions, hasLength(2));
    expect(condition.childConditions.first.type, EffectConditionType.pointsBetween);
    expect(condition.childConditions.first.parameters['minPoints'], 5);
    final nested = condition.childConditions[1];
    expect(nested.type, EffectConditionType.anyOf);
    expect(nested.childConditions, hasLength(2));
    expect(nested.childConditions.first.type, EffectConditionType.hasItem);
    expect(nested.childConditions.last.type, EffectConditionType.notHasItem);
    expect(restored.squareById('event')!.effects.last.condition, isNull);
  });
}
