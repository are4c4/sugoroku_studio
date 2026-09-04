import 'package:flutter/material.dart';

import '../core/id.dart';
import '../data/course_repository.dart';
import '../domain/board.dart';
import 'condition_group_editor.dart';
import 'effect_text.dart';
import 'random_event_editor.dart';
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
  grantItem,
  consumeItem,
  randomEvent,
}

enum _ConditionPreset {
  none,
  pointsAtLeast,
  pointsAtMost,
  pointsBetween,
  hasItem,
  notHasItem,
  itemQuantityAtLeast,
  allOf,
  anyOf,
  not,
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
  late final TextEditingController _nameController;
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
      final goalIndex = squares.indexWhere((item) => item.kind == SquareKind.goal);
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
        return steps < 0 ? _EffectPreset.moveBackward : _EffectPreset.moveForward;
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
      case EffectActionType.grantItem:
        return _EffectPreset.grantItem;
      case EffectActionType.consumeItem:
        return _EffectPreset.consumeItem;
      case EffectActionType.randomEvent:
        return _EffectPreset.randomEvent;
    }
  }

  _ConditionPreset _conditionPresetFor(EffectCondition? condition) {
    if (condition == null) return _ConditionPreset.none;
    return switch (condition.type) {
      EffectConditionType.pointsAtLeast => _ConditionPreset.pointsAtLeast,
      EffectConditionType.pointsAtMost => _ConditionPreset.pointsAtMost,
      EffectConditionType.pointsBetween => _ConditionPreset.pointsBetween,
      EffectConditionType.hasItem => _ConditionPreset.hasItem,
      EffectConditionType.notHasItem => _ConditionPreset.notHasItem,
      EffectConditionType.itemQuantityAtLeast =>
        _ConditionPreset.itemQuantityAtLeast,
      EffectConditionType.allOf => _ConditionPreset.allOf,
      EffectConditionType.anyOf => _ConditionPreset.anyOf,
      EffectConditionType.not => _ConditionPreset.not,
    };
  }

  int _conditionPointsFor(EffectCondition? condition) {
    if (condition == null) return 0;
    if (condition.type == EffectConditionType.pointsBetween) {
      final raw = condition.parameters['minPoints'];
      return raw is num ? raw.toInt() : 0;
    }
    final raw = condition.parameters['points'];
    return raw is num ? raw.toInt() : 0;
  }

  int _conditionMaxPointsFor(EffectCondition? condition) {
    if (condition?.type != EffectConditionType.pointsBetween) return 10;
    final raw = condition!.parameters['maxPoints'];
    return raw is num ? raw.toInt() : 10;
  }

  String _conditionItemNameFor(EffectCondition? condition) {
    if (condition == null) return '';
    final raw = condition.parameters['itemName'];
    return raw is String ? raw.trim() : '';
  }

  int _conditionQuantityFor(EffectCondition? condition) {
    if (condition == null) return 1;
    final raw = condition.parameters['quantity'];
    final quantity = raw is num ? raw.toInt() : 1;
    return quantity < 1 ? 1 : quantity;
  }

  EffectCondition? _conditionFor(
    _ConditionPreset preset, {
    required int points,
    required int maxPoints,
    required String itemName,
    required int quantity,
    required List<EffectCondition> groupConditions,
  }) {
    final safeQuantity = quantity < 1 ? 1 : quantity;
    switch (preset) {
      case _ConditionPreset.none:
        return null;
      case _ConditionPreset.pointsAtLeast:
        return EffectCondition(
          type: EffectConditionType.pointsAtLeast,
          parameters: {'points': points},
        );
      case _ConditionPreset.pointsAtMost:
        return EffectCondition(
          type: EffectConditionType.pointsAtMost,
          parameters: {'points': points},
        );
      case _ConditionPreset.pointsBetween:
        final minPoints = points <= maxPoints ? points : maxPoints;
        final max = points <= maxPoints ? maxPoints : points;
        return EffectCondition(
          type: EffectConditionType.pointsBetween,
          parameters: {'minPoints': minPoints, 'maxPoints': max},
        );
      case _ConditionPreset.hasItem:
        final name = itemName.trim();
        if (name.isEmpty) return null;
        return EffectCondition(
          type: EffectConditionType.hasItem,
          parameters: {'itemName': name},
        );
      case _ConditionPreset.notHasItem:
        final name = itemName.trim();
        if (name.isEmpty) return null;
        return EffectCondition(
          type: EffectConditionType.notHasItem,
          parameters: {'itemName': name},
        );
      case _ConditionPreset.itemQuantityAtLeast:
        final name = itemName.trim();
        if (name.isEmpty) return null;
        return EffectCondition(
          type: EffectConditionType.itemQuantityAtLeast,
          parameters: {'itemName': name, 'quantity': safeQuantity},
        );
      case _ConditionPreset.not:
        if (groupConditions.length != 1) return null;
        return EffectCondition(
          type: EffectConditionType.not,
          parameters: {
            'conditions': groupConditions.map((item) => item.toJson()).toList(),
          },
        );
      case _ConditionPreset.allOf:
      case _ConditionPreset.anyOf:
        if (groupConditions.length < 2) return null;
        final type = preset == _ConditionPreset.allOf
            ? EffectConditionType.allOf
            : EffectConditionType.anyOf;
        return EffectCondition(
          type: type,
          parameters: {
            'conditions': groupConditions.map((item) => item.toJson()).toList(),
          },
        );
    }
  }

  String _conditionPresetLabel(_ConditionPreset preset) {
    return switch (preset) {
      _ConditionPreset.none => '条件なし',
      _ConditionPreset.pointsAtLeast => 'ポイントがN以上',
      _ConditionPreset.pointsAtMost => 'ポイントがN以下',
      _ConditionPreset.pointsBetween => 'ポイントがN〜Mの範囲',
      _ConditionPreset.hasItem => '指定アイテムを持っている',
      _ConditionPreset.notHasItem => '指定アイテムを持っていない',
      _ConditionPreset.itemQuantityAtLeast =>
        '指定アイテムをN個以上持っている',
      _ConditionPreset.allOf => 'すべて満たす（AND）',
      _ConditionPreset.anyOf => 'いずれか満たす（OR）',
      _ConditionPreset.not => '満たさない（NOT）',
    };
  }

  int _amountForEffect(SquareEffect effect) {
    if (effect.actionType == EffectActionType.changePoints) {
      final raw = effect.parameters['points'];
      return raw is num ? raw.toInt() : 0;
    }
    if (effect.actionType == EffectActionType.grantItem ||
        effect.actionType == EffectActionType.consumeItem) {
      return effectItemQuantity(effect);
    }
    final rawSteps = effect.parameters['steps'];
    if (rawSteps is num && rawSteps.toInt() != 0) {
      return rawSteps.toInt().abs();
    }
    final rawTurns = effect.parameters['turns'];
    if (rawTurns is num && rawTurns.toInt() > 0) return rawTurns.toInt();
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
    required EffectCondition? condition,
    required int amount,
    required String? warpTargetId,
    required String message,
    required String itemName,
    required List<RandomEventOption> randomOptions,
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
          condition: condition,
        );
      case _EffectPreset.moveBackward:
        return SquareEffect(
          trigger: trigger,
          actionType: EffectActionType.moveBy,
          parameters: {'steps': -safeAmount},
          condition: condition,
        );
      case _EffectPreset.moveToStart:
        return SquareEffect(
          trigger: trigger,
          actionType: EffectActionType.moveToStart,
          condition: condition,
        );
      case _EffectPreset.skipTurn:
        return SquareEffect(
          trigger: trigger,
          actionType: EffectActionType.skipTurn,
          parameters: {'turns': safeAmount},
          condition: condition,
        );
      case _EffectPreset.rollAgain:
        return SquareEffect(
          trigger: trigger,
          actionType: EffectActionType.rollAgain,
          condition: condition,
        );
      case _EffectPreset.warpTo:
        if (warpTargetId == null) return null;
        return SquareEffect(
          trigger: trigger,
          actionType: EffectActionType.warpTo,
          parameters: {'targetSquareId': warpTargetId},
          condition: condition,
        );
      case _EffectPreset.showMessage:
        final text = message.trim();
        if (text.isEmpty) return null;
        return SquareEffect(
          trigger: trigger,
          actionType: EffectActionType.showMessage,
          parameters: {'message': text},
          condition: condition,
        );
      case _EffectPreset.changePoints:
        return SquareEffect(
          trigger: trigger,
          actionType: EffectActionType.changePoints,
          parameters: {'points': amount},
          condition: condition,
        );
      case _EffectPreset.grantItem:
        final name = itemName.trim();
        if (name.isEmpty) return null;
        return SquareEffect(
          trigger: trigger,
          actionType: EffectActionType.grantItem,
          parameters: {'itemName': name, 'quantity': safeAmount},
          condition: condition,
        );
      case _EffectPreset.consumeItem:
        final name = itemName.trim();
        if (name.isEmpty) return null;
        return SquareEffect(
          trigger: trigger,
          actionType: EffectActionType.consumeItem,
          parameters: {'itemName': name, 'quantity': safeAmount},
          condition: condition,
        );
      case _EffectPreset.randomEvent:
        if (randomOptions.length < 2) return null;
        return SquareEffect(
          trigger: trigger,
          actionType: EffectActionType.randomEvent,
          parameters: {
            'options': randomOptions.map((option) => option.toJson()).toList(),
          },
          condition: condition,
        );
    }
  }

  String _presetLabel(_EffectPreset preset) {
    return switch (preset) {
      _EffectPreset.none => '効果なし',
      _EffectPreset.moveForward => 'Nマス進む',
      _EffectPreset.moveBackward => 'Nマス戻る',
      _EffectPreset.moveToStart => 'スタートに戻る',
      _EffectPreset.skipTurn => 'N回休み',
      _EffectPreset.rollAgain => 'もう一度サイコロを振る',
      _EffectPreset.warpTo => '指定マスへワープ',
      _EffectPreset.showMessage => 'メッセージを表示',
      _EffectPreset.changePoints => 'ポイントを増減',
      _EffectPreset.grantItem => 'アイテムを付与',
      _EffectPreset.consumeItem => 'アイテムを消費',
      _EffectPreset.randomEvent => 'ランダムイベント',
    };
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
    var conditionPreset = _conditionPresetFor(initialEffect?.condition);
    var groupConditions = List<EffectCondition>.of(
      initialEffect?.condition?.childConditions ?? const <EffectCondition>[],
    );
    var randomOptions = List<RandomEventOption>.of(
      initialEffect?.randomEventOptions ?? const <RandomEventOption>[],
    );

    final amountController = TextEditingController(
      text: initialEffect == null ? '1' : _amountForEffect(initialEffect).toString(),
    );
    final messageController = TextEditingController(
      text: initialEffect == null ? '' : effectMessage(initialEffect),
    );
    final itemNameController = TextEditingController(
      text: initialEffect == null ? '' : effectItemName(initialEffect),
    );
    final conditionPointsController = TextEditingController(
      text: _conditionPointsFor(initialEffect?.condition).toString(),
    );
    final conditionMaxPointsController = TextEditingController(
      text: _conditionMaxPointsFor(initialEffect?.condition).toString(),
    );
    final conditionItemNameController = TextEditingController(
      text: _conditionItemNameFor(initialEffect?.condition),
    );
    final conditionQuantityController = TextEditingController(
      text: _conditionQuantityFor(initialEffect?.condition).toString(),
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
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final needsAmount = preset == _EffectPreset.moveForward ||
              preset == _EffectPreset.moveBackward ||
              preset == _EffectPreset.skipTurn ||
              preset == _EffectPreset.changePoints ||
              preset == _EffectPreset.grantItem ||
              preset == _EffectPreset.consumeItem;
          final needsWarpTarget = preset == _EffectPreset.warpTo;
          final needsMessage = preset == _EffectPreset.showMessage;
          final needsItemName = preset == _EffectPreset.grantItem ||
              preset == _EffectPreset.consumeItem;
          final needsRandomOptions = preset == _EffectPreset.randomEvent;
          final needsConditionGroup = conditionPreset == _ConditionPreset.allOf ||
              conditionPreset == _ConditionPreset.anyOf ||
              conditionPreset == _ConditionPreset.not;
          final needsConditionPoints = !needsConditionGroup &&
              (conditionPreset == _ConditionPreset.pointsAtLeast ||
                  conditionPreset == _ConditionPreset.pointsAtMost ||
                  conditionPreset == _ConditionPreset.pointsBetween);
          final needsConditionMaxPoints =
              conditionPreset == _ConditionPreset.pointsBetween;
          final needsConditionItemName = !needsConditionGroup &&
              (conditionPreset == _ConditionPreset.hasItem ||
                  conditionPreset == _ConditionPreset.notHasItem ||
                  conditionPreset == _ConditionPreset.itemQuantityAtLeast);
          final needsConditionQuantity =
              conditionPreset == _ConditionPreset.itemQuantityAtLeast;
          final availablePresets = trigger == EffectTrigger.onPass
              ? const [_EffectPreset.showMessage]
              : _EffectPreset.values
                  .where((item) => item != _EffectPreset.none)
                  .toList(growable: false);

          String amountLabel() {
            if (preset == _EffectPreset.skipTurn) return '休む回数';
            if (preset == _EffectPreset.changePoints) return '増減ポイント';
            if (preset == _EffectPreset.grantItem ||
                preset == _EffectPreset.consumeItem) {
              return '個数';
            }
            return 'マス数';
          }

          EffectConditionType selectedGroupType() {
            return switch (conditionPreset) {
              _ConditionPreset.allOf => EffectConditionType.allOf,
              _ConditionPreset.anyOf => EffectConditionType.anyOf,
              _ConditionPreset.not => EffectConditionType.not,
              _ => EffectConditionType.allOf,
            };
          }

          bool invalidGroupCount() {
            if (!needsConditionGroup) return false;
            if (conditionPreset == _ConditionPreset.not) {
              return groupConditions.length != 1;
            }
            return groupConditions.length < 2;
          }

          return AlertDialog(
            title: Text(initialEffect == null ? 'Actionを追加' : 'Actionを編集'),
            content: SizedBox(
              width: 460,
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
                    DropdownButtonFormField<_ConditionPreset>(
                      initialValue: conditionPreset,
                      decoration: const InputDecoration(
                        labelText: 'Condition',
                        border: OutlineInputBorder(),
                      ),
                      items: _ConditionPreset.values
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(_conditionPresetLabel(item)),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => conditionPreset = value);
                        }
                      },
                    ),
                    if (needsConditionGroup) ...[
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final edited = await showConditionGroupEditor(
                            context,
                            groupType: selectedGroupType(),
                            initialConditions: groupConditions,
                          );
                          if (edited != null && context.mounted) {
                            setDialogState(
                              () => groupConditions = List<EffectCondition>.of(edited),
                            );
                          }
                        },
                        icon: const Icon(Icons.account_tree_outlined),
                        label: Text('子条件を編集（${groupConditions.length}個）'),
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          invalidGroupCount()
                              ? conditionPreset == _ConditionPreset.not
                                  ? 'NOTには子条件を1つ設定してください。'
                                  : '2つ以上の子条件を設定してください。'
                              : conditionDescription(
                                  EffectCondition(
                                    type: selectedGroupType(),
                                    parameters: {
                                      'conditions': groupConditions
                                          .map((item) => item.toJson())
                                          .toList(),
                                    },
                                  ),
                                ),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                    if (needsConditionPoints) ...[
                      const SizedBox(height: 14),
                      TextField(
                        controller: conditionPointsController,
                        keyboardType:
                            const TextInputType.numberWithOptions(signed: true),
                        decoration: InputDecoration(
                          labelText: needsConditionMaxPoints
                              ? '条件の最小ポイント'
                              : '条件のポイント値',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ],
                    if (needsConditionMaxPoints) ...[
                      const SizedBox(height: 14),
                      TextField(
                        controller: conditionMaxPointsController,
                        keyboardType:
                            const TextInputType.numberWithOptions(signed: true),
                        decoration: const InputDecoration(
                          labelText: '条件の最大ポイント',
                          helperText: '逆順でも小さい方を下限として保存します',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                    if (needsConditionItemName) ...[
                      const SizedBox(height: 14),
                      TextField(
                        controller: conditionItemNameController,
                        decoration: const InputDecoration(
                          labelText: '条件のアイテム名',
                          hintText: '例：金の鍵',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                    if (needsConditionQuantity) ...[
                      const SizedBox(height: 14),
                      TextField(
                        controller: conditionQuantityController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '必要な個数',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
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
                    if (needsItemName) ...[
                      const SizedBox(height: 14),
                      TextField(
                        controller: itemNameController,
                        decoration: InputDecoration(
                          labelText: preset == _EffectPreset.consumeItem
                              ? '消費するアイテム名'
                              : 'アイテム名',
                          hintText: '例：金の鍵',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ],
                    if (needsAmount) ...[
                      const SizedBox(height: 14),
                      TextField(
                        controller: amountController,
                        keyboardType: TextInputType.numberWithOptions(
                          signed: preset == _EffectPreset.changePoints,
                        ),
                        decoration: InputDecoration(
                          labelText: amountLabel(),
                          helperText: preset == _EffectPreset.changePoints
                              ? '増加は正数、減少は負数で入力してください'
                              : '1以上の整数を入力してください',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ],
                    if (needsWarpTarget) ...[
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: candidates.any((item) => item.id == warpTargetId)
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
                          hintText: '例：条件を満たしたのでボーナス！',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                    if (needsRandomOptions) ...[
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final edited = await showRandomEventOptionsEditor(
                            context,
                            initialOptions: randomOptions,
                          );
                          if (edited != null && context.mounted) {
                            setDialogState(
                              () => randomOptions = List<RandomEventOption>.of(edited),
                            );
                          }
                        },
                        icon: const Icon(Icons.casino_outlined),
                        label: Text('候補を編集（${randomOptions.length}個）'),
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          randomOptions.length < 2
                              ? '2つ以上の候補を設定してください。'
                              : '各候補は同じ確率で選ばれます。',
                          style: Theme.of(context).textTheme.bodySmall,
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
                onPressed: needsRandomOptions && randomOptions.length < 2 ||
                        invalidGroupCount()
                    ? null
                    : () {
                        final amount = int.tryParse(amountController.text.trim()) ?? 1;
                        final condition = _conditionFor(
                          conditionPreset,
                          points:
                              int.tryParse(conditionPointsController.text.trim()) ?? 0,
                          maxPoints: int.tryParse(
                                conditionMaxPointsController.text.trim(),
                              ) ??
                              10,
                          itemName: conditionItemNameController.text,
                          quantity: int.tryParse(
                                conditionQuantityController.text.trim(),
                              ) ??
                              1,
                          groupConditions: groupConditions,
                        );
                        if (conditionPreset != _ConditionPreset.none &&
                            condition == null) {
                          return;
                        }
                        final effect = _effectFor(
                          preset: preset,
                          trigger: trigger,
                          condition: condition,
                          amount: amount,
                          warpTargetId: warpTargetId,
                          message: messageController.text,
                          itemName: itemNameController.text,
                          randomOptions: randomOptions,
                        );
                        if (effect != null) Navigator.pop(dialogContext, effect);
                      },
                child: const Text('適用'),
              ),
            ],
          );
        },
      ),
    );

    amountController.dispose();
    messageController.dispose();
    itemNameController.dispose();
    conditionPointsController.dispose();
    conditionMaxPointsController.dispose();
    conditionItemNameController.dispose();
    conditionQuantityController.dispose();
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
                    '${triggerDescription(effect.trigger)} · ${conditionDescription(effect.condition)}',
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
    final selectedOutgoingIds =
        _board.outgoingSquares(square.id).map((item) => item.id).toSet();
    final candidates = _board.squares
        .where((item) => item.id != square.id)
        .toList(growable: false);

    final updated = await showModalBottomSheet<_SquareEditResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
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
                Text('マスの設定', style: Theme.of(context).textTheme.titleLarge),
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
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                  Text(
                                    'Trigger → Condition → Action を設定し、上から順番に評価します。',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            Chip(label: Text('${effects.length}個')),
                          ],
                        ),
                        if (effects.isEmpty) ...[
                          const SizedBox(height: 10),
                          const Text('イベントはありません。下のボタンからActionを追加できます。'),
                        ] else
                          for (var index = 0; index < effects.length; index++)
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
                                if (edited != null && context.mounted) {
                                  setModalState(() => effects[index] = edited);
                                }
                              },
                              onDelete: () {
                                setModalState(() => effects.removeAt(index));
                              },
                            ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final added = await _editEffect(candidates: candidates);
                            if (added != null && context.mounted) {
                              setModalState(() => effects.add(added));
                            }
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
                  Text('2つ以上選ぶと分岐になります。',
                      style: Theme.of(context).textTheme.bodySmall),
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
        ),
      ),
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
      case EffectActionType.grantItem:
        return Colors.lightGreen.shade300;
      case EffectActionType.consumeItem:
        return Colors.deepOrange.shade200;
      case EffectActionType.randomEvent:
        return Colors.pink.shade200;
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
                  avatar: Icon(hasBranch ? Icons.call_split : Icons.route, size: 18),
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
                            onPanUpdate: (details) => _moveSquare(square, details.delta),
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
                                      if (_board.outgoingSquares(square.id).length > 1) ...[
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
