import 'dart:math';

import 'board.dart';
import 'game_event.dart';
import 'game_state.dart';
import 'player.dart';

class GameTurnResult {
  const GameTurnResult({required this.state, required this.events});

  final GameState state;
  final List<GameEvent> events;
}

class GameEngine {
  GameEngine({Random? random}) : _random = random ?? Random();

  final Random _random;

  GameState createGame({
    required Board board,
    required List<Player> players,
  }) {
    if (!board.isPlayable) {
      throw StateError('Board must have a connected start-to-goal path.');
    }
    if (players.isEmpty) {
      throw ArgumentError.value(players, 'players', 'must not be empty');
    }

    final startSquareId = board.orderedPath().first.id;
    final initializedPlayers = players
        .map((player) => player.copyWith(currentSquareId: startSquareId))
        .toList(growable: false);

    return GameState(
      board: board,
      players: initializedPlayers,
      currentPlayerIndex: 0,
      turn: 1,
      status: GameStatus.playing,
    );
  }

  GameTurnResult rollCurrentPlayer(GameState state) {
    if (state.status == GameStatus.finished) {
      return GameTurnResult(state: state, events: const <GameEvent>[]);
    }

    final dice = _random.nextInt(6) + 1;
    final events = <GameEvent>[DiceRolled(dice)];
    final path = state.board.orderedPath();
    final currentPlayer = state.currentPlayer;
    final currentIndex = path.indexWhere(
      (square) => square.id == currentPlayer.currentSquareId,
    );
    if (currentIndex < 0) {
      throw StateError('Current player is not on the board path.');
    }

    final targetIndex = min(currentIndex + dice, path.length - 1);
    for (var index = currentIndex + 1; index <= targetIndex; index++) {
      events.add(
        PlayerMoved(
          playerId: currentPlayer.id,
          fromSquareId: path[index - 1].id,
          toSquareId: path[index].id,
        ),
      );
    }

    final destination = path[targetIndex];
    events.add(SquareActivated(destination.id));

    final players = List<Player>.of(state.players);
    players[state.currentPlayerIndex] = currentPlayer.copyWith(
      currentSquareId: destination.id,
    );

    final finished = destination.kind == SquareKind.goal;
    if (finished) {
      events.add(GoalReached(currentPlayer.id));
    }

    final nextPlayerIndex = finished
        ? state.currentPlayerIndex
        : (state.currentPlayerIndex + 1) % players.length;

    return GameTurnResult(
      state: state.copyWith(
        players: players,
        currentPlayerIndex: nextPlayerIndex,
        turn: state.turn + 1,
        diceResult: dice,
        status: finished ? GameStatus.finished : GameStatus.playing,
      ),
      events: List<GameEvent>.unmodifiable(events),
    );
  }
}
