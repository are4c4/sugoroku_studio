import 'board.dart';
import 'player.dart';

abstract class CpuStrategy {
  const CpuStrategy();

  String chooseNextSquare({
    required Board board,
    required Player player,
    required BoardSquare from,
    required List<BoardSquare> options,
  });
}

CpuStrategy cpuStrategyFor(CpuStrategyType type) {
  return switch (type) {
    CpuStrategyType.shortestPath => const ShortestPathCpuStrategy(),
    CpuStrategyType.cautious => const CautiousCpuStrategy(),
    CpuStrategyType.rewardSeeking => const RewardSeekingCpuStrategy(),
  };
}

class ShortestPathCpuStrategy extends CpuStrategy {
  const ShortestPathCpuStrategy();

  @override
  String chooseNextSquare({
    required Board board,
    required Player player,
    required BoardSquare from,
    required List<BoardSquare> options,
  }) {
    _requireOptions(options);

    BoardSquare best = options.first;
    var bestDistance = board.shortestDistanceToGoal(best.id);

    for (final option in options.skip(1)) {
      final distance = board.shortestDistanceToGoal(option.id);
      if (distance == null) continue;
      if (bestDistance == null || distance < bestDistance) {
        best = option;
        bestDistance = distance;
      }
    }
    return best.id;
  }
}

class CautiousCpuStrategy extends CpuStrategy {
  const CautiousCpuStrategy();

  @override
  String chooseNextSquare({
    required Board board,
    required Player player,
    required BoardSquare from,
    required List<BoardSquare> options,
  }) {
    _requireOptions(options);
    return _chooseHighestScore(
      options,
      (option) =>
          _cautiousSquareScore(board, player, option) -
          _goalDistance(board, option.id) * 2,
    ).id;
  }
}

class RewardSeekingCpuStrategy extends CpuStrategy {
  const RewardSeekingCpuStrategy();

  @override
  String chooseNextSquare({
    required Board board,
    required Player player,
    required BoardSquare from,
    required List<BoardSquare> options,
  }) {
    _requireOptions(options);
    return _chooseHighestScore(
      options,
      (option) =>
          _rewardSquareScore(player, option) - _goalDistance(board, option.id),
    ).id;
  }
}

void _requireOptions(List<BoardSquare> options) {
  if (options.isEmpty) {
    throw ArgumentError.value(options, 'options', 'must not be empty');
  }
}

BoardSquare _chooseHighestScore(
  List<BoardSquare> options,
  int Function(BoardSquare option) score,
) {
  var best = options.first;
  var bestScore = score(best);
  for (final option in options.skip(1)) {
    final optionScore = score(option);
    if (optionScore > bestScore) {
      best = option;
      bestScore = optionScore;
    }
  }
  return best;
}

int _goalDistance(Board board, String squareId) {
  return board.shortestDistanceToGoal(squareId) ?? 10000;
}

bool _conditionMatches(Player player, EffectCondition? condition) {
  if (condition == null) return true;
  final rawPoints = condition.parameters['points'];
  final threshold = rawPoints is num ? rawPoints.toInt() : 0;
  return switch (condition.type) {
    EffectConditionType.pointsAtLeast => player.points >= threshold,
    EffectConditionType.pointsAtMost => player.points <= threshold,
  };
}

Iterable<SquareEffect> _activeLandingEffects(
  Player player,
  BoardSquare square,
) {
  return square.effects.where(
    (effect) =>
        effect.trigger == EffectTrigger.onLand &&
        _conditionMatches(player, effect.condition),
  );
}

