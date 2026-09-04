import 'package:flutter/material.dart';

import '../core/id.dart';
import '../data/course_repository.dart';
import '../domain/board.dart';
import 'effect_text.dart';
import 'widgets/board_painter.dart';

enum _EffectPreset {
  none,
  moveForward,
  moveBackward,
  moveToStart,
  skipTurn,
  rollAgain,
  warpTo,
  showMessage,
  changePoints,
}

class _SquareEditResult {
  const _SquareEditResult({
    required this.square,
    required this.outgoingSquareIds,
  });

  final BoardSquare square;
  final Set<String> outgoingSquareIds;
}

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

  bool _isSimpleLinear(Board board) {
    if (board.squares.length < 2) return true;
    if (board.connections.length != board.squares.length - 1) return false;
    for (final square in board.squares) {
      if (board.outgoingSquares(square.id).length > 1) return false;
      if (board.incomingSquares(square.id).length > 1) return false;
    }
    return board.orderedPath().length == board.squares.length;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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

    final wasLinear = _isSimpleLinear(_board);
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
        connections: wasLinear
            ? _connectionsFor(squares)
            : List<BoardConnection>.of(_board.connections),
      );
    });
    if (!wasLinear) {
      _showMessage('マスを追加しました。タップして接続先を設定してください。');
    }
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

    setState(() => _board = _board.copyWith(squares: squares));
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

    final wasLinear = _isSimpleLinear(_board);
    final squares = _board.squares
        .where((item) => item.id != square.id)
        .map(
          (item) => item.copyWith(
            effects: item.effects.where((effect) {
              if (effect.actionType != EffectActionType.warpTo) return true;
              return effect.parameters['targetSquareId'] != square.id;
            }).toList(growable: false),
          ),
        )
        .toList(growable: false);

    List<BoardConnection> connections;
    if (wasLinear) {
      connections = _connectionsFor(squares);
    } else {
      final incoming = _board.connections
          .where((item) => item.toSquareId == square.id)
          .toList(growable: false);
      final outgoing = _board.connections
          .where((item) => item.fromSquareId == square.id)
          .toList(growable: false);
      connections = _board.connections
          .where(
            (item) =>
                item.fromSquareId != square.id && item.toSquareId != square.id,
          )
          .toList();
      if (incoming.length == 1 && outgoing.length == 1) {
        final bridge = BoardConnection(
          fromSquareId: incoming.single.fromSquareId,
          toSquareId: outgoing.single.toSquareId,
        );
        final exists = connections.any(
          (item) =>
              item.fromSquareId == bridge.fromSquareId &&
              item.toSquareId == bridge.toSquareId,
        );
        if (!exists && bridge.fromSquareId != bridge.toSquareId) {
          connections.add(bridge);
        }
      }
    }

    setState(() {
      _board = _board.copyWith(squares: squares, connections: connections);
    });
  }

  _EffectPreset _presetForEffect(SquareEffect effect) {
    switch (effect.actionType) {
      case EffectActionType.moveBy:
        final rawSteps = effect.parameters['steps'];
        final steps = rawSteps is num ? rawSteps.toInt() : 0;
        return steps < 0
            ? _EffectPreset.moveBackward
            : _EffectPreset.moveForward;
      case EffectActionType.moveToStart:
        return _EffectPreset.moveToStart;
      case EffectActionType.skipTurn:
        return _EffectPreset.skipTurn;
      case EffectActionType.rollAgain:
        return _EffectPreset.rollAgain;
      case EffectActionType.warpTo:
        return _EffectPreset.warpTo;
      case EffectActionType.showMessage:
        return _EffectPreset.showMessage;
      case EffectActionType.changePoints:
        return _EffectPreset.changePoints;
    }
  }

  int _amountForEffect(SquareEffect effect) {
    if (effect.actionType == EffectActionType.changePoints) {
      final rawPoints = effect.parameters['points'];
      return rawPoints is num ? rawPoints.toInt() : 0;
    }
    final rawSteps = effect.parameters['steps'];
    if (rawSteps is num && rawSteps.toInt() != 0) {
      return rawSteps.toInt().abs();
    }
    final rawTurns = effect.parameters['turns'];
    if (rawTurns is num && rawTurns.toInt() > 0) {
      return rawTurns.toInt();
    }
    return 1;
  }

  String? _warpTargetForEffect(SquareEffect effect) {
    if (effect.actionType != EffectActionType.warpTo) return null;
    final target = effect.parameters['targetSquareId'];
    return target is String ? target : null;
  }

  SquareEffect? _effectFor({
    required _EffectPreset preset,
    required EffectTrigger trigger,
    required int amount,
    required String? warpTargetId,
    required String message,
  }) {
    final safeAmount = amount < 1 ? 1 : amount;
    switch (preset) {
      case _EffectPreset.none:
        return null;
      case _EffectPreset.moveForward:
        return SquareEffect(
          trigger: trigger,
          actionType: EffectActionType.moveBy,
          parameters: {'steps': safeAmount},
        );
      case _EffectPreset.moveBackward:
        return SquareEffect(
          trigger: trigger,
          actionType: EffectActionType.moveBy,
          parameters: {'steps': -safeAmount},
        );
      case _EffectPreset.moveToStart:
        return SquareEffect(
          trigger: trigger,
          actionType: EffectActionType.moveToStart,
        );
      case _EffectPreset.skipTurn:
        return SquareEffect(
          trigger: trigger,
          actionType: EffectActionType.skipTurn,
          parameters: {'turns': safeAmount},
        );
      case _EffectPreset.rollAgain:
        return SquareEffect(
          trigger: trigger,
          actionType: EffectActionType.rollAgain,
        );
      case _EffectPreset.warpTo:
        if (warpTargetId == null) return null;
        return SquareEffect(
          trigger: trigger,
          actionType: EffectActionType.warpTo,
          parameters: {'targetSquareId': warpTargetId},
        );
      case _EffectPreset.showMessage:
        final text = message.trim();
        if (text.isEmpty) return null;
        return SquareEffect(
          trigger: trigger,
          actionType: EffectActionType.showMessage,
          parameters: {'message': text},
        );
      case _EffectPreset.changePoints:
        return SquareEffect(
          trigger: trigger,
          actionType: EffectActionType.changePoints,
          parameters: {'points': amount},
        );
    }
  }

  String _presetLabel(_EffectPreset preset) {
    switch (preset) {
      case _EffectPreset.none:
        return '効果なし';
      case _EffectPreset.moveForward:
        return 'Nマス進む';
      case _EffectPreset.moveBackward:
        return 'Nマス戻る';
      case _EffectPreset.moveToStart:
        return 'スタートに戻る';
      case _EffectPreset.skipTurn:
        return 'N回休み';
      case _EffectPreset.rollAgain:
        return 'もう一度サイコロを振る';
      case _EffectPreset.warpTo:
        return '指定マスへワープ';
      case _EffectPreset.showMessage:
        return 'メッセージを表示';
      case _EffectPreset.changePoints:
        return 'ポイントを増減';
    }
  }

  Future<SquareEffect?> _editEffect({
    SquareEffect? initialEffect,
    required List<BoardSquare> candidates,
  }) async {
    var trigger = initialEffect?.trigger ?? EffectTrigger.onLand;
    var preset = initialEffect == null
        ? _EffectPreset.moveForward
        : _presetForEffect(initialEffect);
    if (trigger == EffectTrigger.onPass && preset != _EffectPreset.showMessage) {
      preset = _EffectPreset.showMessage;
    }

    final amountController = TextEditingController(
      text: initialEffect == null
          ? '1'
          : _amountForEffect(initialEffect).toString(),
    );
    final messageController = TextEditingController(
      text: initialEffect == null ? '' : effectMessage(initialEffect),
    );
    var warpTargetId = initialEffect == null
        ? (candidates.isEmpty ? null : candidates.first.id)
        : _warpTargetForEffect(initialEffect);
    if (warpTargetId != null &&
        !candidates.any((item) => item.id == warpTargetId)) {
      warpTargetId = candidates.isEmpty ? null : candidates.first.id;
    }

    final result = await showDialog<SquareEffect>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final needsAmount = preset == _EffectPreset.moveForward ||
                preset == _EffectPreset.moveBackward ||
                preset == _EffectPreset.skipTurn ||
                preset == _EffectPreset.changePoints;
            final needsWarpTarget = preset == _EffectPreset.warpTo;
            final needsMessage = preset == _EffectPreset.showMessage;
            final availablePresets = trigger == EffectTrigger.onPass
                ? const [_EffectPreset.showMessage]
                : _EffectPreset.values
                    .where((item) => item != _EffectPreset.none)
                    .toList(growable: false);

            String amountLabel() {
              if (preset == _EffectPreset.skipTurn) return '休む回数';
              if (preset == _EffectPreset.changePoints) return '増減ポイント';
              return 'マス数';
            }

            String amountHelper() {
              if (preset == _EffectPreset.changePoints) {
                return '増加は正数、減少は負数で入力してください';
              }
              return '1以上の整数を入力してください';
            }

            return AlertDialog(
              title: Text(initialEffect == null ? 'Actionを追加' : 'Actionを編集'),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<EffectTrigger>(
                        initialValue: trigger,
                        decoration: const InputDecoration(
                          labelText: 'Trigger',
                          border: OutlineInputBorder(),
                        ),
                        items: EffectTrigger.values
                            .map(
                              (item) => DropdownMenuItem(
                                value: item,
                                child: Text(triggerDescription(item)),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) {
                          if (value == null) return;
                          setDialogState(() {
                            trigger = value;
                            if (trigger == EffectTrigger.onPass) {
                              preset = _EffectPreset.showMessage;
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<_EffectPreset>(
                        initialValue: preset,
                        decoration: const InputDecoration(
                          labelText: 'Action',
                          border: OutlineInputBorder(),
                        ),
                        items: availablePresets
                            .map(
                              (item) => DropdownMenuItem(
                                value: item,
                                child: Text(_presetLabel(item)),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) {
                          if (value == null) return;
                          setDialogState(() {
                            preset = value;
                            if (preset == _EffectPreset.warpTo &&
                                warpTargetId == null &&
                                candidates.isNotEmpty) {
                              warpTargetId = candidates.first.id;
                            }
                          });
                        },
                      ),
                      if (needsAmount) ...[
                        const SizedBox(height: 14),
                        TextField(
                          controller: amountController,
                          keyboardType: TextInputType.numberWithOptions(
                            signed: preset == _EffectPreset.changePoints,
                          ),
                          decoration: InputDecoration(
                            labelText: amountLabel(),
                            helperText: amountHelper(),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ],
                      if (needsWarpTarget) ...[
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          initialValue: candidates.any(
                            (item) => item.id == warpTargetId,
                          )
                              ? warpTargetId
                              : null,
                          decoration: const InputDecoration(
                            labelText: 'ワープ先',
                            border: OutlineInputBorder(),
                          ),
                          items: candidates
                              .map(
                                (item) => DropdownMenuItem(
                                  value: item.id,
                                  child: Text(item.label),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: (value) {
                            setDialogState(() => warpTargetId = value);
                          },
                        ),
                      ],
                      if (needsMessage) ...[
                        const SizedBox(height: 14),
                        TextField(
                          controller: messageController,
                          minLines: 2,
                          maxLines: 5,
                          decoration: const InputDecoration(
                            labelText: '表示するメッセージ',
                            hintText: '例：近道を発見！',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                      if (trigger == EffectTrigger.onPass) ...[
                        const SizedBox(height: 10),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '通過Triggerは現在メッセージActionに対応しています。',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('キャンセル'),
                ),
                FilledButton(
                  onPressed: () {
                    final amount =
                        int.tryParse(amountController.text.trim()) ?? 1;
                    final effect = _effectFor(
                      preset: preset,
                      trigger: trigger,
                      amount: amount,
                      warpTargetId: warpTargetId,
                      message: messageController.text,
                    );
                    if (effect != null) {
                      Navigator.pop(dialogContext, effect);
                    }
                  },
                  child: const Text('適用'),
                ),
              ],
            );
          },
        );
      },
    );

    amountController.dispose();
    messageController.dispose();
    return result;
  }

  Widget _effectBlock({
    required BuildContext context,
    required SquareEffect effect,
    required int index,
    required VoidCallback? onMoveUp,
    required VoidCallback? onMoveDown,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) {
    return Card(
      key: ValueKey('effect-$index-${effect.trigger.name}-${effect.actionType.name}'),
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
        child: Row(
          children: [
            const Icon(Icons.drag_indicator, size: 20),
            const SizedBox(width: 6),
            CircleAvatar(
              radius: 13,
              child: Text('${index + 1}', style: const TextStyle(fontSize: 11)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    effectDescription(effect),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    triggerDescription(effect.trigger),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: '上へ',
              onPressed: onMoveUp,
              icon: const Icon(Icons.arrow_upward, size: 19),
            ),
            IconButton(
              tooltip: '下へ',
              onPressed: onMoveDown,
              icon: const Icon(Icons.arrow_downward, size: 19),
            ),
            IconButton(
              tooltip: '編集',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 19),
            ),
            IconButton(
              tooltip: '削除',
              onPressed: onDelete,
              icon: const Icon(Icons.close, size: 19),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editSquare(BoardSquare square) async {
    final labelController = TextEditingController(text: square.label);
    final effects = List<SquareEffect>.of(square.effects);
    final selectedOutgoingIds = _board
        .outgoingSquares(square.id)
        .map((item) => item.id)
        .toSet();
    final candidates = _board.squares
        .where((item) => item.id != square.id)
        .toList(growable: false);

    final updated = await showModalBottomSheet<_SquareEditResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                4,
                20,
                20 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'マスの設定',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: labelController,
                      decoration: const InputDecoration(
                        labelText: '名前',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (square.kind == SquareKind.normal) ...[
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.account_tree_outlined,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'イベントブロック',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                      Text(
                                        'TriggerとActionを設定し、上から順番に保存します。',
                                        style:
                                            Theme.of(context).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                                Chip(label: Text('${effects.length}個')),
                              ],
                            ),
                            if (effects.isEmpty) ...[
                              const SizedBox(height: 10),
                              const Text(
                                'イベントはありません。下のボタンからActionを追加できます。',
                              ),
                            ] else
                              for (var index = 0;
                                  index < effects.length;
                                  index++)
                                _effectBlock(
                                  context: context,
                                  effect: effects[index],
                                  index: index,
                                  onMoveUp: index == 0
                                      ? null
                                      : () {
                                          setModalState(() {
                                            final effect = effects.removeAt(index);
                                            effects.insert(index - 1, effect);
                                          });
                                        },
                                  onMoveDown: index == effects.length - 1
                                      ? null
                                      : () {
                                          setModalState(() {
                                            final effect = effects.removeAt(index);
                                            effects.insert(index + 1, effect);
                                          });
                                        },
                                  onEdit: () async {
                                    final edited = await _editEffect(
                                      initialEffect: effects[index],
                                      candidates: candidates,
                                    );
                                    if (edited == null || !context.mounted) return;
                                    setModalState(() => effects[index] = edited);
                                  },
                                  onDelete: () {
                                    setModalState(() => effects.removeAt(index));
                                  },
                                ),
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              onPressed: () async {
                                final added = await _editEffect(
                                  candidates: candidates,
                                );
                                if (added == null || !context.mounted) return;
                                setModalState(() => effects.add(added));
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('Actionを追加'),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (square.kind != SquareKind.goal) ...[
                      const SizedBox(height: 22),
                      Text(
                        'このマスから進める先',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '2つ以上選ぶと分岐になります。',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      if (candidates.isEmpty)
                        const Text('接続できるマスがありません。')
                      else
                        ...candidates.map(
                          (candidate) => CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: Text(candidate.label),
                            subtitle: candidate.kind == SquareKind.goal
                                ? const Text('ゴール')
                                : null,
                            value: selectedOutgoingIds.contains(candidate.id),
                            onChanged: (checked) {
                              setModalState(() {
                                if (checked == true) {
                                  selectedOutgoingIds.add(candidate.id);
                                } else {
                                  selectedOutgoingIds.remove(candidate.id);
                                }
                              });
                            },
                          ),
                        ),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          child: const Text('キャンセル'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () {
                            final label = labelController.text.trim();
                            Navigator.pop(
                              sheetContext,
                              _SquareEditResult(
                                square: square.copyWith(
                                  label: label.isEmpty ? square.label : label,
                                  effects: square.kind == SquareKind.normal
                                      ? List<SquareEffect>.unmodifiable(effects)
                                      : square.effects,
                                ),
                                outgoingSquareIds: square.kind == SquareKind.goal
                                    ? const <String>{}
                                    : Set<String>.of(selectedOutgoingIds),
                              ),
                            );
                          },
                          child: const Text('適用'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    labelController.dispose();
    if (updated == null || !mounted) return;

    final connections = _board.connections
        .where((item) => item.fromSquareId != square.id)
        .toList();
    for (final targetId in updated.outgoingSquareIds) {
      connections.add(
        BoardConnection(fromSquareId: square.id, toSquareId: targetId),
      );
    }

    setState(() {
      _board = _board.copyWith(
        squares: _board.squares
            .map((item) => item.id == updated.square.id ? updated.square : item)
            .toList(growable: false),
        connections: connections,
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
      setState(() => _board = board);
      _showMessage(
        board.isPlayable
            ? '保存しました。'
            : '保存しました。スタートからゴールまでの接続を確認してください。',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Color _colorFor(BoardSquare square) {
    if (square.kind == SquareKind.start) return Colors.green.shade300;
    if (square.kind == SquareKind.goal) return Colors.amber.shade300;
    if (square.effects.isEmpty) return Colors.blue.shade200;
    if (square.effects.length > 1) return Colors.deepPurple.shade200;

    final effect = square.effects.first;
    switch (effect.actionType) {
      case EffectActionType.moveBy:
        final rawSteps = effect.parameters['steps'];
        final steps = rawSteps is num ? rawSteps.toInt() : 0;
        return steps < 0 ? Colors.orange.shade200 : Colors.teal.shade200;
      case EffectActionType.moveToStart:
        return Colors.red.shade200;
      case EffectActionType.skipTurn:
        return Colors.purple.shade200;
      case EffectActionType.rollAgain:
        return Colors.lime.shade300;
      case EffectActionType.warpTo:
        return Colors.indigo.shade200;
      case EffectActionType.showMessage:
        return Colors.cyan.shade200;
      case EffectActionType.changePoints:
        return Colors.yellow.shade300;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasBranch = _board.squares.any(
      (square) => _board.outgoingSquares(square.id).length > 1,
    );

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
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'コース名',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Chip(
                  avatar: Icon(
                    hasBranch ? Icons.call_split : Icons.route,
                    size: 18,
                  ),
                  label: Text(hasBranch ? '分岐あり' : '一本道'),
                ),
              ],
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
                            onTap: () => _editSquare(square),
                            onPanUpdate: (details) =>
                                _moveSquare(square, details.delta),
                            onLongPress: () => _removeSquare(square),
                            child: Material(
                              elevation: 4,
                              color: _colorFor(square),
                              borderRadius: BorderRadius.circular(18),
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(5),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        square.label,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                      if (square.effects.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          squareEffectSummary(square),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(fontSize: 8),
                                        ),
                                      ],
                                      if (square.effects.length > 1) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          '効果 ${square.effects.length}個',
                                          style: const TextStyle(
                                            fontSize: 8,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                      if (_board.outgoingSquares(square.id).length >
                                          1) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          '分岐 ${_board.outgoingSquares(square.id).length}',
                                          style: const TextStyle(
                                            fontSize: 8,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ],
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
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'マスをタップ: 設定・接続 / ドラッグ: 移動 / 長押し: 削除',
                      style: TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: () => _addSquare(SquareKind.start),
                          icon: const Icon(Icons.flag_outlined),
                          label: const Text('スタート'),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: () => _addSquare(SquareKind.normal),
                          icon: const Icon(Icons.add_box_outlined),
                          label: const Text('通常マス'),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: () => _addSquare(SquareKind.goal),
                          icon: const Icon(Icons.sports_score_outlined),
                          label: const Text('ゴール'),
                        ),
                      ],
                    ),
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
