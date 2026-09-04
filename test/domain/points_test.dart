import 'package:flutter_test/flutter_test.dart';
import 'package:sugoroku_studio/domain/board.dart';
import 'package:sugoroku_studio/domain/game_engine.dart';
import 'package:sugoroku_studio/domain/game_event.dart';
import 'package:sugoroku_studio/domain/player.dart';

const player1 = Player(
  id: 'p1',
  name: 'Player 1',
  type: PlayerType.human,
  currentSquareId: '',
);

const player2 = Player(
  id: 'p2',
  name: 'Player 2',
  type: PlayerType.human,
  currentSquareId: '',
);

Board createPointsBoard() {
  return Board(
    id: 'points-board',
    name: 'Points Board',
    squares: const [
      BoardSquare(
        id: 'start',
        label: 'Start',
        position: BoardPosition(x: 0, y: 0),
        kind: SquareKind.start,
      ),
      BoardSquare(
        id: 'plus',
        label: '+5',
        position: BoardPosition(x: 100, y: 0),
        kind: SquareKind.normal,
        effects: [
          SquareEffect(
            trigger: EffectTrigger.onLand,
            actionType: EffectActionType.changePoints,
            parameters: {'points': 5},
          ),
        ],
      ),
      BoardSquare(
        id: 'minus',
        label: '-2',
        position: BoardPosition(x: 200, y: 0),
        kind: SquareKind.normal,
        effects: [
          SquareEffect(
            trigger: EffectTrigger.onLand,
            actionType: EffectActionType.changePoints,
            parameters: {'points': -2},
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
      BoardConnection(fromSquareId: 'start', toSquareId: 'plus'),
      BoardConnection(fromSquareId: 'plus', toSquareId: 'minus'),
      BoardConnection(fromSquareId: 'minus', toSquareId: 'goal'),
    ],
    updatedAt: DateTime.utc(2026, 9, 4),
  );
}

void main() {
  test('point changes accumulate across turns', () async {
    final engine = GameEngine();
    final initial = engine.createGame(
      board: createPointsBoard(),
      players: const [player1],
    );

    final first = await engine.rollCurrentPlayer(initial, dice: 1);
    final firstPointEvent = first.events.whereType<PlayerPointsChanged>().single;

    expect(first.state.currentPlayer.currentSquareId, 'plus');
    expect(first.state.currentPlayer.points, 5);
    expect(firstPointEvent.delta, 5);
    expect(firstPointEvent.points, 5);

    final second = await engine.rollCurrentPlayer(first.state, dice: 1);
    final secondPointEvent = second.events.whereType<PlayerPointsChanged>().single;

    expect(second.state.currentPlayer.currentSquareId, 'minus');
    expect(second.state.currentPlayer.points, 3);
    expect(secondPointEvent.delta, -2);
    expect(secondPointEvent.points, 3);
  });

  test('point changes affect only the acting player', () async {
    final engine = GameEngine();
    final initial = engine.createGame(
      board: createPointsBoard(),
      players: const [player1, player2],
    );

    final first = await engine.rollCurrentPlayer(initial, dice: 1);

    expect(first.state.players[0].points, 5);
    expect(first.state.players[1].points, 0);
    expect(first.state.currentPlayerIndex, 1);

    final second = await engine.rollCurrentPlayer(first.state, dice: 1);

    expect(second.state.players[0].points, 5);
    expect(second.state.players[1].points, 5);
    expect(second.state.currentPlayerIndex, 0);
  });

  test('createGame preserves configured starting points', () {
    const playerWithPoints = Player(
      id: 'bonus-player',
      name: 'Bonus Player',
      type: PlayerType.human,
      currentSquareId: '',
      points: 12,
    );
    final engine = GameEngine();

    final state = engine.createGame(
      board: createPointsBoard(),
      players: const [playerWithPoints],
    );

    expect(state.currentPlayer.points, 12);
    expect(state.currentPlayer.currentSquareId, 'start');
  });

  test('JSON round-trip preserves point action parameters', () {
    final restored = Board.fromJson(createPointsBoard().toJson());
    final plusEffect = restored.squareById('plus')!.effects.single;
    final minusEffect = restored.squareById('minus')!.effects.single;

    expect(plusEffect.actionType, EffectActionType.changePoints);
    expect(plusEffect.parameters['points'], 5);
    expect(minusEffect.actionType, EffectActionType.changePoints);
    expect(minusEffect.parameters['points'], -2);
  });
}
