# システムアーキテクチャ

本ドキュメントは、現行の GMD プロジェクト構造を **実装ベース** で説明するための要約版です。詳細仕様は `ProjectSpecification.md` を正本とし、本書は「どの層が何を担当するか」を素早く把握するために使います。

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
   └─ AlertEngine      : [2.30]
   │
   ▼
Display
   ├─ DrawObjects      : オブジェクト生成/更新の下請け
   └─ Dashboard        : 1枚パネルの統括
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
- `IEngine` は `src/Modules/Interfaces/IEngine.mqh` に分離し、将来の拡張時に型定義との責務を混ぜない構成にしています。

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
  → Dashboard
```

以下は予約済みです。

- `MoneyFlow.mqh` `[2.20]`
- `MarketRegime.mqh` `[2.20]`
- `MarketState.mqh` `[2.30]`
- `AlertEngine.mqh` `[2.30]`

重要なのは、**予約席を作ること** と **未完成機能を完成扱いしないこと** を分けることです。

---

## 4. 起動から描画まで

```text
OnInit()
  ├─ Logger 初期化
  ├─ AssetDetection 初期化
  ├─ 各Engine 初期化
  ├─ Dashboard 構築
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
  ├─ Dashboard.Update()
  └─ AdaptiveUpdate に応じてタイマー再設定
```

---

## 5. 今回の構造改善

今回の整理で、レビュー指摘のうち将来効く部分を先に反映しています。

### 5.1 Interfaces を分離
- `Interfaces/IEngine.mqh`
- `Interfaces/IDashboard.mqh`
- `Interfaces/IIndicator.mqh`

### 5.2 Constants を分離
- `Core/Constants.mqh`
- 既存の `Types.mqh` からマジックナンバーを切り離し

### 5.3 Config の受け皿を追加
- `Core/Config.mqh`
- 本体 `input` 群を将来段階的に構造化する準備

### 5.4 AssetDetection の境界を明確化
- `Core/SymbolCache.mqh` を追加
- L1（メモリ）と L2（CSV永続化）を今後分離しやすい形に変更

### 5.5 Session の発展余地を確保
- `Core/SessionClock.mqh` は現役の実装
- `Core/SessionManager.mqh` は将来の多市場統括の受け皿

---

## 6. 補足

- 仕様の正本: `docs/ProjectSpecification.md`
- ユーザー向け説明: `docs/UserManual.md`
- 実装判断の背景: `docs/DevelopmentPolicy.md`
