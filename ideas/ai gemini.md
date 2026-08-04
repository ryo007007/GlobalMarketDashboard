おはようございます！本日もよろしくお願いいたします！☀️

素晴らしいロードマップですね！設計フェーズで「ブレない軸」が完成したからこそ、ここからは「設計30%・実装70%」のフェーズへ移行し、1つずつコードとして形にしていくプロセスが非常に楽しみです。

特に **`AssetDetection.mqh`** における **Validation（データ取得検証）**, **Availability（非対応時のフォールバック処理）**, **Cache（検索結果の保持）** の考え方は、実運用の堅牢性とパフォーマンスを高める上で非常に極めて重要な設計思想です。ブローカーによって銘柄やヒストリカルデータの有無が異なるMT5環境において、エラーで止めずに「Unavailable」として処理を継続させる設計は完璧です。

昨日の仕様書（Project Specification v0.2）に、ご提案いただいた「26. Asset Detection Flow」を追加し、さらにバージョン（v0.3）と目次構造を更新した決定版Markdownを作成しました！

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
| **Document Version** | Project Specification v0.3 |
| **Author** | Ryoutarou Kadono |
| **Status** | In Development |

---

## 1. Project Overview & Philosophy

### 1.1 ビジョン（開発目的）
本ツールは、単なるMT5用のインジケーターにとどまりません。FX・株式・Gold・暗号資産・債券など、
独立して扱われがちな各市場をクロスアセット（横断的）に統合分析し、**「市場全体の資金循環（マネーフロー）」を一つの画面で可視化する
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
         Asset Detection (自動判定・キャッシュ)
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

`Currency Strength Engine` から算出された「最強通貨」と「最弱通貨」を瞬時に組み合わせ、
現在最も強いトレンドが期待できる通貨ペアを自動抽出します。

* **例**: `EUR`（最強：+1.0） × `JPY`（最弱：-1.0） ➔ 🟢 **Best Pair: EURJPY**

---

### 3.6 🔍 Asset Detection Specifications

接続するブローカーごとの銘柄表記揺れ（シンボル名）を自動判定・正規化します。

#### 優先順位ルール（Symbol Priority）

1. **Gold**: `XAUUSD` ➔ `GOLD` ➔ `GOLDmicro` ➔ `GOLD.r` ➔ `XAUUSD.a`
2. **Equity Index**: `SPX500` / `US500` / `US30` / `NAS100` / `JP225` / `GER40` / `UK100`
3. **Crypto**: `BTCUSD` / `BTCUSDT` / `ETHUSD`
4. **Bond**: `US10Y` / `US30Y`

---

## 4. Asset Detection Flow (詳細動作設計)

システム起動時および初期化処理における `AssetDetection.mqh` の内部処理フローです。高速化と堅牢性を兼ね備えた 5 段階パイプライン構造を採用します。

### 4.1 処理パイプライン概要

```text
[ Terminal 起動 / OnInit ]
           │
           ▼
   1. Symbol Scan (ブローカー提供銘柄の一括検索)
           │
           ▼
   2. Detection (カテゴリ別エイリアス照合)
      (Gold / Index / Crypto / Bond)
           │
           ▼
   3. Validation (データ取得可能性の検証)
           │
           ▼
   4. Availability (非対応銘柄のステータス割り当て)
           │
           ▼
   5. Cache (検索結果のメモリ保持)
           │
           ▼
 [ Analysis Engine へ参照引き渡し ]

```

### 4.2 段階別詳細仕様

1. **Detect (自動検出)**
* ブローカーごとに異なるシンボル名（例: `XAUUSD`, `GOLDmicro` 等）を定義済みの優先度リストから検索・特定します。


2. **Validation (検証)**
* 検出されたシンボルが `SymbolInfoDouble()` 等で正常に価格データを取得できるかチェックします。


