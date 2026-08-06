# Global Market Dashboard Ultimate

> 相場を見るのではなく、**世界のお金の流れを見る。**

Global Market Dashboard Ultimate（GMD）は、MetaTrader 5 上で  
**FX・株価指数・貴金属・暗号資産・債券** を横断し、市場間の資金の流れと相互関係を  
**1画面で可視化する** 統合マーケット分析ダッシュボードです。

現在の実装重心は **Ver2.11 の土台整備** にあり、  
銘柄自動検出・通貨強弱・Best Pair・Confidence・Anomaly・Energy・Adaptive Update を中心に開発を進めています。

---

## Features（特徴）

| 機能 | 説明 | 状態 |
|------|------|------|
| **Asset Detection** | ブローカー表記の違いを吸収し、Gold / 指数 / Crypto 等を自動検出 | ✅ 稼働中 |
| **Currency Strength** | 8通貨・28ペアの強弱ランキング | ✅ 稼働中 |
| **Best Pair** | 最強×最弱から推奨ペアと方向を提案 | ✅ 稼働中 |
| **Confidence** | エンジン間の一致度を 0〜100% で表示 | ✅ 稼働中 |
| **Anomaly Engine** | 五十日・季節性など暦の統計的偏りを点数化 | ✅ 稼働中 |
| **Energy Engine** | 値幅圧縮の蓄積を 0〜100 で数値化（方向は予測しない） | ✅ 稼働中 |
| **Adaptive Update** | 市場状況に応じて更新間隔を 3 段切替 | ✅ 稼働中 |
| **Session Clock** | 現地時刻＋地域別夏時間でセッション判定 | ✅ 稼働中 |
| **Money Flow** | アセット間の資金流出入 | 🔜 Ver2.20 |
| **Price Level** | 日/週/月の高安と距離・接近監視 | 🔜 Ver2.20+ |
| **Pivot** | Daily〜Yearly Pivot（Weekly 優先） | 🔜 Ver2.20+ |
| **Market Structure** | 大波/中波/小波・200BB・サイクル位相 | 📋 Ver2.30+ |
| **Today's Setup** | 戦略の型ガイド（シグナルではない） | 📋 Ver3.00 |
| **Engine Manager** | 更新順の一元管理 | 📋 Ver2.20+ |
| **Bollinger / Cycle** | BBとサイクル位相（分離予約） | 📋 Ver2.30+ |
| **Market Regime** | Risk ON / OFF / Neutral | 🔜 Ver2.20 |
| **Market State / Alert** | 状態畳み込み・遷移通知 | 🔜 Ver2.30 |
| **Correlation / Statistics** | 相関・統計エンジン | 📋 Ver3.00 |

---

## Screenshots

> スクリーンショットは `examples/` に配置予定です。  
> 現時点では実装が進み次第追加します。

| 画面 | ファイル（予定） |
|------|------------------|
| Dashboard 全体 | `examples/Dashboard.png` |
| Currency Strength | `examples/CurrencyStrength.png` |
| Hybrid Mode | `examples/HybridMode.png` |
| Money Flow | `examples/MoneyFlow.png` |

---

## インストール

1. MetaTrader 5 で **ファイル > データフォルダを開く**
2. `MQL5/Indicators/` 配下に `GlobalMarketDashboard` フォルダごと配置
3. MetaEditor で `src/MarketDashboard_Ultimate.mq5` を開き、**F7** でコンパイル
4. ナビゲーターからチャートにドラッグ＆ドロップ

> フォルダ構造を崩すと相対インクルードが解決できないため、そのまま配置してください。

---

## ディレクトリ構成

