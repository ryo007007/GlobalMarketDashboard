これまで議論・整理してきた設計思想やアーキテクチャ（`Liquidity Score`、`Capital Rotation`、`Confidence` 寄与率、`Risk Score` 0〜100、モジュールディレクトリ構造、UIレイアウト、コードブロックの記述法など）のすべてを融合させ、**仕様書ドキュメントとしてそのまま保存・運用できる最高品質のプロ仕様Markdown**に再構成・ブラッシュアップしました。

---

```markdown
# 🌐 Global Market Dashboard Ultimate Edition
> **Integrated Market Analysis Platform for MetaTrader 5**

---

## 📌 Project Metadata

| Item | Details |
| :--- | :--- |
| **Project Name** | Global Market Dashboard Ultimate |
| **Platform** | MetaTrader 5 (MT5) |
| **Language** | MQL5 |
| **Repository** | `GlobalMarketDashboard` |
| **Current Version** | `2.11 Ultimate` (Development) |
| **Document Version** | Project Specification v0.2 |
| **Author** | Ryoutarou Kadono |
| **Status** | In Development |

---

## 1. Project Overview & Philosophy

### 1.1 ビジョン（開発目的）
本ツールは、単なるMT5用のインジケーターにとどまりません。FX・株式・Gold・暗号資産・債券など、
独立して扱われがちな各市場をクロスアセット（横断的）に統合分析し、
**「市場全体の資金循環（マネーフロー）」を一つの画面で可視化する
統合マーケット分析プラットフォーム**を目指します。

> **💡 コアコンセプト**
> * 「相場を見る」のではなく **「世界のお金の流れを見る」**
> * 市場の状態そのものを多角的な数値として定量化する **「Market Analytics Engine」**

---

## 2. System Architecture & Flow

各エンジン層が独立してデータ処理を行い、描画層へ連携する堅牢なパイプライン設計を採用しています。

### 2.1 全体処理パイプライン

```text
               [ Data Layer ]
         Asset Detection (自動判定)
                    │
                    ▼
            [ Analysis Layer ]
 ┌──────────────────────────────────────┐
 │ 1. Currency Strength Engine          │
 │ 2. Market Regime Engine (Risk Score) │
 │ 3. Money Flow Engine                 │
 │ 4. Confidence Engine                 │
 │ 5. Best Pair Engine                  │
 └──────────────────┬───────────────────┘
                    │
                    ▼
          [ Presentation Layer ]
 ┌──────────────────────────────────────┐
 │ Dashboard UI / Multi-Panel Display   │
 └──────────────────────────────────────┘

```

---

## 3. Core Engine Detailed Specifications

---

### 3.1 🔀 Currency Strength Engine

全28通貨ペアの値動きから主要7通貨の相対的な強弱関係を算出します。

* **対象通貨 (7 Currency)**: `USD`, `EUR`, `JPY`, `GBP`, `CHF`, `AUD`, `CAD`
* **対象ペア (28 Pairs)**: 主要メジャー・クロス通貨ペア全28種類
* **算出ロジック (Ver2.11)**:
* 一定時間（タイムフレーム）における上昇/下降判定
* 上昇時：分子側通貨 `+1` / 下降時：分母側通貨 `+1`


* **表示方式**: 強度順に 1位〜7位 をランキング化し、ダイナミックに色分け
* 🔴 **最強**: 赤系 (Strong Buy)
* 🔵 **最弱**: 青系 (Strong Sell)


* **将来拡張 (Ver2.20)**: 通貨ペアごとの重み付け（`Weight`）、`ATR`・ボラティリティ加算機能の実装

---

### 3.2 🌊 Money Flow & Liquidity Engine

多角的なアセットクラス間の資金流出入と、機関投資家の「現金化（キャッシュ化）圧力」を判定します。

#### 対象市場アセット

* **FX** / **Gold & Silver** / **株価指数** / **暗号資産** / **債券**

#### 表示ルール

* `↑↑` / `↑` : 資金流入（緑）
* `→` : 中立（灰色）
* `↓↓` / `↓` : 資金流出（赤）

#### 💧 流動性判定（Liquidity Score）

* **Cash Preference (現金化圧力の急増)**: `Gold ↑` + `Bond ↑` + `JPY ↑` + `VIX ↑`
* **Risk-Seeking (リスク資産への流入)**: `Stocks/NASDAQ ↑` + `Crypto/BTC ↑` + `Gold ↓` + `JPY ↓`

---

### 3.3 🛡️ Market Regime Engine

マクロ市場の主要9指標（`Inputs`）の状態から総合的なリスクセンチメントを測定し、**`Risk Score (0 〜 100)`** を算出します。

#### データインプット

`SP500`, `NASDAQ`, `US10Y`, `Gold`, `USDJPY`, `BTC`, `ETH`, `VIX`, `DXY`

#### Risk Score 区分テーブル

| Score | Status | 判定テキスト | 市場状況 |
| --- | --- | --- | --- |
| **80–100** | 🔥 **Strong Risk ON** | 強いリスクオン | 株・クリプト急騰、安全資産（円・金）売却 |
| **60–79** | 🟢 **Risk ON** | リスクオン | リスク資産選好、トレンド継続 |
| **40–59** | ⚪ **Neutral** | 中立・レンジ | 銘柄間で強弱拮抗、方向感なし |
| **20–39** | 🔴 **Risk OFF** | リスクオフ | リスク資産売却、安全資産へ避難 |
| **0–19** | ❄️ **Strong Risk OFF** | 強いリスクオフ | 全面リスク回避・パニック・現金化の進行 |

---

### 3.4 🎯 Confidence Engine

各エンジンの判定結果を指定された寄与率（可変パラメーター）で合算し、現在の相場環境に対する総合的な確信度（`0 〜 100%`）を出力します。

#### 寄与率内訳（可変・カスタマイズ可能）

```text
  Currency Strength 一致率 : 40%
