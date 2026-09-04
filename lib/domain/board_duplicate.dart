import 'board.dart';
import 'item_definition.dart';

Board duplicateBoard(
  Board source, {
  required String newBoardId,
  required String newName,
  required DateTime updatedAt,
}) {
  final squareIdMap = <String, String>{};
  for (var index = 0; index < source.squares.length; index++) {
    squareIdMap[source.squares[index].id] = '$newBoardId-square-$index';
  }

  SquareEffect duplicateEffect(SquareEffect effect) {
    final parameters = Map<String, dynamic>.from(effect.parameters);
    if (effect.actionType == EffectActionType.warpTo) {
      final oldTarget = parameters['targetSquareId'];
      if (oldTarget is String) {
        final newTarget = squareIdMap[oldTarget];
        if (newTarget != null) {
          parameters['targetSquareId'] = newTarget;
        }
      }
    }

    return SquareEffect(
      trigger: effect.trigger,
      actionType: effect.actionType,
      parameters: parameters,
      condition: effect.condition == null
          ? null
          : EffectCondition.fromJson(effect.condition!.toJson()),
    );
  }

  final squares = source.squares
      .map(
        (square) => BoardSquare(
          id: squareIdMap[square.id]!,
          label: square.label,
          position: BoardPosition(
            x: square.position.x,
            y: square.position.y,
          ),
          kind: square.kind,
          effects: square.effects.map(duplicateEffect).toList(growable: false),
        ),
      )
      .toList(growable: false);

  final connections = <BoardConnection>[];
  for (final connection in source.connections) {
    final from = squareIdMap[connection.fromSquareId];
    final to = squareIdMap[connection.toSquareId];
    if (from == null || to == null) continue;
    connections.add(BoardConnection(fromSquareId: from, toSquareId: to));
  }

  final itemDefinitions = source.itemDefinitions
      .map((definition) => ItemDefinition.fromJson(definition.toJson()))
      .toList(growable: false);

  return Board(
    id: newBoardId,
    name: newName,
    squares: squares,
    connections: connections,
    itemDefinitions: itemDefinitions,
    updatedAt: updatedAt,
  );
}
