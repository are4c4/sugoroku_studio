import 'package:flutter_test/flutter_test.dart';
import 'package:sugoroku_studio/domain/board.dart';
import 'package:sugoroku_studio/domain/game_engine.dart';
import 'package:sugoroku_studio/domain/game_event.dart';
import 'package:sugoroku_studio/domain/player.dart';

const player = Player(
  id: 'p1',
  name: 'Player 1',
  type: PlayerType.human,
  currentSquareId: '',
);

Board createMultipleEffectsBoard() {
  return Board(
    id: 'board-multiple-effects',
    name: 'Multiple Effects',
    squares: const [
      BoardSquare(
        id: 'start',
        label: 'Start',
        position: BoardPosition(x: 0, y: 0),
        kind: SquareKind.start,
      ),
      BoardSquare(
        id: 'combo',
        label: 'Combo',
        position: BoardPosition(x: 100, y: 0),
        kind: SquareKind.normal,
        effects: [
          SquareEffect(
            trigger: EffectTrigger.onLand,
            actionType: EffectActionType.moveBy,
            parameters: {'steps': 1},
          ),
          SquareEffect(
            trigger: EffectTrigger.onLand,
            actionType: EffectActionType.skipTurn,
            parameters: {'turns': 2},
          ),
          SquareEffect(
            trigger: EffectTrigger.onLand,
            actionType: EffectActionType.rollAgain,
          ),
        ],
      ),
      BoardSquare(
        id: 'after',
        label: 'After',
        position: BoardPosition(x: 200, y: 0),
        kind: SquareKind.normal,
      ),
      BoardSquare(
        id: 'goal',
        label: 'Goal',
        position: BoardPosition(x: 300, y: 0),
        kind: SquareKind.goal,
      ),
    ],
    connections: const [
      BoardConnection(fromSquareId: 'start', toSquareId: 'combo'),
      BoardConnection(fromSquareId: 'combo', toSquareId: 'after'),
      BoardConnection(fromSquareId: 'after', toSquareId: 'goal'),
    ],
    updatedAt: DateTime.utc(2026, 9, 4),
  );
}

void main() {
  test('multiple effects execute in their stored order', () async {
    final board = createMultipleEffectsBoard();
    final engine = GameEngine();
    final initial = engine.createGame(board: board, players: const [player]);

    final result = await engine.rollCurrentPlayer(initial, dice: 1);
    final applied = result.events.whereType<SquareEffectApplied>().toList();

    expect(
      applied.map((event) => event.effect.actionType),
      [
        EffectActionType.moveBy,
        EffectActionType.skipTurn,
        EffectActionType.rollAgain,
      ],
    );
    expect(result.state.currentPlayer.currentSquareId, 'after');
    expect(result.state.currentPlayer.skipTurns, 2);
    expect(result.state.currentPlayerIndex, 0);
    expect(result.state.turn, 1);
    expect(result.events.whereType<ExtraRollGranted>().length, 1);
  });

  test('JSON round-trip preserves multiple effect order and parameters', () {
    final restored = Board.fromJson(createMultipleEffectsBoard().toJson());
    final effects = restored.squareById('combo')!.effects;

    expect(effects.length, 3);
    expect(effects[0].actionType, EffectActionType.moveBy);
    expect(effects[0].parameters['steps'], 1);
    expect(effects[1].actionType, EffectActionType.skipTurn);
    expect(effects[1].parameters['turns'], 2);
    expect(effects[2].actionType, EffectActionType.rollAgain);
  });
}
