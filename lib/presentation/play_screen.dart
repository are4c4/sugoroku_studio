import 'package:flutter/material.dart';

import '../domain/board.dart';
import '../domain/cpu_strategy.dart';
import '../domain/game_engine.dart';
import '../domain/game_event.dart';
import '../domain/game_state.dart';
import '../domain/player.dart';
import 'effect_text.dart';
import 'widgets/board_painter.dart';
import 'widgets/game_effects.dart';

class PlayScreen extends StatefulWidget {
  const PlayScreen({
    required this.board,
    required this.players,
    super.key,
  });

  final Board board;
  final List<Player> players;

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen> {
  static const Size _canvasSize = Size(900, 600);
  static const double _squareSize = BoardConnectionPainter.squareSize;

  late final GameEngine _engine;
  late GameState _state;
  late Map<String, String> _displaySquareIds;
  bool _rolling = false;
  bool _cpuTurnScheduled = false;
  bool _diceRolling = false;
  int? _diceFace;
  String? _activatedSquareId;
  String? _effectBanner;
  String? _winnerName;
  String _message = '';

  @override
  void initState() {
    super.initState();
    _engine = GameEngine();
    _state = _engine.createGame(board: widget.board, players: widget.players);
    _displaySquareIds = {
      for (final player in _state.players) player.id: player.currentSquareId,
    };
    _message = '${_state.currentPlayer.name}のターンです';
    WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleCpuTurn());
  }

  String _resultMessage(GameTurnResult result, Player actingPlayer) {
    if (result.events.any((event) => event is GoalReached)) {
      return '${actingPlayer.name}がゴール！ 🎉';
    }
    if (result.events.any((event) => event is PlayerTurnSkipped)) {
      return '${actingPlayer.name}は1回休みです';
    }
    if (result.events.any((event) => event is ExtraRollGranted)) {
      return '${actingPlayer.name}はもう一度サイコロを振れます！';
    }

    SquareEffectApplied? appliedEffect;
    for (final event in result.events) {
      if (event is SquareEffectApplied) appliedEffect = event;
    }
    if (appliedEffect != null) {
      switch (appliedEffect.effect.actionType) {
        case EffectActionType.skipTurn:
          return '${actingPlayer.name}: ${effectDescription(appliedEffect.effect)}！ 次回は休みです';
        case EffectActionType.moveBy:
        case EffectActionType.moveToStart:
        case EffectActionType.warpTo:
          return '${actingPlayer.name}: ${effectDescription(appliedEffect.effect)}！';
        case EffectActionType.rollAgain:
          return '${actingPlayer.name}はもう一度サイコロを振れます！';
        case EffectActionType.showMessage:
          break;
        case EffectActionType.changePoints:
          final finalPlayer = result.state.players.firstWhere(
            (player) => player.id == actingPlayer.id,
            orElse: () => actingPlayer,
          );
          return '${actingPlayer.name}: ★ ${finalPlayer.points}pt';
        case EffectActionType.grantItem:
          final finalPlayer = result.state.players.firstWhere(
            (player) => player.id == actingPlayer.id,
            orElse: () => actingPlayer,
          );
          return '${actingPlayer.name}: 🎒 ${finalPlayer.totalItems}個所持';
        case EffectActionType.randomEvent:
          return '${actingPlayer.name}: 🎰 ランダムイベント！';
      }
    }
    return '次は${result.state.currentPlayer.name}のターンです';
  }

  String _routeDistanceLabel(BoardSquare option) {
    final distance = widget.board.shortestDistanceToGoal(option.id);
    if (distance == null) return 'この先からゴールへ到達できません';
    return 'ゴールまで最短 $distance マス';
  }

  String _cpuStrategyLabel(CpuStrategyType strategy) {
    return switch (strategy) {
      CpuStrategyType.shortestPath => '最短',
      CpuStrategyType.cautious => '安全',
      CpuStrategyType.rewardSeeking => '報酬',
    };
  }

