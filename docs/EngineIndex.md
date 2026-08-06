# Engine Index（エンジン一覧とテスト対応）

各エンジンと単体テストの対応表。  
詳細仕様は `ProjectSpecification.md`、層構造は `Architecture.md` を参照。

| Engine | ファイル | 実装時期 | テスト |
|--------|----------|----------|--------|
| Currency Strength | `Engines/CurrencyStrength.mqh` | 2.11 ✅ | `Test_CurrencyStrength.mq5` |
| Best Pair | `Engines/BestPair.mqh` | 2.11 ✅ | `Test_BestPair.mq5` |
| Confidence | `Engines/Confidence.mqh` | 2.11 ✅ | `Test_Confidence.mq5` |
| Anomaly | `Engines/AnomalyEngine.mqh` | 2.11 ✅ | `Test_AnomalyEngine.mq5` |
| Energy | `Engines/EnergyEngine.mqh` | 2.11 ✅ | `Test_EnergyEngine.mq5` |
| Adaptive Update | `Engines/AdaptiveUpdate.mqh` | 2.11 ✅ | `Test_AdaptiveUpdate.mq5` |
| Money Flow | `Engines/MoneyFlow.mqh` | 2.20 枠 | `Test_MoneyFlow.mq5` |
| Market Regime | `Engines/MarketRegime.mqh` | 2.20 枠 | `Test_MarketRegime.mq5` |
| Market State | `Engines/MarketState.mqh` | 2.30 枠 | `Test_MarketState.mq5` |
| Alert | `Engines/AlertEngine.mqh` | 2.30 枠 | `Test_AlertEngine.mq5` |
| Correlation | `Engines/CorrelationEngine.mqh` | 3.00 予約 | `Test_CorrelationEngine.mq5` |
| Statistics | `Engines/StatisticsEngine.mqh` | 3.00 予約 | `Test_StatisticsEngine.mq5` |

## Core（エンジン以外の主要モジュール）

| モジュール | テスト |
|------------|--------|
| Asset Detection | `Test_AssetDetection.mq5` |
| Session Clock | `Test_SessionClock.mq5` |

## 方針

- **1 Engine = 1 Test** を目標にする（予約枠もプレースホルダで確保）
- 未実装エンジンのテストは「落ちない・IsReady=false」を確認するだけにする
- 本実装が入ったら、そのテストを「値域・境界・表示」の検証に書き換える

## 将来の docs 分割案（任意）

必要になったタイミングで、次のように Engine 単位の設計メモを増やしてよい。

```text
docs/
  EngineDesign/
    CurrencyStrength.md
    MoneyFlow.md
    AssetDetection.md
    ...
  DisplayDesign.md
```

今は `ProjectSpecification.md` が正本なので、無理に分割しない。
