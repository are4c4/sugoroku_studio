import 'package:flutter_test/flutter_test.dart';
import 'package:sugoroku_studio/domain/board.dart';
import 'package:sugoroku_studio/domain/cpu_strategy.dart';
import 'package:sugoroku_studio/domain/effect_condition_evaluator.dart';
import 'package:sugoroku_studio/domain/player.dart';

const hasKey = EffectCondition(
  type: EffectConditionType.hasItem,
  parameters: {'itemName': 'Key'},
);

EffectCondition notOf(EffectCondition child) => EffectCondition(
      type: EffectConditionType.not,
      parameters: {
        'conditions': [child.toJson()],
      },
    );

Board createStrategyBoard(EffectCondition condition) {
  return Board(
    id: 'not-strategy-board',
    name: 'NOT Strategy',
    squares: [
      const BoardSquare(
        id: 'fork',
        label: 'Fork',
        position: BoardPosition(x: 0, y: 0),
        kind: SquareKind.start,
      ),
      const BoardSquare(
        id: 'short',
        label: 'Short',
        position: BoardPosition(x: 100, y: -40),
        kind: SquareKind.normal,
      ),
      BoardSquare(
        id: 'reward',
        label: 'Reward',
        position: const BoardPosition(x: 100, y: 40),
        kind: SquareKind.normal,
        effects: [
          SquareEffect(
            trigger: EffectTrigger.onLand,
            actionType: EffectActionType.changePoints,
            parameters: const {'points': 10},
            condition: condition,
          ),
        ],
      ),
      const BoardSquare(
        id: 'reward-mid',
        label: 'Reward Mid',
        position: BoardPosition(x: 200, y: 40),
        kind: SquareKind.normal,
      ),
      const BoardSquare(
        id: 'goal',
        label: 'Goal',
        position: BoardPosition(x: 300, y: 0),
        kind: SquareKind.goal,
      ),
    ],
    connections: const [
      BoardConnection(fromSquareId: 'fork', toSquareId: 'short'),
      BoardConnection(fromSquareId: 'fork', toSquareId: 'reward'),
      BoardConnection(fromSquareId: 'short', toSquareId: 'goal'),
      BoardConnection(fromSquareId: 'reward', toSquareId: 'reward-mid'),
      BoardConnection(fromSquareId: 'reward-mid', toSquareId: 'goal'),
    ],
    updatedAt: DateTime(2026, 9, 4),
  );
}

Player cpuPlayer({Map<String, int> inventory = const {}}) => Player(
      id: 'cpu',
      name: 'CPU',
      type: PlayerType.cpu,
      currentSquareId: 'fork',
      cpuStrategy: CpuStrategyType.rewardSeeking,
      inventory: inventory,
    );

void main() {
  test('NOT inverts exactly one child condition', () {
    final condition = notOf(hasKey);

    expect(
      effectConditionMatches(condition, points: 0, inventory: const {}),
      isTrue,
    );
    expect(
      effectConditionMatches(
        condition,
        points: 0,
        inventory: const {'Key': 1},
      ),
      isFalse,
    );
  });

  test('NOT with zero or multiple children is safe false', () {
    const empty = EffectCondition(
      type: EffectConditionType.not,
      parameters: {'conditions': <Map<String, dynamic>>[]},
    );
    final multiple = EffectCondition(
      type: EffectConditionType.not,
      parameters: {
        'conditions': [
          hasKey.toJson(),
          const EffectCondition(
            type: EffectConditionType.pointsAtLeast,
            parameters: {'points': 1},
          ).toJson(),
        ],
      },
    );

    expect(
      effectConditionMatches(empty, points: 0, inventory: const {}),
      isFalse,
    );
    expect(
      effectConditionMatches(multiple, points: 0, inventory: const {}),
      isFalse,
    );
  });

  test('NOT can wrap nested AND conditions', () {
    final condition = notOf(
      EffectCondition(
        type: EffectConditionType.allOf,
        parameters: {
          'conditions': [
            const EffectCondition(
              type: EffectConditionType.pointsAtLeast,
              parameters: {'points': 5},
            ).toJson(),
            hasKey.toJson(),
          ],
        },
      ),
    );

    expect(
      effectConditionMatches(condition, points: 5, inventory: const {'Key': 1}),
      isFalse,
    );
    expect(
      effectConditionMatches(condition, points: 4, inventory: const {'Key': 1}),
      isTrue,
    );
    expect(
      effectConditionMatches(condition, points: 5, inventory: const {}),
      isTrue,
    );
  });

  test('JSON round-trip preserves NOT child condition', () {
    final original = notOf(
      const EffectCondition(
        type: EffectConditionType.pointsBetween,
        parameters: {'minPoints': 3, 'maxPoints': 8},
      ),
    );

    final restored = EffectCondition.fromJson(original.toJson());

    expect(restored.type, EffectConditionType.not);
    expect(restored.childConditions, hasLength(1));
    expect(
      restored.childConditions.single.type,
      EffectConditionType.pointsBetween,
    );
    expect(restored.childConditions.single.parameters['minPoints'], 3);
    expect(restored.childConditions.single.parameters['maxPoints'], 8);
  });

  test('reward CPU uses the shared evaluator for NOT conditions', () {
    final board = createStrategyBoard(notOf(hasKey));
    const strategy = RewardSeekingCpuStrategy();
    final from = board.squareById('fork')!;
    final options = board.outgoingSquares(from.id);

    expect(
      strategy.chooseNextSquare(
        board: board,
        player: cpuPlayer(),
        from: from,
        options: options,
      ),
      'reward',
    );
    expect(
      strategy.chooseNextSquare(
        board: board,
        player: cpuPlayer(inventory: const {'Key': 1}),
        from: from,
        options: options,
      ),
      'short',
    );
  });
}
