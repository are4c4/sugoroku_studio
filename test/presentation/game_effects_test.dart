import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugoroku_studio/presentation/widgets/game_effects.dart';

void main() {
  testWidgets('dice display renders the selected face', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DiceDisplay(value: 4, rolling: false),
        ),
      ),
    );

    expect(find.text('⚃'), findsOneWidget);
  });

  testWidgets('effect banner shows the event message', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EffectBanner(message: '3マス進む'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('3マス進む'), findsOneWidget);
  });

  testWidgets('goal overlay shows the winner', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              GoalCelebrationOverlay(playerName: 'プレイヤー1'),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('プレイヤー1 ゴール！'), findsOneWidget);
    expect(find.text('🎉'), findsOneWidget);
  });
}
