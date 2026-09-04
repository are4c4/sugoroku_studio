enum PlayerType { human, cpu }

class Player {
  const Player({
    required this.id,
    required this.name,
    required this.type,
    required this.currentSquareId,
    this.skipTurns = 0,
    this.points = 0,
    this.inventory = const <String, int>{},
    this.routeHistory = const <String>[],
  });

  final String id;
  final String name;
  final PlayerType type;
  final String currentSquareId;
  final int skipTurns;
  final int points;
  final Map<String, int> inventory;
  final List<String> routeHistory;

  int itemQuantity(String itemName) => inventory[itemName] ?? 0;

  int get totalItems => inventory.values.fold(0, (sum, quantity) => sum + quantity);

  Player copyWith({
    String? name,
    PlayerType? type,
    String? currentSquareId,
    int? skipTurns,
    int? points,
    Map<String, int>? inventory,
    List<String>? routeHistory,
  }) {
    return Player(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      currentSquareId: currentSquareId ?? this.currentSquareId,
      skipTurns: skipTurns ?? this.skipTurns,
      points: points ?? this.points,
      inventory: inventory ?? this.inventory,
      routeHistory: routeHistory ?? this.routeHistory,
    );
  }
}
