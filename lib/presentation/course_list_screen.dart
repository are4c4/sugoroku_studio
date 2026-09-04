import 'package:flutter/material.dart';

import '../core/id.dart';
import '../data/course_repository.dart';
import '../domain/board.dart';
import 'course_editor_screen.dart';
import 'item_definition_editor.dart';
import 'player_setup_screen.dart';

class CourseListScreen extends StatefulWidget {
  const CourseListScreen({required this.repository, super.key});

  final CourseRepository repository;

  @override
  State<CourseListScreen> createState() => _CourseListScreenState();
}

class _CourseListScreenState extends State<CourseListScreen> {
  late Future<List<Board>> _boardsFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _boardsFuture = widget.repository.listBoards();
  }

  Future<void> _refresh() async {
    setState(_reload);
    await _boardsFuture;
  }

  Board _createStarterBoard() {
    final boardId = createId('board');
    final squares = <BoardSquare>[
      BoardSquare(
        id: '$boardId-start',
        label: 'スタート',
        position: const BoardPosition(x: 70, y: 220),
        kind: SquareKind.start,
      ),
      BoardSquare(
        id: '$boardId-normal-1',
        label: 'マス1',
        position: const BoardPosition(x: 190, y: 140),
        kind: SquareKind.normal,
      ),
      BoardSquare(
        id: '$boardId-normal-2',
        label: 'マス2',
        position: const BoardPosition(x: 310, y: 220),
        kind: SquareKind.normal,
      ),
      BoardSquare(
        id: '$boardId-normal-3',
        label: 'マス3',
        position: const BoardPosition(x: 430, y: 140),
        kind: SquareKind.normal,
      ),
      BoardSquare(
        id: '$boardId-goal',
        label: 'ゴール',
        position: const BoardPosition(x: 550, y: 220),
        kind: SquareKind.goal,
      ),
    ];
    final connections = <BoardConnection>[
      for (var index = 0; index < squares.length - 1; index++)
        BoardConnection(
          fromSquareId: squares[index].id,
          toSquareId: squares[index + 1].id,
        ),
    ];

    return Board(
      id: boardId,
      name: '新しいコース',
      squares: squares,
      connections: connections,
      updatedAt: DateTime.now(),
    );
  }

  Future<void> _createBoard() async {
    final board = _createStarterBoard();
    await widget.repository.saveBoard(board);
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CourseEditorScreen(
          repository: widget.repository,
          initialBoard: board,
        ),
      ),
    );
    if (!mounted) return;
    setState(_reload);
  }

  Future<void> _editBoard(Board board) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CourseEditorScreen(
          repository: widget.repository,
          initialBoard: board,
        ),
      ),
    );
    if (!mounted) return;
    setState(_reload);
  }

  Future<void> _editItemDefinitions(Board board) async {
    final definitions = await showItemDefinitionsEditor(
      context,
      initialDefinitions: board.itemDefinitions,
    );
    if (definitions == null || !mounted) return;

    await widget.repository.saveBoard(
      board.copyWith(
        itemDefinitions: definitions,
        updatedAt: DateTime.now(),
      ),
    );
    if (!mounted) return;
    setState(_reload);
  }

  Future<void> _deleteBoard(Board board) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('コースを削除しますか？'),
        content: Text('「${board.name}」は元に戻せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await widget.repository.deleteBoard(board.id);
    if (!mounted) return;
    setState(_reload);
  }

  void _playBoard(Board board) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => PlayerSetupScreen(board: board)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sugoroku Studio')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createBoard,
        icon: const Icon(Icons.add),
        label: const Text('新規コース'),
      ),
      body: FutureBuilder<List<Board>>(
        future: _boardsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48),
                    const SizedBox(height: 12),
                    Text('コースを読み込めませんでした。\n${snapshot.error}'),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _refresh,
                      child: const Text('再読み込み'),
                    ),
                  ],
                ),
              ),
            );
          }

          final boards = snapshot.data ?? const <Board>[];
          if (boards.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.route_outlined,
                    size: 72,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'まだコースがありません',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text('「新規コース」から最初のすごろくを作りましょう。'),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              itemCount: boards.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final board = boards[index];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text('${board.squares.length}'),
                    ),
                    title: Text(board.name),
                    subtitle: Text(
                      '${board.isPlayable ? '${board.squares.length}マス・プレイ可能' : '${board.squares.length}マス・経路を確認してください'} · 使用アイテム${board.itemDefinitions.length}種',
                    ),
                    onTap: () => _editBoard(board),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'プレイ',
                          onPressed: board.isPlayable
                              ? () => _playBoard(board)
                              : null,
                          icon: const Icon(Icons.play_arrow),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') _editBoard(board);
                            if (value == 'items') _editItemDefinitions(board);
                            if (value == 'delete') _deleteBoard(board);
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'edit',
                              child: Text('編集'),
                            ),
                            PopupMenuItem(
                              value: 'items',
                              child: Text('使用可能アイテム'),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('削除'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
