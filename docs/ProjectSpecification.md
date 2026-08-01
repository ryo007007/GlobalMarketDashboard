# Global Market Dashboard Ultimate

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

ことである。

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

## 11. Best Pair Engine

## 12. Market Open Countdown

## 13. Economic Events

## 14. Future Roadmap

## 15. Version History
