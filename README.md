# Sugoroku Studio

A customizable sugoroku board game maker built with Flutter.

## Current MVP

Issue #1 の v0.1〜v0.2 を基準に、コースを作って1人で遊べる最初の縦スライスを実装しています。

- コース一覧
- 新規コース作成
- コース名編集
- スタート／通常／ゴールマスの追加
- マスのドラッグによる自由配置
- 通常マスのタップ編集
- 一本道の接続
- コースのローカルJSON保存・読込・削除
- 1人プレイ
- 1〜6のサイコロ
- 1マスずつの駒移動表示
- ゴール判定
- Nマス進む
- Nマス戻る
- スタートに戻る
- 1回休み
- もう一度サイコロを振る
- 効果による移動先の特殊マスを続けて解決
- Board / Square / Connection / Effect の分離
- GameEngine / GameEvent とUIの分離
- Human / CPU 共通 Player モデルの土台
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
│  ├─ game_state.dart
│  ├─ game_event.dart
│  └─ game_engine.dart
└─ presentation/
   ├─ course_list_screen.dart
   ├─ course_editor_screen.dart
   ├─ effect_text.dart
   ├─ play_screen.dart
   └─ widgets/
```

画面上の座標 (`BoardPosition`) とゲーム上の経路 (`BoardConnection`) は別データです。マス効果 (`SquareEffect`) もマス本体から分離しています。

特殊マスは `GameEngine` が `SquareEffect` を解決し、移動や効果発動を `GameEvent` として発行します。UIはイベント列を使って駒移動やメッセージを表示するため、今後CPUやアニメーションを追加してもゲームルールをUIへ埋め込まずに拡張できます。

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

v0.1 のコース作成・1人プレイと v0.2 の基本特殊マスまで実装済みです。次の大きな候補は v0.3 のCPUプレイヤー、ローカル複数人、プレイヤー設定、基本アニメーション／エフェクトです。
