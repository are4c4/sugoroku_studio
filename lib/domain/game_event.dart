import 'board.dart';

sealed class GameEvent {
  const GameEvent();
}

class DiceRolled extends GameEvent {
  const DiceRolled(this.value);

  final int value;
}

class RouteChosen extends GameEvent {
  const RouteChosen({
    required this.playerId,
    required this.fromSquareId,
    required this.toSquareId,
  });

  final String playerId;
  final String fromSquareId;
  final String toSquareId;
}

class PlayerMoved extends GameEvent {
  const PlayerMoved({
    required this.playerId,
    required this.fromSquareId,
    required this.toSquareId,
  });

  final String playerId;
  final String fromSquareId;
  final String toSquareId;
}

class SquarePassed extends GameEvent {
  const SquarePassed(this.squareId);

  final String squareId;
}

class SquareActivated extends GameEvent {
  const SquareActivated(this.squareId);

  final String squareId;
}

class SquareEffectApplied extends GameEvent {
  const SquareEffectApplied({
    required this.squareId,
    required this.effect,
  });

  final String squareId;
  final SquareEffect effect;
}

class PlayerPointsChanged extends GameEvent {
  const PlayerPointsChanged({
    required this.playerId,
    required this.delta,
    required this.points,
  });

  final String playerId;
  final int delta;
  final int points;
}

class PlayerItemGranted extends GameEvent {
  const PlayerItemGranted({
    required this.playerId,
    required this.itemName,
    required this.quantity,
    required this.totalQuantity,
  });

  final String playerId;
  final String itemName;
  final int quantity;
  final int totalQuantity;
}

class ExtraRollGranted extends GameEvent {
  const ExtraRollGranted(this.playerId);

  final String playerId;
}

class PlayerTurnSkipped extends GameEvent {
  const PlayerTurnSkipped({
    required this.playerId,
    required this.remainingSkipTurns,
  });

  final String playerId;
  final int remainingSkipTurns;
}

class GoalReached extends GameEvent {
  const GoalReached(this.playerId);

  final String playerId;
}
