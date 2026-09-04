enum PlayerType { human, cpu }

class Player {
  const Player({
    required this.id,
    required this.name,
    required this.type,
    required this.currentSquareId,
    this.skipTurns = 0,
    this.routeHistory = const <String>[],
  });

  final String id;
  final String name;
  final PlayerType type;
  final String currentSquareId;
  final int skipTurns;
  final List<String> routeHistory;

  Player copyWith({
    String? name,
    PlayerType? type,
    String? currentSquareId,
    int? skipTurns,
    List<String>? routeHistory,
  }) {
    return Player(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      currentSquareId: currentSquareId ?? this.currentSquareId,
      skipTurns: skipTurns ?? this.skipTurns,
      routeHistory: routeHistory ?? this.routeHistory,
    );
  }
}
