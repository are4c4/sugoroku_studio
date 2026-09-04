import 'package:flutter/material.dart';

import '../domain/board.dart';
import '../domain/item_definition.dart';
import '../domain/player.dart';

List<ItemDefinition> usableItemDefinitions(Board board, Player player) {
  return board.itemDefinitions
      .where((definition) => player.itemQuantity(definition.name) > 0)
      .toList(growable: false);
}

Future<String?> showItemUseDialog(
  BuildContext context, {
  required Board board,
  required Player player,
}) {
  final definitions = usableItemDefinitions(board, player);
  if (definitions.isEmpty) return Future<String?>.value();

  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('アイテムを使う'),
      content: SizedBox(
        width: 460,
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: definitions.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final definition = definitions[index];
            final quantity = player.itemQuantity(definition.name);
            final delta = definition.pointsDelta;
            final sign = delta > 0 ? '+' : '';
            final description = definition.description.trim();
            return Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.inventory_2_outlined),
                title: Text('${definition.name} ×$quantity'),
                subtitle: Text(
                  description.isEmpty
                      ? '使うと $sign${delta}pt'
                      : '$description\n使うと $sign${delta}pt',
                ),
                isThreeLine: description.isNotEmpty,
                trailing: FilledButton(
                  onPressed: () => Navigator.pop(
                    dialogContext,
                    definition.name,
                  ),
                  child: const Text('使う'),
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('閉じる'),
        ),
      ],
    ),
  );
}
