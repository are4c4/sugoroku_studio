import 'package:flutter_test/flutter_test.dart';
import 'package:sugoroku_studio/domain/board.dart';
import 'package:sugoroku_studio/domain/game_engine.dart';
import 'package:sugoroku_studio/domain/game_event.dart';
import 'package:sugoroku_studio/domain/player.dart';

Board createItemBoard(List<SquareEffect> effects) {
  return Board(
    id: 'item-board',
    name: 'Item Board',
    squares: [
      const BoardSquare(
        id: 'start',
        label: 'Start',
        position: BoardPosition(x: 0, y: 0),
        kind: SquareKind.start,
      ),
      BoardSquare(
        id: 'item',
        label: 'Item',
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
      BoardConnection(fromSquareId: 'start', toSquareId: 'item'),
      BoardConnection(fromSquareId: 'item', toSquareId: 'goal'),
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
  test('same item grants stack and emit running totals', () async {
    const first = SquareEffect(
      trigger: EffectTrigger.onLand,
      actionType: EffectActionType.grantItem,
      parameters: {'itemName': '金の鍵', 'quantity': 2},
    );
    const second = SquareEffect(
      trigger: EffectTrigger.onLand,
      actionType: EffectActionType.grantItem,
      parameters: {'itemName': '金の鍵', 'quantity': 3},
    );
    final engine = GameEngine();
    final state = engine.createGame(
      board: createItemBoard(const [first, second]),
      players: const [player],
    );

    final result = await engine.rollCurrentPlayer(state, dice: 1);
    final grants = result.events.whereType<PlayerItemGranted>().toList();

    expect(result.state.currentPlayer.itemQuantity('金の鍵'), 5);
    expect(result.state.currentPlayer.totalItems, 5);
    expect(grants.map((event) => event.quantity), [2, 3]);
    expect(grants.map((event) => event.totalQuantity), [2, 5]);
  });

  test('item grant affects only the acting player', () async {
    const grant = SquareEffect(
      trigger: EffectTrigger.onLand,
      actionType: EffectActionType.grantItem,
      parameters: {'itemName': 'ポーション', 'quantity': 1},
    );
    const secondPlayer = Player(
      id: 'p2',
      name: 'Player 2',
      type: PlayerType.human,
      currentSquareId: '',
    );
    final engine = GameEngine();
    final state = engine.createGame(
      board: createItemBoard(const [grant]),
      players: const [player, secondPlayer],
    );

    final result = await engine.rollCurrentPlayer(state, dice: 1);

    expect(result.state.players[0].itemQuantity('ポーション'), 1);
    expect(result.state.players[1].inventory, isEmpty);
  });

  test('createGame preserves configured starting inventory', () {
    const configured = Player(
      id: 'configured',
      name: 'Configured',
      type: PlayerType.human,
      currentSquareId: '',
      inventory: {'地図': 2},
    );
    final engine = GameEngine();

    final state = engine.createGame(
      board: createItemBoard(const []),
      players: const [configured],
    );

    expect(state.currentPlayer.itemQuantity('地図'), 2);
    expect(state.currentPlayer.totalItems, 2);
  });

  test('JSON round-trip preserves item grant parameters and condition', () {
    const effect = SquareEffect(
      trigger: EffectTrigger.onLand,
      actionType: EffectActionType.grantItem,
      parameters: {'itemName': '宝箱', 'quantity': 4},
      condition: EffectCondition(
        type: EffectConditionType.pointsAtLeast,
        parameters: {'points': 10},
      ),
    );

    final restored = Board.fromJson(createItemBoard(const [effect]).toJson());
    final restoredEffect = restored.squareById('item')!.effects.single;

    expect(restoredEffect.actionType, EffectActionType.grantItem);
    expect(restoredEffect.parameters['itemName'], '宝箱');
    expect(restoredEffect.parameters['quantity'], 4);
    expect(restoredEffect.condition?.type, EffectConditionType.pointsAtLeast);
    expect(restoredEffect.condition?.parameters['points'], 10);
  });
}