+ Money Flow                : 30%
+ Market Regime (Risk Score): 20%
+ Momentum                  : 10%
-----------------------------------
= Total Confidence         : 0 〜 100% (例: 91%)

```

---

### 3.5 🏆 Best Pair Engine

`Currency Strength Engine` から算出された「最強通貨」と「最弱通貨」を瞬時に組み合わせ、現在最も強いトレンドが期待できる通貨ペアを自動抽出します。

* **例**: `EUR`（最強：+1.0） × `JPY`（最弱：-1.0） ➔ 🟢 **Best Pair: EURJPY**

---

### 3.6 🔍 Asset Detection

接続するブローカーごとの銘柄表記揺れ（シンボル名）を自動判定・正規化します。

#### 優先順位ルール（Symbol Priority）

1. **Gold**: `XAUUSD` ➔ `GOLD` ➔ `GOLDmicro` ➔ `XAUUSD.r`
2. **Equity Index**: `SPX500` / `US500` / `US30` / `NAS100` / `JP225`
3. **Crypto**: `BTCUSD` / `BTCUSDT` / `ETHUSD`

---

## 4. UI & Display Specifications

### 4.1 Display Modes（画面表示モード）

1. **Mode 1 (Chart)**: チャートメイン表示（MA, BB, Pivot等のテクニカル指標）
2. **Mode 2 (Dashboard)**: 分析パネルのみを全画面表示
3. **Mode 3 (Hybrid)**: チャート画面 ＋ ダッシュボードパネルの併用（推奨）
4. **Mode 4 (Minimal)**: 強弱ランキング等、最低限の情報のみを表示する省スペースモード

---

### 4.2 🖼️ Dashboard Layout (Ver2.11 完成イメージ)

ダッシュボード右上に配置される本プラットフォームのメインインターフェースです。

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

#### 表示情報の優先順位

1. **Market Summary** (Risk Score & Confidence)
2. **Currency Strength & Best Pair**
3. **Money Flow**
4. **Market Open Countdown**
5. **Economic Events**

---

## 5. System Architecture & Directory Structure

大規模開発および保守性を確保するため、`Engines/`, `Display/`, `Core/` の3軸でモジュールをディレクトリカプセル化します。

### 📁 モジュールツリー構成 (`src/`)

```text
src/
└── Modules/
    ├── Engines/                // [計算・判定ロジック]
    │   ├── CurrencyStrength.mqh // 通貨強弱スコア計算
    │   ├── MoneyFlow.mqh        // 資金流出入・マネーフロー分析
    │   ├── MarketRegime.mqh     // Risk Score & 地合い判定
    │   ├── Confidence.mqh       // 寄与率合算・確信度計算
    │   └── BestPair.mqh         // 最強vs最弱ペア自動選定
    │
    ├── Display/                // [UI描画・描画制御]
    │   ├── Dashboard.mqh        // GUI全体の統括制御
    │   ├── SummaryPanel.mqh     // Market Summary 描画
    │   ├── RankingPanel.mqh     // 強弱ランキングパネル描画
    │   └── MoneyFlowPanel.mqh   // マネーフロー・アセット描画
    │
    └── Core/                   // [基盤・ユーティリティ]
        ├── AssetDetection.mqh   // ブローカー表記揺れ自動検出
        ├── Logger.mqh           // 初期化・検出・エラー・ロード等のログ管理
        └── Utils.mqh            // 共通関数・配列操作・型変換

