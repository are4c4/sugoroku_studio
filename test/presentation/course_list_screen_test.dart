import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugoroku_studio/data/course_repository.dart';
import 'package:sugoroku_studio/domain/board.dart';
import 'package:sugoroku_studio/presentation/course_list_screen.dart';

class _MemoryCourseRepository implements CourseRepository {
  _MemoryCourseRepository(this.boards);

  final List<Board> boards;

  @override
  Future<void> deleteBoard(String id) async {
    boards.removeWhere((board) => board.id == id);
  }

  @override
  Future<Board?> getBoard(String id) async {
    for (final board in boards) {
      if (board.id == id) return board;
    }
    return null;
  }

  @override
  Future<List<Board>> listBoards() async => List<Board>.of(boards);

  @override
  Future<void> saveBoard(Board board) async {
    final index = boards.indexWhere((item) => item.id == board.id);
    if (index >= 0) {
      boards[index] = board;
    } else {
      boards.add(board);
    }
  }
}

Board _createBoard({
  String id = 'original',
  String name = 'テストコース',
  DateTime? updatedAt,
}) {
  return Board(
    id: id,
    name: name,
    squares: const [
      BoardSquare(
        id: 'start',
        label: 'スタート',
        position: BoardPosition(x: 0, y: 0),
        kind: SquareKind.start,
      ),
      BoardSquare(
        id: 'goal',
        label: 'ゴール',
        position: BoardPosition(x: 100, y: 0),
        kind: SquareKind.goal,
      ),
    ],
    connections: const [
      BoardConnection(fromSquareId: 'start', toSquareId: 'goal'),
    ],
    updatedAt: updatedAt ?? DateTime(2026, 9, 5),
  );
}

void main() {
  testWidgets('course menu duplicates and saves a separate board', (tester) async {
    final repository = _MemoryCourseRepository([_createBoard()]);

    await tester.pumpWidget(
      MaterialApp(home: CourseListScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.text('テストコース'), findsOneWidget);
    expect(repository.boards, hasLength(1));

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('複製'));
    await tester.pumpAndSettle();

    expect(repository.boards, hasLength(2));
    final copy = repository.boards.singleWhere(
      (board) => board.id != 'original',
    );
    expect(copy.name, 'テストコース のコピー');
    expect(copy.squares.map((square) => square.id), isNot(contains('start')));
    expect(copy.isPlayable, isTrue);
    expect(find.text('テストコース のコピー'), findsOneWidget);
  });

  testWidgets('search filters courses by partial name and shows empty state', (
    tester,
  ) async {
    final repository = _MemoryCourseRepository([
      _createBoard(id: 'alpha', name: 'Alpha Course'),
      _createBoard(id: 'beta', name: 'Beta Course'),
    ]);

    await tester.pumpWidget(
      MaterialApp(home: CourseListScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Alpha Course'), findsOneWidget);
    expect(find.text('Beta Course'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'alp');
    await tester.pump();

    expect(find.text('Alpha Course'), findsOneWidget);
    expect(find.text('Beta Course'), findsNothing);

    await tester.enterText(find.byType(TextField), 'missing');
    await tester.pump();

    expect(find.textContaining('一致するコースはありません'), findsOneWidget);
    expect(find.text('検索をクリア'), findsOneWidget);
  });

  testWidgets('default sort is newest and can switch to name ascending', (
    tester,
  ) async {
    final repository = _MemoryCourseRepository([
      _createBoard(
        id: 'zeta',
        name: 'Zeta Course',
        updatedAt: DateTime(2026, 9, 1),
      ),
      _createBoard(
        id: 'alpha',
        name: 'Alpha Course',
        updatedAt: DateTime(2026, 9, 5),
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(home: CourseListScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.text('Alpha Course')).dy,
      lessThan(tester.getTopLeft(find.text('Zeta Course')).dy),
    );

    await tester.tap(find.text('更新が新しい順'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('名前 A→Z').last);
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.text('Alpha Course')).dy,
      lessThan(tester.getTopLeft(find.text('Zeta Course')).dy),
    );
  });
}
