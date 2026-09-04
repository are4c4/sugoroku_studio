import 'board.dart';

bool effectConditionMatches(
  EffectCondition? condition, {
  required int points,
  required Map<String, int> inventory,
}) {
  return _effectConditionMatches(
    condition,
    points: points,
    inventory: inventory,
    depth: 0,
  );
}

bool _effectConditionMatches(
  EffectCondition? condition, {
  required int points,
  required Map<String, int> inventory,
  required int depth,
}) {
  if (condition == null) return true;
  if (depth >= 16) return false;

  int itemQuantity(String rawName) {
    final name = rawName.trim();
    return name.isEmpty ? 0 : inventory[name] ?? 0;
  }

  switch (condition.type) {
    case EffectConditionType.pointsAtLeast:
      final raw = condition.parameters['points'];
      final threshold = raw is num ? raw.toInt() : 0;
      return points >= threshold;
    case EffectConditionType.pointsAtMost:
      final raw = condition.parameters['points'];
      final threshold = raw is num ? raw.toInt() : 0;
      return points <= threshold;
    case EffectConditionType.pointsBetween:
      final rawMin = condition.parameters['minPoints'];
      final rawMax = condition.parameters['maxPoints'];
      final first = rawMin is num ? rawMin.toInt() : 0;
      final second = rawMax is num ? rawMax.toInt() : 0;
      final minPoints = first <= second ? first : second;
      final maxPoints = first <= second ? second : first;
      return points >= minPoints && points <= maxPoints;
    case EffectConditionType.hasItem:
      final rawName = condition.parameters['itemName'];
      return rawName is String && itemQuantity(rawName) > 0;
    case EffectConditionType.notHasItem:
      final rawName = condition.parameters['itemName'];
      return rawName is String &&
          rawName.trim().isNotEmpty &&
          itemQuantity(rawName) == 0;
    case EffectConditionType.itemQuantityAtLeast:
      final rawName = condition.parameters['itemName'];
      final rawQuantity = condition.parameters['quantity'];
      final quantity = rawQuantity is num ? rawQuantity.toInt() : 1;
      final threshold = quantity < 1 ? 1 : quantity;
      return rawName is String && itemQuantity(rawName) >= threshold;
    case EffectConditionType.allOf:
      final children = condition.childConditions;
      return children.isNotEmpty &&
          children.every(
            (child) => _effectConditionMatches(
              child,
              points: points,
              inventory: inventory,
              depth: depth + 1,
            ),
          );
    case EffectConditionType.anyOf:
      final children = condition.childConditions;
      return children.isNotEmpty &&
          children.any(
            (child) => _effectConditionMatches(
              child,
              points: points,
              inventory: inventory,
              depth: depth + 1,
            ),
          );
  }
}
