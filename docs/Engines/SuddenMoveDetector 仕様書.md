# SuddenMoveDetector 仕様書

| 項目 | 内容 |
|------|------|
| モジュール名 | SuddenMoveDetector |
| ファイル名 | `SuddenMoveDetector.mqh` |
| 対象プラットフォーム | MetaTrader 5 (MQL5) |
| 用途 | MTF_TrendSign ダッシュボード等への組込み用 急変検知モジュール |
| バージョン | 1.0 |
| 最終更新 | 2026-10-08 |

---

## 1. 目的

SuddenMoveDetector（以下 SMD）は、以下の3つの条件を組み合わせて  
**急変（Sudden Move）を早期に検知**するモジュールである。

1. **ATRスパイク**  
   直近バーの値幅が平均ATRに対して異常に拡大しているか

2. **ROC Zスコア**  
   直近の価格変化率が、過去分布に対して統計的に異常か

3. **複数ペア同時性**  
   特にJPYクロス複数ペアが同方向に同時急変しているか

これにより、単一銘柄のノイズではなく、**市場全体のリスクリバーサル（リスクオフ／リスクオン）の初期段階**を捉えることを目的とする。

**重要**  
本モジュールは「今後どう動くか」の方向予測を行わない。  
「今、異常な動きが起きている」という事実のみを検知する。

---

## 2. 設計思想

- **AND条件を基本とする**  
  ATRスパイク と ROC Zスコアの両方を満たした場合のみ「急変」と判定する。  
  どちらか一方だけでは通常のセッション内値動きでも頻繁にヒットするため。

- **複数ペア同時性を重視**  
  1銘柄だけの急変はノイズの可能性が高い。  
  特にJPYクロスが複数同時に同方向へ動いた場合に「広がりのある動き」とみなす。

- **連発防止**  
  同一シンボルに対して短時間に何度もアラートを出さない。

- **再利用性**  
  グローバル状態に依存しない単体判定関数 `SMD_CheckSpike()` を用意し、  
  CCompression Scanner など他モジュールからも利用可能にする。

- **ハンドル管理**  
  iATRハンドルは Init 時に一度だけ作成し、Deinit で必ず解放する。

---

## 3. 入力パラメータ

| パラメータ名 | 型 | 既定値 | 説明 |
|--------------|-----|--------|------|
| `SMD_ATR_Period` | int | 14 | ATR計算期間 |
| `SMD_ATR_SpikeMult` | double | 2.5 | ATRスパイク判定倍率（直近バーレンジ / 平均ATR） |
| `SMD_ROC_Period` | int | 5 | ROC計算期間（本数） |
| `SMD_ROC_ZLookback` | int | 50 | ROC平均・標準偏差算出用の過去本数 |
| `SMD_ROC_ZThreshold` | double | 2.0 | ROC Zスコア閾値（何σ以上で急変とみなすか） |
| `SMD_MinAlignedPairs` | int | 3 | 何ペア同時検知でリスクオフ/オン確定とみなすか |
| `SMD_OnlyJPYCrosses` | bool | true | JPYクロスのみを対象にするか（呼び出し側で制御） |

---

## 4. コア判定ロジック

### 4.1 ATRスパイク

```text
atrAverage  = 直近確定バーのATR(14)
atrCurrent  = 形成中バーの High - Low
atrRatio    = atrCurrent / atrAverage

atrSpike = (atrRatio >= SMD_ATR_SpikeMult)
```

- ハンドルは `SMD_Init()` で一度だけ作成する。  
  毎ティック作成すると計算が間に合わず、ATR比が常に0になるバグの原因になる。

### 4.2 ROC Zスコア

```text
ROC[i] = (Close[i] - Close[i + ROC_Period]) / Close[i + ROC_Period] * 100

mean   = 過去 SMD_ROC_ZLookback 本のROC平均
stdev  = 同期間の標準偏差

rocZScore = (現在ROC - mean) / stdev

rocSpike = (|rocZScore| >= SMD_ROC_ZThreshold)
isDirUp  = (現在ROC > 0)
```

### 4.3 最終急変判定

```text
isSpike = atrSpike AND rocSpike
```

両方の条件を満たした場合のみ「急変中」と判定する。

---

## 5. 複数ペア同時性（Broad Risk Move）

```text
upCount   = 上昇急変と判定されたシンボル数
downCount = 下落急変と判定されたシンボル数

if downCount >= SMD_MinAlignedPairs → リスクオフ（円買い優勢）
if upCount   >= SMD_MinAlignedPairs → リスクオン（円売り優勢）
```

- 単発の急変ではなく、**市場全体に広がった動き**かどうかを判定する。
- 主にJPYクロスを対象にすることで、リスクオフ／リスクオンの初期シグナルとして機能する。

---

## 6. Pivotスクイーズ検知（前日警戒シグナル）

