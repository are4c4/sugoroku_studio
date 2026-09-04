import 'dart:async';
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

class RouteChoiceContext {
  const RouteChoiceContext({
    required this.board,
    required this.player,
    required this.fromSquare,
    required this.options,
    required this.remainingSteps,
  });

  final Board board;
  final Player player;
  final BoardSquare fromSquare;
  final List<BoardSquare> options;
  final int remainingSteps;
}

typedef RouteSelector = FutureOr<String> Function(RouteChoiceContext context);

class GameEngine {
  GameEngine({Random? random}) : _random = random ?? Random();

  static const int _maxEffectActivationsPerRoll = 16;

  final Random _random;

  int rollDice() => _random.nextInt(6) + 1;

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

    final start = board.startSquare!;
    final initializedPlayers = players
        .map(
          (player) => player.copyWith(
            currentSquareId: start.id,
            routeHistory: <String>[start.id],
          ),
        )
        .toList(growable: false);

    return GameState(
      board: board,
      players: initializedPlayers,
      currentPlayerIndex: 0,
      turn: 1,
      status: GameStatus.playing,
    );
  }

  Future<GameTurnResult> rollCurrentPlayer(
    GameState state, {
    int? dice,
    RouteSelector? routeSelector,
  }) async {
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

    final rolledDice = dice ?? rollDice();
    if (rolledDice < 1 || rolledDice > 6) {
      throw ArgumentError.value(rolledDice, 'dice', 'must be between 1 and 6');
    }

    final board = state.board;
    final selector = routeSelector ?? _chooseFirstRoute;
    final events = <GameEvent>[DiceRolled(rolledDice)];
    var currentSquareId = currentPlayer.currentSquareId;
    var currentPoints = currentPlayer.points;
    var routeHistory = List<String>.of(currentPlayer.routeHistory);
    if (routeHistory.isEmpty || routeHistory.last != currentSquareId) {
      routeHistory = <String>[currentSquareId];
    }

    void emitPassMessageEffects(BoardSquare square) {
      final passMessages = square.effects
          .where(
            (effect) =>
                effect.trigger == EffectTrigger.onPass &&
                effect.actionType == EffectActionType.showMessage,
          )
          .toList(growable: false);
      if (passMessages.isEmpty) return;

      events.add(SquarePassed(square.id));
      for (final effect in passMessages) {
        events.add(SquareEffectApplied(squareId: square.id, effect: effect));
      }
    }

    Future<void> moveForward(int steps) async {
      for (var step = 0; step < steps; step++) {
        final from = board.squareById(currentSquareId);
        if (from == null || from.kind == SquareKind.goal) return;
        final options = board.outgoingSquares(from.id);
        if (options.isEmpty) return;

        var next = options.first;
        if (options.length > 1) {
          final requestedId = await selector(
            RouteChoiceContext(
              board: board,
              player: currentPlayer.copyWith(
                currentSquareId: currentSquareId,
                points: currentPoints,
                routeHistory: List<String>.unmodifiable(routeHistory),
              ),
              fromSquare: from,
              options: options,
              remainingSteps: steps - step,
            ),
          );
          next = options.firstWhere(
            (option) => option.id == requestedId,
            orElse: () => options.first,
          );
          events.add(
            RouteChosen(
              playerId: currentPlayer.id,
              fromSquareId: from.id,
              toSquareId: next.id,
            ),
          );
        }

        events.add(
          PlayerMoved(
            playerId: currentPlayer.id,
            fromSquareId: currentSquareId,
            toSquareId: next.id,
          ),
        );
        currentSquareId = next.id;
        routeHistory.add(next.id);

        final willContinue = step < steps - 1 && next.kind != SquareKind.goal;
        if (willContinue) {
          emitPassMessageEffects(next);
        }
        if (next.kind == SquareKind.goal) return;
      }
    }

    void moveBackward(int steps) {
      for (var step = 0; step < steps; step++) {
        if (routeHistory.length > 1) {
          final from = currentSquareId;
          routeHistory.removeLast();
          currentSquareId = routeHistory.last;
          events.add(
            PlayerMoved(
              playerId: currentPlayer.id,
              fromSquareId: from,
              toSquareId: currentSquareId,
            ),
          );
          continue;
        }

        final incoming = board.incomingSquares(currentSquareId);
        if (incoming.isEmpty) return;
        final from = currentSquareId;
        currentSquareId = incoming.first.id;
        routeHistory = <String>[currentSquareId];
        events.add(
          PlayerMoved(
            playerId: currentPlayer.id,
            fromSquareId: from,
            toSquareId: currentSquareId,
          ),
        );
      }
    }

    void moveDirectlyTo(String targetSquareId, {required bool resetHistory}) {
      final target = board.squareById(targetSquareId);
      if (target == null || target.id == currentSquareId) return;
      final from = currentSquareId;
      currentSquareId = target.id;
      if (resetHistory) {
        routeHistory = <String>[target.id];
      } else {
        routeHistory.add(target.id);
      }
      events.add(
        PlayerMoved(
          playerId: currentPlayer.id,
          fromSquareId: from,
          toSquareId: target.id,
        ),
      );
    }

    await moveForward(rolledDice);

    var skipTurnsToAdd = 0;
    var extraRollGranted = false;
    var activationCount = 0;
    var shouldActivateSquare = true;

    while (shouldActivateSquare &&
        activationCount < _maxEffectActivationsPerRoll) {
      activationCount++;
      final activatedSquare = board.squareById(currentSquareId);
      if (activatedSquare == null) break;
      final positionBeforeEffects = currentSquareId;
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
            if (steps > 0) {
              await moveForward(steps);
            } else if (steps < 0) {
              moveBackward(steps.abs());
            }
          case EffectActionType.moveToStart:
            final start = board.startSquare;
            if (start != null) {
              moveDirectlyTo(start.id, resetHistory: true);
            }
          case EffectActionType.skipTurn:
            final rawTurns = effect.parameters['turns'];
            final turns = rawTurns is num ? rawTurns.toInt() : 1;
            skipTurnsToAdd += turns < 1 ? 1 : turns;
          case EffectActionType.rollAgain:
            extraRollGranted = true;
            events.add(ExtraRollGranted(currentPlayer.id));
          case EffectActionType.warpTo:
            final targetSquareId = effect.parameters['targetSquareId'];
            if (targetSquareId is String) {
              moveDirectlyTo(targetSquareId, resetHistory: false);
            }
          case EffectActionType.showMessage:
            break;
          case EffectActionType.changePoints:
            final rawDelta = effect.parameters['points'];
            final delta = rawDelta is num ? rawDelta.toInt() : 0;
            currentPoints += delta;
            events.add(
              PlayerPointsChanged(
                playerId: currentPlayer.id,
                delta: delta,
                points: currentPoints,
              ),
            );
        }
      }

      shouldActivateSquare = currentSquareId != positionBeforeEffects;
    }

    final destination = board.squareById(currentSquareId);
    if (destination == null) {
      throw StateError('Current player is not on the board.');
    }

    final updatedPlayer = currentPlayer.copyWith(
      currentSquareId: destination.id,
      skipTurns: currentPlayer.skipTurns + skipTurnsToAdd,
      points: currentPoints,
      routeHistory: List<String>.unmodifiable(routeHistory),
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
        diceResult: rolledDice,
        status: finished ? GameStatus.finished : GameStatus.playing,
      ),
      events: List<GameEvent>.unmodifiable(events),
    );
  }

  String _chooseFirstRoute(RouteChoiceContext context) => context.options.first.id;
}
