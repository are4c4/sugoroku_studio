import 'package:flutter/material.dart';

import '../domain/board.dart';
import 'effect_text.dart';

enum _PrimitiveConditionPreset {
  pointsAtLeast,
  pointsAtMost,
  pointsBetween,
  hasItem,
  notHasItem,
  itemQuantityAtLeast,
}

bool _isGroupType(EffectConditionType type) {
  return type == EffectConditionType.allOf ||
      type == EffectConditionType.anyOf ||
      type == EffectConditionType.not;
}

String _operatorLabel(EffectConditionType type) {
  return switch (type) {
    EffectConditionType.allOf => 'AND',
    EffectConditionType.anyOf => 'OR',
    EffectConditionType.not => 'NOT',
    _ => '',
  };
}

int _requiredChildCount(EffectConditionType type) {
  return type == EffectConditionType.not ? 1 : 2;
}

bool _hasValidChildCount(
  EffectConditionType type,
  List<EffectCondition> conditions,
) {
  if (type == EffectConditionType.not) return conditions.length == 1;
  return conditions.length >= 2;
}

Future<List<EffectCondition>?> showConditionGroupEditor(
  BuildContext context, {
  required EffectConditionType groupType,
  required List<EffectCondition> initialConditions,
  int depth = 0,
}) async {
  assert(_isGroupType(groupType));

  final conditions = List<EffectCondition>.of(initialConditions);
  final operatorLabel = _operatorLabel(groupType);
  final requiredCount = _requiredChildCount(groupType);

  return showDialog<List<EffectCondition>>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) {
        final canAddChild = groupType != EffectConditionType.not || conditions.isEmpty;

        Future<void> addPrimitive() async {
          if (!canAddChild) return;
          final condition = await _showPrimitiveConditionEditor(context);
          if (condition != null && context.mounted) {
            setDialogState(() => conditions.add(condition));
          }
        }

        Future<void> addGroup(EffectConditionType type) async {
          if (!canAddChild) return;
          final children = await showConditionGroupEditor(
            context,
            groupType: type,
            initialConditions: const <EffectCondition>[],
            depth: depth + 1,
          );
          if (children == null || !context.mounted) return;
          setDialogState(
            () => conditions.add(
              EffectCondition(
                type: type,
                parameters: {
                  'conditions': children.map((item) => item.toJson()).toList(),
                },
              ),
            ),
          );
        }

        Future<void> editCondition(int index) async {
          final current = conditions[index];
          if (_isGroupType(current.type)) {
            final children = await showConditionGroupEditor(
              context,
              groupType: current.type,
              initialConditions: current.childConditions,
              depth: depth + 1,
            );
            if (children == null || !context.mounted) return;
            setDialogState(
              () => conditions[index] = EffectCondition(
                type: current.type,
                parameters: {
                  'conditions': children.map((item) => item.toJson()).toList(),
                },
              ),
            );
            return;
          }

          final edited = await _showPrimitiveConditionEditor(
            context,
            initialCondition: current,
          );
          if (edited != null && context.mounted) {
            setDialogState(() => conditions[index] = edited);
          }
        }

        String helpText() {
          return switch (groupType) {
            EffectConditionType.allOf => 'すべての子条件を満たしたときに成立します。',
            EffectConditionType.anyOf => 'いずれか1つの子条件を満たしたときに成立します。',
            EffectConditionType.not => '1つの子条件の真偽を反転します。',
            _ => '',
          };
        }

        String childCountText() {
          if (!_hasValidChildCount(groupType, conditions)) {
            return groupType == EffectConditionType.not
                ? 'NOT条件には子条件がちょうど1つ必要です。'
                : '複合条件には2つ以上の子条件が必要です。';
          }
          return groupType == EffectConditionType.not
              ? '1個の子条件をNOTで反転します。'
              : '${conditions.length}個の子条件を$operatorLabelで評価します。';
        }

        return AlertDialog(
          title: Text('$operatorLabel 条件を編集'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(helpText()),
                  const SizedBox(height: 12),
                  if (conditions.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        requiredCount == 1
                            ? '子条件がありません。1つ追加してください。'
                            : '子条件がありません。2つ以上追加してください。',
                      ),
                    )
                  else
                    for (var index = 0; index < conditions.length; index++)
                      Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            radius: 14,
                            child: Text('${index + 1}'),
                          ),
                          title: Text(conditionDescription(conditions[index])),
                          subtitle: Text(
                            _isGroupType(conditions[index].type)
                                ? '${_operatorLabel(conditions[index].type)} グループ'
                                : '基本条件',
                          ),
                          onTap: () => editCondition(index),
                          trailing: IconButton(
                            tooltip: '削除',
                            onPressed: () {
                              setDialogState(() => conditions.removeAt(index));
                            },
                            icon: const Icon(Icons.close),
                          ),
                        ),
                      ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: canAddChild ? addPrimitive : null,
                        icon: const Icon(Icons.add),
                        label: const Text('基本条件を追加'),
                      ),
                      if (depth < 3) ...[
                        OutlinedButton.icon(
                          onPressed: canAddChild
                              ? () => addGroup(EffectConditionType.allOf)
                              : null,
                          icon: const Icon(Icons.account_tree_outlined),
                          label: const Text('ANDを追加'),
                        ),
                        OutlinedButton.icon(
                          onPressed: canAddChild
                              ? () => addGroup(EffectConditionType.anyOf)
                              : null,
                          icon: const Icon(Icons.call_split_outlined),
                          label: const Text('ORを追加'),
                        ),
                        OutlinedButton.icon(
                          onPressed: canAddChild
                              ? () => addGroup(EffectConditionType.not)
                              : null,
                          icon: const Icon(Icons.not_interested_outlined),
                          label: const Text('NOTを追加'),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    childCountText(),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
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
              onPressed: !_hasValidChildCount(groupType, conditions)
                  ? null
                  : () => Navigator.pop(
                        dialogContext,
                        List<EffectCondition>.unmodifiable(conditions),
                      ),
              child: const Text('適用'),
            ),
          ],
        );
      },
    ),
  );
}

