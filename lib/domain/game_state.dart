import 'board.dart';
import 'player.dart';

enum GameStatus { playing, finished }

class GameState {
  const GameState({
    required this.board,
    required this.players,
    required this.currentPlayerIndex,
    required this.turn,
    required this.status,
    this.diceResult,
  });

  final Board board;
  final List<Player> players;
  final int currentPlayerIndex;
  final int turn;
  final int? diceResult;
  final GameStatus status;

  Player get currentPlayer => players[currentPlayerIndex];

  GameState copyWith({
    List<Player>? players,
    int? currentPlayerIndex,
    int? turn,
    int? diceResult,
    bool clearDiceResult = false,
    GameStatus? status,
  }) {
    return GameState(
      board: board,
      players: players ?? this.players,
      currentPlayerIndex: currentPlayerIndex ?? this.currentPlayerIndex,
      turn: turn ?? this.turn,
      diceResult: clearDiceResult ? null : diceResult ?? this.diceResult,
      status: status ?? this.status,
    );
  }
}
