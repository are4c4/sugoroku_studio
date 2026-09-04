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

  static const int _maxEffectActivationsPerRoll = 16;

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

    final players = List<Player>.of(state.players);
    final currentPlayer = state.currentPlayer;

    if (currentPlayer.skipTurns > 0) {
      final updatedPlayer = currentPlayer.copyWith(
        skipTurns: currentPlayer.skipTurns - 1,
      );
      players[state.currentPlayerIndex] = updatedPlayer;
      final nextPlayerIndex = (state.currentPlayerIndex + 1) % players.length;

      return GameTurnResult(
        state: state.copyWith(
          players: players,
          currentPlayerIndex: nextPlayerIndex,
          turn: state.turn + 1,
          clearDiceResult: true,
        ),
        events: [
          PlayerTurnSkipped(
            playerId: currentPlayer.id,
            remainingSkipTurns: updatedPlayer.skipTurns,
          ),
        ],
      );
    }

    final dice = _random.nextInt(6) + 1;
    final events = <GameEvent>[DiceRolled(dice)];
    final path = state.board.orderedPath();
    var positionIndex = path.indexWhere(
      (square) => square.id == currentPlayer.currentSquareId,
    );
    if (positionIndex < 0) {
      throw StateError('Current player is not on the board path.');
    }

    void moveToIndex(int requestedIndex) {
      final targetIndex = requestedIndex.clamp(0, path.length - 1).toInt();
      if (targetIndex > positionIndex) {
        for (var index = positionIndex + 1; index <= targetIndex; index++) {
          events.add(
            PlayerMoved(
              playerId: currentPlayer.id,
              fromSquareId: path[index - 1].id,
              toSquareId: path[index].id,
            ),
          );
        }
      } else if (targetIndex < positionIndex) {
        for (var index = positionIndex - 1; index >= targetIndex; index--) {
          events.add(
            PlayerMoved(
              playerId: currentPlayer.id,
              fromSquareId: path[index + 1].id,
              toSquareId: path[index].id,
            ),
          );
        }
      }
      positionIndex = targetIndex;
    }

    moveToIndex(positionIndex + dice);

    var skipTurnsToAdd = 0;
    var extraRollGranted = false;
    var activationCount = 0;
    var shouldActivateSquare = true;

    while (shouldActivateSquare &&
        activationCount < _maxEffectActivationsPerRoll) {
      activationCount++;
      final activatedSquare = path[positionIndex];
      final positionBeforeEffects = positionIndex;
      events.add(SquareActivated(activatedSquare.id));

      for (final effect in activatedSquare.effects) {
        if (effect.trigger != EffectTrigger.onLand) continue;
        events.add(
          SquareEffectApplied(squareId: activatedSquare.id, effect: effect),
        );

        switch (effect.actionType) {
          case EffectActionType.moveBy:
            final rawSteps = effect.parameters['steps'];
            final steps = rawSteps is num ? rawSteps.toInt() : 0;
            moveToIndex(positionIndex + steps);
          case EffectActionType.moveToStart:
            moveToIndex(0);
          case EffectActionType.skipTurn:
            final rawTurns = effect.parameters['turns'];
            final turns = rawTurns is num ? rawTurns.toInt() : 1;
            skipTurnsToAdd += turns < 1 ? 1 : turns;
          case EffectActionType.rollAgain:
            extraRollGranted = true;
            events.add(ExtraRollGranted(currentPlayer.id));
          case EffectActionType.warpTo:
            // Warp is reserved for the branching-course milestone. Keeping the
            // action in the model preserves JSON compatibility until then.
            break;
        }
      }

      shouldActivateSquare = positionIndex != positionBeforeEffects;
    }

    final destination = path[positionIndex];
    final updatedPlayer = currentPlayer.copyWith(
      currentSquareId: destination.id,
      skipTurns: currentPlayer.skipTurns + skipTurnsToAdd,
    );
    players[state.currentPlayerIndex] = updatedPlayer;

    final finished = destination.kind == SquareKind.goal;
    if (finished) {
      events.add(GoalReached(currentPlayer.id));
    }

    final nextPlayerIndex = finished || extraRollGranted
        ? state.currentPlayerIndex
        : (state.currentPlayerIndex + 1) % players.length;
    final nextTurn = extraRollGranted && !finished ? state.turn : state.turn + 1;

    return GameTurnResult(
      state: state.copyWith(
        players: players,
        currentPlayerIndex: nextPlayerIndex,
        turn: nextTurn,
        diceResult: dice,
        status: finished ? GameStatus.finished : GameStatus.playing,
      ),
      events: List<GameEvent>.unmodifiable(events),
    );
  }
}
