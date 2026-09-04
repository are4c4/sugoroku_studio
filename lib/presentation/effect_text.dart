import '../domain/board.dart';

String triggerDescription(EffectTrigger trigger) {
  switch (trigger) {
    case EffectTrigger.onLand:
      return '止まったとき';
    case EffectTrigger.onPass:
      return '通過したとき';
  }
}

String conditionDescription(EffectCondition? condition) {
  if (condition == null) return '条件なし';
  switch (condition.type) {
    case EffectConditionType.pointsAtLeast:
      final rawPoints = condition.parameters['points'];
      final points = rawPoints is num ? rawPoints.toInt() : 0;
      return '★ $points pt以上';
    case EffectConditionType.pointsAtMost:
      final rawPoints = condition.parameters['points'];
      final points = rawPoints is num ? rawPoints.toInt() : 0;
      return '★ $points pt以下';
    case EffectConditionType.pointsBetween:
      final rawMin = condition.parameters['minPoints'];
      final rawMax = condition.parameters['maxPoints'];
      final first = rawMin is num ? rawMin.toInt() : 0;
      final second = rawMax is num ? rawMax.toInt() : 0;
      final minPoints = first <= second ? first : second;
      final maxPoints = first <= second ? second : first;
      return '★ $minPoints〜$maxPoints pt';
    case EffectConditionType.hasItem:
      final rawName = condition.parameters['itemName'];
      final itemName = rawName is String ? rawName.trim() : '';
      return itemName.isEmpty ? '🎒 アイテム所持' : '🎒「$itemName」を所持';
    case EffectConditionType.notHasItem:
      final rawName = condition.parameters['itemName'];
      final itemName = rawName is String ? rawName.trim() : '';
      return itemName.isEmpty ? '🎒 アイテム未所持' : '🎒「$itemName」を未所持';
    case EffectConditionType.itemQuantityAtLeast:
      final rawName = condition.parameters['itemName'];
      final itemName = rawName is String ? rawName.trim() : '';
      final rawQuantity = condition.parameters['quantity'];
      final quantity = rawQuantity is num ? rawQuantity.toInt() : 1;
      final threshold = quantity < 1 ? 1 : quantity;
      return itemName.isEmpty
          ? '🎒 アイテム×$threshold以上'
          : '🎒「$itemName」×$threshold以上';
  }
}

String effectMessage(SquareEffect effect) {
  final rawMessage = effect.parameters['message'];
  return rawMessage is String ? rawMessage.trim() : '';
}

String effectItemName(SquareEffect effect) {
  final rawName = effect.parameters['itemName'];
  return rawName is String ? rawName.trim() : '';
}

int effectItemQuantity(SquareEffect effect) {
  final rawQuantity = effect.parameters['quantity'];
  final quantity = rawQuantity is num ? rawQuantity.toInt() : 1;
  return quantity < 1 ? 1 : quantity;
}

String effectDescription(SquareEffect effect) {
  switch (effect.actionType) {
    case EffectActionType.moveBy:
      final rawSteps = effect.parameters['steps'];
      final steps = rawSteps is num ? rawSteps.toInt() : 0;
      if (steps > 0) return '$stepsマス進む';
      if (steps < 0) return '${steps.abs()}マス戻る';
      return '移動なし';
    case EffectActionType.moveToStart:
      return 'スタートへ戻る';
    case EffectActionType.skipTurn:
      final rawTurns = effect.parameters['turns'];
      final turns = rawTurns is num ? rawTurns.toInt() : 1;
      return '${turns < 1 ? 1 : turns}回休み';
    case EffectActionType.rollAgain:
      return 'もう一度振る';
    case EffectActionType.warpTo:
      return 'ワープ';
    case EffectActionType.showMessage:
      final message = effectMessage(effect);
      return message.isEmpty ? 'メッセージを表示' : 'メッセージ「$message」';
    case EffectActionType.changePoints:
      final rawPoints = effect.parameters['points'];
      final points = rawPoints is num ? rawPoints.toInt() : 0;
      if (points > 0) return '$pointsポイント獲得';
      if (points < 0) return '${points.abs()}ポイント失う';
      return 'ポイント変化なし';
    case EffectActionType.grantItem:
      final itemName = effectItemName(effect);
      final quantity = effectItemQuantity(effect);
      return itemName.isEmpty ? 'アイテムを付与' : '「$itemName」×$quantity を獲得';
    case EffectActionType.consumeItem:
      final itemName = effectItemName(effect);
      final quantity = effectItemQuantity(effect);
      return itemName.isEmpty ? 'アイテムを消費' : '「$itemName」×$quantity を消費';
    case EffectActionType.randomEvent:
      final count = effect.randomEventOptions.length;
      return count == 0 ? 'ランダムイベント' : 'ランダムイベント（$count候補）';
  }
}

String squareEffectSummary(BoardSquare square) {
  if (square.effects.isEmpty) return '';
  return square.effects.map(effectDescription).join(' / ');
}