int _cautiousSquareScore(
  Board board,
  Player player,
  BoardSquare square,
) {
  var score = 0;
  for (final effect in _activeLandingEffects(player, square)) {
    switch (effect.actionType) {
      case EffectActionType.moveBy:
        final rawSteps = effect.parameters['steps'];
        final steps = rawSteps is num ? rawSteps.toInt() : 0;
        score += steps >= 0 ? steps : steps * 12;
      case EffectActionType.moveToStart:
        score -= 120;
      case EffectActionType.skipTurn:
        final rawTurns = effect.parameters['turns'];
        final turns = rawTurns is num ? rawTurns.toInt().clamp(1, 20) : 1;
        score -= turns * 20;
      case EffectActionType.rollAgain:
        score += 4;
      case EffectActionType.warpTo:
        final target = effect.parameters['targetSquareId'];
        if (target is String) {
          final currentDistance = _goalDistance(board, square.id);
          final targetDistance = _goalDistance(board, target);
          score += (currentDistance - targetDistance).clamp(-20, 20);
        }
      case EffectActionType.showMessage:
        break;
      case EffectActionType.changePoints:
        final rawPoints = effect.parameters['points'];
        final points = rawPoints is num ? rawPoints.toInt() : 0;
        if (points < 0) score += points * 3;
      case EffectActionType.grantItem:
        final rawQuantity = effect.parameters['quantity'];
        final quantity = rawQuantity is num ? rawQuantity.toInt().clamp(1, 20) : 1;
        score += quantity;
      case EffectActionType.randomEvent:
        final outcomes = effect.randomEventOptions;
        if (outcomes.isNotEmpty) {
          var worst = _cautiousRandomOutcomeScore(outcomes.first);
          for (final outcome in outcomes.skip(1)) {
            final outcomeScore = _cautiousRandomOutcomeScore(outcome);
            if (outcomeScore < worst) worst = outcomeScore;
          }
          score += worst;
        }
    }
  }
  return score;
}

int _cautiousRandomOutcomeScore(RandomEventOption option) {
  switch (option.outcomeType) {
    case RandomEventOutcomeType.showMessage:
      return 0;
    case RandomEventOutcomeType.changePoints:
      final rawPoints = option.parameters['points'];
      final points = rawPoints is num ? rawPoints.toInt() : 0;
      return points < 0 ? points * 2 : 0;
    case RandomEventOutcomeType.grantItem:
      return 1;
  }
}

int _rewardSquareScore(Player player, BoardSquare square) {
  var score = 0;
  for (final effect in _activeLandingEffects(player, square)) {
    switch (effect.actionType) {
      case EffectActionType.moveBy:
        final rawSteps = effect.parameters['steps'];
        final steps = rawSteps is num ? rawSteps.toInt() : 0;
        score += steps * 2;
      case EffectActionType.moveToStart:
        score -= 25;
      case EffectActionType.skipTurn:
        final rawTurns = effect.parameters['turns'];
        final turns = rawTurns is num ? rawTurns.toInt().clamp(1, 20) : 1;
        score -= turns * 6;
      case EffectActionType.rollAgain:
        score += 6;
      case EffectActionType.warpTo:
        break;
      case EffectActionType.showMessage:
        break;
      case EffectActionType.changePoints:
        final rawPoints = effect.parameters['points'];
        final points = rawPoints is num ? rawPoints.toInt() : 0;
        score += points * 4;
      case EffectActionType.grantItem:
        final rawQuantity = effect.parameters['quantity'];
        final quantity = rawQuantity is num ? rawQuantity.toInt().clamp(1, 20) : 1;
        score += quantity * 10;
      case EffectActionType.randomEvent:
        final outcomes = effect.randomEventOptions;
        if (outcomes.isNotEmpty) {
          final total = outcomes.fold<int>(
            0,
            (sum, outcome) => sum + _rewardRandomOutcomeScore(outcome),
          );
          score += total ~/ outcomes.length;
        }
    }
  }
  return score;
}

int _rewardRandomOutcomeScore(RandomEventOption option) {
  switch (option.outcomeType) {
    case RandomEventOutcomeType.showMessage:
      return 0;
    case RandomEventOutcomeType.changePoints:
      final rawPoints = option.parameters['points'];
      final points = rawPoints is num ? rawPoints.toInt() : 0;
      return points * 4;
    case RandomEventOutcomeType.grantItem:
      final rawQuantity = option.parameters['quantity'];
      final quantity = rawQuantity is num ? rawQuantity.toInt().clamp(1, 20) : 1;
      return quantity * 10;
  }
}
