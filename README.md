# Global Market Dashboard Ultimate

## Concept

相場を見るのではなく

世界のお金の流れを見る。

---

## Features

✅ Currency Strength

✅ Best Pair

✅ Confidence

⬜ Money Flow

⬜ Bond

⬜ AI Radar

---

## Development Roadmap

Ver2.11

Ver2.20

Ver3.00

# GlobalMarketDashboard

## ディレクトリ構造

```text
GlobalMarketDashboard/
│
├── README.md
├── CHANGELOG.md
├── ROADMAP.md
├── LICENSE
│
├── docs/
│   ├── ProjectSpecification.md   ← 設計の正本
│   ├── Architecture.md
│   ├── CodingRules.md
│   ├── DevelopmentPolicy.md
│   ├── VersionRule.md
│   ├── GitRule.md
│   ├── GeneralFlow.md
│   ├── TradingGuide.md
│   ├── UserManual.md
│   ├── MeetingNotes.md
│   └── images/
│
├── src/
│   ├── MarketDashboard_Ultimate.mq5
│   │
│   ├── Modules/
│   │   ├── Core/
│   │   │   ├── Types.mqh              [2.11]
│   │   │   ├── Logger.mqh             [2.11]
│   │   │   ├── AssetDetection.mqh     [2.11]
│   │   │   ├── SessionClock.mqh       [2.11] 現地時刻と夏時間
│   │   │   └── Utils.mqh              [2.11]
│   │   │
│   │   ├── Engines/
│   │   │   ├── CurrencyStrength.mqh   [2.11]
│   │   │   ├── BestPair.mqh           [2.11]
│   │   │   ├── Confidence.mqh         [2.11]
│   │   │   ├── AnomalyEngine.mqh      [2.11] 暦のアノマリー
│   │   │   ├── AdaptiveUpdate.mqh     [2.11] 更新間隔の段
│   │   │   ├── EnergyEngine.mqh       [2.11] 圧縮の蓄積
│   │   │   ├── MoneyFlow.mqh          [2.20] 枠のみ
│   │   │   ├── MarketRegime.mqh       [2.20] 枠のみ
│   │   │   ├── MarketState.mqh        [2.30] 枠のみ
│   │   │   └── AlertEngine.mqh        [2.30] 枠のみ
│   │   │
│   │   └── Display/
│   │       ├── DrawObjects.mqh        [2.11] 描画の下請け
│   │       └── Dashboard.mqh          [2.11] レイアウト
│   │
│   ├── Include/
│   └── Archive/
│
├── tests/
│   ├── Test_AssetDetection.mq5
│   ├── Test_CurrencyStrength.mq5
│   ├── Test_Confidence.mq5
│   ├── Test_AnomalyEngine.mq5
│   ├── Test_SessionClock.mq5
│   ├── Test_AdaptiveUpdate.mq5
│   ├── Test_EnergyEngine.mq5
│   ├── Test_MoneyFlow.mq5          [2.20] 枠の確認のみ
│   └── Test_MarketRegime.mq5       [2.20] 枠の確認のみ
│
├── examples/
├── ideas/
├── presets/
└── releases/
```

---

## インストール

1. MetaTrader 5 で `ファイル > データフォルダを開く` を選ぶ
2. `MQL5/Indicators/` に `GlobalMarketDashboard` フォルダごと置く
3. MetaEditor で `src/MarketDashboard_Ultimate.mq5` を開き、F7 でコンパイル
4. ナビゲーターからチャートにドラッグ&ドロップ

インクルードは相対パスで解決しています。フォルダ構造を保ったまま配置してください。

---

## テストの動かし方

`tests/` の各ファイルはスクリプトです。MetaEditor でコンパイルし、
任意のチャートにドラッグすると「エキスパート」タブに結果が出ます。

| ファイル | 確認する内容 |
| --- | --- |
| `Test_AssetDetection.mq5` | 接尾辞の検出、8アセットと28ペアの検証結果 |
| `Test_CurrencyStrength.mq5` | 通貨強弱のランキング、矢印、Best Pair、処理時間 |
| `Test_Confidence.mq5` | 信頼度の値域と、算出できないときの扱い |
| `Test_AnomalyEngine.mq5` | 特定の日付を与えたときに期待した規則が発火するか。季節性がFXスコアに混入しないか |
| `Test_SessionClock.mq5` | 欧州と米国の夏時間が別々に切り替わるか。境界日を直接指定して検証する |
| `Test_AdaptiveUpdate.mq5` | 段が3つに収まるか。速くする方向だけ滞留時間を免除しているか |
| `Test_EnergyEngine.mq5` | 銘柄をまたいで同じ尺度に収まるか。材料不足で 0 を返していないか |

`Test_AnomalyEngine.mq5` と `Test_SessionClock.mq5` の2本は価格を読みません。
日付を与えれば結果が一意に決まるので、失敗したときに原因が必ず特定できます。
特に夏時間の境界は年に4回しか自然には来ないため、
実運用を待っていると誤りに半年気づきません。
