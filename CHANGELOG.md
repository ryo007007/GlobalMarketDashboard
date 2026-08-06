
# Changelog

## v2.11

Project Started

Initial Repository

### Core

- `Types.mqh` 追加。全モジュール共通の enum / struct / `IEngine` を一箇所に集約
- `Logger.mqh` 追加。5段階のログレベルとエラーコード（`[GMD][WARN][CS-101]` 形式）
- `AssetDetection.mqh` 追加。接尾辞の自動検出、8アセット・28通貨ペアの検証
- `Utils.mqh` 追加。桁揃え・時間足表記・更新間隔判定などの汎用関数

### Engines

- `CurrencyStrength.mqh` 追加。8通貨28ペアを直近N本で重み付け集計
- `BestPair.mqh` 追加。最強×最弱から推奨ペアと方向を1つ提案
- `Confidence.mqh` 追加。Ver2.11 暫定式で信頼度を0〜100%表示
- `AnomalyEngine.mqh` 追加。暦から決まる統計的な偏りを点数化する独立エンジン
  - 規則表方式。18規則を登録（実装13 / Ver2.20予約5）
  - `scope` で資産を分離。Sell in May を通貨ペアに加算しない
  - 五十日は東京時間で判定し、8:00〜10:30 の仲値前後のみ有効
  - 月別 Market Season Score（Bull / Neutral / Bear）
  - 合計は ±15 で打ち止め。星4未満の規則は既定で無効
  - 既定では Confidence の数値に加算せず、別行で並べて表示
  - リスク志向バイアス（`GetRiskBiasScore()`）を追加。株の季節性から
    「リスクを取りやすい季節か」だけを導く。株スコアの1/2・上限±5で、
    通貨ペアのスコアには加算しない。Ver2.20の MarketRegime が入力として読む
- `MoneyFlow.mqh` / `MarketRegime.mqh` は枠のみ（Ver2.20で実装）

### Display

- `DrawObjects.mqh` 追加。オブジェクトの生成・差分更新・一括削除
- `Dashboard.mqh` 追加。ランキング8行 + Best Pair + Confidence + Anomaly の1枚パネル

### Main

- `MarketDashboard_Ultimate.mq5` 追加。Core → Engines → Display の結線
- 更新はタイマー方式。毎ティック計算しない
- 足の確定時のみ更新するモードを追加

### Docs

- `docs/ProjectSpecification.md` を v1.3 に更新

---

## 仕様変更の記録

### v1.3 (仕様書)

- 通貨強弱を「1本の陰陽線」から「直近N本の重み付き集計」に変更
- 矢印を水準ではなく勢いの指標として分離（7段階）
- 段階色（6色グラデーション）を廃止し、赤・白・青の3色に簡素化
- 7通貨・28ペアという記述の誤りを修正（28ペアは8通貨の組み合わせ）
- NZD を対象通貨に追加