急変の「前兆」として、前日のPivot幅（R1-S1）が過去平均に対してどれだけ狭いかを見る。

```text
Pivot = (High + Low + Close) / 3
R1    = 2 * Pivot - Low
S1    = 2 * Pivot - High
range = R1 - S1

squeezeRatio = 前日range / 過去N日平均range

squeeze状態 = (squeezeRatio <= 閾値)
```

- `SMD_CheckPivotSqueeze()` : 1シンボル判定
- `SMD_CountPivotSqueezeSymbols()` : 監視対象全体でスクイーズ状態のシンボル数を返す

複数シンボルで同時にスクイーズしている場合、「市場全体が方向感を欠いて溜め込んでいる」状態と解釈できる。

---

## 7. 公開インターフェース

### 7.1 初期化・終了

| 関数 | 説明 |
|------|------|
| `SMD_Init(symbols[], count, tf)` | 監視シンボルと時間足を登録。iATRハンドルを作成 |
| `SMD_Deinit()` | 作成したハンドルをすべて解放。OnDeinit から必ず呼ぶこと |

### 7.2 更新・取得

| 関数 | 説明 |
|------|------|
| `SMD_Update()` | 全監視シンボルの状態を再計算。OnTimer から定期的に呼ぶ |
| `SMD_GetAlertCount(dirUp)` | 指定方向の急変シンボル数を返す |
| `SMD_IsBroadRiskMove(isRiskOff)` | 閾値以上の同時急変があれば true。方向を isRiskOff に格納 |
| `SMD_GetState(index, outState)` | 個別シンボルの状態を取得（パネル表示用） |
| `SMD_ShouldFireAlert(st, cooldownSeconds)` | 連発防止付きアラート発火判定 |

### 7.3 単体判定（他モジュール連携用）

| 関数 | 説明 |
|------|------|
| `SMD_CheckSpike(symbol, tf, atrHandle, isSpike, isUp, atrRatio, rocZ)` | グローバル状態に依存しない単体急変判定。CCompression Scanner 等から利用可能 |
| `SMD_CheckPivotSqueeze(...)` | 1シンボルのPivotスクイーズ判定 |
| `SMD_CountPivotSqueezeSymbols(...)` | 監視対象全体のスクイーズ数 |

---

## 8. 組込み手順（MTF_TrendSign 等への組込み例）

```mql5
// 1. メインファイル冒頭
#include "SuddenMoveDetector.mqh"

// 2. OnInit()
string symbols[] = {"USDJPY", "EURJPY", "GBPJPY", "AUDJPY", "NZDJPY", "CADJPY", "CHFJPY"};
SMD_Init(symbols, ArraySize(symbols), PERIOD_M5);

// 3. OnTimer() 内
SMD_Update();

bool isRiskOff;
if(SMD_IsBroadRiskMove(isRiskOff))
  {
   // 既存のアラート関数を呼ぶ
   // isRiskOff == true  → リスクオフ
   // isRiskOff == false → リスクオン
  }

// 4. OnDeinit()
SMD_Deinit();
```

---

## 9. 実装上の注意点

- **iATRハンドルは Init で1回だけ作成する**  
  毎ティック作成すると計算が間に合わず、ATR比が常に0になる。

- **形成中バーを使用している**  
  急変を早く捉えるため、shift=0 のレンジを使用している。  
  確定足のみにしたい場合は呼び出し側で調整すること。

- **データ不足時は false を返す**  
  履歴が足りない場合は判定せず、次の更新を待つ。

- **Deinit を忘れない**  
  ハンドルリークを防ぐため、OnDeinit から必ず `SMD_Deinit()` を呼ぶ。

---

## 10. 他モジュールとの関係

- **CCompression**  
  圧縮状態の検知後、解放（TRANSITION）時に急変が起きやすいかを  
  `SMD_CheckSpike()` で補完判定できる。

- **Market Regime / Money Flow**  
  広がりのある急変（Broad Risk Move）は、Regime や Money Flow の変化の  
  初期シグナルとして利用可能。

- **Alert Engine**  
  実際の通知（Push / Popup / Sound）は呼び出し側または Alert Engine に委譲する。  
  本モジュールは「判定」と「連発防止」までを担当する。

---

## 11. 既知の制約・今後の拡張

| 項目 | 内容 |
|------|------|
| 対象 | 主にJPYクロスを想定。他通貨ペアでも動作するが、閾値調整が必要 |
| 時間足 | 呼び出し側で指定。短すぎる時間足ではノイズが増える |
| 前兆検知 | Pivotスクイーズは「可能性」の提示であり、必ずしも急変に至るとは限らない |
| 今後の拡張 | ・セッション時間帯による閾値調整<br>・出来高（ティックボリューム）の併用<br>・CCompression との正式連携インターフェース |

---

**End of SuddenMoveDetector Specification**
```
