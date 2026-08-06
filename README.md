# Global Market Dashboard Ultimate

相場を見るのではなく、**世界のお金の流れを見る。**

Global Market Dashboard Ultimate（GMD）は、MT5上でFX・指数・金属・暗号資産の文脈を横断的に扱うマーケット分析ダッシュボードです。現在の実装重心は **Ver2.11 の土台整備** にあり、銘柄自動検出・通貨強弱・Best Pair・Confidence・Anomaly・Energy・Adaptive Update を中心に開発を進めています。

---

## Current Status

### 実装済み / 稼働中（Ver2.11）
- Asset Detection
- Currency Strength
- Best Pair
- Confidence
- Anomaly Engine
- Energy Engine
- Adaptive Update
- Session Clock
- Dashboard
- 単体テスト用スクリプト群

### 予約済み / 段階導入
- Money Flow `[2.20]`
- Market Regime `[2.20]`
- Symbol Cache (L2 CSV) `[2.20]`
- Session Manager `[2.20+]`
- Market State `[2.30]`
- Alert Engine `[2.30]`

---

## ディレクトリ構成

```text
GlobalMarketDashboard/
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
│   └── Modules/
│       ├── Interfaces/
│       │   ├── IEngine.mqh
│       │   ├── IDashboard.mqh
│       │   └── IIndicator.mqh
│       ├── Core/
│       │   ├── Constants.mqh
│       │   ├── Config.mqh
│       │   ├── Types.mqh
│       │   ├── Logger.mqh
│       │   ├── Utils.mqh
│       │   ├── AssetDetection.mqh
│       │   ├── SymbolCache.mqh      [2.20] 契約のみ
│       │   ├── SessionClock.mqh
│       │   └── SessionManager.mqh   [2.20+] 受け皿
│       ├── Engines/
│       │   ├── CurrencyStrength.mqh
│       │   ├── BestPair.mqh
│       │   ├── Confidence.mqh
│       │   ├── AnomalyEngine.mqh
│       │   ├── AdaptiveUpdate.mqh
│       │   ├── EnergyEngine.mqh
│       │   ├── MoneyFlow.mqh        [2.20] 枠のみ
│       │   ├── MarketRegime.mqh     [2.20] 枠のみ
│       │   ├── MarketState.mqh      [2.30] 枠のみ
│       │   └── AlertEngine.mqh      [2.30] 枠のみ
│       └── Display/
│           ├── DrawObjects.mqh
│           └── Dashboard.mqh
│
├── tests/
│   ├── Test_AdaptiveUpdate.mq5
│   ├── Test_AnomalyEngine.mq5
│   ├── Test_AssetDetection.mq5
│   ├── Test_Confidence.mq5
│   ├── Test_CurrencyStrength.mq5
│   ├── Test_EnergyEngine.mq5
│   ├── Test_MarketRegime.mq5
│   ├── Test_MoneyFlow.mq5
│   └── Test_SessionClock.mq5
│
├── examples/
├── ideas/
├── presets/
└── releases/
```

---

## 設計上の改善ポイント（今回反映）

- `Interfaces/` を新設し、`IEngine` を型定義から分離
- `Constants.mqh` を新設し、マジックナンバーを集約
- `Config.mqh` を新設し、将来の設定統合先を明確化
- `SymbolCache.mqh` を新設し、AssetDetection のL2キャッシュ境界を分離
- `SessionManager.mqh` を追加し、`SessionClock` から将来のセッション統括へ拡張しやすい形を確保
- 仕様書・README・Architecture の記述を現行構成へ同期

---

## インストール

1. MetaTrader 5 で `ファイル > データフォルダを開く`
2. `MQL5/Indicators/` 配下に `GlobalMarketDashboard` フォルダごと配置
3. MetaEditor で `src/MarketDashboard_Ultimate.mq5` を開き、F7 でコンパイル
4. ナビゲーターからチャートにドラッグ&ドロップ

フォルダ構造を崩すと相対インクルードが解決できないため、そのまま配置してください。

---

## テストの動かし方

`tests/` 配下のファイルはテスト用スクリプトです。MetaEditorでコンパイルし、任意のチャートにドラッグすると「エキスパート」タブへ結果が出ます。

| ファイル | 確認する内容 |
|---|---|
| `Test_AssetDetection.mq5` | 8アセットと28ペアの検出結果、接尾辞推定 |
| `Test_CurrencyStrength.mq5` | ランキング、矢印、Best Pair、処理時間 |
| `Test_Confidence.mq5` | 値域、未計算時の扱い |
| `Test_AnomalyEngine.mq5` | 日付規則・季節性の発火、scope分離 |
| `Test_SessionClock.mq5` | 欧州/米国/豪州の夏時間境界 |
| `Test_AdaptiveUpdate.mq5` | 3段制御とヒステリシス |
| `Test_EnergyEngine.mq5` | 圧縮状態、材料不足時の扱い |
| `Test_MoneyFlow.mq5` | Ver2.20枠の確認 |
| `Test_MarketRegime.mq5` | Ver2.20枠の確認 |

---

## 主要ドキュメント

- 設計の正本: `docs/ProjectSpecification.md`
- 構造説明: `docs/Architecture.md`
- 開発方針: `docs/DevelopmentPolicy.md`
- コーディング規約: `docs/CodingRules.md`
- 利用者向け: `docs/UserManual.md`