Future<EffectCondition?> _showPrimitiveConditionEditor(
  BuildContext context, {
  EffectCondition? initialCondition,
}) async {
  var preset = _presetFor(initialCondition);
  final pointsController = TextEditingController(
    text: _pointsFor(initialCondition).toString(),
  );
  final maxPointsController = TextEditingController(
    text: _maxPointsFor(initialCondition).toString(),
  );
  final itemNameController = TextEditingController(
    text: _itemNameFor(initialCondition),
  );
  final quantityController = TextEditingController(
    text: _quantityFor(initialCondition).toString(),
  );

  final result = await showDialog<EffectCondition>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) {
        final needsPoints = preset == _PrimitiveConditionPreset.pointsAtLeast ||
            preset == _PrimitiveConditionPreset.pointsAtMost ||
            preset == _PrimitiveConditionPreset.pointsBetween;
        final needsMaxPoints =
            preset == _PrimitiveConditionPreset.pointsBetween;
        final needsItemName = preset == _PrimitiveConditionPreset.hasItem ||
            preset == _PrimitiveConditionPreset.notHasItem ||
            preset == _PrimitiveConditionPreset.itemQuantityAtLeast;
        final needsQuantity =
            preset == _PrimitiveConditionPreset.itemQuantityAtLeast;

        return AlertDialog(
          title: Text(initialCondition == null ? '基本条件を追加' : '基本条件を編集'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<_PrimitiveConditionPreset>(
                    initialValue: preset,
                    decoration: const InputDecoration(
                      labelText: '条件',
                      border: OutlineInputBorder(),
                    ),
                    items: _PrimitiveConditionPreset.values
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text(_labelFor(item)),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value != null) setDialogState(() => preset = value);
                    },
                  ),
                  if (needsPoints) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: pointsController,
                      keyboardType:
                          const TextInputType.numberWithOptions(signed: true),
                      decoration: InputDecoration(
                        labelText: needsMaxPoints ? '最小ポイント' : 'ポイント値',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ],
                  if (needsMaxPoints) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: maxPointsController,
                      keyboardType:
                          const TextInputType.numberWithOptions(signed: true),
                      decoration: const InputDecoration(
                        labelText: '最大ポイント',
                        helperText: '逆順でも小さい方を下限として判定します',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                  if (needsItemName) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: itemNameController,
                      decoration: const InputDecoration(
                        labelText: 'アイテム名',
                        hintText: '例：金の鍵',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                  if (needsQuantity) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: quantityController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '必要な個数',
                        border: OutlineInputBorder(),
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
                final condition = _conditionFor(
                  preset,
                  points: int.tryParse(pointsController.text.trim()) ?? 0,
                  maxPoints: int.tryParse(maxPointsController.text.trim()) ?? 10,
                  itemName: itemNameController.text,
                  quantity: int.tryParse(quantityController.text.trim()) ?? 1,
                );
                if (condition != null) Navigator.pop(dialogContext, condition);
              },
              child: const Text('適用'),
            ),
          ],
        );
      },
    ),
  );

  pointsController.dispose();
  maxPointsController.dispose();
  itemNameController.dispose();
  quantityController.dispose();
  return result;
}

