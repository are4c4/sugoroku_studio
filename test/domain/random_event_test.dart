import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sugoroku_studio/domain/board.dart';
import 'package:sugoroku_studio/domain/game_engine.dart';
import 'package:sugoroku_studio/domain/game_event.dart';
import 'package:sugoroku_studio/domain/player.dart';

class FixedRandom implements Random {
  FixedRandom(this.value);

  final int value;

  @override
  bool nextBool() => value.isEven;

  @override
  double nextDouble() => 0.5;

  @override
  int nextInt(int max) => value % max;
}

const options = <RandomEventOption>[
  RandomEventOption(
    label: 'お知らせ',
    outcomeType: RandomEventOutcomeType.showMessage,
    parameters: {'message': '何も起こらなかった'},
  ),
  RandomEventOption(
    label: 'ボーナス',
    outcomeType: RandomEventOutcomeType.changePoints,
    parameters: {'points': 7},
  ),
  RandomEventOption(
    label: '宝箱',
    outcomeType: RandomEventOutcomeType.grantItem,
    parameters: {'itemName': '金の鍵', 'quantity': 2},
  ),
];

Board createRandomBoard() {
  return Board(
    id: 'random-board',
    name: 'Random Board',
    squares: [
      const BoardSquare(
        id: 'start',
        label: 'Start',
        position: BoardPosition(x: 0, y: 0),
        kind: SquareKind.start,
      ),
      BoardSquare(
        id: 'random',
        label: 'Random',
        position: const BoardPosition(x: 100, y: 0),
        kind: SquareKind.normal,
        effects: [
          SquareEffect(
            trigger: EffectTrigger.onLand,
            actionType: EffectActionType.randomEvent,
            parameters: {
              'options': options.map((option) => option.toJson()).toList(),
            },
          ),
        ],
      ),
      const BoardSquare(
        id: 'goal',
        label: 'Goal',
        position: BoardPosition(x: 200, y: 0),
        kind: SquareKind.goal,
      ),
    ],
    connections: const [
      BoardConnection(fromSquareId: 'start', toSquareId: 'random'),
      BoardConnection(fromSquareId: 'random', toSquareId: 'goal'),
    ],
    updatedAt: DateTime.utc(2026, 9, 4),
  );
}

const player = Player(
  id: 'p1',
  name: 'Player 1',
  type: PlayerType.human,
  currentSquareId: '',
);

void main() {
  test('random event selects one option and applies point outcome', () async {
    final engine = GameEngine(random: FixedRandom(1));
    final state = engine.createGame(
      board: createRandomBoard(),
      players: const [player],
    );

    final result = await engine.rollCurrentPlayer(state, dice: 1);
    final chosen = result.events.whereType<RandomEventChosen>().single;

    expect(chosen.optionIndex, 1);
    expect(chosen.option.label, 'ボーナス');
    expect(chosen.option.outcomeType, RandomEventOutcomeType.changePoints);
    expect(result.state.currentPlayer.points, 7);
    expect(result.events.whereType<PlayerPointsChanged>().single.delta, 7);
    expect(result.events.whereType<PlayerItemGranted>(), isEmpty);
  });

  test('random item outcome updates inventory only when selected', () async {
    final engine = GameEngine(random: FixedRandom(2));
    final state = engine.createGame(
      board: createRandomBoard(),
      players: const [player],
    );

    final result = await engine.rollCurrentPlayer(state, dice: 1);
    final chosen = result.events.whereType<RandomEventChosen>().single;

    expect(chosen.optionIndex, 2);
    expect(chosen.option.label, '宝箱');
    expect(result.state.currentPlayer.itemQuantity('金の鍵'), 2);
    expect(result.events.whereType<PlayerPointsChanged>(), isEmpty);
    expect(result.events.whereType<PlayerItemGranted>().single.quantity, 2);
  });

  test('random message outcome changes no player state', () async {
    final engine = GameEngine(random: FixedRandom(0));
    final state = engine.createGame(
      board: createRandomBoard(),
      players: const [player],
    );

    final result = await engine.rollCurrentPlayer(state, dice: 1);
    final chosen = result.events.whereType<RandomEventChosen>().single;

    expect(chosen.option.outcomeType, RandomEventOutcomeType.showMessage);
    expect(chosen.option.parameters['message'], '何も起こらなかった');
    expect(result.state.currentPlayer.points, 0);
    expect(result.state.currentPlayer.inventory, isEmpty);
  });

  test('JSON round-trip preserves random event options and condition', () {
    const condition = EffectCondition(
      type: EffectConditionType.pointsAtLeast,
      parameters: {'points': 5},
    );
    final board = createRandomBoard();
    final randomSquare = board.squareById('random')!;
    final effect = randomSquare.effects.single;
    final conditioned = SquareEffect(
      trigger: effect.trigger,
      actionType: effect.actionType,
      parameters: effect.parameters,
      condition: condition,
    );
    final updated = board.copyWith(
      squares: board.squares
          .map(
            (square) => square.id == 'random'
                ? square.copyWith(effects: [conditioned])
                : square,
          )
          .toList(growable: false),
    );

    final restored = Board.fromJson(updated.toJson());
    final restoredEffect = restored.squareById('random')!.effects.single;
    final restoredOptions = restoredEffect.randomEventOptions;

    expect(restoredEffect.actionType, EffectActionType.randomEvent);
    expect(restoredEffect.condition?.type, EffectConditionType.pointsAtLeast);
    expect(restoredOptions.length, 3);
    expect(restoredOptions[1].outcomeType, RandomEventOutcomeType.changePoints);
    expect(restoredOptions[1].parameters['points'], 7);
    expect(restoredOptions[2].parameters['itemName'], '金の鍵');
  });
}
