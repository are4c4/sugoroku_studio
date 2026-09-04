# Sugoroku Studio

A customizable sugoroku board game maker built with Flutter.

## Current MVP

Issue #1 の v0.1〜v0.5 を基準に、コースを作成し、人間やCPUと実際に遊べる縦スライスを実装しています。

- コース一覧
- 新規コース作成
- コース名編集
- スタート／通常／ゴールマスの追加
- マスのドラッグによる自由配置
- 通常マスのタップ編集
- マスごとの接続先編集
- 一本道／分岐コース
- 接続方向の矢印表示
- コースのローカルJSON保存・読込・削除
- 1人プレイ
- ローカル複数人プレイ
- 人間 + CPU の混在プレイ
- CPUターンの自動実行
- 人間/CPU共通の休みターン自動消化
- ゴール後のリプレイ / 終了操作
- プレイヤー名・人間/CPU設定
- CPUごとのStrategy設定（最短 / 安全重視 / 報酬重視）
- プレイヤーごとのポイント
- プレイヤーごとの所持アイテム
- 人間プレイヤーの分岐ルート選択
- CPU Strategyによる分岐ルート選択
- 1〜6のサイコロ
- サイコロロール演出
- 1マスずつの駒移動アニメーション
- 特殊マス発動の強調・バナー表示
- ゴール時の紙吹雪・ゴール表示
- ゴール判定
- Nマス進む
- Nマス戻る
- スタートに戻る
- N回休み
- もう一度サイコロを振る
- 指定マスへのワープ
- メッセージを表示
- ポイントを増減
- アイテムを付与
- ランダムイベント（メッセージ / ポイント / アイテム候補）
- 1つのマスに複数効果を設定
- Trigger / Condition / Action のブロック型効果編集
- 「止まったとき (`onLand`)」Trigger
- 「通過したとき (`onPass`)」Trigger（現在はメッセージAction対応）
- 条件なし / ポイントがN以上 / ポイントがN以下
- 指定アイテムを所持 / 指定アイテムをN個以上所持
- 効果の追加・編集・削除・実行順の並べ替え
- 複数効果を保存順に実行
- 効果による移動先の特殊マスを続けて解決
- 分岐後の「戻る」で実際に通ったルートを逆走
- Board / Square / Connection / Effect の分離
- GameEngine / GameEvent とUIの分離
- Human / CPU 共通 Player モデル
- Flutter analyze / test のGitHub Actions

## Architecture

```text
lib/
├─ core/
├─ data/
│  ├─ course_repository.dart
│  └─ local_course_repository.dart
├─ domain/
│  ├─ board.dart
│  ├─ player.dart
│  ├─ cpu_strategy.dart
│  ├─ game_state.dart
│  ├─ game_event.dart
│  └─ game_engine.dart
└─ presentation/
   ├─ course_list_screen.dart
   ├─ course_editor_screen.dart
   ├─ player_setup_screen.dart
   ├─ effect_text.dart
   ├─ random_event_editor.dart
   ├─ play_screen.dart
   └─ widgets/
      ├─ board_painter.dart
      └─ game_effects.dart
```

画面上の座標 (`BoardPosition`) とゲーム上の経路 (`BoardConnection`) は別データです。マス効果 (`SquareEffect`) もマス本体から分離しています。

`Board` は複数の outgoing connection を持つグラフとして扱います。`GameEngine` は分岐点で `RouteSelector` を呼び出し、人間プレイヤーはUIで進路を選択します。CPUは `Player.cpuStrategy` に応じて `CpuStrategy` を差し替え、最短ルート・安全重視・報酬重視から進路を決定します。複数CPUが参加する場合も、それぞれ別のStrategyを設定できます。プレイヤーには実際に通った `routeHistory` を保持するため、分岐後の「Nマス戻る」も選んだ経路を正しく逆走できます。

`ShortestPathCpuStrategy` はゴールまでの距離を最優先します。`CautiousCpuStrategy` は休み・後退・スタート戻り・ポイント損失・ランダムイベントの悪い結果などをリスクとして評価します。`RewardSeekingCpuStrategy` はポイント獲得、アイテム付与、再ロール、ランダムイベントの期待報酬などを評価します。条件付きEffectは、そのCPUの現在ポイントと所持アイテムで成立するものだけを経路評価に含めます。