_PrimitiveConditionPreset _presetFor(EffectCondition? condition) {
  if (condition == null) return _PrimitiveConditionPreset.pointsAtLeast;
  return switch (condition.type) {
    EffectConditionType.pointsAtLeast => _PrimitiveConditionPreset.pointsAtLeast,
    EffectConditionType.pointsAtMost => _PrimitiveConditionPreset.pointsAtMost,
    EffectConditionType.pointsBetween => _PrimitiveConditionPreset.pointsBetween,
    EffectConditionType.hasItem => _PrimitiveConditionPreset.hasItem,
    EffectConditionType.notHasItem => _PrimitiveConditionPreset.notHasItem,
    EffectConditionType.itemQuantityAtLeast =>
      _PrimitiveConditionPreset.itemQuantityAtLeast,
    EffectConditionType.allOf ||
    EffectConditionType.anyOf ||
    EffectConditionType.not =>
      _PrimitiveConditionPreset.pointsAtLeast,
  };
}

String _labelFor(_PrimitiveConditionPreset preset) {
  return switch (preset) {
    _PrimitiveConditionPreset.pointsAtLeast => 'ポイントがN以上',
    _PrimitiveConditionPreset.pointsAtMost => 'ポイントがN以下',
    _PrimitiveConditionPreset.pointsBetween => 'ポイントがN〜Mの範囲',
    _PrimitiveConditionPreset.hasItem => '指定アイテムを持っている',
    _PrimitiveConditionPreset.notHasItem => '指定アイテムを持っていない',
    _PrimitiveConditionPreset.itemQuantityAtLeast =>
      '指定アイテムをN個以上持っている',
  };
}

int _pointsFor(EffectCondition? condition) {
  if (condition == null) return 0;
  if (condition.type == EffectConditionType.pointsBetween) {
    final raw = condition.parameters['minPoints'];
    return raw is num ? raw.toInt() : 0;
  }
  final raw = condition.parameters['points'];
  return raw is num ? raw.toInt() : 0;
}

int _maxPointsFor(EffectCondition? condition) {
  if (condition?.type != EffectConditionType.pointsBetween) return 10;
  final raw = condition!.parameters['maxPoints'];
  return raw is num ? raw.toInt() : 10;
}

String _itemNameFor(EffectCondition? condition) {
  if (condition == null) return '';
  final raw = condition.parameters['itemName'];
  return raw is String ? raw.trim() : '';
}

int _quantityFor(EffectCondition? condition) {
  if (condition == null) return 1;
  final raw = condition.parameters['quantity'];
  final quantity = raw is num ? raw.toInt() : 1;
  return quantity < 1 ? 1 : quantity;
}

EffectCondition? _conditionFor(
  _PrimitiveConditionPreset preset, {
  required int points,
  required int maxPoints,
  required String itemName,
  required int quantity,
}) {
  final safeQuantity = quantity < 1 ? 1 : quantity;
  switch (preset) {
    case _PrimitiveConditionPreset.pointsAtLeast:
      return EffectCondition(
        type: EffectConditionType.pointsAtLeast,
        parameters: {'points': points},
      );
    case _PrimitiveConditionPreset.pointsAtMost:
      return EffectCondition(
        type: EffectConditionType.pointsAtMost,
        parameters: {'points': points},
      );
    case _PrimitiveConditionPreset.pointsBetween:
      final minPoints = points <= maxPoints ? points : maxPoints;
      final max = points <= maxPoints ? maxPoints : points;
      return EffectCondition(
        type: EffectConditionType.pointsBetween,
        parameters: {'minPoints': minPoints, 'maxPoints': max},
      );
    case _PrimitiveConditionPreset.hasItem:
      final name = itemName.trim();
      if (name.isEmpty) return null;
      return EffectCondition(
        type: EffectConditionType.hasItem,
        parameters: {'itemName': name},
      );
    case _PrimitiveConditionPreset.notHasItem:
      final name = itemName.trim();
      if (name.isEmpty) return null;
      return EffectCondition(
        type: EffectConditionType.notHasItem,
        parameters: {'itemName': name},
      );
    case _PrimitiveConditionPreset.itemQuantityAtLeast:
      final name = itemName.trim();
      if (name.isEmpty) return null;
      return EffectCondition(
        type: EffectConditionType.itemQuantityAtLeast,
        parameters: {'itemName': name, 'quantity': safeQuantity},
      );
  }
}
