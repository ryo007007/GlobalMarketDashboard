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
│   ├── ProjectSpecification.md
│   ├── UserManual.md
│   └── Images/
│
├── src/
│   ├── MarketDashboard_Ultimate.mq5
│   │
│   ├── Modules/
│   │   ├── Core/
│   │   │   ├── AssetDetection.mqh
│   │   │   ├── Logger.mqh
│   │   │   ├── Types.mqh
│   │   │   └── Utils.mqh
│   │   │
│   │   ├── Engines/
│   │   │   ├── CurrencyStrength.mqh
│   │   │   ├── MoneyFlow.mqh
│   │   │   ├── MarketRegime.mqh
│   │   │   ├── Confidence.mqh
│   │   │   └── BestPair.mqh
│   │   │
│   │   └── Display/
│   │       ├── Dashboard.mqh
│   │       ├── SummaryPanel.mqh
│   │       ├── RankingPanel.mqh
│   │       └── MoneyFlowPanel.mqh
│
├── tests/
│   ├── Test_AssetDetection.mq5
│   ├── Test_CurrencyStrength.mq5
│   ├── Test_MarketRegime.mq5
│   ├── Test_MoneyFlow.mq5
│   └── Test_Confidence.mq5
│
├── presets/
│
└── releases/