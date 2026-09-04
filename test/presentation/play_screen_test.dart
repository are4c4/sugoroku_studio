import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sugoroku_studio/domain/board.dart';
import 'package:sugoroku_studio/domain/item_definition.dart';
import 'package:sugoroku_studio/domain/player.dart';
import 'package:sugoroku_studio/presentation/play_screen.dart';

Board createOneStepBoard() {
  return Board(
    id: 'board',
    name: 'Test Board',
    squares: const [
      BoardSquare(
        id: 'start',
        label: 'Start',
        position: BoardPosition(x: 100, y: 200),
        kind: SquareKind.start,
      ),
      BoardSquare(
        id: 'goal',
        label: 'Goal',
        position: BoardPosition(x: 300, y: 200),
        kind: SquareKind.goal,
      ),
    ],
    connections: const [
      BoardConnection(fromSquareId: 'start', toSquareId: 'goal'),
    ],
    updatedAt: DateTime(2026, 9, 4),
  );
}

Board createUsableItemBoard() {
  return createOneStepBoard().copyWith(
    itemDefinitions: const [
      ItemDefinition(
        name: 'Potion',
        description: 'ポイントを回復',
        actionType: ItemUseActionType.changePoints,
        parameters: {'points': 5},
      ),
    ],
  );
}

Future<void> pumpFor(
  WidgetTester tester,
  Duration duration, {
  Duration step = const Duration(milliseconds: 100),
}) async {
  var elapsed = Duration.zero;
  while (elapsed < duration) {
    await tester.pump(step);
    elapsed += step;
  }
}

void main() {
  testWidgets('human skip turn is disabled and consumed automatically', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PlayScreen(
          board: createOneStepBoard(),
          players: const [
            Player(
              id: 'p1',
              name: 'プレイヤー1',
              type: PlayerType.human,
              currentSquareId: '',
              skipTurns: 1,
            ),
            Player(
              id: 'p2',
              name: 'プレイヤー2',
              type: PlayerType.human,
              currentSquareId: '',
            ),
          ],
        ),
      ),
    );

    expect(find.text('1回休み'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);

    await pumpFor(tester, const Duration(milliseconds: 1700));

    expect(find.text('ターン 2・プレイヤー2'), findsOneWidget);
    expect(find.text('振る'), findsOneWidget);
  });

  testWidgets('goal screen can restart the same game', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PlayScreen(
          board: createOneStepBoard(),
          players: const [
            Player(
              id: 'p1',
              name: 'プレイヤー1',
              type: PlayerType.human,
              currentSquareId: '',
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.text('振る'));
    await pumpFor(tester, const Duration(milliseconds: 2600));

    expect(find.text('ゲーム終了'), findsOneWidget);
    expect(find.text('もう一度'), findsOneWidget);
    expect(find.text('終了'), findsOneWidget);

    await tester.tap(find.text('もう一度'));
    await tester.pump();

    expect(find.text('ターン 1・プレイヤー1'), findsOneWidget);
    expect(find.text('振る'), findsOneWidget);
    expect(find.text('ゲーム終了'), findsNothing);
  });

  testWidgets('human can use a defined item without ending the turn', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PlayScreen(
          board: createUsableItemBoard(),
          players: const [
            Player(
              id: 'p1',
              name: 'プレイヤー1',
              type: PlayerType.human,
              currentSquareId: '',
              inventory: {'Potion': 2},
            ),
          ],
        ),
      ),
    );

    final itemButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'アイテム'),
    );
    expect(itemButton.onPressed, isNotNull);

    await tester.tap(find.text('アイテム'));
    await tester.pumpAndSettle();

    expect(find.text('Potion ×2'), findsOneWidget);
    expect(find.textContaining('使うと +5pt'), findsOneWidget);

    await tester.tap(find.text('使う'));
    await pumpFor(tester, const Duration(milliseconds: 1700));

    expect(find.text('ターン 1・プレイヤー1'), findsOneWidget);
    expect(find.textContaining('★ 5pt'), findsOneWidget);
    expect(find.text('振る'), findsOneWidget);

    await tester.tap(find.text('アイテム'));
    await tester.pumpAndSettle();
    expect(find.text('Potion ×1'), findsOneWidget);
  });

  testWidgets('item button is disabled for inventory without definitions', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PlayScreen(
          board: createUsableItemBoard(),
          players: const [
            Player(
              id: 'p1',
              name: 'プレイヤー1',
              type: PlayerType.human,
              currentSquareId: '',
              inventory: {'Unknown': 1},
            ),
          ],
        ),
      ),
    );

    final itemButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'アイテム'),
    );
    expect(itemButton.onPressed, isNull);
    expect(find.text('振る'), findsOneWidget);
  });
}
