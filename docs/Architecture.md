# システムアーキテクチャ

本ドキュメントは、現行の GMD プロジェクト構造を **実装ベース** で説明するための要約版です。  
詳細仕様は `ProjectSpecification.md` を正本とし、本書は「どの層が何を担当するか」を素早く把握するために使います。

---

## 1. 全体像

```text
MT5 Terminal
   │
   ├─ 価格 / バー / 気配値 / 銘柄一覧
   ▼
Core
   ├─ Constants        : 共通定数
   ├─ Types            : 列挙型・構造体
   ├─ Config           : 設定統合の受け皿
   ├─ Logger           : ログと診断
   ├─ Utils            : 汎用関数
   ├─ AssetDetection   : この口座で何が使えるかを確定
   ├─ SessionClock     : 現地時刻ベースの市場セッション判定
   ├─ SymbolCache      : [2.20] L2キャッシュ境界
   └─ SessionManager   : [2.20+] セッション統括の受け皿
   │
   ▼
Engines
   ├─ CurrencyStrength : 8通貨・28ペアの強弱
   ├─ BestPair         : 最強×最弱から提案ペアを選定
   ├─ Confidence       : エンジン結果の一致度
   ├─ AnomalyEngine    : 暦の文脈
   ├─ EnergyEngine     : 圧縮の蓄積
   ├─ AdaptiveUpdate   : 更新間隔の段を決定
   ├─ MoneyFlow        : [2.20]
   ├─ MarketRegime     : [2.20]
   ├─ MarketState      : [2.30]
   ├─ AlertEngine      : [2.30]
   ├─ PriceLevelEngine : [2.20+] 重要価格帯
   ├─ PivotEngine      : [2.20+] ピボット（Weekly 優先）
   ├─ CorrelationEngine: [3.00] 予約
   └─ StatisticsEngine : [3.00] 予約
   │
   ▼
Display
   ├─ DrawObjects      : オブジェクト生成/更新の下請け
   ├─ Dashboard        : 1枚パネルの統括・指揮
   ├─ SummaryPanel     : Best Pair / Confidence / Regime 行
   ├─ RankingPanel     : 通貨強弱ランキング 8 行
   ├─ MoneyFlowPanel   : [2.20] 資金フロー行
   ├─ StatusBar        : フッター（更新間隔・ペア数・時刻）
   └─ ChartOverlay     : [2.30+] Hybrid モード用チャート要素
   │
   ▼
Chart
```

---

## 2. 依存ルール

```text
Display  ──依存──▶  Engines  ──依存──▶  Core
```

- Core は最下層です。上位層を参照しません。
- Engines は計算だけを担当し、描画を持ちません。
- Display は描画だけを担当し、分析ロジックを持ちません。
- `IEngine` / `IDashboard` / `IIndicator` は `src/Modules/Interfaces/` に分離し、型定義との責務を混ぜません。

---

## 3. Ver2.11 の実働範囲

現時点で「動くこと」が完成条件に入っているのは次の流れです。

```text
AssetDetection
  → CurrencyStrength
  → AnomalyEngine
  → EnergyEngine
  → BestPair
  → Confidence
  → Dashboard（＋分割パネル骨格）
```

以下は予約済みです。

- `MoneyFlow.mqh` `[2.20]`
- `MarketRegime.mqh` `[2.20]`
- `MarketState.mqh` `[2.30]`
- `AlertEngine.mqh` `[2.30]`
- `PriceLevelEngine.mqh` `[2.20+]`
- `PivotEngine.mqh` `[2.20+]`
- `CorrelationEngine.mqh` `[3.00]`
- `StatisticsEngine.mqh` `[3.00]`

重要なのは、**予約席を作ること** と **未完成機能を完成扱いしないこと** を分けることです。

---

## 4. 起動から描画まで

```text
OnInit()
  ├─ Logger 初期化
  ├─ AssetDetection 初期化
  ├─ 各Engine 初期化
  ├─ Dashboard 構築（内部で各 Panel を初期化）
  ├─ 初回計算
  ├─ 初回描画
  └─ MillisecondTimer 開始
```

定常稼働は `OnTimer()` が主ループです。

```text
OnTimer()
  ├─ 更新タイミング判定
  ├─ CurrencyStrength.Calculate()
  ├─ AnomalyEngine.Calculate()
  ├─ EnergyEngine.Calculate()
  ├─ BestPair.Calculate()
  ├─ Confidence.Calculate()
  ├─ Dashboard.Update()  （各 Panel へ差分更新を委譲）
  └─ AdaptiveUpdate に応じてタイマー再設定
```

---

## 5. Display 分割方針

Ver2.11 時点では描画ロジックの多くが `Dashboard.mqh` に集約されている。  
将来の保守性のため、以下のパネルに段階的に切り出す。

| ファイル | 担当 | 導入時期 |
|----------|------|----------|
| `SummaryPanel.mqh` | Best Pair / Confidence / Regime 行 | 骨格済 → 本実装は描画安定後 |
| `RankingPanel.mqh` | 通貨強弱 8 行 | 骨格済 |
| `MoneyFlowPanel.mqh` | 資金フロー行 | [2.20] |
| `StatusBar.mqh` | フッター（間隔・段・時刻） | 骨格済 |
| `ChartOverlay.mqh` | Hybrid モードのチャート要素 | [2.30+] |
| `DrawObjects.mqh` | 低レベル ObjectCreate / Set の共通化 | ✅ |
| `Dashboard.mqh` | 統括・レイアウト・呼び出し順 | ✅ |

切り出しの原則：
- **先に動くものを壊さない**。骨格を置き、中身は Dashboard が動いている間に徐々に移す。
- 各 Panel は `Build()` / `Update()` / `Destroy()` のライフサイクルを持つ（`IDashboard` 契約に準拠）。

---

## 6. 今回の構造改善（反映済み）

### 6.1 Interfaces を分離
- `Interfaces/IEngine.mqh`
- `Interfaces/IDashboard.mqh`
- `Interfaces/IIndicator.mqh`

### 6.2 Constants / Config を分離
- `Core/Constants.mqh`
- `Core/Config.mqh`

### 6.3 AssetDetection の境界を明確化
- `Core/SymbolCache.mqh`（L2 永続化の受け皿）

### 6.4 Session の発展余地
- `Core/SessionClock.mqh`（現役）
- `Core/SessionManager.mqh`（将来の多市場統括）

### 6.5 Display の分割骨格
- Summary / Ranking / MoneyFlow / StatusBar / ChartOverlay を追加

### 6.6 将来 Engine の予約席
- `PriceLevelEngine.mqh` `[2.20+]`
- `PivotEngine.mqh` `[2.20+]`
- `CorrelationEngine.mqh` `[3.00]`
- `StatisticsEngine.mqh` `[3.00]`

---

## 7. 補足

- 仕様の正本: `docs/ProjectSpecification.md`
- ユーザー向け説明: `docs/UserManual.md`
- 実装判断の背景: `docs/DevelopmentPolicy.md`