  void _scheduleCpuTurn() {
    if (!mounted ||
        _rolling ||
        _cpuTurnScheduled ||
        _state.status == GameStatus.finished ||
        _state.currentPlayer.type != PlayerType.cpu) {
      return;
    }

    _cpuTurnScheduled = true;
    Future<void>.delayed(const Duration(milliseconds: 800), () async {
      if (!mounted) return;
      _cpuTurnScheduled = false;
      if (_rolling ||
          _state.status == GameStatus.finished ||
          _state.currentPlayer.type != PlayerType.cpu) {
        return;
      }
      setState(() => _message = '${_state.currentPlayer.name}がサイコロを振ります…');
      await _runCurrentTurn();
    });
  }

  Future<String> _selectRoute(RouteChoiceContext choice) async {
    if (choice.player.type == PlayerType.cpu) {
      final strategy = cpuStrategyFor(choice.player.cpuStrategy);
      return strategy.chooseNextSquare(
        board: choice.board,
        player: choice.player,
        from: choice.fromSquare,
        options: choice.options,
      );
    }

    if (!mounted) return choice.options.first.id;
    final selected = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('進むルートを選択'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${choice.fromSquare.label}から分岐します。残り${choice.remainingSteps}マスです。',
              ),
              const SizedBox(height: 12),
              for (final option in choice.options)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(dialogContext, option.id),
                    icon: const Icon(Icons.alt_route),
                    label: Align(
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(option.label),
                          Text(
                            _routeDistanceLabel(option),
                            style: Theme.of(dialogContext).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    return selected ?? choice.options.first.id;
  }

  Future<void> _animateDice(int finalValue) async {
    if (!mounted) return;
    setState(() {
      _diceRolling = true;
      _effectBanner = null;
      _activatedSquareId = null;
    });

    for (var frame = 0; frame < 10; frame++) {
      await Future<void>.delayed(const Duration(milliseconds: 55));
      if (!mounted) return;
      setState(() => _diceFace = (frame % 6) + 1);
    }

    if (!mounted) return;
    setState(() {
      _diceFace = finalValue;
      _diceRolling = false;
    });
    await Future<void>.delayed(const Duration(milliseconds: 180));
  }

  Future<void> _showEffect(String squareId, String message) async {
    if (!mounted) return;
    setState(() {
      _activatedSquareId = squareId;
      _effectBanner = message;
    });
    await Future<void>.delayed(const Duration(milliseconds: 620));
    if (!mounted) return;
    setState(() {
      _activatedSquareId = null;
      _effectBanner = null;
    });
  }

  String _randomOutcomeMessage(RandomEventOption option) {
    switch (option.outcomeType) {
      case RandomEventOutcomeType.showMessage:
        final rawMessage = option.parameters['message'];
        final message = rawMessage is String ? rawMessage.trim() : '';
        return message.isEmpty
            ? '🎰 ${option.label}'
            : '🎰 ${option.label}：$message';
      case RandomEventOutcomeType.changePoints:
        return '🎰 ${option.label}';
      case RandomEventOutcomeType.grantItem:
        return '🎰 ${option.label}';
    }
  }

  Future<void> _playEvents(
    GameTurnResult result,
    Player actingPlayer, {
    required bool diceAlreadyAnimated,
  }) async {
    final finalPlayer = result.state.players.firstWhere(
      (player) => player.id == actingPlayer.id,
      orElse: () => actingPlayer,
    );

    for (final event in result.events) {
      if (!mounted) return;

      if (event is DiceRolled) {
        if (!diceAlreadyAnimated) {
          setState(
            () => _message = '${actingPlayer.name}がサイコロを振っています…',
          );
          await _animateDice(event.value);
        }
        if (!mounted) return;
        setState(() => _message = '${actingPlayer.name}: 🎲 ${event.value}');
        continue;
      }

      if (event is RouteChosen) {
        final target = widget.board.squareById(event.toSquareId);
        await _showEffect(
          event.fromSquareId,
          '↗ ${target?.label ?? '選択したルート'}へ進みます',
        );
        continue;
      }

      if (event is PlayerMoved) {
        setState(() => _displaySquareIds[event.playerId] = event.toSquareId);
        await Future<void>.delayed(const Duration(milliseconds: 270));
        continue;
      }

      if (event is SquarePassed) {
        setState(() => _activatedSquareId = event.squareId);
        await Future<void>.delayed(const Duration(milliseconds: 120));
        continue;
      }

      if (event is SquareActivated) {
        setState(() => _activatedSquareId = event.squareId);
        await Future<void>.delayed(const Duration(milliseconds: 160));
        continue;
      }

      if (event is SquareEffectApplied) {
        if (event.effect.actionType == EffectActionType.changePoints ||
            event.effect.actionType == EffectActionType.grantItem) {
          continue;
        }
        if (event.effect.actionType == EffectActionType.randomEvent) {
          await _showEffect(event.squareId, '🎰 ランダムイベントを抽選中…');
          continue;
        }
        final message = effectMessage(event.effect);
        await _showEffect(
          event.squareId,
          event.effect.actionType == EffectActionType.showMessage
              ? '💬 ${message.isEmpty ? 'メッセージ' : message}'
              : '✨ ${effectDescription(event.effect)}',
        );
        continue;
      }

      if (event is RandomEventChosen) {
        await _showEffect(
          event.squareId,
          _randomOutcomeMessage(event.option),
        );
        continue;
      }

      if (event is PlayerPointsChanged) {
        final sign = event.delta > 0 ? '+' : '';
        await _showEffect(
          finalPlayer.currentSquareId,
          '⭐ $sign${event.delta}pt → ${event.points}pt',
        );
        continue;
      }

      if (event is PlayerItemGranted) {
        await _showEffect(
          finalPlayer.currentSquareId,
          '🎒 「${event.itemName}」×${event.quantity} → 所持${event.totalQuantity}個',
        );
        continue;
      }

      if (event is ExtraRollGranted) {
        await _showEffect(
          finalPlayer.currentSquareId,
          '🎲 もう一度振れます！',
        );
        continue;
      }

      if (event is PlayerTurnSkipped) {
        await _showEffect(
          actingPlayer.currentSquareId,
          '⏸ ${actingPlayer.name}は1回休み',
        );
        continue;
      }

      if (event is GoalReached) {
        setState(() {
          _winnerName = actingPlayer.name;
          _activatedSquareId = null;
          _effectBanner = null;
        });
        await Future<void>.delayed(const Duration(milliseconds: 900));
      }
    }
  }

  Future<void> _runCurrentTurn() async {
    if (_rolling || _state.status == GameStatus.finished) return;

    final actingPlayer = _state.currentPlayer;
    setState(() => _rolling = true);

    int? rolledDice;
    if (actingPlayer.skipTurns == 0) {
      rolledDice = _engine.rollDice();
      setState(() => _message = '${actingPlayer.name}がサイコロを振っています…');
      await _animateDice(rolledDice);
      if (!mounted) return;
      setState(() => _message = '${actingPlayer.name}: 🎲 $rolledDice');
    }

    final result = await _engine.rollCurrentPlayer(
      _state,
      dice: rolledDice,
      routeSelector: _selectRoute,
    );
    await _playEvents(
      result,
      actingPlayer,
      diceAlreadyAnimated: rolledDice != null,
    );
    if (!mounted) return;

    setState(() {
      _state = result.state;
      _displaySquareIds = {
        for (final player in result.state.players)
          player.id: player.currentSquareId,
      };
      _message = _resultMessage(result, actingPlayer);
      _activatedSquareId = null;
      _effectBanner = null;
      _rolling = false;
    });
    _scheduleCpuTurn();
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
      case EffectActionType.showMessage:
        return Colors.cyan.shade200;
      case EffectActionType.changePoints:
        return Colors.yellow.shade300;
      case EffectActionType.grantItem:
        return Colors.lightGreen.shade300;
      case EffectActionType.randomEvent:
        return Colors.pink.shade200;
    }
  }

  Color _playerColor(int index) {
    const colors = <Color>[
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.brown,
    ];
    return colors[index % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final currentIsHuman = _state.currentPlayer.type == PlayerType.human;

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
                        child: AnimatedScale(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOutBack,
                          scale: _activatedSquareId == square.id ? 1.13 : 1,
                          child: Material(
                            color: _colorFor(square),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                              side: _activatedSquareId == square.id
                                  ? BorderSide(
                                      color: Theme.of(context).colorScheme.primary,
                                      width: 4,
                                    )
                                  : BorderSide.none,
                            ),
                            elevation: _activatedSquareId == square.id ? 10 : 3,
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
                                    if (widget.board
                                            .outgoingSquares(square.id)
                                            .length >
                                        1)
                                      const Text(
                                        '分岐',
                                        style: TextStyle(
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    for (var index = 0;
                        index < _state.players.length;
                        index++)
                      Builder(
                        builder: (context) {
                          final player = _state.players[index];
                          final squareId = _displaySquareIds[player.id] ??
                              player.currentSquareId;
                          final square = widget.board.squares.firstWhere(
                            (item) => item.id == squareId,
                          );
                          return AnimatedPositioned(
                            key: ValueKey(player.id),
                            duration: const Duration(milliseconds: 230),
                            curve: Curves.easeInOutCubic,
                            left: square.position.x + 6 + (index % 3) * 23,
                            top: square.position.y - 15 + (index ~/ 3) * 24,
                            width: 22,
                            height: 22,
                            child: AnimatedScale(
                              duration: const Duration(milliseconds: 180),
                              scale: player.id == actingPlayerId ? 1.18 : 1,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: _playerColor(index),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                  boxShadow: const [
                                    BoxShadow(blurRadius: 4, color: Colors.black26),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    '${index + 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    Positioned(
                      top: 20,
                      left: (_canvasSize.width - 72) / 2,
                      child: DiceDisplay(
                        value: _diceFace ?? _state.diceResult,
                        rolling: _diceRolling,
                      ),
                    ),
                    if (_effectBanner != null)
                      Positioned(
                        top: 112,
                        left: 180,
                        right: 180,
                        child: EffectBanner(message: _effectBanner!),
                      ),
                    if (_winnerName != null)
                      GoalCelebrationOverlay(playerName: _winnerName!),
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
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (var index = 0;
                              index < _state.players.length;
                              index++) ...[
                            Chip(
                              avatar: CircleAvatar(
                                backgroundColor: _playerColor(index),
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                              label: Text(
                                '${_state.players[index].name}${_state.players[index].type == PlayerType.cpu ? ' (CPU・${_cpuStrategyLabel(_state.players[index].cpuStrategy)})' : ''} · ★ ${_state.players[index].points}pt · 🎒 ${_state.players[index].totalItems}',
                              ),
                              backgroundColor:
                                  index == _state.currentPlayerIndex
                                      ? Theme.of(context)
                                          .colorScheme
                                          .secondaryContainer
                                      : null,
                            ),
                            const SizedBox(width: 6),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _state.status == GameStatus.finished
                                    ? 'ゲーム終了'
                                    : 'ターン ${_state.turn}・${_state.currentPlayer.name}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(_message),
                            ],
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: !_rolling &&
                                  _state.status != GameStatus.finished &&
                                  currentIsHuman
                              ? _runCurrentTurn
                              : null,
                          icon: _rolling
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : currentIsHuman
                                  ? const Icon(Icons.casino_outlined)
                                  : const Icon(Icons.smart_toy_outlined),
                          label: Text(
                            _state.status == GameStatus.finished
                                ? 'ゴール'
                                : currentIsHuman
                                    ? '振る'
                                    : 'CPUターン',
                          ),
                        ),
                      ],
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

  String? get actingPlayerId => _rolling ? _state.currentPlayer.id : null;
}
