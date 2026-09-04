import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sugoroku_studio/data/local_course_repository.dart';
import 'package:sugoroku_studio/domain/board.dart';

void main() {
  test('save, load, and delete boards locally', () async {
    final temp = await Directory.systemTemp.createTemp('sugoroku_studio_test');
    addTearDown(() => temp.delete(recursive: true));

    final repository = LocalCourseRepository(directoryProvider: () async => temp);
    final board = Board(
      id: 'board-1',
      name: 'Saved board',
      squares: const [
        BoardSquare(
          id: 'start',
          label: 'Start',
          position: BoardPosition(x: 0, y: 0),
          kind: SquareKind.start,
        ),
        BoardSquare(
          id: 'goal',
          label: 'Goal',
          position: BoardPosition(x: 100, y: 0),
          kind: SquareKind.goal,
        ),
      ],
      connections: const [
        BoardConnection(fromSquareId: 'start', toSquareId: 'goal'),
      ],
      updatedAt: DateTime(2026, 9, 4),
    );

    await repository.saveBoard(board);
    final loaded = await repository.getBoard(board.id);

    expect(loaded, isNotNull);
    expect(loaded!.name, 'Saved board');
    expect((await repository.listBoards()).length, 1);

    await repository.deleteBoard(board.id);
    expect(await repository.listBoards(), isEmpty);
  });
}
