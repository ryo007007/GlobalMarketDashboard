```markdown
# CCompression Specification Ver.0.1

## 1. 目的

CCompression は、市場の変動幅の縮小を中心として、市場がCompression状態にある可能性を検出し、その後の状態変化を観測する。ADXはトレンド強度を評価する補助指標として使用する。

### 重要
CCompression は以下を**行わない**：
- 上昇予測
- 下落予測
- ブレイクアウト予測

あくまで以下の市場状態を検出する：
```
NORMAL → COMPRESSION → STRONG COMPRESSION → TIGHT COMPRESSION → TRANSITION
```

---

## 2. 対象時間足

### 本番仕様（Ver.1）
**D1 固定**

Market Regime との整合性を優先する。

### 開発・検証用
現在の `Test_Compression.mq5` では、D1 だけでなく H4 などでも検証可能としている。

> **本番 Ver.1 では D1 を標準時間足とする。**  
> **開発・検証段階では H4 等を使用して挙動確認を行う。**

※ USDJPY / GOLD / GBPJPY の H4 検証は、本番仕様を H4 に変更したものではない。

---

## 3. ATR

| 項目 | 設定 |
|------|------|
| Period | ATR(14) |
| Raw | `ATR% = ATR(14) / Close × 100` |
| Percentile | 過去 125 期間の ATR% 分布における現在値のパーセンタイル |

### Score
| Percentile | Score |
|------------|-------|
| 0 ～ 20    | 2     |
| >20 ～ 35  | 1     |
| >35        | 0     |

---

## 4. Bollinger Band Width

| 項目 | 設定 |
|------|------|
| Period | 20 |
| Deviation | 2.0 |
| Raw | `BB Width = (Upper Band - Lower Band) / Middle Band × 100` |
| Percentile | 過去 125 期間と比較 |

### Score
| Percentile | Score |
|------------|-------|
| 0 ～ 10    | 2     |
| >10 ～ 20  | 1     |
| >20        | 0     |

※ Compression 指標として特に重要。

---

## 5. 20期間 Range

| 項目 | 設定 |
|------|------|
| Raw | `Range20% = (Highest High[20] - Lowest Low[20]) / Close × 100` |
| Percentile | 過去 125 期間と比較 |

### Score
| Percentile | Score |
|------------|-------|
| 0 ～ 20    | 2     |
| >20 ～ 40  | 1     |
| >40        | 0     |

---

## 6. ADX

| 項目 | 設定 |
|------|------|
| Period | ADX(14) |
| 判定方式 | Percentile ではなく**絶対値**を使用 |

### Score
| ADX値     | Score |
|-----------|-------|
| < 15      | 2     |
| 15 ～ <20 | 1     |
| ≥ 20      | 0     |

---

## 7. Compression Score

4 指標の合計：

```
ATR       0～2
BB Width  0～2
Range20   0～2
ADX       0～2
----------------
Total     0～8
```

### 状態定義
| Score | State                |
|-------|----------------------|
| 0～2  | NORMAL               |
| 3～4  | COMPRESSION          |
| 5～6  | STRONG COMPRESSION   |
| 7～8  | TIGHT COMPRESSION    |

※ 本値は Ver.0.1 の仮説値とする。

---

## 8. 状態遷移（Delta による観測）

Ver.0.1 では、正式な `BUILDING` / `RELEASE` 状態は持たない。

現在取得可能な情報は以下：
- Score
- Previous Score
- Delta
- Age
- State

**Delta から Compression の強弱変化を観測する。**

例：
- Score 3 → 4（Delta +1） → Compression Strengthening
- Score 5 → 4（Delta -1） → Compression Weakening

将来 Dashboard で `BUILDING` / `RELEASING` 表示を追加するのは別の改良として扱う。

---

## 9. TRANSITION

**TRANSITION は、単なる Score 低下では発生させない。**

以下の **3 条件をすべて満たした場合** に TRANSITION とする。

### 条件A
前回状態が以下のいずれか：
- STRONG COMPRESSION
- TIGHT COMPRESSION

### 条件B
```
Current Score < Previous Score
```

### 条件C
現在の値が前回値より上昇している：
```
ATR% > 前回ATR%
または
BB Width > 前回BB Width
```

3 条件を満たすと `TRANSITION` となる。

---

## 10. 方向判定を行わない

CCompression は「圧縮が解除され始めた」ことまでを検出する。

その後の方向は以下の別 Engine から取得する：

```
CCompression
      ↓
TRANSITION
      │
      ├── Currency Strength
      ├── Strength Gap
      ├── Money Flow
      └── Market Regime
```

CCompression 自身が方向性を出力しない設計を維持する。

---

## 11. Output

### メイン表示（Ver.0.1）
```
Compression: TIGHT
Score: 7/8
Delta: +1
Age: 3
```

### 詳細表示（将来拡張）
```
ATR       2/2
BB Width  2/2
Range20   2/2
ADX       1/2
```

### 現在の State 一覧
- NORMAL
- COMPRESSION
- STRONG COMPRESSION
- TIGHT COMPRESSION
- TRANSITION

※ `State: BUILDING` は現時点では使用しない。

---

## 12. Delta

```
Delta = Current Score - Previous Score
```

例：
- 2 → 3 = +1
- 3 → 5 = +2
- 4 → 3 = -1

Compression の強さが強まっているか弱まっているかを示す指標。

---

## 13. Age

```
Age = 現在の STATE が何回連続して続いているか
```

実装ルール：
- 前回 State == 今回 State → Age + 1
- State が変化 → Age = 1

例（H4 の場合）：
```
H4 #1  NORMAL
H4 #2  COMPRESSION  → Age 1
H4 #3  COMPRESSION  → Age 2
H4 #4  COMPRESSION  → Age 3
H4 #5  COMPRESSION  → Age 4
H4 #6  NORMAL       → Age 1（リセット）
```

---

## 14. データ取得・計算タイミング

- 確定済みバーを使用する
- 現在形成中のバーは判定に使用しない
- 新しい対象時間足バーが開始された時に再計算する
- Ver.1 の対象時間足は D1
- 開発・検証では H4 等を使用可能

---

## 15. 未使用・将来拡張

- `BUILDING` / `RELEASING` 状態の正式導入
- H4 / H1 / M15 への時間足拡張
- Dashboard 詳細表示の拡充
- 他 Engine（Currency Strength / Money Flow / Market Regime）との連携強化

---

**End of Specification Ver.0.1**
```
