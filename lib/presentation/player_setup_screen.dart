import 'package:flutter/material.dart';

import '../core/id.dart';
import '../domain/board.dart';
import '../domain/player.dart';
import 'play_screen.dart';

class PlayerSetupScreen extends StatefulWidget {
  const PlayerSetupScreen({required this.board, super.key});

  final Board board;

  @override
  State<PlayerSetupScreen> createState() => _PlayerSetupScreenState();
}

class _PlayerDraft {
  _PlayerDraft({required String name, required this.type})
      : controller = TextEditingController(text: name),
        cpuStrategy = CpuStrategyType.shortestPath;

  final TextEditingController controller;
  PlayerType type;
  CpuStrategyType cpuStrategy;

  void dispose() => controller.dispose();
}

class _PlayerSetupScreenState extends State<PlayerSetupScreen> {
  final List<_PlayerDraft> _players = [
    _PlayerDraft(name: 'プレイヤー1', type: PlayerType.human),
  ];

  @override
  void dispose() {
    for (final player in _players) {
      player.dispose();
    }
    super.dispose();
  }

  void _addPlayer(PlayerType type) {
    setState(() {
      final number = _players.length + 1;
      _players.add(
        _PlayerDraft(
          name: type == PlayerType.cpu ? 'CPU$number' : 'プレイヤー$number',
          type: type,
        ),
      );
    });
  }

  void _removePlayer(int index) {
    if (_players.length <= 1) return;
    final removed = _players.removeAt(index);
    removed.dispose();
    setState(() {});
  }

  void _startGame() {
    final players = <Player>[
      for (var index = 0; index < _players.length; index++)
        Player(
          id: createId('player'),
          name: _players[index].controller.text.trim().isEmpty
              ? (_players[index].type == PlayerType.cpu
                  ? 'CPU${index + 1}'
                  : 'プレイヤー${index + 1}')
              : _players[index].controller.text.trim(),
          type: _players[index].type,
          currentSquareId: '',
          cpuStrategy: _players[index].cpuStrategy,
        ),
    ];

    Navigator.of(context).pushReplacement<void, void>(
      MaterialPageRoute<void>(
        builder: (_) => PlayScreen(board: widget.board, players: players),
      ),
    );
  }

  String _typeLabel(PlayerType type) {
    return switch (type) {
      PlayerType.human => '人間',
      PlayerType.cpu => 'CPU',
    };
  }

  IconData _typeIcon(PlayerType type) {
    return switch (type) {
      PlayerType.human => Icons.person_outline,
      PlayerType.cpu => Icons.smart_toy_outlined,
    };
  }

  String _strategyLabel(CpuStrategyType strategy) {
    return switch (strategy) {
      CpuStrategyType.shortestPath => '最短ルート',
      CpuStrategyType.cautious => '安全重視',
      CpuStrategyType.rewardSeeking => '報酬重視',
    };
  }

  String _strategyDescription(CpuStrategyType strategy) {
    return switch (strategy) {
      CpuStrategyType.shortestPath => 'ゴールまでの残りマス数を最優先します。',
      CpuStrategyType.cautious => '休み・後退・ポイント損失などの危険を避けます。',
      CpuStrategyType.rewardSeeking => 'ポイント・アイテム・再ロールなどの報酬を狙います。',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('プレイヤー設定')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  Text(
                    widget.board.name,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 4),
                  const Text('1人プレイ、ローカル複数人、人間 + CPUを自由に組み合わせられます。'),
                  const SizedBox(height: 20),
                  for (var index = 0; index < _players.length; index++) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(child: Text('${index + 1}')),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                children: [
                                  TextField(
                                    controller: _players[index].controller,
                                    decoration: const InputDecoration(
                                      labelText: '名前',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  DropdownButtonFormField<PlayerType>(
                                    initialValue: _players[index].type,
                                    decoration: const InputDecoration(
                                      labelText: 'プレイヤー種別',
                                      border: OutlineInputBorder(),
                                    ),
                                    items: [
                                      for (final type in PlayerType.values)
                                        DropdownMenuItem(
                                          value: type,
                                          child: Row(
                                            children: [
                                              Icon(_typeIcon(type), size: 20),
                                              const SizedBox(width: 8),
                                              Text(_typeLabel(type)),
                                            ],
                                          ),
                                        ),
                                    ],
                                    onChanged: (type) {
                                      if (type == null) return;
                                      setState(() => _players[index].type = type);
                                    },
                                  ),
                                  if (_players[index].type == PlayerType.cpu) ...[
                                    const SizedBox(height: 10),
                                    DropdownButtonFormField<CpuStrategyType>(
                                      initialValue: _players[index].cpuStrategy,
                                      decoration: const InputDecoration(
                                        labelText: 'CPU Strategy',
                                        border: OutlineInputBorder(),
                                      ),
                                      items: [
                                        for (final strategy
                                            in CpuStrategyType.values)
                                          DropdownMenuItem(
                                            value: strategy,
                                            child: Text(_strategyLabel(strategy)),
                                          ),
                                      ],
                                      onChanged: (strategy) {
                                        if (strategy == null) return;
                                        setState(
                                          () => _players[index].cpuStrategy = strategy,
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 6),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        _strategyDescription(
                                          _players[index].cpuStrategy,
                                        ),
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: '削除',
                              onPressed: _players.length > 1
                                  ? () => _removePlayer(index)
                                  : null,
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _addPlayer(PlayerType.human),
                          icon: const Icon(Icons.person_add_alt_1_outlined),
                          label: const Text('人間を追加'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _addPlayer(PlayerType.cpu),
                          icon: const Icon(Icons.smart_toy_outlined),
                          label: const Text('CPUを追加'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Material(
              elevation: 8,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _startGame,
                    icon: const Icon(Icons.play_arrow),
                    label: Text('${_players.length}人でゲーム開始'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
