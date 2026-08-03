# Global Market Dashboard Ultimate Edition

**Project** : Global Market Dashboard Ultimate

**Platform** : MetaTrader 5 (MT5)

**Language** : MQL5

**Repository** : GlobalMarketDashboard

**Current Version** : 2.11 Ultimate (Development)

**Document Version** : Project Specification v0.1

**Author** : Ryoutarou Kadono

**Status** : In Development

## 1. Project Overview
プロジェクト概要

## 2. Development Goals
開発目的

## 3. Design Philosophy
設計思想

Global Market Dashboard Ultimate は

単なるMT5インジケーターではない。

FX・株式・Gold・暗号資産・債券を一つの画面で確認し、

市場全体の資金の流れを短時間で把握するための
マーケット分析ダッシュボードである。

目的は

「相場を見る」のではなく

「世界のお金の流れを見る」

「市場の状態そのものを数値化するエンジン」

## 4. System Overview
システム概要

## 5. Display Modes
画面構成

## 6. Currency Strength Engine
対象通貨

USD
EUR
JPY
GBP
CHF
AUD
CAD

対象通貨ペア

28通貨ペア

判定方法

一定時間内の上昇・下降を判定

上昇
→ 分子 +1

下降
→ 分母 +1

ランキング表示

1位〜7位

色分け

最強：赤

最弱：青

信頼度

現在検討中


## 7. Money Flow Engine

目的

市場全体の資金の流れを可視化する。

対象市場

FX

Gold

Silver

株価指数

暗号資産

債券

リスクオン／リスクオフ

表示方法

↑ 資金流入

→ 中立

↓ 資金流出

色

流入：緑

流出：赤

中立：灰色

## 8. Asset Detection

Asset Detection    
    ↓
    
データ取得    
    ↓
    
Market Regime Engine    
    ↓
    
Money Flow Engine    
    ↓
    
Dashboard表示

Gold

XAUUSD

GOLD

GOLDmicro

Silver

XAGUSD

BTC

BTCUSD

BTCUSDT

Index

US30

NAS100

SPX500

JP225

Asset Detection

FX
・USDJPY
・EURUSD
・GBPUSD

Precious Metals
・Gold
・Silver

Equity Index
・SP500
・NAS100
・US30
・JP225
・GER40
・UK100

Crypto
・BTC
・ETH

Bond
・US10Y
・US30Y

## 9. Market Regime Engine

Inputs

SP500

NASDAQ

US10Y

Gold

USDJPY

BTC

ETH

VIX

DXY

↓

Score

↓

Risk ON

Risk OFF

Neutral

## 10. Confidence Engine

現在検討中

Confidence

判定材料

・Currency Strength
・Money Flow
・Risk Score
・Market Regime
・Momentum

↓

0〜100%


## 11. Best Pair Engine

Best Pair Engine

入力

Currency Strength

↓

最強通貨

最弱通貨

↓

おすすめ通貨ペア

例

EUR ↑

JPY ↓

↓

EURJPY

## 12. Display Modes

Mode 1

Chart

・チャート
・移動平均
・BB
・Pivot

Mode 2

Dashboard

・Market Dashboardのみ

Mode 3

Hybrid

・チャート
・Dashboard

Mode 4

Minimal

・ランキングのみ

## 13. Market Open Countdown

## 14. Economic Events

## 15. Future Roadmap

## 16. Performance Design

更新間隔

1秒

または

新しいバーのみ

CPU負荷

できるだけ低くする

オブジェクト数

最小限

描画

差分更新

## 17. Version History

（ProjectSpecification Ver0.2）

## 18. Module Structure

# システムモジュール構成 (System Modules Architecture)

本プロジェクトは、保守性・再利用性・拡張性を高めるため、以下の役割別ヘッダーファイル（`.mqh`）にクラス・モジュールを分割して開発します。

---

## 📁 モジュール一覧 & 役割定義

```text
src/
├── CurrencyStrength.mqh  // 28通貨ペアの強弱スコア計算エンジン
├── MoneyFlow.mqh         // アセット間（株・金・債券・暗号資産）の資金流出入分析
├── MarketRegime.mqh      // Risk Score (0-100) および Risk ON/OFF 判定
├── AssetDetection.mqh    // ブローカー固有の銘柄名・GOLD等の自動検出
├── Confidence.mqh        // 各エンジンの寄与率に基づく総合確信度 (0-100%) 計算
├── BestPair.mqh          // 最強 vs 最弱の「ベストペア」自動選定ロジック
├── Dashboard.mqh         // Market Summary 含む GUI 描画・UIレイアウト制御
├── EventManager.mqh      // 市場オープンカウントダウン・経済指標イベント管理
├── Utils.mqh             // 配列操作・型変換・汎用補助関数群
└── Logger.mqh            // 動作ログ・エラーハンドリング・デバッグ出力・初期化・シンボル検出・エラー・読み込み
```



## 19. Dashboard Layout

```text
┌─────────────────────────────────────┐
│ Market Summary                      │
│ Risk ON 82%                         │
├─────────────────────────────────────┤
│ Currency Strength                   │
│ USD █████                           │
│ EUR ████                            │
│ JPY █                               │
├─────────────────────────────────────┤
│ Money Flow                          │
│ Stocks ↑                            │
│ Gold ↓                              │
│ Bond ↓                              │
│ Crypto ↑                            │
├─────────────────────────────────────┤
│ Best Pair                           │
│ EURJPY                              │
└─────────────────────────────────────┘

Market Summary

↓

Currency Strength

↓

Best Pair

↓

Money Flow

↓

Market Open

↓

Economic Events
```

## 20. Data Update Policy

通貨強弱

1秒毎

株価指数

5秒毎

Gold

5秒毎

Bond

10秒毎

Economic Event

60秒毎

Market Open

60秒毎

## 21. Symbol Priority

Gold

XAUUSD

↓

GOLD

↓

GOLDmicro

↓

XAUUSD.r

## 22. Settings

Update Interval

Currency Timeframe

Color Theme

Display Mode

Auto Detect Symbols

Show Events

Show Market Open

## 23. Color Rules

Strong Buy

赤

Buy

オレンジ

Neutral

白

Sell

水色

Strong Sell

青

## 24. Future AI Engine

AI Engine

Market Pattern

Money Rotation

Correlation

Probability

Recommendation

## 用語集（Glossary）

Risk ON

投資家がリスク資産へ資金を移す状態

Risk OFF

安全資産へ資金を移す状態

Money Flow

市場間の資金循環

Confidence

売買シグナルの信頼度

Market Regime

市場全体の状態
