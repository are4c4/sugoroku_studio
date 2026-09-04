import 'package:flutter/material.dart';

import '../domain/board.dart';

enum _OutcomePreset { showMessage, changePoints, grantItem }

_OutcomePreset _presetFor(RandomEventOption option) {
  switch (option.outcomeType) {
    case RandomEventOutcomeType.showMessage:
      return _OutcomePreset.showMessage;
    case RandomEventOutcomeType.changePoints:
      return _OutcomePreset.changePoints;
    case RandomEventOutcomeType.grantItem:
      return _OutcomePreset.grantItem;
  }
}

String _presetLabel(_OutcomePreset preset) {
  switch (preset) {
    case _OutcomePreset.showMessage:
      return 'メッセージ';
    case _OutcomePreset.changePoints:
      return 'ポイント増減';
    case _OutcomePreset.grantItem:
      return 'アイテム付与';
  }
}

String randomEventOptionDescription(RandomEventOption option) {
  switch (option.outcomeType) {
    case RandomEventOutcomeType.showMessage:
      final message = option.parameters['message'];
      return message is String && message.trim().isNotEmpty
          ? '💬 ${message.trim()}'
          : '💬 メッセージ';
    case RandomEventOutcomeType.changePoints:
      final rawPoints = option.parameters['points'];
      final points = rawPoints is num ? rawPoints.toInt() : 0;
      final sign = points > 0 ? '+' : '';
      return '⭐ $sign${points}pt';
    case RandomEventOutcomeType.grantItem:
      final rawName = option.parameters['itemName'];
      final name = rawName is String ? rawName.trim() : '';
      final rawQuantity = option.parameters['quantity'];
      final quantity = rawQuantity is num && rawQuantity.toInt() > 0
          ? rawQuantity.toInt()
          : 1;
      return '🎒 ${name.isEmpty ? 'アイテム' : name} ×$quantity';
  }
}

Future<RandomEventOption?> _editOption(
  BuildContext context, {
  RandomEventOption? initial,
}) async {
  var preset = initial == null ? _OutcomePreset.showMessage : _presetFor(initial);
  final labelController = TextEditingController(text: initial?.label ?? '');
  final messageController = TextEditingController(
    text: initial?.parameters['message'] is String
        ? initial!.parameters['message'] as String
        : '',
  );
  final pointsController = TextEditingController(
    text: initial?.parameters['points'] is num
        ? (initial!.parameters['points'] as num).toInt().toString()
        : '0',
  );
  final itemNameController = TextEditingController(
    text: initial?.parameters['itemName'] is String
        ? initial!.parameters['itemName'] as String
        : '',
  );
  final quantityController = TextEditingController(
    text: initial?.parameters['quantity'] is num
        ? (initial!.parameters['quantity'] as num).toInt().toString()
        : '1',
  );

  final result = await showDialog<RandomEventOption>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) {
        return AlertDialog(
          title: Text(initial == null ? 'ランダム候補を追加' : 'ランダム候補を編集'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: labelController,
                    decoration: const InputDecoration(
                      labelText: '候補名',
                      hintText: '例：大当たり',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<_OutcomePreset>(
                    initialValue: preset,
                    decoration: const InputDecoration(
                      labelText: '結果',
                      border: OutlineInputBorder(),
                    ),
                    items: _OutcomePreset.values
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text(_presetLabel(item)),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value != null) setDialogState(() => preset = value);
                    },
                  ),
                  if (preset == _OutcomePreset.showMessage) ...[
                    const SizedBox(height: 14),
                    TextField(
                      controller: messageController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: '表示するメッセージ',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                  if (preset == _OutcomePreset.changePoints) ...[
                    const SizedBox(height: 14),
                    TextField(
                      controller: pointsController,
                      keyboardType:
                          const TextInputType.numberWithOptions(signed: true),
                      decoration: const InputDecoration(
                        labelText: '増減ポイント',
                        helperText: '増加は正数、減少は負数',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                  if (preset == _OutcomePreset.grantItem) ...[
                    const SizedBox(height: 14),
                    TextField(
                      controller: itemNameController,
                      decoration: const InputDecoration(
                        labelText: 'アイテム名',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: quantityController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '個数',
                        helperText: '1以上の整数',
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
                final label = labelController.text.trim();
                switch (preset) {
                  case _OutcomePreset.showMessage:
                    final message = messageController.text.trim();
                    if (message.isEmpty) return;
                    Navigator.pop(
                      dialogContext,
                      RandomEventOption(
                        label: label.isEmpty ? 'メッセージ' : label,
                        outcomeType: RandomEventOutcomeType.showMessage,
                        parameters: {'message': message},
                      ),
                    );
                  case _OutcomePreset.changePoints:
                    final points =
                        int.tryParse(pointsController.text.trim()) ?? 0;
                    Navigator.pop(
                      dialogContext,
                      RandomEventOption(
                        label: label.isEmpty ? 'ポイント変化' : label,
                        outcomeType: RandomEventOutcomeType.changePoints,
                        parameters: {'points': points},
                      ),
                    );
                  case _OutcomePreset.grantItem:
                    final itemName = itemNameController.text.trim();
                    if (itemName.isEmpty) return;
                    final parsed =
                        int.tryParse(quantityController.text.trim()) ?? 1;
                    final quantity = parsed < 1 ? 1 : parsed;
                    Navigator.pop(
                      dialogContext,
                      RandomEventOption(
                        label: label.isEmpty ? itemName : label,
                        outcomeType: RandomEventOutcomeType.grantItem,
                        parameters: {
                          'itemName': itemName,
                          'quantity': quantity,
                        },
                      ),
                    );
                }
              },
              child: const Text('適用'),
            ),
          ],
        );
      },
    ),
  );

  labelController.dispose();
  messageController.dispose();
  pointsController.dispose();
  itemNameController.dispose();
  quantityController.dispose();
  return result;
}

Future<List<RandomEventOption>?> showRandomEventOptionsEditor(
  BuildContext context, {
  required List<RandomEventOption> initialOptions,
}) {
  final options = List<RandomEventOption>.of(initialOptions);
  return showDialog<List<RandomEventOption>>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) {
        return AlertDialog(
          title: const Text('ランダムイベント候補'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('各候補は同じ確率で選ばれます。2つ以上設定してください。'),
                  const SizedBox(height: 10),
                  for (var index = 0; index < options.length; index++)
                    Card(
                      child: ListTile(
                        leading: CircleAvatar(child: Text('${index + 1}')),
                        title: Text(options[index].label),
                        subtitle: Text(randomEventOptionDescription(options[index])),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: '編集',
                              onPressed: () async {
                                final edited = await _editOption(
                                  context,
                                  initial: options[index],
                                );
                                if (edited != null && context.mounted) {
                                  setDialogState(() => options[index] = edited);
                                }
                              },
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              tooltip: '削除',
                              onPressed: () =>
                                  setDialogState(() => options.removeAt(index)),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final added = await _editOption(context);
                      if (added != null && context.mounted) {
                        setDialogState(() => options.add(added));
                      }
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('候補を追加'),
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
              onPressed: options.length < 2
                  ? null
                  : () => Navigator.pop(
                        dialogContext,
                        List<RandomEventOption>.unmodifiable(options),
                      ),
              child: const Text('適用'),
            ),
          ],
        );
      },
    ),
  );
}
