sealed class GameEvent {
  const GameEvent();
}

class DiceRolled extends GameEvent {
  const DiceRolled(this.value);

  final int value;
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

class SquareActivated extends GameEvent {
  const SquareActivated(this.squareId);

  final String squareId;
}

class GoalReached extends GameEvent {
  const GoalReached(this.playerId);

  final String playerId;
}