通常マスは複数の `SquareEffect` を持てます。エディタでは各Effectを `Trigger -> Condition -> Action` として設定し、複数のActionを追加・編集・削除・並べ替えできます。`onLand` では移動・休み・追加ロール・ワープ・メッセージ表示・ポイント増減・アイテム付与・ランダムイベントを利用できます。`onPass` は最初の安全な縦スライスとしてメッセージ表示に対応し、プレイヤーがそのマスを通過した場合だけ発火します。停止した場合は `onPass` は発火しません。

各Effectには任意の条件を付けられます。ポイント条件に加えて「指定アイテムを持っている」「指定アイテムをN個以上持っている」を利用できます。条件を満たさないActionは発火しません。Actionは保存順に評価されるため、同じマスで先にポイントを増減した結果だけでなく、先にアイテムを獲得した結果も後続ActionのConditionから参照できます。条件がない既存データは従来どおり無条件Effectとして読み込まれます。

各 `Player` はランタイム状態として `points` と `inventory` を持ちます。`changePoints` Actionは正数・負数の両方を受け付け、`grantItem` Actionは名前付きアイテムを1個以上付与します。同名アイテムは所持数を加算し、作用したプレイヤー本人の状態だけを更新します。プレイ画面ではポイントと所持アイテム総数を表示し、付与時にはアイテム名・増加数・所持数をバナー表示します。

`randomEvent` Actionは2つ以上の `RandomEventOption` から1つを等確率で選択します。現在の候補結果はメッセージ表示、ポイント増減、アイテム付与に対応しています。抽選結果は `RandomEventChosen` としてGameEventへ流し、選択されたポイント・アイテム結果も既存の専用GameEventで処理します。移動やワープをランダム候補に含めないことで、最初の実装では再帰的な経路変更を避けています。

プレイ画面の自動ターン処理はCPUだけに限定せず、`skipTurns > 0` のプレイヤーにも適用します。そのため人間プレイヤーも「1回休み」のときにサイコロボタンを押す必要はなく、自動で休みを消化して次のプレイヤーへ進みます。ゴール後は同じBoard・Player設定から状態を再生成して「もう一度」遊ぶか、プレイ画面を終了できます。

特殊マスは `GameEngine` が `SquareEffect` を解決し、移動や効果発動を `GameEvent` として発行します。プレイ画面は `GameEvent` を順番に再生して、サイコロ、駒移動、分岐、特殊マス、メッセージ、ポイント、アイテム、ランダムイベント、ゴールの演出を行います。ゲームルールと演出を分けることで、今後アイテム消費やより一般的な条件式などを追加してもルールをUIへ埋め込まずに拡張できます。

ローカル保存は `CourseRepository` を境界にしています。現在の `LocalCourseRepository` は構造化JSONをアプリのドキュメント領域へ保存します。SQLite/Drift等へ移行する場合もUIから永続化実装を切り離せます。

## Run locally

Flutter SDK をインストール後、依存関係を取得します。

```bash
flutter pub get
```

このリポジトリは現在、アプリ本体のソースと設定を先に管理しています。clone後に対象プラットフォームのrunnerが無い場合は、一度だけFlutter標準のrunnerを生成してください。

```bash
flutter create --platforms=android,ios,macos --org com.are4c4 .
```

その後、たとえばmacOSでは次のように起動できます。

```bash
flutter run -d macos
```

## Quality checks

```bash
flutter analyze
flutter test
```

## Roadmap

設計の基準は [Issue #1](https://github.com/are4c4/sugoroku_studio/issues/1) です。

v0.1 のコース作成・基本プレイ、v0.2 の基本特殊マス、v0.3 のプレイヤー設定・CPU・ローカル複数人・基本アニメーション、v0.4 の分岐コース・ワープ・CPU経路選択まで実装済みです。v0.5 では複数効果、Trigger / Condition / Actionブロック、メッセージAction、`onLand` / `onPass` Trigger、ポイント増減、ポイント条件、アイテム付与、アイテム所持条件、ランダムイベント、高度なCPU Strategyまで実装しています。次の候補はアイテム消費、より一般的な条件式です。
