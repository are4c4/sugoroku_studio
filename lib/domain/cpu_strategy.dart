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

class ShortestPathCpuStrategy extends CpuStrategy {
  const ShortestPathCpuStrategy();

  @override
  String chooseNextSquare({
    required Board board,
    required Player player,
    required BoardSquare from,
    required List<BoardSquare> options,
  }) {
    if (options.isEmpty) {
      throw ArgumentError.value(options, 'options', 'must not be empty');
    }

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
