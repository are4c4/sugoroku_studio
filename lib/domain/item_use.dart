import 'game_engine.dart';
import 'game_event.dart';
import 'game_state.dart';
import 'item_definition.dart';

extension ItemUseGameEngine on GameEngine {
  GameTurnResult useCurrentPlayerItem(
    GameState state, {
    required String itemName,
  }) {
    if (state.status != GameStatus.playing || state.currentPlayer.skipTurns > 0) {
      return GameTurnResult(state: state, events: const <GameEvent>[]);
    }

    final definition = state.board.itemDefinitionByName(itemName);
    if (definition == null) {
      return GameTurnResult(state: state, events: const <GameEvent>[]);
    }

    final currentPlayer = state.currentPlayer;
    final owned = currentPlayer.itemQuantity(definition.name);
    if (owned < 1) {
      return GameTurnResult(state: state, events: const <GameEvent>[]);
    }

    final inventory = Map<String, int>.of(currentPlayer.inventory);
    final remaining = owned - 1;
    if (remaining == 0) {
      inventory.remove(definition.name);
    } else {
      inventory[definition.name] = remaining;
    }

    var points = currentPlayer.points;
    final events = <GameEvent>[
      PlayerItemConsumed(
        playerId: currentPlayer.id,
        itemName: definition.name,
        quantity: 1,
        totalQuantity: remaining,
      ),
    ];

    switch (definition.actionType) {
      case ItemUseActionType.changePoints:
        final delta = definition.pointsDelta;
        points += delta;
        events.add(
          PlayerPointsChanged(
            playerId: currentPlayer.id,
            delta: delta,
            points: points,
          ),
        );
    }

    final players = List.of(state.players);
    players[state.currentPlayerIndex] = currentPlayer.copyWith(
      points: points,
      inventory: Map<String, int>.unmodifiable(inventory),
    );

    return GameTurnResult(
      state: state.copyWith(players: players),
      events: List<GameEvent>.unmodifiable(events),
    );
  }
}
