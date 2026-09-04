import 'package:flutter/material.dart';

import '../core/id.dart';
import '../data/course_repository.dart';
import '../domain/board.dart';
import 'widgets/board_painter.dart';

class CourseEditorScreen extends StatefulWidget {
  const CourseEditorScreen({
    required this.repository,
    required this.initialBoard,
    super.key,
  });

  final CourseRepository repository;
  final Board initialBoard;

  @override
  State<CourseEditorScreen> createState() => _CourseEditorScreenState();
}

class _CourseEditorScreenState extends State<CourseEditorScreen> {
  static const Size _canvasSize = Size(900, 600);
  static const double _squareSize = BoardConnectionPainter.squareSize;

  late Board _board;
  late TextEditingController _nameController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _board = widget.initialBoard;
    _nameController = TextEditingController(text: _board.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  List<BoardConnection> _connectionsFor(List<BoardSquare> squares) {
    if (squares.length < 2) return const <BoardConnection>[];
    return [
      for (var index = 0; index < squares.length - 1; index++)
        BoardConnection(
          fromSquareId: squares[index].id,
          toSquareId: squares[index + 1].id,
        ),
    ];
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _addSquare(SquareKind kind) {
    if (kind == SquareKind.start &&
        _board.squares.any((square) => square.kind == SquareKind.start)) {
      _showMessage('スタートは1つまでです。');
      return;
    }
    if (kind == SquareKind.goal &&
        _board.squares.any((square) => square.kind == SquareKind.goal)) {
      _showMessage('ゴールは1つまでです。');
      return;
    }

    final normalCount = _board.squares
        .where((square) => square.kind == SquareKind.normal)
        .length;
    final square = BoardSquare(
      id: createId('square'),
      label: switch (kind) {
        SquareKind.start => 'スタート',
        SquareKind.normal => 'マス${normalCount + 1}',
        SquareKind.goal => 'ゴール',
      },
      position: BoardPosition(
        x: 90 + (_board.squares.length % 6) * 110,
        y: 330 + (_board.squares.length % 2) * 90,
      ),
      kind: kind,
    );

    final squares = List<BoardSquare>.of(_board.squares);
    if (kind == SquareKind.start) {
      squares.insert(0, square);
    } else if (kind == SquareKind.goal) {
      squares.add(square);
    } else {
      final goalIndex =
          squares.indexWhere((item) => item.kind == SquareKind.goal);
      if (goalIndex >= 0) {
        squares.insert(goalIndex, square);
      } else {
        squares.add(square);
      }
    }

    setState(() {
      _board = _board.copyWith(
        squares: squares,
        connections: _connectionsFor(squares),
      );
    });
  }

  void _moveSquare(BoardSquare square, Offset delta) {
    final nextX = (square.position.x + delta.dx)
        .clamp(0, _canvasSize.width - _squareSize)
        .toDouble();
    final nextY = (square.position.y + delta.dy)
        .clamp(0, _canvasSize.height - _squareSize)
        .toDouble();
    final squares = _board.squares
        .map(
          (item) => item.id == square.id
              ? item.copyWith(position: BoardPosition(x: nextX, y: nextY))
              : item,
        )
        .toList(growable: false);

    setState(() {
      _board = _board.copyWith(squares: squares);
    });
  }

  Future<void> _removeSquare(BoardSquare square) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('マスを削除しますか？'),
        content: Text('「${square.label}」を削除します。'),
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
    if (confirmed != true || !mounted) return;

    final squares = _board.squares
        .where((item) => item.id != square.id)
        .toList(growable: false);
    setState(() {
      _board = _board.copyWith(
        squares: squares,
        connections: _connectionsFor(squares),
      );
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final name = _nameController.text.trim();
    final board = _board.copyWith(
      name: name.isEmpty ? '名称未設定' : name,
      updatedAt: DateTime.now(),
    );

    try {
      await widget.repository.saveBoard(board);
      if (!mounted) return;
      _board = board;
      _showMessage('保存しました。');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Color _colorFor(SquareKind kind) {
    return switch (kind) {
      SquareKind.start => Colors.green.shade300,
      SquareKind.normal => Colors.blue.shade200,
      SquareKind.goal => Colors.amber.shade300,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('コース編集'),
        actions: [
          IconButton(
            tooltip: '保存',
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'コース名',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLowest,
              ),
              child: InteractiveViewer(
                constrained: false,
                minScale: 0.5,
                maxScale: 2.5,
                boundaryMargin: const EdgeInsets.all(160),
                child: SizedBox(
                  width: _canvasSize.width,
                  height: _canvasSize.height,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: BoardConnectionPainter(board: _board),
                        ),
                      ),
                      for (final square in _board.squares)
                        Positioned(
                          left: square.position.x,
                          top: square.position.y,
                          width: _squareSize,
                          height: _squareSize,
                          child: GestureDetector(
                            onPanUpdate: (details) =>
                                _moveSquare(square, details.delta),
                            onLongPress: () => _removeSquare(square),
                            child: Material(
                              elevation: 4,
                              color: _colorFor(square.kind),
                              borderRadius: BorderRadius.circular(18),
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(6),
                                  child: Text(
                                    square.label,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Material(
            elevation: 8,
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: () => _addSquare(SquareKind.start),
                      icon: const Icon(Icons.flag_outlined),
                      label: const Text('スタート'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonalIcon(
                      onPressed: () => _addSquare(SquareKind.normal),
                      icon: const Icon(Icons.add_box_outlined),
                      label: const Text('通常マス'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonalIcon(
                      onPressed: () => _addSquare(SquareKind.goal),
                      icon: const Icon(Icons.sports_score_outlined),
                      label: const Text('ゴール'),
                    ),
                    const SizedBox(width: 16),
                    const Text('ドラッグ: 移動 / 長押し: 削除'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