```

---

## 6. Performance & Update Policy

チャート描画のチラつき防止とCPU負荷軽減のため、アセットの性質に応じたタイマー非同期更新と差分描画を実施します。

### ⏱️ 更新インターバル規則

| 分析対象 | 更新間隔 | 理由 |
| --- | --- | --- |
| **Currency Strength** | **1秒** | FX短期トレンドの即時追従 |
| **Equity Index / Gold** | **5秒** | ボラティリティ監視 |
| **Bond (米国債)** | **10秒** | マクロ金利動向の監視 |
| **Economic Events / Market Open** | **60秒** | タイマーカウントダウン制御 |

---

## 7. Color System & Rules

直感的な状況把握を可能にするため、標準カラーテーマを厳格に定義します。

* 🔴 **Strong Buy (最強く)**: 赤 (`#FF0000` / `clrRed`)
* 🟠 **Buy (強)**: オレンジ (`#FF8C00` / `clrDarkOrange`)
* ⚪ **Neutral (中立)**: 白 / 灰色 (`#DCDCDC` / `clrGainsboro`)
* 🩵 **Sell (弱)**: 水色 (`#00BFFF` / `clrDeepSkyBlue`)
* 🔵 **Strong Sell (最弱)**: 青 (`#0000FF` / `clrBlue`)

---

## 8. Development Roadmap

各フェーズごとの開発ロードマップです。

```text
 [Ver2.11 (現行目標)] ──> [Ver2.20] ──> [Ver2.30] ──> [Ver3.00] ──> [Ver4.00]
 コア分析&UI完成       機能拡張       マクロ統合      高度分析      AI & 統計

```

### 🚀 Ver2.11 (第一段階：コア機能優先)

* [x] Currency Strength Engine & ランキング表示
* [x] Best Pair 選定機能
* [x] 基本 Dashboard UI / モジュール構成化 (`Engines/`, `Display/`, `Core/`)
* [x] Confidence Engine (基礎版)

### 📈 Ver2.20 (第二段階：分析機能の強化)

* [ ] Money Flow Engine & Liquidity Score
* [ ] Market Regime Engine (Risk Score 0–100)
* [ ] Asset Detection (銘柄自動判別)

### 🌐 Ver2.30 (第三段階：マクロ情報の統合)

* [ ] Market Open Countdown (市場オープンタイマー)
* [ ] Economic Events (経済指標イベント表示)
* [ ] 4パターン Display Mode 切替機能

### 🔮 Ver3.00 (将来拡張：高度資金循環分析)

* [ ] Capital Rotation Engine (資金の移動矢印表示)
* [ ] ETF Flow データ連動 (SPY, QQQ, GLD, IBIT等)
* [ ] 相関分析 (Correlation Engine)

### 🤖 Ver4.00 (長期構想：次世代アナリティクス)

* [ ] AI / ML パターン予測エンジン
* [ ] ポートフォリオ最適化分析

---

## 9. Coding & Architecture Standards

### 9.1 命名規則 (Naming Conventions)

* **クラス名**: 先頭に `C` を付与（例: `CMarketRegime`, `CCurrencyStrength`）
* **メンバー変数**: 先頭に `m_` を付与（例: `m_riskScore`）
* **グローバル変数**: 先頭に `g_` を付与（例: `g_dashboard`）
* **入力パラメータ**: 先頭に `Inp` を付与（例: `InpUpdateInterval`）
* **主要メソッド**: 役割に応じた動詞で統一（`Calculate()`, `Update()`, `Draw()`, `Detect()`）
* **ファイル名**: PascalCase（例: `SummaryPanel.mqh`）

### 9.2 インターフェース設計（疎結合原則）

ダッシュボード（`Display`）層は、分析（`Engines`）層の内部計算を知る必要がなく、`Calculate()` を呼び出して結果（スコア・文字列・構造体）を受け取り描画に集中するインターフェース設計を徹底します。

---

## 📖 用語集 (Glossary)

* **Risk ON**: 投資家が株式や暗号資産などのリスク資産へ資金を積極的に移す状態。
* **Risk OFF**: 投資家が国債・金・現金などの安全資産へ資金を退避させる状態。
* **Money Flow**: アセット間を移動するグローバルな資本の流出入・循環。
* **Confidence**: 複数エンジンの判定の一致率から算出される売買シグナルの確信度。
* **Liquidity Score**: 市場参加者の現金化（キャッシュ化）圧力を測定する指標。

```

```
