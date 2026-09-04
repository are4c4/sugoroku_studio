import 'package:flutter_test/flutter_test.dart';
import 'package:sugoroku_studio/domain/board.dart';
import 'package:sugoroku_studio/domain/board_duplicate.dart';
import 'package:sugoroku_studio/domain/item_definition.dart';

void main() {
  Board createSourceBoard() {
    return Board(
      id: 'source-board',
      name: '元コース',
      squares: const [
        BoardSquare(
          id: 'start',
          label: 'スタート',
          position: BoardPosition(x: 10, y: 20),
          kind: SquareKind.start,
        ),
        BoardSquare(
          id: 'event',
          label: 'ワープ',
          position: BoardPosition(x: 120, y: 40),
          kind: SquareKind.normal,
          effects: [
            SquareEffect(
              trigger: EffectTrigger.onLand,
              actionType: EffectActionType.warpTo,
              parameters: {'targetSquareId': 'bonus'},
              condition: EffectCondition(
                type: EffectConditionType.allOf,
                parameters: {
                  'conditions': [
                    {
                      'type': 'pointsAtLeast',
                      'parameters': {'points': 3},
                    },
                    {
                      'type': 'hasItem',
                      'parameters': {'itemName': '鍵'},
                    },
                  ],
                },
              ),
            ),
          ],
        ),
        BoardSquare(
          id: 'bonus',
          label: 'ボーナス',
          position: BoardPosition(x: 240, y: 40),
          kind: SquareKind.normal,
        ),
        BoardSquare(
          id: 'goal',
          label: 'ゴール',
          position: BoardPosition(x: 360, y: 20),
          kind: SquareKind.goal,
        ),
      ],
      connections: const [
        BoardConnection(fromSquareId: 'start', toSquareId: 'event'),
        BoardConnection(fromSquareId: 'event', toSquareId: 'bonus'),
        BoardConnection(fromSquareId: 'bonus', toSquareId: 'goal'),
      ],
      itemDefinitions: const [
        ItemDefinition(
          name: '鍵',
          description: 'テスト用',
          actionType: ItemUseActionType.changePoints,
          parameters: {'points': 5},
        ),
      ],
      updatedAt: DateTime(2026, 9, 1),
    );
  }

  test('duplicate gets a new board and square identity while preserving layout', () {
    final source = createSourceBoard();
    final duplicated = duplicateBoard(
      source,
      newBoardId: 'copy-board',
      newName: '元コース のコピー',
      updatedAt: DateTime(2026, 9, 5),
    );

    expect(duplicated.id, 'copy-board');
    expect(duplicated.name, '元コース のコピー');
    expect(duplicated.updatedAt, DateTime(2026, 9, 5));
    expect(
      duplicated.squares.map((square) => square.id),
      ['copy-board-square-0', 'copy-board-square-1', 'copy-board-square-2', 'copy-board-square-3'],
    );
    expect(
      duplicated.squares.map((square) => square.id).toSet().intersection(
            source.squares.map((square) => square.id).toSet(),
          ),
      isEmpty,
    );
    expect(duplicated.squares.map((square) => square.label),
        source.squares.map((square) => square.label));
    expect(duplicated.squares[1].position.x, 120);
    expect(duplicated.squares[1].position.y, 40);
    expect(duplicated.squares[1].kind, SquareKind.normal);
  });

  test('connections and warp targets are remapped to duplicated square ids', () {
    final duplicated = duplicateBoard(
      createSourceBoard(),
      newBoardId: 'copy-board',
      newName: 'copy',
      updatedAt: DateTime(2026, 9, 5),
    );

    expect(
      duplicated.connections.map(
        (connection) => '${connection.fromSquareId}->${connection.toSquareId}',
      ),
      [
        'copy-board-square-0->copy-board-square-1',
        'copy-board-square-1->copy-board-square-2',
        'copy-board-square-2->copy-board-square-3',
      ],
    );

    final warp = duplicated.squares[1].effects.single;
    expect(warp.parameters['targetSquareId'], 'copy-board-square-2');
    expect(warp.condition?.type, EffectConditionType.allOf);
    expect(warp.condition?.childConditions, hasLength(2));
    expect(duplicated.isPlayable, isTrue);
  });

  test('item definitions are preserved without reusing their parameter map', () {
    final source = createSourceBoard();
    final duplicated = duplicateBoard(
      source,
      newBoardId: 'copy-board',
      newName: 'copy',
      updatedAt: DateTime(2026, 9, 5),
    );

    expect(duplicated.itemDefinitions, hasLength(1));
    expect(duplicated.itemDefinitions.single.name, '鍵');
    expect(duplicated.itemDefinitions.single.pointsDelta, 5);
    expect(
      identical(
        duplicated.itemDefinitions.single.parameters,
        source.itemDefinitions.single.parameters,
      ),
      isFalse,
    );
  });

  test('invalid connections are not copied across boards', () {
    final source = createSourceBoard();
    final malformed = Board(
      id: source.id,
      name: source.name,
      squares: source.squares,
      connections: [
        ...source.connections,
        const BoardConnection(fromSquareId: 'event', toSquareId: 'missing'),
      ],
      itemDefinitions: source.itemDefinitions,
      updatedAt: source.updatedAt,
    );

    final duplicated = duplicateBoard(
      malformed,
      newBoardId: 'copy-board',
      newName: 'copy',
      updatedAt: DateTime(2026, 9, 5),
    );

    expect(duplicated.connections, hasLength(3));
    expect(
      duplicated.connections.any(
        (connection) => connection.toSquareId == 'missing',
      ),
      isFalse,
    );
  });
}