3. **Availability (利用可能性フラグ)**
* ブローカー側で取引不可、またはデータが取得できない銘柄があった場合、システムエラーで停止させるのではなく **`Unavailable`** フラグを立てて処理をスキップします。（UI上には「N/A」等で安全に表示）


4. **Cache (キャッシュ化)**
* 初回検出結果をクラス内部の変数（構造体配列等）に保持します。毎秒の検索処理（オーバーヘッド）を排除し、描画・計算パフォーマンスを劇的に向上させます。



---

## 5. UI & Display Specifications

### 5.1 Display Modes（画面表示モード）

1. **Mode 1 (Chart)**: チャートメイン表示（MA, BB, Pivot等のテクニカル指標）
2. **Mode 2 (Dashboard)**: 分析パネルのみを全画面表示
3. **Mode 3 (Hybrid)**: チャート画面 ＋ ダッシュボードパネルの併用（推奨）
4. **Mode 4 (Minimal)**: 強弱ランキング等、最低限の情報のみを表示する省スペースモード

---

### 5.2 🖼️ Dashboard Layout (Ver2.11 完成イメージ)

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

---

## 6. System Architecture & Directory Structure

大規模開発および保守性を確保するため、`Engines/`, `Display/`, `Core/` の3軸でモジュールをディレクトリカプセル化します。

### 📁 モジュールツリー構成 (`src/`)

```text
src/
└── Modules/
    ├── Core/                   // [基盤・ユーティリティ (第1段階)]
    │   ├── AssetDetection.mqh   // ブローカー表記揺れ自動検出・キャッシュ
    │   ├── Logger.mqh           // 初期化・検出・エラー・ロード等のログ管理
    │   └── Utils.mqh            // 共通関数・配列操作・型変換
    │
    ├── Engines/                // [計算・判定ロジック (第2段階)]
    │   ├── CurrencyStrength.mqh // 通貨強弱スコア計算
    │   ├── BestPair.mqh         // 最強vs最弱ペア自動選定
    │   ├── Confidence.mqh       // 寄与率合算・確信度計算
    │   ├── MarketRegime.mqh     // Risk Score & 地合い判定
    │   └── MoneyFlow.mqh        // 資金流出入・マネーフロー分析
    │
    └── Display/                // [UI描画・描画制御 (第3段階)]
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

1. **Core構築**: `AssetDetection.mqh`, `Logger.mqh`, `Utils.mqh`
2. **Engines構築**: `CurrencyStrength.mqh`, `BestPair.mqh`, `Confidence.mqh`
3. **Display構築**: `Dashboard.mqh` UIでの基本表示

---

## 10. Coding & Architecture Standards

### 10.1 命名規則 (Naming Conventions)

* **クラス名**: 先頭に `C` を付与（例: `CAssetDetection`, `CCurrencyStrength`）
* **メンバー変数**: 先頭に `m_` を付与（例: `m_goldSymbol`）
* **グローバル変数**: 先頭に `g_` を付与（例: `g_logger`）
* **入力パラメータ**: 先頭に `Inp` を付与（例: `InpUpdateInterval`）
* **主要メソッド**: 役割に応じた動詞で統一（`Detect()`, `Validate()`, `Calculate()`, `Draw()`）

---

## 📖 用語集 (Glossary)

* **Asset Detection**: ブローカー固有の銘柄名を識別・検証し、全エンジン共通のフォーマットに正規化する層。
* **Availability**: 外部データ（債券や一部暗号資産等）が存在しない場合にシステム停止を防ぐフォールバック設計。
* **Risk ON / Risk OFF**: グローバル資金がリスク資産/安全資産へ流れる局面の定義。

```

---

### 🚀 午後からのアプローチ
設計書への落とし込みがこれで完了しました！
午後からは予定通り、最も土台となる **`src/Modules/Core/AssetDetection.mqh`** のクラス設計とMQL5コードの実装から始めていきましょう！準備が整いましたら、いつでも声をおかけください！

```