```text
GlobalMarketDashboard/
├── README.md
├── CHANGELOG.md
├── ROADMAP.md
├── LICENSE
│
├── docs/                          ← 設計の正本・補足ドキュメント
│   ├── ProjectSpecification.md
│   ├── Architecture.md
│   ├── CodingRules.md
│   ├── DevelopmentPolicy.md
│   └── images/
│
├── src/
│   ├── MarketDashboard_Ultimate.mq5
│   └── Modules/
│       ├── Interfaces/            ← IEngine / IDashboard / IIndicator
│       ├── Core/                  ← Types / Logger / AssetDetection / SessionClock ...
│       ├── Engines/               ← CurrencyStrength / Energy / Anomaly / ...
│       └── Display/               ← Dashboard + 分割パネル群
│           ├── Dashboard.mqh
│           ├── DrawObjects.mqh
│           ├── SummaryPanel.mqh
│           ├── RankingPanel.mqh
│           ├── MoneyFlowPanel.mqh
│           ├── StatusBar.mqh
│           └── ChartOverlay.mqh
│
├── tests/                         ← 単体テスト用スクリプト
├── examples/                      ← スクリーンショット・使用例
├── presets/
└── releases/
```

---

## テストの動かし方

`tests/` 配下のファイルを MetaEditor でコンパイルし、任意のチャートにドラッグすると  
「エキスパート」タブへ結果が出ます。

| ファイル | 確認内容 |
|----------|----------|
| `Test_AssetDetection.mq5` | 8アセットと28ペアの検出結果 |
| `Test_CurrencyStrength.mq5` | ランキング・矢印・処理時間 |
| `Test_BestPair.mq5` | 推奨ペアが実在銘柄か・方向解釈 |
| `Test_Confidence.mq5` | 値域・未計算時の扱い |
| `Test_AnomalyEngine.mq5` | 日付規則・季節性・scope 分離 |
| `Test_SessionClock.mq5` | 欧州/米国/豪州の夏時間境界 |
| `Test_AdaptiveUpdate.mq5` | 3段制御とヒステリシス |
| `Test_EnergyEngine.mq5` | 圧縮状態・材料不足時の扱い |
| `Test_MoneyFlow.mq5` | Ver2.20 枠の確認 |
| `Test_MarketRegime.mq5` | Ver2.20 枠の確認 |
| `Test_MarketState.mq5` | Ver2.30 枠の確認 |
| `Test_AlertEngine.mq5` | Ver2.30 枠の確認 |
| `Test_CorrelationEngine.mq5` | Ver3.00 予約枠の確認 |
| `Test_StatisticsEngine.mq5` | Ver3.00 予約枠の確認 |
| `Test_PriceLevelEngine.mq5` | Ver2.20+ 枠の確認 |
| `Test_PivotEngine.mq5` | Ver2.20+ 枠の確認 |
| `Test_MarketStructure.mq5` | Ver2.30+ 枠の確認 |
| `Test_SetupGuide.mq5` | Ver3.00 予約枠の確認 |

エンジンとテストの対応表は [`docs/EngineIndex.md`](docs/EngineIndex.md) を参照。

---

## Roadmap（概要）

| バージョン | 内容 |
|------------|------|
| **Ver2.11** | 基盤固め：Asset Detection / Currency Strength / Best Pair / Confidence / Anomaly / Energy / Adaptive Update / Dashboard |
| **Ver2.20** | Money Flow / Market Regime / Symbol Cache (L2) |
| **Ver2.30** | Market State / Alert Engine / Display Mode 完成 |
| **Ver3.00** | Correlation Engine / Statistics Engine / Flow Analysis |
| **Ver4.00** | Analytics / Prediction / Portfolio |

詳細は [`ROADMAP.md`](ROADMAP.md) を参照してください。

---

## 主要ドキュメント

| ドキュメント | 内容 |
|--------------|------|
| [`docs/ProjectSpecification.md`](docs/ProjectSpecification.md) | 設計の正本（Single Source of Truth） |
| [`docs/Architecture.md`](docs/Architecture.md) | 層構造と依存ルール |
| [`docs/DevelopmentPolicy.md`](docs/DevelopmentPolicy.md) | 開発方針 |
| [`docs/CodingRules.md`](docs/CodingRules.md) | コーディング規約 |
| [`docs/UserManual.md`](docs/UserManual.md) | 利用者向け説明 |

---

## License

本プロジェクトのライセンスは [`LICENSE`](LICENSE) を参照してください。

---

**「世界のお金の流れを見る」** — その一貫したコンセプトの下で、長く育てていくソフトウェアプロジェクトです。
