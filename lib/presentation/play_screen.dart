import 'package:flutter/material.dart';

import '../domain/board.dart';
import '../domain/game_engine.dart';
import '../domain/game_event.dart';
import '../domain/game_state.dart';
import '../domain/player.dart';
import 'effect_text.dart';
import 'widgets/board_painter.dart';

class PlayScreen extends StatefulWidget {
  const PlayScreen({required this.board, super.key});

  final Board board;

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen> {
  static const Size _canvasSize = Size(900, 600);
  static const double _squareSize = BoardConnectionPainter.squareSize;

  late final GameEngine _engine;
  late GameState _state;
  late String _displaySquareId;
  bool _rolling = false;
  String _message = 'サイコロを振ってスタート！';

  @override
  void initState() {
    super.initState();
    _engine = GameEngine();
    _state = _engine.createGame(
      board: widget.board,
      players: const [
        Player(
          id: 'human-1',
          name: 'プレイヤー1',
          type: PlayerType.human,
          currentSquareId: '',
        ),
      ],
    );
    _displaySquareId = _state.currentPlayer.currentSquareId;
  }

  String _resultMessage(GameTurnResult result) {
    if (result.events.any((event) => event is GoalReached)) {
      return 'ゴール！ 🎉';
    }
    if (result.events.any((event) => event is PlayerTurnSkipped)) {
      return '1回休み！ このターンはサイコロを振りませんでした';
    }
    if (result.events.any((event) => event is ExtraRollGranted)) {
      return 'もう一度サイコロを振れます！';
    }

    SquareEffectApplied? appliedEffect;
    for (final event in result.events) {
      if (event is SquareEffectApplied) appliedEffect = event;
    }
    if (appliedEffect != null) {
      switch (appliedEffect.effect.actionType) {
        case EffectActionType.skipTurn:
          return '${effectDescription(appliedEffect.effect)}！ 次のターンは休みです';
        case EffectActionType.moveBy:
        case EffectActionType.moveToStart:
          return '${effectDescription(appliedEffect.effect)}！';
        case EffectActionType.rollAgain:
          return 'もう一度サイコロを振れます！';
        case EffectActionType.warpTo:
          return effectDescription(appliedEffect.effect);
      }
    }
    return '次のサイコロを振りましょう';
  }

  Future<void> _rollDice() async {
    if (_rolling || _state.status == GameStatus.finished) return;
    setState(() => _rolling = true);

    final result = _engine.rollCurrentPlayer(_state);
    final skipped = result.events.any((event) => event is PlayerTurnSkipped);
    if (skipped) {
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      setState(() {
        _state = result.state;
        _message = _resultMessage(result);
        _rolling = false;
      });
      return;
    }

    final dice = result.state.diceResult;
    if (dice != null) {
      setState(() => _message = '🎲 $dice が出ました');
    }

    for (final event in result.events) {
      if (event is! PlayerMoved) continue;
      await Future<void>.delayed(const Duration(milliseconds: 220));
      if (!mounted) return;
      setState(() => _displaySquareId = event.toSquareId);
    }

    if (!mounted) return;
    setState(() {
      _state = result.state;
      _displaySquareId = result.state.players.first.currentSquareId;
      _message = _resultMessage(result);
      _rolling = false;
    });
  }

  Color _colorFor(BoardSquare square) {
    if (square.kind == SquareKind.start) return Colors.green.shade300;
    if (square.kind == SquareKind.goal) return Colors.amber.shade300;
    if (square.effects.isEmpty) return Colors.blue.shade200;

    final effect = square.effects.first;
    switch (effect.actionType) {
      case EffectActionType.moveBy:
        final rawSteps = effect.parameters['steps'];
        final steps = rawSteps is num ? rawSteps.toInt() : 0;
        return steps < 0 ? Colors.orange.shade200 : Colors.teal.shade200;
      case EffectActionType.moveToStart:
        return Colors.red.shade200;
      case EffectActionType.skipTurn:
        return Colors.purple.shade200;
      case EffectActionType.rollAgain:
        return Colors.lime.shade300;
      case EffectActionType.warpTo:
        return Colors.indigo.shade200;
    }
  }

  @override
  Widget build(BuildContext context) {
    final displaySquare = widget.board.squares.firstWhere(
      (square) => square.id == _displaySquareId,
    );

    return Scaffold(
      appBar: AppBar(title: Text(widget.board.name)),
      body: Column(
        children: [
          Expanded(
            child: InteractiveViewer(
              constrained: false,
              minScale: 0.5,
              maxScale: 2.5,
              boundaryMargin: const EdgeInsets.all(160),
              child: SizedBox(
                width: _canvasSize.width,
                height: _canvasSize.height,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: BoardConnectionPainter(board: widget.board),
                      ),
                    ),
                    for (final square in widget.board.squares)
                      Positioned(
                        left: square.position.x,
                        top: square.position.y,
                        width: _squareSize,
                        height: _squareSize,
                        child: Material(
                          color: _colorFor(square),
                          borderRadius: BorderRadius.circular(18),
                          elevation: 3,
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(5),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    square.label,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                  if (square.effects.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      squareEffectSummary(square),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 8),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      left: displaySquare.position.x + 23,
                      top: displaySquare.position.y - 20,
                      width: 28,
                      height: 28,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: const [
                            BoxShadow(blurRadius: 6, color: Colors.black26),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Material(
            elevation: 10,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _state.status == GameStatus.finished
                                ? 'ゲーム終了'
                                : 'ターン ${_state.turn}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(_message),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _rolling || _state.status == GameStatus.finished
                          ? null
                          : _rollDice,
                      icon: _rolling
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.casino_outlined),
                      label: Text(
                        _state.status == GameStatus.finished ? 'ゴール' : '振る',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
