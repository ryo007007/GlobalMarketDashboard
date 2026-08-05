ChatGPTからのフィードバック、非常に的確で素晴らしい視点ですね！

特に **「各エンジンの Inputs / Outputs / Class Methods の明記」** や **「Purpose / Calculation / Display の構造的分離」** は、午後のコード実装（`.mqh`作成）へスムーズに移行するための橋渡しとして完璧な整理方法です。

ドキュメントバージョンを **`Project Specification v1.0 Draft`** へ引き上げ、Inputs/Outputs、主要クラスメソッド（`CCurrencyStrength`, `CAssetDetection` 等）、将来の拡張章（`Class Diagram`, `Error Handling` 等のプレースホルダー）まで統合した、**実装者が一切迷わない「超プロ仕様」の決定版仕様書**にブラッシュアップしました！

---

# 🌐 Global Market Dashboard Ultimate Edition

> **Integrated Market Analysis Platform for MetaTrader 5**

---

## 📌 Project Metadata

| Item | Details |
| --- | --- |
| **Project Name** | Global Market Dashboard Ultimate |
| **Platform** | MetaTrader 5 (MT5) |
| **Language** | MQL5 |
| **Repository** | `GlobalMarketDashboard` |
| **Document Version** | **Project Specification v1.0 Draft** |
| **Current Target** | `Ver 2.11 Ultimate` (Development) |
| **Author** | Ryoutarou Kadono |
| **Status** | In Development |

---

## 📋 Table of Contents

