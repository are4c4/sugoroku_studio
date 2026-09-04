import 'package:flutter/material.dart';

import '../domain/item_definition.dart';

Future<List<ItemDefinition>?> showItemDefinitionsEditor(
  BuildContext context, {
  required List<ItemDefinition> initialDefinitions,
}) {
  final definitions = List<ItemDefinition>.of(initialDefinitions);

  return showDialog<List<ItemDefinition>>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) {
        Future<void> addDefinition() async {
          final definition = await _showItemDefinitionEditor(
            context,
            reservedNames: definitions.map((item) => item.name).toSet(),
          );
          if (definition != null && context.mounted) {
            setDialogState(() => definitions.add(definition));
          }
        }

        Future<void> editDefinition(int index) async {
          final current = definitions[index];
          final definition = await _showItemDefinitionEditor(
            context,
            initialDefinition: current,
            reservedNames: definitions
                .where((item) => !identical(item, current))
                .map((item) => item.name)
                .toSet(),
          );
          if (definition != null && context.mounted) {
            setDialogState(() => definitions[index] = definition);
          }
        }

        return AlertDialog(
          title: const Text('使用可能アイテム'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'マス効果などで獲得するアイテム名と同じ名前を登録すると、プレイ中に任意使用できます。現在は使用時のポイント増減に対応しています。',
                  ),
                  const SizedBox(height: 12),
                  if (definitions.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('使用可能アイテムはまだありません。'),
                    )
                  else
                    for (var index = 0; index < definitions.length; index++)
                      Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(Icons.inventory_2_outlined),
                          title: Text(definitions[index].name),
                          subtitle: Text(
                            _definitionSummary(definitions[index]),
                          ),
                          onTap: () => editDefinition(index),
                          trailing: IconButton(
                            tooltip: '削除',
                            onPressed: () {
                              setDialogState(() => definitions.removeAt(index));
                            },
                            icon: const Icon(Icons.close),
                          ),
                        ),
                      ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: addDefinition,
                    icon: const Icon(Icons.add),
                    label: const Text('使用可能アイテムを追加'),
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
              onPressed: () => Navigator.pop(
                dialogContext,
                List<ItemDefinition>.unmodifiable(definitions),
              ),
              child: const Text('適用'),
            ),
          ],
        );
      },
    ),
  );
}

Future<ItemDefinition?> _showItemDefinitionEditor(
  BuildContext context, {
  ItemDefinition? initialDefinition,
  required Set<String> reservedNames,
}) async {
  final nameController = TextEditingController(text: initialDefinition?.name ?? '');
  final descriptionController = TextEditingController(
    text: initialDefinition?.description ?? '',
  );
  final pointsController = TextEditingController(
    text: (initialDefinition?.pointsDelta ?? 1).toString(),
  );
  String? errorText;

  final result = await showDialog<ItemDefinition>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(initialDefinition == null ? 'アイテムを追加' : 'アイテムを編集'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: initialDefinition == null,
                decoration: InputDecoration(
                  labelText: 'アイテム名',
                  hintText: '例：ポイント薬',
                  errorText: errorText,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: '説明（任意）',
                  hintText: '例：使うと5ポイント獲得',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pointsController,
                keyboardType: const TextInputType.numberWithOptions(signed: true),
                decoration: const InputDecoration(
                  labelText: '使用時のポイント増減',
                  helperText: '獲得は正数、減少は負数で入力してください',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                setDialogState(() => errorText = 'アイテム名を入力してください。');
                return;
              }
              if (reservedNames.contains(name)) {
                setDialogState(() => errorText = '同じ名前のアイテムが既にあります。');
                return;
              }
              Navigator.pop(
                dialogContext,
                ItemDefinition(
                  name: name,
                  description: descriptionController.text.trim(),
                  actionType: ItemUseActionType.changePoints,
                  parameters: {
                    'points': int.tryParse(pointsController.text.trim()) ?? 0,
                  },
                ),
              );
            },
            child: const Text('適用'),
          ),
        ],
      ),
    ),
  );

  nameController.dispose();
  descriptionController.dispose();
  pointsController.dispose();
  return result;
}

String _definitionSummary(ItemDefinition definition) {
  final delta = definition.pointsDelta;
  final sign = delta > 0 ? '+' : '';
  final effect = '使用時 $sign${delta}pt';
  if (definition.description.trim().isEmpty) return effect;
  return '${definition.description.trim()} · $effect';
}
