import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../domain/board.dart';
import 'course_repository.dart';

class LocalCourseRepository implements CourseRepository {
  LocalCourseRepository({Future<Directory> Function()? directoryProvider})
      : _directoryProvider = directoryProvider ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _directoryProvider;

  Future<File> _storageFile() async {
    final directory = await _directoryProvider();
    final appDirectory = Directory('${directory.path}/sugoroku_studio');
    if (!await appDirectory.exists()) {
      await appDirectory.create(recursive: true);
    }
    return File('${appDirectory.path}/boards.json');
  }

  Future<List<Board>> _loadAll() async {
    final file = await _storageFile();
    if (!await file.exists()) return <Board>[];

    final source = await file.readAsString();
    if (source.trim().isEmpty) return <Board>[];

    final decoded = jsonDecode(source);
    if (decoded is! List) {
      throw const FormatException('boards.json must contain a JSON array.');
    }

    return decoded
        .map(
          (board) => Board.fromJson(
            Map<String, dynamic>.from(board as Map),
          ),
        )
        .toList();
  }

  Future<void> _writeAll(List<Board> boards) async {
    final file = await _storageFile();
    final payload = jsonEncode(boards.map((board) => board.toJson()).toList());
    await file.writeAsString(payload, flush: true);
  }

  @override
  Future<List<Board>> listBoards() async {
    final boards = await _loadAll();
    boards.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return List<Board>.unmodifiable(boards);
  }

  @override
  Future<Board?> getBoard(String id) async {
    final boards = await _loadAll();
    for (final board in boards) {
      if (board.id == id) return board;
    }
    return null;
  }

  @override
  Future<void> saveBoard(Board board) async {
    final boards = await _loadAll();
    final index = boards.indexWhere((item) => item.id == board.id);
    final value = board.copyWith(updatedAt: DateTime.now());
    if (index >= 0) {
      boards[index] = value;
    } else {
      boards.add(value);
    }
    await _writeAll(boards);
  }

  @override
  Future<void> deleteBoard(String id) async {
    final boards = await _loadAll();
    boards.removeWhere((board) => board.id == id);
    await _writeAll(boards);
  }
}
