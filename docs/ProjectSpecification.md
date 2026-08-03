# Global Market Dashboard Ultimate

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

ProjectSpecification v0.1

## 18. Module Structure

Modules

CurrencyStrength.mqh

MoneyFlow.mqh

MarketRegime.mqh

AssetDetection.mqh

Confidence.mqh

BestPair.mqh

Dashboard.mqh

EventManager.mqh

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
