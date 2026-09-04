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

  test('JSON round-trip preserves optional conditions', () {
    const conditionalEffect = SquareEffect(
      trigger: EffectTrigger.onLand,
      actionType: EffectActionType.showMessage,
      parameters: {'message': 'qualified'},
      condition: EffectCondition(
        type: EffectConditionType.pointsAtLeast,
        parameters: {'points': 15},
      ),
    );
    const unconditionalEffect = SquareEffect(
      trigger: EffectTrigger.onLand,
      actionType: EffectActionType.showMessage,
      parameters: {'message': 'always'},
    );

    final restored = Board.fromJson(
      createConditionalBoard(
        const [conditionalEffect, unconditionalEffect],
      ).toJson(),
    );
    final effects = restored.squareById('event')!.effects;

    expect(effects[0].condition?.type, EffectConditionType.pointsAtLeast);
    expect(effects[0].condition?.parameters['points'], 15);
    expect(effects[1].condition, isNull);
  });
}
