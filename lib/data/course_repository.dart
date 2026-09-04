import '../domain/board.dart';

abstract interface class CourseRepository {
  Future<List<Board>> listBoards();

  Future<Board?> getBoard(String id);

  Future<void> saveBoard(Board board);

  Future<void> deleteBoard(String id);
}
