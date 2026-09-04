import 'package:flutter_test/flutter_test.dart';
import 'package:sugoroku_studio/domain/board.dart';
import 'package:sugoroku_studio/domain/game_engine.dart';
import 'package:sugoroku_studio/domain/game_event.dart';
import 'package:sugoroku_studio/domain/item_definition.dart';
import 'package:sugoroku_studio/domain/item_use.dart';
import 'package:sugoroku_studio/domain/player.dart';

Board createItemBoard() {
  return Board(
    id: 'item-board',
    name: 'Item Board',
    squares: const [
      BoardSquare(
        id: 'start',
        label: 'Start',
        position: BoardPosition(x: 0, y: 0),
        kind: SquareKind.start,
      ),
      BoardSquare(
        id: 'goal',
        label: 'Goal',
        position: BoardPosition(x: 100, y: 0),
        kind: SquareKind.goal,
      ),
    ],
    connections: const [
      BoardConnection(fromSquareId: 'start', toSquareId: 'goal'),
    ],
    itemDefinitions: const [
      ItemDefinition(
        name: 'Potion',
        description: 'Gain 5 points',
        actionType: ItemUseActionType.changePoints,
        parameters: {'points': 5},
      ),
      ItemDefinition(
        name: 'Penalty',
        description: 'Lose 3 points',
        actionType: ItemUseActionType.changePoints,
        parameters: {'points': -3},
      ),
    ],
    updatedAt: DateTime(2026, 9, 4),
  );
}

Player player(
  String id, {
  int points = 0,
  int skipTurns = 0,
  Map<String, int> inventory = const {},
}) {
  return Player(
    id: id,
    name: id,
    type: PlayerType.human,
    currentSquareId: '',
    points: points,
    skipTurns: skipTurns,
    inventory: inventory,
  );
}

void main() {
  test('board JSON round-trip preserves usable item definitions', () {
    final restored = Board.fromJson(createItemBoard().toJson());

    expect(restored.itemDefinitions, hasLength(2));
    expect(restored.itemDefinitions.first.name, 'Potion');
    expect(restored.itemDefinitions.first.description, 'Gain 5 points');
    expect(
      restored.itemDefinitions.first.actionType,
      ItemUseActionType.changePoints,
    );
    expect(restored.itemDefinitions.first.pointsDelta, 5);
    expect(restored.itemDefinitionByName('Potion')?.pointsDelta, 5);
  });

  test('using an item consumes one and applies points without ending the turn', () {
    final engine = GameEngine();
    final created = engine.createGame(
      board: createItemBoard(),
      players: [player('p1', points: 2, inventory: const {'Potion': 2})],
    );
    final state = created.copyWith(diceResult: 4);

    final result = engine.useCurrentPlayerItem(state, itemName: 'Potion');

    expect(result.state.currentPlayer.points, 7);
    expect(result.state.currentPlayer.itemQuantity('Potion'), 1);
    expect(result.state.currentPlayerIndex, state.currentPlayerIndex);
    expect(result.state.turn, state.turn);
    expect(result.state.diceResult, 4);
    expect(result.events.whereType<PlayerItemConsumed>(), hasLength(1));
    final pointsEvent = result.events.whereType<PlayerPointsChanged>().single;
    expect(pointsEvent.delta, 5);
    expect(pointsEvent.points, 7);
  });

  test('item use changes only the current player', () {
    final engine = GameEngine();
    final state = engine.createGame(
      board: createItemBoard(),
      players: [
        player('p1', inventory: const {'Potion': 1}),
        player('p2', points: 20, inventory: const {'Potion': 3}),
      ],
    );

    final result = engine.useCurrentPlayerItem(state, itemName: 'Potion');

    expect(result.state.players[0].points, 5);
    expect(result.state.players[0].itemQuantity('Potion'), 0);
    expect(result.state.players[1].points, 20);
    expect(result.state.players[1].itemQuantity('Potion'), 3);
    expect(result.state.currentPlayerIndex, 0);
  });

  test('unknown or unowned items are safe no-ops', () {
    final engine = GameEngine();
    final state = engine.createGame(
      board: createItemBoard(),
      players: [player('p1', inventory: const {'Unknown': 1})],
    );

    final unknown = engine.useCurrentPlayerItem(state, itemName: 'Unknown');
    final unowned = engine.useCurrentPlayerItem(state, itemName: 'Potion');

    expect(unknown.state, same(state));
    expect(unknown.events, isEmpty);
    expect(unowned.state, same(state));
    expect(unowned.events, isEmpty);
  });

  test('items cannot be used while the current player is skipping a turn', () {
    final engine = GameEngine();
    final state = engine.createGame(
      board: createItemBoard(),
      players: [
        player(
          'p1',
          skipTurns: 1,
          inventory: const {'Potion': 1},
        ),
      ],
    );

    final result = engine.useCurrentPlayerItem(state, itemName: 'Potion');

    expect(result.state, same(state));
    expect(result.events, isEmpty);
    expect(result.state.currentPlayer.itemQuantity('Potion'), 1);
  });

  test('negative point items use the same action model', () {
    final engine = GameEngine();
    final state = engine.createGame(
      board: createItemBoard(),
      players: [
        player('p1', points: 10, inventory: const {'Penalty': 1}),
      ],
    );

    final result = engine.useCurrentPlayerItem(state, itemName: 'Penalty');

    expect(result.state.currentPlayer.points, 7);
    expect(result.state.currentPlayer.itemQuantity('Penalty'), 0);
    expect(result.events.whereType<PlayerPointsChanged>().single.delta, -3);
  });
}
