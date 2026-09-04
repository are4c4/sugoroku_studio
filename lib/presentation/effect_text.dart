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
  final rawPoints = condition.parameters['points'];
  final points = rawPoints is num ? rawPoints.toInt() : 0;
  switch (condition.type) {
    case EffectConditionType.pointsAtLeast:
      return '★ $points pt以上';
    case EffectConditionType.pointsAtMost:
      return '★ $points pt以下';
  }
}

String effectMessage(SquareEffect effect) {
  final rawMessage = effect.parameters['message'];
  return rawMessage is String ? rawMessage.trim() : '';
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
  }
}

String squareEffectSummary(BoardSquare square) {
  if (square.effects.isEmpty) return '';
  return square.effects.map(effectDescription).join(' / ');
}
