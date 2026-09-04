import 'package:flutter/material.dart';

import '../core/id.dart';
import '../data/course_repository.dart';
import '../domain/board.dart';
import '../domain/board_duplicate.dart';
import 'course_editor_screen.dart';
import 'item_definition_editor.dart';
import 'player_setup_screen.dart';

enum _CourseSort {
  updatedNewest,
  updatedOldest,
  nameAscending,
  nameDescending,
}

class CourseListScreen extends StatefulWidget {
  const CourseListScreen({required this.repository, super.key});

  final CourseRepository repository;

  @override
  State<CourseListScreen> createState() => _CourseListScreenState();
}

class _CourseListScreenState extends State<CourseListScreen> {
  late Future<List<Board>> _boardsFuture;
  late final TextEditingController _searchController;
  _CourseSort _sort = _CourseSort.updatedNewest;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _reload();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _reload() {
    _boardsFuture = widget.repository.listBoards();
  }

  Future<void> _refresh() async {
    setState(_reload);
    await _boardsFuture;
  }

  List<Board> _visibleBoards(List<Board> boards) {
    final query = _searchQuery.trim().toLowerCase();
    final visible = boards
        .where((board) => query.isEmpty || board.name.toLowerCase().contains(query))
        .toList();

    switch (_sort) {
      case _CourseSort.updatedNewest:
        visible.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      case _CourseSort.updatedOldest:
        visible.sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
      case _CourseSort.nameAscending:
        visible.sort((a, b) => a.name.compareTo(b.name));
      case _CourseSort.nameDescending:
        visible.sort((a, b) => b.name.compareTo(a.name));
    }
    return visible;
  }

  String _sortLabel(_CourseSort sort) {
    return switch (sort) {
      _CourseSort.updatedNewest => '更新が新しい順',
      _CourseSort.updatedOldest => '更新が古い順',
      _CourseSort.nameAscending => '名前 A→Z',
      _CourseSort.nameDescending => '名前 Z→A',
    };
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

  Future<void> _duplicateBoard(Board board) async {
    final duplicated = duplicateBoard(
      board,
      newBoardId: createId('board'),
      newName: '${board.name} のコピー',
      updatedAt: DateTime.now(),
    );
    await widget.repository.saveBoard(duplicated);
    if (!mounted) return;
    setState(_reload);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('「${duplicated.name}」を作成しました。')),
    );
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

          final visibleBoards = _visibleBoards(boards);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          labelText: 'コースを検索',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchQuery.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: '検索をクリア',
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                  icon: const Icon(Icons.clear),
                                ),
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (value) => setState(() => _searchQuery = value),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 180,
                      child: DropdownButtonFormField<_CourseSort>(
                        initialValue: _sort,
                        decoration: const InputDecoration(
                          labelText: '並び順',
                          border: OutlineInputBorder(),
                        ),
                        items: _CourseSort.values
                            .map(
                              (sort) => DropdownMenuItem(
                                value: sort,
                                child: Text(_sortLabel(sort)),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) {
                          if (value != null) setState(() => _sort = value);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: visibleBoards.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.search_off, size: 48),
                            const SizedBox(height: 10),
                            Text('「${_searchQuery.trim()}」に一致するコースはありません'),
                            const SizedBox(height: 10),
                            TextButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                              child: const Text('検索をクリア'),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _refresh,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                          itemCount: visibleBoards.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final board = visibleBoards[index];
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
                                        if (value == 'duplicate') {
                                          _duplicateBoard(board);
                                        }
                                        if (value == 'items') {
                                          _editItemDefinitions(board);
                                        }
                                        if (value == 'delete') _deleteBoard(board);
                                      },
                                      itemBuilder: (_) => const [
                                        PopupMenuItem(
                                          value: 'edit',
                                          child: Text('編集'),
                                        ),
                                        PopupMenuItem(
                                          value: 'duplicate',
                                          child: Text('複製'),
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
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
