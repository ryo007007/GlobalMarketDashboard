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
│   │   │   └── Utils.mqh              [2.11]
│   │   │
│   │   ├── Engines/
│   │   │   ├── CurrencyStrength.mqh   [2.11]
│   │   │   ├── BestPair.mqh           [2.11]
│   │   │   ├── Confidence.mqh         [2.11]
│   │   │   ├── MoneyFlow.mqh          [2.20] 枠のみ
│   │   │   └── MarketRegime.mqh       [2.20] 枠のみ
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