1. [Project Overview & Philosophy](https://www.google.com/search?q=%231-project-overview--philosophy)
2. [System Architecture & Data Flow](https://www.google.com/search?q=%232-system-architecture--data-flow)
3. [Core Engine Specifications](https://www.google.com/search?q=%233-core-engine-specifications)
* 3.1 [Asset Detection Engine](https://www.google.com/search?q=%2331-asset-detection-engine)
* 3.2 [Currency Strength Engine](https://www.google.com/search?q=%2332-currency-strength-engine)
* 3.3 [Best Pair Engine](https://www.google.com/search?q=%2333-best-pair-engine)
* 3.4 [Confidence Engine](https://www.google.com/search?q=%2334-confidence-engine)
* 3.5 [Market Regime Engine](https://www.google.com/search?q=%2335-market-regime-engine)
* 3.6 [Money Flow & Liquidity Engine](https://www.google.com/search?q=%2336-money-flow--liquidity-engine)


4. [Asset Detection Flow & Lifecycle](https://www.google.com/search?q=%234-asset-detection-flow--lifecycle)
5. [UI & Display Specifications](https://www.google.com/search?q=%235-ui--display-specifications)
6. [System Directory & Module Structure](https://www.google.com/search?q=%236-system-directory--module-structure)
7. [Performance & Update Policy](https://www.google.com/search?q=%237-performance--update-policy)
8. [Color System & Rules](https://www.google.com/search?q=%238-color-system--rules)
9. [Development Roadmap & Milestones](https://www.google.com/search?q=%239-development-roadmap--milestones)
10. [Coding & Architecture Standards](https://www.google.com/search?q=%2310-coding--architecture-standards)
11. [Future Architecture Extensions (Draft)](https://www.google.com/search?q=%2311-future-architecture-extensions-draft)
12. [Glossary](https://www.google.com/search?q=%23-glossary)

---

## 1. Project Overview & Philosophy

### 1.1 ビジョン（開発目的）

本ツールは、単なるMT5用のインジケーターにとどまりません。FX・株式・Gold・暗号資産・債券など、独立して扱われがちな各市場をクロスアセット（横断的）に統合分析し、**「市場全体の資金循環（マネーフロー）」を一つの画面で可視化する統合マーケット分析プラットフォーム**を目指します。

> **💡 コアコンセプト**
> * 「相場を見る」のではなく **「世界のお金の流れを見る」**
> * 市場の状態そのものを多角的な数値として定量化する **「Market Analytics Engine」**
> 
> 

---

## 2. System Architecture & Data Flow

各エンジン層が独立してデータ処理を行い、描画層へ連携する疎結合なパイプライン設計を採用しています。

```text
                     [ Data Layer ]
         Asset Detection (自動判定・キャッシュ)
                            │
                            ▼
                    [ Analysis Layer ]
 ┌────────────────────────────────────────────────────────┐
 │ 1. CCurrencyStrength : 28ペア相対強弱スコア計算       │
 │ 2. CBestPair         : 最強 vs 最弱ペアの自動選定      │
 │ 3. CConfidence       : 多角的指標の寄与率合算 (0-100%)│
 │ 4. CMarketRegime     : Risk Score (0-100) & 地合い判定│
 │ 5. CMoneyFlow        : アセット間資本流出入分析       │
 └──────────────────────────┬─────────────────────────────┘
                            │
                            ▼
                  [ Presentation Layer ]
 ┌────────────────────────────────────────────────────────┐
 │ CDashboard / Multi-Panel Display (UI統括・差分描画)   │
 └────────────────────────────────────────────────────────┘

```

---

## 3. Core Engine Specifications

---

### 3.1 🔍 Asset Detection Engine (`CAssetDetection`)

ブローカーごとのシンボル名表記揺れを自動識別・検証し、システム共通の識別コードへと正規化します。

* **3.1.1 Purpose**: ブローカー依存のシンボル表記差分（`XAUUSD`, `GOLDmicro` 等）を透過的に吸収する。
* **3.1.2 Inputs**:
* Terminal Symbol List（気配値表示および全提供銘柄リスト）
* Aliases Table（定義済み優先度検索テーブル）


* **3.2.3 Outputs**:
* Normalized Symbol Names (`string`)
* Availability Flags (`bool`)


* **3.1.4 Class Interface**:

```cpp
class CAssetDetection
{
private:
   string   m_cachedGoldSymbol;
   bool     m_isGoldAvailable;
   // 他アセットのキャッシュ変数...

public:
            CAssetDetection();
   bool     DetectAll();
   string   GetGoldSymbol()    const { return m_cachedGoldSymbol; }
   bool     IsGoldAvailable()  const { return m_isGoldAvailable; }
   // Validate / Cache 内部メソッド...
};

```

---

### 3.2 🔀 Currency Strength Engine (`CCurrencyStrength`)

全28通貨ペアの値動きから主要7通貨の相対的な強弱関係を算出します。

* **3.2.1 Purpose**: FX市場における各通貨の買われ・売られ状態をリアルタイムで数値化する。
* **3.2.2 Inputs**:
* 28 Currency Pairs Price Data
* Target Timeframe (`ENUM_TIMEFRAMES`)


* **3.2.3 Calculation**:
* 各ペアの上昇/下降判定（上昇: 分子 `+1` / 下降: 分母 `+1`）
* 合計スコアに基づき 1位〜7位 へソート


* **3.2.4 Outputs**:
* Currency Rank List (`1st ~ 7th`)
* Strength Scores (`double`)
* UI Color Map (`color`)


* **3.2.5 Class Interface**:

```cpp
class CCurrencyStrength
{
private:
   double   m_scores[7];
   int      m_rankings[7];

public:
            CCurrencyStrength();
   bool     Calculate(ENUM_TIMEFRAMES tf);
   double   GetScore(string currency) const;
   int      GetRank(string currency)  const;
};

```

---

### 3.3 🏆 Best Pair Engine (`CBestPair`)

`Currency Strength Engine` から算出された「最強通貨」と「最弱通貨」を瞬時に組み合わせ、現在最も強いトレンドが期待できる通貨ペアを自動抽出します。

* **3.3.1 Purpose**: トレード効率が最も高い通貨ペアを瞬時に提示する。
* **3.3.2 Inputs**:
* Currency Ranks (`CCurrencyStrength` から取得)


* **3.3.3 Calculation**:
* 最強通貨 (Rank 1) と 最弱通貨 (Rank 7) のペアリングおよび売買方向の決定


* **3.3.4 Outputs**:
* Best Pair Name (例: `"EURJPY"`)
* Direction Indicator (例: `"BUY"` / `"SELL"`)


* **3.3.5 Class Interface**:

```cpp
class CBestPair
{
public:
   string   GetBestPair(const CCurrencyStrength &csEngine, string &outDirection);
};

```

---

### 3.4 🎯 Confidence Engine (`CConfidence`)

各エンジンの判定結果を指定された寄与率パラメーターで合算し、現在の相場環境に対する総合的な確信度（`0 〜 100%`）を出力します。

* **3.4.1 Purpose**: エントリーや分析における市場環境の整合性（信頼度）を数値化する。
* **3.4.2 Inputs & Weights**:
* Currency Strength 一致率 : `40%`
* Money Flow 方向性        : `30%`
* Market Regime Risk Score  : `20%`
* Momentum                  : `10%`


* **3.4.3 Outputs**:
* Confidence Score (`0 〜 100%`)


* **3.4.4 Class Interface**:

```cpp
class CConfidence
{
public:
   int      CalculateConfidence(double csScore, double mfScore, int riskScore);
};

```

---

### 3.5 🛡️ Market Regime Engine (`CMarketRegime`)

マクロ市場の主要9指標の状態から総合的なリスクセンチメントを測定し、**`Risk Score (0 〜 100)`** を算出します。

* **3.5.1 Inputs**: `SP500`, `NASDAQ`, `US10Y`, `Gold`, `USDJPY`, `BTC`, `ETH`, `VIX`, `DXY`
* **3.5.2 Outputs & Classification**:

| Score | Status | 判定テキスト | 市場状況 |
| --- | --- | --- | --- |
| **80–100** | 🔥 **Strong Risk ON** | 強いリスクオン | 株・クリプト急騰、安全資産売却 |
| **60–79** | 🟢 **Risk ON** | リスクオン | リスク資産選好、トレンド継続 |
| **40–59** | ⚪ **Neutral** | 中立・レンジ | 銘柄間で強弱拮抗、方向感なし |
| **20–39** | 🔴 **Risk OFF** | リスクオフ | リスク資産売却、安全資産へ避難 |
| **0–19** | ❄️ **Strong Risk OFF** | 強いリスクオフ | 全面リスク回避・パニック・現金化の進行 |

---

### 3.6 🌊 Money Flow & Liquidity Engine (`CMoneyFlow`)

多角的なアセットクラス間の資金流出入と、機関投資家の「現金化（キャッシュ化）圧力」を判定します。

* **3.6.1 Target Assets**: FX / Gold & Silver / Equity Index / Crypto / Bond
* **3.6.2 Output Indicators**: `↑↑` (強い流入), `↑` (流入), `→` (中立), `↓` (流出), `↓↓` (強い流出)
* **3.6.3 Liquidity Score (現金化圧力)**:
* **Cash Preference**: `Gold ↑` + `Bond ↑` + `JPY ↑` + `VIX ↑` ➔ 有事の現金化シナリオの検知



---

## 4. Asset Detection Flow & Lifecycle

システム起動時および初期化処理における `AssetDetection.mqh` の内部ライフサイクルです。

```text
[ Terminal 起動 / OnInit ]
           │
           ▼
   1. Symbol Scan     : ブローカー提供銘柄の一括検索
           │
           ▼
   2. Detection       : カテゴリ別エイリアス照合 (Gold/Index/Crypto/Bond)
           │
           ▼
   3. Validation      : SymbolInfoDouble() 等による価格取得確認
           │
           ▼
   4. Availability    : 未対応銘柄への Unavailable (N/A) フラグ付与
           │
           ▼
   5. Cache           : 検出結果のメモリ保持 (毎秒の再検索を排除)
           │
           ▼
 [ Engine & UI へ参照引き渡し ]

```

---

## 5. UI & Display Specifications

### 5.1 Display Modes

1. **Mode 1 (Chart)**: チャートメイン表示（MA, BB, Pivot等）
2. **Mode 2 (Dashboard)**: 分析パネルのみを全画面表示
3. **Mode 3 (Hybrid)**: チャート画面 ＋ ダッシュボードパネルの併用（推奨）
4. **Mode 4 (Minimal)**: 強弱ランキング等、最低限の情報のみを表示する省スペースモード

### 5.2 🖼️ Dashboard Layout (Ver2.11 完成イメージ)

```text
┌──────────────────────────────┐
│ GLOBAL MARKET DASHBOARD      │
├──────────────────────────────┤
│ Risk ON        82%           │
│ Confidence     91%           │
│ Best Pair EURJPY             │
├──────────────────────────────┤
│ Currency Strength            │
│ USD █████                    │
│ EUR ████                     │
│ GBP ███                      │
│ AUD ██                       │
│ JPY █                        │
├──────────────────────────────┤
│ Money Flow                   │
│ Stocks      ↑↑               │
│ Gold        ↓                │
│ Bond        ↓                │
│ Crypto      ↑↑↑              │
├──────────────────────────────┤
│ Tokyo   OPEN                 │
│ London  03:12                │
│ NewYork 09:54                │
├──────────────────────────────┤
│ CPI      2h14m               │
│ FOMC     1d03h               │
└──────────────────────────────┘

```

---

## 6. System Directory & Module Structure

大規模開発および保守性を確保するため、`Engines/`, `Display/`, `Core/` の3軸でモジュールをディレクトリカプセル化します。

```text
src/
└── Modules/
    ├── Core/                   // [基盤・ユーティリティ (第1フェーズ)]
    │   ├── AssetDetection.mqh   // ブローカー表記揺れ自動検出・キャッシュ
    │   ├── Logger.mqh           // 初期化・検出・エラー・ロード等のログ管理
    │   └── Utils.mqh            // 共通関数・配列操作・型変換
    │
    ├── Engines/                // [計算・判定ロジック (第2フェーズ)]
    │   ├── CurrencyStrength.mqh // 通貨強弱スコア計算
    │   ├── BestPair.mqh         // 最強vs最弱ペア自動選定
    │   ├── Confidence.mqh       // 寄与率合算・確信度計算
    │   ├── MarketRegime.mqh     // Risk Score & 地合い判定
    │   └── MoneyFlow.mqh        // 資金流出入・マネーフロー分析
    │
    └── Display/                // [UI描画・描画制御 (第3フェーズ)]
        ├── Dashboard.mqh        // GUI全体の統括制御
        ├── SummaryPanel.mqh     // Market Summary 描画
        ├── RankingPanel.mqh     // 強弱ランキングパネル描画
        └── MoneyFlowPanel.mqh   // マネーフロー・アセット描画

```

---

## 7. Performance & Update Policy

### ⏱️ 更新インターバル規則

| 分析対象 | 更新間隔 | 理由 |
| --- | --- | --- |
| **Currency Strength** | **1秒** | FX短期トレンドの即時追従 |
| **Equity Index / Gold** | **5秒** | ボラティリティ監視 |
| **Bond (米国債)** | **10秒** | マクロ金利動向の監視 |
| **Economic Events / Market Open** | **60秒** | タイマーカウントダウン制御 |

---

## 8. Color System & Rules

* 🔴 **Strong Buy (最強く)**: 赤 (`#FF0000` / `clrRed`)
* 🟠 **Buy (強)**: オレンジ (`#FF8C00` / `clrDarkOrange`)
* ⚪ **Neutral (中立)**: 白 / 灰色 (`#DCDCDC` / `clrGainsboro`)
* 🩵 **Sell (弱)**: 水色 (`#00BFFF` / `clrDeepSkyBlue`)
* 🔵 **Strong Sell (最弱)**: 青 (`#0000FF` / `clrBlue`)

---

## 9. Development Roadmap & Milestones

```text
 [Ver2.11 (基盤&核心部)] ──> [Ver2.20 (分析拡張)] ──> [Ver2.30 (マクロ統合)] ──> [Ver3.00+]
  Core ➔ Engines ➔ Display       Regime/Flow          Events/Modes         Advanced

```

### 🚀 Ver2.11 (実装ターゲット)

* [x] 仕様書 v1.0 Draft の確立
* [ ] **Core構築**: `AssetDetection.mqh`, `Logger.mqh`, `Utils.mqh`
* [ ] **Engines構築**: `CurrencyStrength.mqh`, `BestPair.mqh`, `Confidence.mqh`
* [ ] **Display構築**: `Dashboard.mqh` 基本UIでの動作確認

---

## 10. Coding & Architecture Standards

### 10.1 命名規則 (Naming Conventions)

* **クラス名**: 先頭に `C`（例: `CAssetDetection`, `CCurrencyStrength`）
* **メンバー変数**: 先頭に `m_`（例: `m_goldSymbol`）
* **グローバル変数**: 先頭に `g_`（例: `g_logger`）
* **入力パラメータ**: 先頭に `Inp`（例: `InpUpdateInterval`）
* **主要メソッド**: 役割に応じた動詞で統一（`Detect()`, `Validate()`, `Calculate()`, `Draw()`）

---

## 11. Future Architecture Extensions (Draft)

プロジェクトの成長に備え、将来的に順次追記・拡張する章のプレースホルダーです。

* **29. Class Diagram**: 全クラスの依存関係図説
* **30. Data Flow**: イベント駆動（`OnTimer` / `OnTick`）時のデータ流通図
* **31. Error Handling**: エラーコード定義とリカバリー手順
* **32. Performance Benchmark**: CPU/メモリ使用量の許容上限規定
* **33. Test Plan**: 単体テストおよび各種ブローカーでの結合テスト計画
* **34. Release Checklist**: 本番ビルド前のチェック項目
* **35. Known Limitations**: プラットフォーム固有の制限事項メモ

---

## 📖 Glossary

* **Asset Detection**: ブローカー固有の銘柄名を識別・検証し、全エンジン共通のフォーマットに正規化する層。
* **Availability**: 外部データが存在しない場合にシステム停止を防ぐフォールバック設計。
* **Money Flow**: アセット間を移動するグローバルな資本の流出入・循環。
* **Confidence**: 複数エンジンの判定の一致率から算出される売買シグナルの確信度。

---
