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

Board createMessageBoard() {
  return Board(
    id: 'message-board',
    name: 'Message Board',
    squares: const [
      BoardSquare(
        id: 'start',
        label: 'Start',
        position: BoardPosition(x: 0, y: 0),
        kind: SquareKind.start,
      ),
      BoardSquare(
        id: 'pass',
        label: 'Pass',
        position: BoardPosition(x: 100, y: 0),
        kind: SquareKind.normal,
        effects: [
          SquareEffect(
            trigger: EffectTrigger.onPass,
            actionType: EffectActionType.showMessage,
            parameters: {'message': 'ここを通過しました'},
          ),
        ],
      ),
      BoardSquare(
        id: 'land',
        label: 'Land',
        position: BoardPosition(x: 200, y: 0),
        kind: SquareKind.normal,
        effects: [
          SquareEffect(
            trigger: EffectTrigger.onLand,
            actionType: EffectActionType.showMessage,
            parameters: {'message': 'ここに止まりました'},
          ),
        ],
      ),
      BoardSquare(
        id: 'goal',
        label: 'Goal',
        position: BoardPosition(x: 300, y: 0),
        kind: SquareKind.goal,
      ),
    ],
    connections: const [
      BoardConnection(fromSquareId: 'start', toSquareId: 'pass'),
      BoardConnection(fromSquareId: 'pass', toSquareId: 'land'),
      BoardConnection(fromSquareId: 'land', toSquareId: 'goal'),
    ],
    updatedAt: DateTime.utc(2026, 9, 4),
  );
}

void main() {
  test('onPass message fires only while moving through a square', () async {
    final engine = GameEngine();
    final initial = engine.createGame(
      board: createMessageBoard(),
      players: const [player],
    );

    final result = await engine.rollCurrentPlayer(initial, dice: 2);
    final passed = result.events.whereType<SquarePassed>().toList();
    final applied = result.events.whereType<SquareEffectApplied>().toList();

    expect(passed.map((event) => event.squareId), ['pass']);
    expect(applied.length, 2);
    expect(applied[0].squareId, 'pass');
    expect(applied[0].effect.trigger, EffectTrigger.onPass);
    expect(applied[0].effect.parameters['message'], 'ここを通過しました');
    expect(applied[1].squareId, 'land');
    expect(applied[1].effect.trigger, EffectTrigger.onLand);
    expect(applied[1].effect.parameters['message'], 'ここに止まりました');
    expect(result.state.currentPlayer.currentSquareId, 'land');
  });

  test('onPass message does not fire when the player lands on that square', () async {
    final engine = GameEngine();
    final initial = engine.createGame(
      board: createMessageBoard(),
      players: const [player],
    );

    final result = await engine.rollCurrentPlayer(initial, dice: 1);

    expect(result.events.whereType<SquarePassed>(), isEmpty);
    expect(result.events.whereType<SquareEffectApplied>(), isEmpty);
    expect(result.state.currentPlayer.currentSquareId, 'pass');
  });

  test('JSON round-trip preserves message text and trigger', () {
    final restored = Board.fromJson(createMessageBoard().toJson());
    final passEffect = restored.squareById('pass')!.effects.single;
    final landEffect = restored.squareById('land')!.effects.single;

    expect(passEffect.trigger, EffectTrigger.onPass);
    expect(passEffect.actionType, EffectActionType.showMessage);
    expect(passEffect.parameters['message'], 'ここを通過しました');
    expect(landEffect.trigger, EffectTrigger.onLand);
    expect(landEffect.actionType, EffectActionType.showMessage);
    expect(landEffect.parameters['message'], 'ここに止まりました');
  });
}
