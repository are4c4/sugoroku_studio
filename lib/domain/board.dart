enum SquareKind { start, normal, goal }

enum EffectTrigger { onLand, onPass }

enum EffectActionType {
  moveBy,
  moveToStart,
  skipTurn,
  rollAgain,
  warpTo,
  showMessage,
}

class BoardPosition {
  const BoardPosition({required this.x, required this.y});

  final double x;
  final double y;

  Map<String, dynamic> toJson() => {'x': x, 'y': y};

  factory BoardPosition.fromJson(Map<String, dynamic> json) {
    return BoardPosition(
      x: (json['x'] as num?)?.toDouble() ?? 0,
      y: (json['y'] as num?)?.toDouble() ?? 0,
    );
  }
}

class SquareEffect {
  const SquareEffect({
    required this.trigger,
    required this.actionType,
    this.parameters = const <String, dynamic>{},
  });

  final EffectTrigger trigger;
  final EffectActionType actionType;
  final Map<String, dynamic> parameters;

  Map<String, dynamic> toJson() => {
        'trigger': trigger.name,
        'actionType': actionType.name,
        'parameters': parameters,
      };

  factory SquareEffect.fromJson(Map<String, dynamic> json) {
    return SquareEffect(
      trigger: EffectTrigger.values.byName(
        json['trigger'] as String? ?? EffectTrigger.onLand.name,
      ),
      actionType: EffectActionType.values.byName(
        json['actionType'] as String? ?? EffectActionType.moveBy.name,
      ),
      parameters: Map<String, dynamic>.from(
        json['parameters'] as Map? ?? const <String, dynamic>{},
      ),
    );
  }
}

class BoardSquare {
  const BoardSquare({
    required this.id,
    required this.label,
    required this.position,
    required this.kind,
    this.effects = const <SquareEffect>[],
  });

  final String id;
  final String label;
  final BoardPosition position;
  final SquareKind kind;
  final List<SquareEffect> effects;

  BoardSquare copyWith({
    String? label,
    BoardPosition? position,
    SquareKind? kind,
    List<SquareEffect>? effects,
  }) {
    return BoardSquare(
      id: id,
      label: label ?? this.label,
      position: position ?? this.position,
      kind: kind ?? this.kind,
      effects: effects ?? this.effects,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'position': position.toJson(),
        'kind': kind.name,
        'effects': effects.map((effect) => effect.toJson()).toList(),
      };

  factory BoardSquare.fromJson(Map<String, dynamic> json) {
    final rawEffects = json['effects'] as List<dynamic>? ?? const <dynamic>[];
    return BoardSquare(
      id: json['id'] as String,
      label: json['label'] as String? ?? '',
      position: BoardPosition.fromJson(
        Map<String, dynamic>.from(json['position'] as Map? ?? const {}),
      ),
      kind: SquareKind.values.byName(
        json['kind'] as String? ?? SquareKind.normal.name,
      ),
      effects: rawEffects
          .map(
            (effect) => SquareEffect.fromJson(
              Map<String, dynamic>.from(effect as Map),
            ),
          )
          .toList(growable: false),
    );
  }
}

class BoardConnection {
  const BoardConnection({
    required this.fromSquareId,
    required this.toSquareId,
  });

  final String fromSquareId;
  final String toSquareId;

  Map<String, dynamic> toJson() => {
        'fromSquareId': fromSquareId,
        'toSquareId': toSquareId,
      };

  factory BoardConnection.fromJson(Map<String, dynamic> json) {
    return BoardConnection(
      fromSquareId: json['fromSquareId'] as String,
      toSquareId: json['toSquareId'] as String,
    );
  }
}

class Board {
  const Board({
    required this.id,
    required this.name,
    required this.squares,
    required this.connections,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final List<BoardSquare> squares;
  final List<BoardConnection> connections;
  final DateTime updatedAt;

  Board copyWith({
    String? name,
    List<BoardSquare>? squares,
    List<BoardConnection>? connections,
    DateTime? updatedAt,
  }) {
    return Board(
      id: id,
      name: name ?? this.name,
      squares: squares ?? this.squares,
      connections: connections ?? this.connections,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  BoardSquare? get startSquare {
    for (final square in squares) {
      if (square.kind == SquareKind.start) return square;
    }
    return null;
  }

  BoardSquare? squareById(String id) {
    for (final square in squares) {
      if (square.id == id) return square;
    }
    return null;
  }

  List<BoardSquare> outgoingSquares(String squareId) {
    final result = <BoardSquare>[];
    for (final connection in connections) {
      if (connection.fromSquareId != squareId) continue;
      final target = squareById(connection.toSquareId);
      if (target != null && !result.any((item) => item.id == target.id)) {
        result.add(target);
      }
    }
    return List<BoardSquare>.unmodifiable(result);
  }

  List<BoardSquare> incomingSquares(String squareId) {
    final result = <BoardSquare>[];
    for (final connection in connections) {
      if (connection.toSquareId != squareId) continue;
      final source = squareById(connection.fromSquareId);
      if (source != null && !result.any((item) => item.id == source.id)) {
        result.add(source);
      }
    }
    return List<BoardSquare>.unmodifiable(result);
  }

  int? shortestDistanceToGoal(String fromSquareId) {
    final start = squareById(fromSquareId);
    if (start == null) return null;
    if (start.kind == SquareKind.goal) return 0;

    final queue = <String>[fromSquareId];
    final distances = <String, int>{fromSquareId: 0};
    var cursor = 0;

    while (cursor < queue.length) {
      final currentId = queue[cursor++];
      final currentDistance = distances[currentId]!;
      for (final next in outgoingSquares(currentId)) {
        if (distances.containsKey(next.id)) continue;
        final distance = currentDistance + 1;
        if (next.kind == SquareKind.goal) return distance;
        distances[next.id] = distance;
        queue.add(next.id);
      }
    }
    return null;
  }

  bool canReachGoalFrom(String squareId) => shortestDistanceToGoal(squareId) != null;

  List<BoardSquare> orderedPath() {
    final start = startSquare;
    if (start == null) return const <BoardSquare>[];

    final path = <BoardSquare>[];
    final visited = <String>{};
    BoardSquare? current = start;
    while (current != null && visited.add(current.id)) {
      path.add(current);
      final next = outgoingSquares(current.id);
      current = next.isEmpty ? null : next.first;
    }
    return path;
  }

  bool get isPlayable {
    final start = startSquare;
    if (start == null) return false;
    if (!squares.any((square) => square.kind == SquareKind.goal)) return false;
    return canReachGoalFrom(start.id);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'squares': squares.map((square) => square.toJson()).toList(),
        'connections':
            connections.map((connection) => connection.toJson()).toList(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Board.fromJson(Map<String, dynamic> json) {
    final rawSquares = json['squares'] as List<dynamic>? ?? const <dynamic>[];
    final rawConnections =
        json['connections'] as List<dynamic>? ?? const <dynamic>[];
    return Board(
      id: json['id'] as String,
      name: json['name'] as String? ?? '名称未設定',
      squares: rawSquares
          .map(
            (square) => BoardSquare.fromJson(
              Map<String, dynamic>.from(square as Map),
            ),
          )
          .toList(growable: false),
      connections: rawConnections
          .map(
            (connection) => BoardConnection.fromJson(
              Map<String, dynamic>.from(connection as Map),
            ),
          )
          .toList(growable: false),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
