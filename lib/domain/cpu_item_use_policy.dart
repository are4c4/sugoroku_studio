import 'board.dart';
import 'player.dart';

String? chooseAutomaticCpuItem({
  required Board board,
  required Player player,
}) {
  if (player.type != PlayerType.cpu) return null;

  String? selectedName;
  var selectedDelta = 0;

  for (final definition in board.itemDefinitions) {
    if (player.itemQuantity(definition.name) < 1) continue;
    final delta = definition.pointsDelta;
    if (delta <= selectedDelta) continue;

    selectedName = definition.name;
    selectedDelta = delta;
  }

  return selectedName;
}
