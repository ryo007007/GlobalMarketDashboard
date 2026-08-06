# Global Market Dashboard Ultimate Edition — プロジェクト仕様書

| 項目 | 内容 |
|---|---|
| Project | Global Market Dashboard Ultimate |
| Platform | MetaTrader 5 (MT5) |
| Language | MQL5 |
| Repository | GlobalMarketDashboard |
| Current Version | 2.11 Ultimate (Development) |
| Document Version | Project Specification **v1.4** |
| Author | Ryoutarou Kadono |
| Status | In Development（実装フェーズ / Ver2.11 着手中） |
| Last Update | 2026-08-06 |

> **本書の位置づけ**：本書はGMDの単一の正（Single Source of Truth）である。実装・レビュー・将来の機能追加は、すべて本書を起点とする。
>
> **本書は完成版ではない。** コードを書けば必ず「この仕様の方が良い」が出てくる。それが正常であり、そのたびに本書を更新して `v1.1` → `v1.2` → `v2.0` と育てていく。仕様書が更新されないプロジェクトは、設計書とコードが乖離して最終的に設計書が捨てられる。**更新されることを前提に書いてある**（35.5参照）。

---

## 目次

**Part I — プロジェクト定義**
1. プロジェクト概要　2. 開発目的　3. 設計思想　4. システム概要（Architecture Diagram）

**Part II — 分析エンジン仕様**
5. Currency Strength Engine　6. Money Flow Engine　7. Market Regime Engine
8. Confidence Engine　9. Best Pair Engine　10. Anomaly Engine

**Part III — 表示仕様**
11. 表示モード　12. マーケットオープン　13. 経済指標イベント
14. ダッシュボードレイアウト　15. 色分けルール

**Part IV — 実装基盤**
16. パフォーマンス設計　17. バージョン履歴　18. モジュール構成
19. データ更新ポリシー　20. シンボル優先順位　21. 設定項目
22. 用語集　23. コーディング規約

**Part V — 計画**
24. 将来的な分析エンジン　25. 開発ロードマップ

**Part VI — 詳細設計（実装者向け）**
26. Asset Detection Flow　27. Test Plan　28. 未確定事項
29. Class Diagram　30. Data Flow　31. Error Handling
32. Performance Benchmark　33. Release Checklist
34. Known Limitations　35. ドキュメント体系とリポジトリ構成

**付録**
A. AssetDetection.mqh 実装スケルトン　B. 共通データ構造リファレンス

---

## 0. 本書の読み方（Document Conventions）

### 0.1 章の共通構成

Part II（5〜10章）の各エンジン章は、すべて同じ順序で記述する。目的の議論と実装の詳細を混ぜないための規約である。

| 節 | 内容 | 読む人 |
|---|---|---|
| x.1 Purpose | 何のための機能か。1〜3文で言い切る | 全員 |
| x.2 Inputs | 入力データと前提条件。表で明記 | 実装者 |
| x.3 Calculation | 計算式・判定ロジック | 実装者 |
| x.4 Output | 出力する値と型 | 実装者 |
| x.5 Display | 画面上での見え方 | 実装者・利用者 |
| x.6 Class Interface | `.mqh` のクラス定義 | 実装者 |
| x.7 Implementation Notes | 落とし穴と対策 | 実装者 |
| x.8 Future Expansion | 将来の拡張余地 | 全員 |

### 0.2 用語・記法の統一

| 表記 | 用途 | 例 |
|---|---|---|
| `Inp_〜` | 入力パラメータ | `Inp_StrengthTimeframe` |
| `g_〜` | グローバル変数 | `g_assets` |
| `m_〜` | メンバ変数 | `m_score[]` |
| `C〜` | クラス | `CCurrencyStrength` |
| `S〜` | 構造体 | `SAssetInfo` |
| `ENUM_〜` | 列挙型 | `ENUM_ASSET_STATE` |
| `GMD_〜` | チャートオブジェクト名 | `GMD_Rank_USD` |

以下の語は本書内で意味を固定する。混用しない。

| 用語 | 定義 | 混同しやすい語 |
|---|---|---|
| **アセット（Asset）** | GMDが扱う論理的な資産。`ASSET_GOLD` 等 | 銘柄 |
| **銘柄（Symbol）** | ブローカーが提供する実際の名前。`XAUUSD.a` 等 | アセット |
| **スコア（Score）** | 各エンジンが出す生の数値 | 信頼度 |
| **信頼度（Confidence）** | スコアの確からしさ。0〜100% | スコア |
| **レジーム（Regime）** | 市場全体の状態。Risk ON/OFF/Neutral | シグナル |
| **状態（State）** | アセットの可用性。OK/Pending/Stale/Unavailable | レジーム |

### 0.3 実装フェーズの表記

本書は Ver4.00 までを見据えた設計を含む。**設計として書いてあること = 今すぐ作ること、ではない。** 各機能には実装フェーズを併記する。

| 表記 | 意味 |
|---|---|
| `[2.11]` | Ver2.11 で実装する。**今作るのはこれだけ** |
| `[2.20]` | Ver2.20 で実装する。設計だけ先に固めてある |
| `[2.30+]` | それ以降。方向性のみ |

**実装者は `[2.11]` の箇所だけを見れば作業できる。** 先の設計を書いてあるのは、後から追加したときに構造を壊さないためであり、今すぐ全部作るためではない。

### 0.4 要求レベルの表記

| 表記 | 意味 |
|---|---|
| **必須** | 実装しなければVer2.11は完成としない |
| **推奨** | 実装するべき。省略する場合は理由を28章に記録する |
| **任意** | 余力があれば |

---

## 1. プロジェクト概要

Global Market Dashboard Ultimate（以下GMD）は、単一銘柄・単一市場を分析する通常のインジケーターではなく、**FX・株価指数・貴金属・暗号資産・債券という複数の市場を横断し、市場間の資金の流れと相互関係を1画面で可視化する統合マーケット分析ダッシュボード**である。

コンセプトは以下の1文に集約される。

> 「相場を見る」のではなく、「世界のお金の流れを見る」

GMDは、価格そのものではなく「今、資金がどこからどこへ動いているか」を数値化し、トレーダーが数秒で市場全体の地合いを把握できる状態を目指す。

---

## 2. 開発目的

1. 複数市場（FX・株価指数・貴金属・暗号資産・債券）の状態を1画面で同時に把握できるようにする
2. 通貨強弱・資金フロー・リスクオン/オフといった「市場の空気感」を定量化し、裁量判断の根拠を数値で補強する
3. 手動で複数のチャート・複数のインジケーターを見比べる手間を削減する
4. 将来的な統計・相関分析・機械学習への拡張を見据えた、保守しやすいモジュール構成にする

---

## 3. 設計思想（Design Philosophy）

- **1画面完結**：チャートを切り替えなくても市場全体の状態が分かること
- **数値化優先**：「なんとなく強い/弱い」ではなく、スコア・パーセンテージという形で根拠を残すこと
- **軽量であること**：多数の銘柄・多数の指標を同時に扱うため、CPU負荷とオブジェクト数を常に意識すること（詳細は16章）
- **壊れにくいこと**：ブローカーごとの銘柄表記の違い、週末のデータ欠損、通貨ペアの非存在など、実運用で必ず起きる例外を前提に設計すること（詳細は9章・26章）
- **止めないこと**：検出できない銘柄があっても、インジケーター全体は動き続けること。欠損は「エラー」ではなく「Unavailable という状態」として扱い、縮退運転（Graceful Degradation）で表示を継続する（詳細は26.8）

---

## 4. システム概要（Architecture Diagram）

### 4.1 全体アーキテクチャ

本書を初めて読む人は、まずこの図だけ見れば全体像がつかめる。**データはMT5から入り、一方向に流れてチャートへ出る。逆流はしない。**

```text
┌──────────────────────────────────────────────────────────────┐
│                      MT5 Terminal                             │
│         SymbolsTotal / SymbolInfoTick / CopyClose             │
└───────────────────────────┬──────────────────────────────────┘
                            │ 価格・銘柄情報
                            ▼
┌──────────────────────────────────────────────────────────────┐
│  Core                                                         │
│  ┌────────────┐  ┌──────────┐  ┌─────────────────────────┐  │
│  │ Types.mqh  │  │ Utils    │  │  AssetDetection         │  │
│  │ 型定義     │  │ 汎用関数 │  │  この口座で何が使えるか  │  │
│  └────────────┘  └──────────┘  └───────────┬─────────────┘  │
│                    ┌──────────┐             │                │
│                    │ Logger   │◀────────────┤ 全モジュールが  │
│                    └──────────┘             │ 使用           │
└────────────────────────────────────────────┼────────────────┘
                                              │ SAssetRegistry
                                              │（使える銘柄名の一覧）
                            ┌─────────────────┴─────────────────┐
                            ▼                                    ▼
┌──────────────────────────────────────────────────────────────┐
│  Engines（すべて IEngine を実装）                              │
│                                                               │
│   ┌──────────────────┐        ┌──────────────────┐          │
│   │ CurrencyStrength │───────▶│    BestPair      │          │
│   │  8通貨の強弱     │  強弱  │  推奨ペアを選ぶ  │          │
│   └────────┬─────────┘        └──────────────────┘          │
│            │                                                  │
│   ┌────────▼─────────┐  ┌──────────────────┐                │
│   │    MoneyFlow     │  │  MarketRegime    │                │
│   │  資金の流出入    │  │  Risk ON / OFF   │                │
│   └────────┬─────────┘  └────────┬─────────┘                │
│                                                               │
│   ┌──────────────────┐  ← 価格を読まない。暦だけを見る       │
│   │  AnomalyEngine   │    ゆえに他のどれにも依存しない        │
│   │  暦の文脈を点数化 │                                       │
│   └────────┬─────────┘                                       │
│            │                      │                          │
│            └──────────┬───────────┘                          │
│                       ▼                                       │
│              ┌──────────────────┐                            │
│              │   Confidence     │  3エンジンの一致度         │
│              └──────────────────┘                            │
└───────────────────────────┬──────────────────────────────────┘
                            │ 計算済みの値（getter経由）
                            ▼
┌──────────────────────────────────────────────────────────────┐
│  Display                                                      │
│              ┌──────────────────┐                            │
│              │    Dashboard     │  統括・描画の指揮のみ       │
│              └────────┬─────────┘                            │
│      ┌────────────────┼────────────────┐                     │
│      ▼                ▼                ▼                     │
│ ┌──────────┐  ┌─────────────┐  ┌───────────────┐           │
│ │ Summary  │  │  Ranking    │  │  MoneyFlow    │           │
│ │  Panel   │  │   Panel     │  │    Panel      │           │
│ └──────────┘  └─────────────┘  └───────────────┘           │
└───────────────────────────┬──────────────────────────────────┘
                            │ ObjectCreate / ObjectSetString
                            ▼
                    ┌───────────────┐
                    │     Chart     │
                    └───────────────┘
```

### 4.2 一行で言うと

```text
MT5 → AssetDetection → 各Engine → Confidence → Dashboard → Chart
```

- **AssetDetection が最上流**である。「この口座で何が使えるか」が決まらないと、どのエンジンも動けない
- **Confidence は他エンジンの下流**にある。3エンジンの結果が出そろってから計算する
- **Dashboard は計算しない。描くだけ**である

### 4.3 分析エンジン一覧

GMDは以下の6つの分析エンジンと、それらを束ねるダッシュボード表示層で構成される。

| エンジン | 役割 |
|---|---|
| Currency Strength Engine | 主要8通貨・28通貨ペアの強弱をスコア化 |
| Money Flow Engine | 株式・貴金属・暗号資産・債券などアセット間の資金流出入を判定 |
| Market Regime Engine | 複数指標を合成し、Risk ON / Risk OFF / Neutralを判定 |
| Confidence Engine | 各エンジンの一致度から、シグナル全体の信頼度を算出 |
| Best Pair Engine | 通貨強弱から、最も分かりやすいトレンドが出やすい通貨ペアを提案 |
| Anomaly Engine | 五十日・季節性など暦から決まる統計的な偏りを点数化（価格を読まない） |

これらの結果を `Display/Dashboard.mqh` が受け取り、選択された表示モード（12章）に応じて画面に描画する。

### 4.4 Ver2.11 で動く範囲

上図のうち、Ver2.11で実際に動くのは以下の太線部分だけである。

```text
MT5 → AssetDetection → CurrencyStrength → BestPair ─┐
                                                     ├→ Confidence → Dashboard → Chart
        （暦のみ）    →   AnomalyEngine  ────────────┘
                                                          ▲
                                       MoneyFlow / MarketRegime は Ver2.20
```

Confidence はVer2.11では入力が2つ（強弱の明確さ・データ充足率）に減るため、暫定の重み配分で動かす（8.3参照）。

---

## 5. 通貨強弱エンジン（Currency Strength Engine v2）

> **v1.3で全面改訂。** 判定を「直近1本の陰陽線」から「**直近N本の重み付き集計**」に変更し、対象を8通貨・28ペアに確定した。旧v1仕様（1本判定・6段階グラデーション）は破棄する。

### 5.1 Purpose

主要8通貨の相対的な強弱を数値化し、「今どの通貨に資金が向かっているか」を**1秒で**判断できるようにする。GMDで最初に完成させる中核エンジンであり、Best Pair・Confidence の入力元でもある。

設計上の最優先事項は**視認性**である。情報を増やすことではなく、見た瞬間に判断できることを優先する。

### 5.2 Inputs

| 入力 | 型 | 取得元 | 必須 | 既定 | 備考 |
|---|---|---|---|---|---|
| 対象通貨 | `ENUM_CURRENCY[8]` | 固定定義 | 必須 | — | USD / EUR / GBP / JPY / CHF / AUD / CAD / **NZD** |
| 対象通貨ペア | `SFxPair[28]` | `CAssetDetection` | 必須 | — | 8C2 = 28ペア。実在するもののみ |
| 判定時間足 | `ENUM_TIMEFRAMES` | `Inp_StrengthTimeframe` | 必須 | `PERIOD_M1` | M1 / M5 / M15 など自由 |
| 判定本数 | `int` | `Inp_StrengthBars` | 必須 | `3` | 1〜10。何本さかのぼるか |
| 重み方式 | `bool` | `Inp_UseWeighting` | 任意 | `true` | false なら全バー重み1 |
| 最低ペア数 | `int` | `Inp_StrengthMinPairs` | 任意 | `20` | これ未満なら計算しない |

**前提条件**：`CAssetDetection::GetFxPairCount() >= Inp_StrengthMinPairs`。下回る場合は計算せず `IsReady()` が false を返す。

#### 対象28ペア

```text
対USD      EURUSD  GBPUSD  AUDUSD  NZDUSD  USDJPY  USDCHF  USDCAD
対EUR      EURGBP  EURJPY  EURCHF  EURAUD  EURCAD  EURNZD
対GBP      GBPJPY  GBPCHF  GBPAUD  GBPCAD  GBPNZD
対AUD      AUDJPY  AUDCHF  AUDCAD  AUDNZD
対CAD      CADJPY  CADCHF
対NZD      NZDJPY  NZDCHF  NZDCAD
対CHF      CHFJPY
```

> **7通貨では28ペアにならない。** 7C2 = 21ペアである。28ペアは NZD を含む8通貨の組み合わせ（8C2）であり、v1.2までの「7通貨・28ペア」という記述は誤りだった。実装時に判明したためv1.3で訂正する。

### 5.3 Calculation

#### 5.3.1 基本の考え方

各ペアについて、直近N本のバーを1本ずつ見る。**上昇した足では基軸通貨に加点、下降した足では決済通貨に加点**する。負の値は使わない（加点のみ）。

#### 5.3.2 重み付け

**新しい足ほど重みを大きくする。** 直近の動きを強く反映させるためである。

| バー | シフト | 既定の重み（N=3） |
|---|---|---|
| 3本前 → 2本前 | shift 3 | ×1 |
| 2本前 → 1本前 | shift 2 | ×2 |
| 1本前 → 現在の確定足 | shift 1 | ×3 |

一般化すると、**シフト `s`（1が最新の確定足）の重みは `N - s + 1`** である。`Inp_UseWeighting = false` のときは全バー重み1になる。

重みの合計（N=3のとき）：

\[
W_{total} = 1 + 2 + 3 = 6
\]

#### 5.3.3 擬似コード

```text
scoreRaw[8] = 0

for each pair in availablePairs:            // 最大28ペア
    for s = Inp_StrengthBars downto 1:      // 古い足 → 新しい足
        w = Inp_UseWeighting ? (Inp_StrengthBars - s + 1) : 1

        open  = iOpen (pair.symbol, tf, s)
        close = iClose(pair.symbol, tf, s)

        if close > open:                    // 陽線 = 基軸通貨が強い
            scoreRaw[pair.base]  += w
        else if close < open:               // 陰線 = 決済通貨が強い
            scoreRaw[pair.quote] += w
        // 同値は加点しない

        ※ pair.inverted == true の場合、base と quote を入れ替えて適用する
```

#### 5.3.4 正規化

1通貨が取り得る最大点は「相手7通貨 × 重み合計」である。

\[
Score_{max} = 7 \times W_{total}
\]

\[
Score_c = \frac{scoreRaw_c}{Score_{max}} \times 100
\]

- 範囲は 0〜100、**50が中立**である
- 8通貨の合計は理論上つねに 400 になる（引き分けの足を除く）
- N=3・重み付きのとき `Score_max = 42`

**ゼロ除算対策は必須。** 使用ペア数が0、または全ペアが同値だった場合は、全通貨を 50 とする。

#### 5.3.5 勢い（矢印）の算出

スコアは「水準」であり、矢印は「**直近1本の勢い**」を表す。別の指標として計算する。

最新の確定足（shift 1）**のみ**を対象に、重みを使わず加減する。

```text
momentum[c] = (その通貨が上昇側だったペア数) - (下降側だったペア数)
```

1通貨は7ペアに登場するため、値域は **-7 〜 +7** である。

| momentum | 矢印 | 意味 |
|---|---|---|
| +6 以上 | `↑↑↑` | 全面高 |
| +3 〜 +5 | `↑↑` | 強い上昇 |
| +1 〜 +2 | `↑` | 上昇 |
| 0 | `→` | 中立 |
| -1 〜 -2 | `↓` | 下降 |
| -3 〜 -5 | `↓↓` | 強い下降 |
| -6 以下 | `↓↓↓` | 全面安 |

### 5.4 Output

| 出力 | 型 | 範囲 | 利用先 |
|---|---|---|---|
| 生スコア | `int[8]` | 0〜42（N=3時） | 内部・デバッグ |
| 正規化スコア | `double[8]` | 0〜100 | Confidence / RankingPanel |
| 勢い | `int[8]` | -7〜+7 | 矢印表示 |
| 矢印文字列 | `string[8]` | `↑↑↑`〜`↓↓↓` | RankingPanel |
| ランキング | `int[8]` | 1〜8位 | RankingPanel |
| 最強通貨 | `ENUM_CURRENCY` | — | Best Pair |
| 最弱通貨 | `ENUM_CURRENCY` | — | Best Pair |
| 点差（1位−8位） | `double` | 0〜100 | Confidence |
| 使用ペア数 | `int` | 0〜28 | Confidence |
| 準備完了フラグ | `bool` | — | Dashboard |

### 5.5 Display

#### 5.5.1 表示例

```text
①  USD   72  ↑↑↑
②  EUR   61  ↑↑
③  GBP   55  ↑
④  AUD   50  →
⑤  CAD   45  ↓
⑥  CHF   41  ↓
⑦  NZD   33  ↓↓
⑧  JPY   22  ↓↓↓
```

#### 5.5.2 配色ルール（v1.3で簡素化）

| 対象 | 色 |
|---|---|
| **1位（最強）** | 赤 `clrRed` |
| **8位（最弱）** | 青 `clrDodgerBlue` |
| その他6通貨 | 白 `clrWhite` |

> **なぜ簡素化したか。** 旧仕様は6段階のグラデーション（赤→オレンジ→黄→白→水色→青）だったが、色が多いほど判断が遅くなる。**このダッシュボードの目的は一瞬で資金の流れを判断すること**であり、色は「両端2つだけ」で足りる。中間順位の情報は数字と矢印が担う。
>
> 白基調にしておくと、黒背景・白背景のどちらのチャートでも破綻しない利点もある。

矢印の色は文字色に追従させる（矢印だけ別色にしない）。

#### 5.5.3 その他の表示規則

- 8通貨をスコア降順に**縦1列**で表示する。1位と8位が上下端に来るため、両端の色が最も目立つ
- 使用ペア数が `Inp_StrengthMinPairs` 未満のときは、全体をグレー `clrGray` にし `Limited data (n/28)` を併記する
- スコアは整数に丸めて表示する（小数は判断の役に立たない）

### 5.6 Class Interface

```cpp
class CCurrencyStrength : public IEngine
{
private:
   CAssetDetection  *m_assets;
   int               m_scoreRaw[CUR_COUNT];      // 生スコア
   double            m_score[CUR_COUNT];         // 0-100 正規化
   int               m_momentum[CUR_COUNT];      // -7 〜 +7
   int               m_rank[CUR_COUNT];          // 1〜8
   ENUM_CURRENCY     m_byRank[CUR_COUNT];        // 順位 → 通貨
   int               m_pairsUsed;
   bool              m_ready;

public:
   bool              Init(CAssetDetection *assets, ENUM_TIMEFRAMES tf,
                          int bars, bool useWeight, int minPairs);
   bool              Calculate(void);                   // IEngine
   bool              IsReady(void);                     // IEngine
   string            GetName(void);                     // IEngine

   double            GetScore(ENUM_CURRENCY c);
   int               GetRawScore(ENUM_CURRENCY c);
   int               GetMomentum(ENUM_CURRENCY c);
   string            GetArrow(ENUM_CURRENCY c);
   int               GetRank(ENUM_CURRENCY c);
   ENUM_CURRENCY     GetByRank(int rank);               // 1〜8
   ENUM_CURRENCY     GetStrongest(void);
   ENUM_CURRENCY     GetWeakest(void);
   double            GetSpread(void);                   // 1位 − 8位
   int               GetPairsUsed(void);
   color             GetColor(ENUM_CURRENCY c);         // 赤/青/白
};
```

### 5.7 Implementation Notes

- **シフト0（形成中の足）は使わない。** ティックごとにランキングが入れ替わり実用にならない。最新は必ず shift 1 から
- `pair.inverted == true` の扱いを誤ると強弱が完全に反転する。`EURUSD` しか無い口座と `USDEUR` しか無い口座の両方でテストする
- `iOpen` / `iClose` が 0 を返す場合（データ未取得）は、そのバーを**スキップして次のバーへ**進む。0で計算しない
- 必要バー数は `Inp_StrengthBars + 1` 本。`Bars()` がこれを下回るペアは使用ペア数に数えない
- 週末は全ペアが同値になり得る。全通貨50になっても異常ではない
- 計算量は 28ペア × N本 = N=3で84回の `iClose` 呼び出し。1秒間隔でも問題にならない

### 5.8 Future Expansion

- **マルチタイムフレーム版**：M5 / H1 / H4 を同時計算し、一致度を見る（Ver3.00）
- **ATR正規化**：ボラティリティの違いを吸収し、値幅の大きい通貨に偏らないようにする
- 重み配分を線形以外（指数など）から選べるようにする
- 強弱の時系列を保持し、順位変動を矢印ではなくスパークラインで表示する

---

## 6. マネーフロー・エンジン（Money Flow Engine）

### 6.1 Purpose

FX以外の主要市場（株価指数・貴金属・暗号資産・債券）について、資金が入ってきているか出て行っているかを判定し、市場をまたいだ資金の移動を可視化する。GMDのコンセプトを最も直接的に体現する機能である。

### 6.2 Inputs

| 入力 | 型 | 取得元 | 必須 | 備考 |
|---|---|---|---|---|
| 対象アセット | `ENUM_ASSET_ID[]` | `CAssetDetection` | 必須 | Unavailable は自動除外 |
| 判定時間足 | `ENUM_TIMEFRAMES` | `Inp_FlowTimeframe` | 必須 | 既定 M15 |
| 判定期間 | `int` | `Inp_FlowPeriod` | 必須 | 既定 8本 |
| 流入判定しきい値 | `double` | `Inp_FlowThreshold` | 必須 | 既定 0.30（%） |
| 強流入判定しきい値 | `double` | `Inp_FlowStrongThreshold` | 必須 | 既定 0.80（%） |

対象カテゴリと代表アセット：

| カテゴリ | アセット |
|---|---|
| Stocks（株価指数） | US30, NAS100, SPX500, JP225, GER40, UK100 |
| Metals（貴金属） | Gold, Silver |
| Crypto（暗号資産） | BTC, ETH |
| Bonds（債券） | US10Y, US30Y |

### 6.3 Calculation

**変化率で正規化することが必須である。** 価格の上昇幅そのままでは、株価指数（数万）とGold（数千）とBTC（数万）で桁が違い、比較にならない。

```text
changeRate(asset) = ( Close[0] - Close[Inp_FlowPeriod] ) / Close[Inp_FlowPeriod] * 100

カテゴリスコア = 利用可能なアセットの changeRate の単純平均
```

判定：

| 条件 | 状態 | 記号 |
|---|---|---|
| `rate >= Inp_FlowStrongThreshold` | STRONG_INFLOW | ↑↑↑ |
| `Inp_FlowThreshold <= rate` | INFLOW | ↑ |
| `-Inp_FlowThreshold < rate < Inp_FlowThreshold` | NEUTRAL | → |
| `rate <= -Inp_FlowThreshold` | OUTFLOW | ↓ |
| `rate <= -Inp_FlowStrongThreshold` | STRONG_OUTFLOW | ↓↓↓ |

> **しきい値の注意**：既定の0.30%はM15×8本（＝2時間）を想定した値である。時間足を変えたらしきい値も変える必要がある。将来的にはATR比での自動調整（6.8）に移行する。

### 6.4 Output

| 出力 | 型 | 説明 |
|---|---|---|
| アセット別フロー | `ENUM_FLOW_STATE[ASSET_COUNT]` | 5段階 |
| アセット別変化率 | `double[ASSET_COUNT]` | % |
| カテゴリ別フロー | `ENUM_FLOW_STATE[5]` | Stocks/Metals/Crypto/Bonds |
| 有効カテゴリ数 | `int` | Confidence の入力 |

### 6.5 Display

- カテゴリ単位で ↑↑↑ / ↑ / →（灰）/ ↓ / ↓↓↓ を一覧表示
- 記号の色：流入＝緑、中立＝灰、流出＝赤
- カテゴリ内の全アセットが Unavailable の場合は `Unavailable`（暗灰）を表示し、行は消さない（26.8）
- ツールチップで内訳（各アセットの変化率）を出せると理想的（任意）

### 6.6 Class Interface

```cpp
enum ENUM_FLOW_STATE
{
   FLOW_STRONG_OUTFLOW = -2,
   FLOW_OUTFLOW        = -1,
   FLOW_NEUTRAL        =  0,
   FLOW_INFLOW         =  1,
   FLOW_STRONG_INFLOW  =  2,
   FLOW_UNAVAILABLE    =  99
};

class CMoneyFlow : public IEngine
{
private:
   ENUM_FLOW_STATE m_assetFlow[ASSET_COUNT];
   double          m_changeRate[ASSET_COUNT];
   ENUM_FLOW_STATE m_categoryFlow[5];
   bool            m_ready;

public:
   bool             Init(CAssetDetection *assets);
   bool             Calculate(void);
   bool             IsReady(void) { return m_ready; }
   string           GetName(void) { return "MoneyFlow"; }

   ENUM_FLOW_STATE  GetFlow(ENUM_ASSET_ID id);
   ENUM_FLOW_STATE  GetCategoryFlow(ENUM_ASSET_CATEGORY cat);
   double           GetChangeRate(ENUM_ASSET_ID id);
   string           GetFlowSymbol(ENUM_FLOW_STATE st);   // "↑↑↑" 等
   color            GetFlowColor(ENUM_FLOW_STATE st);
   int              GetActiveCategoryCount(void);
};
```

### 6.7 Implementation Notes

- `Close[Inp_FlowPeriod]` が0の銘柄（データ未取得）でゼロ除算が起きる。除算前に必ず `> 0` を確認する
- 債券が Unavailable な環境が多数派である。Bonds行が常にUnavailableでも正常動作とみなす
- カテゴリ平均は、利用可能なアセットのみで割ること（`/6` 固定にしない）

### 6.8 Future Expansion

- しきい値のATR自動調整（`rate / ATR%` で判定し、銘柄ごとのボラ差を吸収）
- 出来高（`iVolume`）を加味した本来の意味でのMoney Flow指標への発展
- Money Rotation 分析：どのカテゴリからどのカテゴリへ資金が移ったかの矢印表示（Ver3.00）

---

## 7. 市場レジーム・エンジン（Market Regime Engine）

### 7.1 Purpose

複数の市場指標を1つのスコアに合成し、市場全体が Risk ON（リスク選好）か Risk OFF（リスク回避）かを判定する。個別の銘柄ではなく「相場の空気」を数値にする層である。

### 7.2 Inputs

| 指標 | 寄与方向 | 既定重み | 必須 |
|---|---|---|---|
| SPX500 | 上昇 → Risk ON | 0.20 | 推奨 |
| NAS100 | 上昇 → Risk ON | 0.15 | 推奨 |
| BTC | 上昇 → Risk ON | 0.10 | 任意 |
| ETH | 上昇 → Risk ON | 0.05 | 任意 |
| USDJPY | 上昇 → Risk ON | 0.15 | 推奨 |
| Gold | 上昇 → Risk OFF | −0.10 | 推奨 |
| US10Y | 上昇 → Risk OFF | −0.10 | 任意 |
| VIX | 上昇 → Risk OFF | −0.15 | 任意 |
| DXY | 上昇 → Risk OFF | −0.10 | 任意 |

**重み再配分ルール（必須）**：Unavailable な指標の重みは、利用可能な指標へ按分する。

```text
adjustedWeight(i) = weight(i) / Σ( 利用可能な指標の |weight| )
```

利用可能な指標が3つ未満の場合は計算せず `Regime: Insufficient data` を表示する。

### 7.3 Calculation

```text
1. 各指標を直近N本（Inp_RegimePeriod、既定20）の変化率に変換
2. 変化率を Z-score で標準化（過去M本の平均・標準偏差を使用、既定M=100）
   z(i) = ( rate(i) - mean(i) ) / stddev(i)
   ※ stddev が 0 の場合は z = 0 とする
3. 加重合成
   raw = Σ( z(i) × adjustedWeight(i) )
4. 0〜100 にスケーリング（tanh で外れ値を圧縮する）
   Score = ( tanh(raw) + 1 ) / 2 × 100
```

3値への変換：

| Score | レジーム |
|---|---|
| 60以上 | Risk ON |
| 40超〜60未満 | Neutral |
| 40以下 | Risk OFF |

重みの初期値は経験則の仮値である。Ver4.00の分析エンジンで最適化する前提とし、`Inp_RegimeWeights`（セミコロン区切り文字列）で外から変更できるようにしておく。

### 7.4 Output

| 出力 | 型 | 範囲 |
|---|---|---|
| レジームスコア | `double` | 0〜100 |
| レジーム3値 | `ENUM_REGIME` | ON / OFF / NEUTRAL |
| 指標別寄与度 | `double[]` | 内訳表示・デバッグ用 |
| 使用指標数 | `int` | 0〜9 |

### 7.5 Display

- `Risk ON  82%` のようにレジーム名とスコアを併記
- 色：Risk ON＝緑、Neutral＝白、Risk OFF＝赤
- 使用指標数が減っている場合は `Risk ON 82% (5/9)` のように分母を出す（**推奨**）

### 7.6 Class Interface

```cpp
enum ENUM_REGIME { REGIME_RISK_OFF = -1, REGIME_NEUTRAL = 0, REGIME_RISK_ON = 1 };

class CMarketRegime : public IEngine
{
private:
   double        m_score;
   ENUM_REGIME   m_regime;
   double        m_contribution[ASSET_COUNT];
   double        m_weights[ASSET_COUNT];
   int           m_usedCount;
   bool          m_ready;

public:
   bool          Init(CAssetDetection *assets);
   bool          Calculate(void);
   bool          IsReady(void) { return m_ready; }
   string        GetName(void) { return "MarketRegime"; }

   double        GetScore(void)       { return m_score; }
   ENUM_REGIME   GetRegime(void)      { return m_regime; }
   string        GetRegimeText(void);                    // "Risk ON" 等
   color         GetRegimeColor(void);
   double        GetContribution(ENUM_ASSET_ID id);
   int           GetUsedIndicatorCount(void) { return m_usedCount; }
   bool          RebalanceWeights(void);                 // 7.2 の再配分
};
```

### 7.7 Implementation Notes

- Z-score計算には過去100本の統計が必要なため、起動直後は `IsReady()` が false になる期間がある。PENDING表示で待つこと（26.3と同じ思想）
- `tanh` を使うのは、指標が1つ暴れただけでスコアが0や100に張り付くのを防ぐため
- 重み再配分を忘れると、債券が取れない環境でスコアが常に低めに偏る。**AD-012相当のバグとして最優先で検証する**

### 7.8 Future Expansion

- レジームの継続時間を計測し「Risk ON 3時間継続」を表示
- レジーム転換の検知とアラート（Ver3.00）
- ヒストリカルなレジーム推移をミニチャート化

---

## 8. 信頼度エンジン（Confidence Engine）

### 8.1 Purpose

各エンジンの出力がどれだけ互いに一致しているかを評価し、「今このダッシュボードの示す方向をどれだけ信じてよいか」を0〜100%で示す。数値の確からしさを数値化する層である。

### 8.2 Inputs

| 入力 | 出所 | 既定重み | 正規化方法 |
|---|---|---|---|
| 通貨強弱の点差 | `CCurrencyStrength::GetSpread()` | 0.30 | 点差 / 最大点差 × 100。**[2.11]** |
| データ充足率 | `GetPairsUsed() / 28` | 0.20 | そのまま%。**[2.11]** |
| マネーフローの一致度 | `CMoneyFlow` | 0.25 | 同方向カテゴリ数 / 有効カテゴリ数 × 100。`[2.20]` |
| レジームスコアの極端さ | `CMarketRegime::GetScore()` | 0.25 | `abs(score - 50) × 2`。`[2.20]` |

### 8.3 Calculation

#### 8.3.1 Ver2.11 の暫定式（Money Flow / Market Regime が未実装のため）

Ver2.11では入力が2つしかない。**通貨強弱の点差**と**データ充足率**である。

\[
Confidence = \left( 50 + \frac{Spread}{2} \right) \times \frac{PairsUsed}{28}
\]

- \(Spread\) は正規化スコアの **1位 − 8位**（0〜100）
- 点差が0（全通貨横並び）なら 50、点差が100（完全に一方向）なら 100 になる
- データが欠けている分だけ全体を割り引く

計算例：

| 状況 | 1位 | 8位 | Spread | 使用ペア | Confidence |
|---|---|---|---|---|---|
| 明確なトレンド | 72 | 22 | 50 | 28/28 | **75%** |
| 非常に強いトレンド | 88 | 5 | 83 | 28/28 | **92%** |
| 横並び | 54 | 46 | 8 | 28/28 | **54%** |
| 横並び + データ欠損 | 54 | 46 | 8 | 21/28 | **41%** |

> Ver2.11の Confidence は「**通貨強弱がどれだけはっきりしているか**」しか見ていない。Money Flow と Market Regime が入るVer2.20で、8.3.2の本式へ移行する。この暫定期間であることを利用者に伝えるため、Ver2.11では表示に `(FX only)` を併記する。

#### 8.3.2 Ver2.20以降の本式

```text
Confidence(%) = Σ( normalizedInput(i) × adjustedWeight(i) )

・各入力は 0〜100 に正規化してから加重平均する
・取得できないエンジンがある場合、その重みは他へ按分する（7.2と同じルール）
・最終値は 0〜100 にクリップする
```

判定区分：

| Confidence | 表示 | 意味 |
|---|---|---|
| 80〜100 | High（緑） | 各エンジンが強く一致 |
| 50〜79 | Medium（白） | 概ね一致 |
| 0〜49 | Low（灰） | 判断材料が不足、または矛盾 |

### 8.4 Output

| 出力 | 型 | 説明 |
|---|---|---|
| 総合信頼度 | `double` | 0〜100 |
| 内訳 | `double[4]` | 各入力の寄与。デバッグ・ツールチップ用 |
| 判定区分 | `ENUM_CONFIDENCE_LEVEL` | High / Medium / Low |

### 8.5 Display

`Confidence  91%` の1行。色は判定区分に従う。内訳はツールチップで表示（**任意**）。

### 8.6 Class Interface

```cpp
enum ENUM_CONFIDENCE_LEVEL { CONF_LOW, CONF_MEDIUM, CONF_HIGH };

class CConfidence : public IEngine
{
private:
   double  m_confidence;
   double  m_breakdown[4];
   bool    m_ready;

public:
   bool                   Init(CCurrencyStrength *cs, CMoneyFlow *mf, CMarketRegime *mr);
   bool                   Calculate(void);
   bool                   IsReady(void) { return m_ready; }
   string                 GetName(void) { return "Confidence"; }

   double                 GetConfidence(void) { return m_confidence; }
   ENUM_CONFIDENCE_LEVEL  GetLevel(void);
   double                 GetBreakdown(int index);
   string                 GetBreakdownText(void);   // ログ・ツールチップ用
};
```

### 8.7 Implementation Notes

- Confidence は**他エンジンの計算完了後**に実行する。呼び出し順序を Dashboard 側で固定すること（30章のデータフロー参照）
- 全エンジンが Unavailable の場合、Confidence は0ではなく「算出不可（`--`）」を表示する。0%とすると「確実に外れる」という誤ったメッセージになる

### 8.8 Future Expansion

- 過去のシグナルの的中率を記録し、実績ベースで重みを自動調整（Ver4.00）
- 時間帯別の信頼度補正（東京時間はレンジになりやすい等）

---

### 8.9 アノマリーとの関係（v1.4 追記）

Anomaly Engine のスコアを Confidence の数値に足すかどうかは、**既定で足さない**（`Inp_AnomalyToConfidence = false`）。

理由は、2つが答えている問いが違うことにある。

| | 答えている問い |
|---|---|
| Confidence | この表示を信じてよいか（データが揃っているか、強弱が明確か） |
| Anomaly | 今日は上がりやすい日か（暦の文脈） |

前者はデータ品質の指標で、後者は期待値の偏りである。足し合わせると `74%` という1つの数字になるが、その74%が「データが足りない」のか「季節性が悪い」のかを読み手が区別できない。低い数字を見たときに取るべき行動が、前者なら「待つ」、後者なら「枚数を落とす」で、まったく違う。

そのため既定では**2行に分けて並べて出す**。

```text
Confidence  78%  (FX only)
Anomaly     +5   (五十日, 月末)
```

`Inp_AnomalyToConfidence = true` にすると加算する。その場合、表示は必ず内訳付きになる。

```text
Confidence  83%  (78 +5)
```

`83%` とだけ出すことはしない。合成した数値を根拠なしに見せると、後から検証できなくなる。

加算する場合の式は次のとおり。scope は現在チャートの銘柄で決める（円のペアなら `SCOPE_JPY`）。

\[
Confidence = \mathrm{clip}\left( Base + Score_{anomaly},\ 0,\ 100 \right)
\]

---

## 9. ベストペア・エンジン（Best Pair Engine）

### 9.1 Purpose

通貨強弱の結果から、最もトレンドが出やすい＝最も分かりやすい通貨ペアを1つ提案する。強弱ランキングを見て自分で組み合わせを考える手間をなくす。

### 9.2 Inputs

| 入力 | 出所 | 必須 |
|---|---|---|
| 最強通貨 | `CCurrencyStrength::GetStrongest()` | 必須 |
| 最弱通貨 | `CCurrencyStrength::GetWeakest()` | 必須 |
| 銘柄解決関数 | `CAssetDetection::GetFxSymbol()` | 必須 |

### 9.3 Calculation

最強・最弱を単純に文字列結合しただけでは、**そのペアがブローカーに存在しない場合がある**（例：`CHFUSD` は無いが `USDCHF` はある。基軸通貨の並びは通貨ごとに慣習が決まっている）。以下のフローを**必ず**実装する。

```text
1. strongest（1位）と weakest（8位）を CCurrencyStrength から取得する
2. CAssetDetection::GetFxSymbol(strongest, weakest, inverted) を呼ぶ
   → 検出済みレジストリを引くだけ。ここで銘柄探索を再実装しない
3. inverted == false（例 strongest=USD, weakest=JPY → "USDJPY" が実在）
      → 方向は BUY（強い通貨を買う）
4. inverted == true（例 strongest=JPY, weakest=USD だが銘柄は "USDJPY"）
      → 銘柄は "USDJPY" のまま。方向を SELL に反転する
      → "JPYUSD" という存在しない表記は絶対に画面へ出さない
5. 銘柄が見つからない場合は「該当ペアなし（N/A）」を明示する
6. 点差（GetSpread()）が Inp_BestPairMinSpread（既定20）未満なら、
   ペアは表示するが方向を NONE とし「点差不足」を示す
```

### 9.4 Output

| 出力 | 型 | 説明 |
|---|---|---|
| 推奨銘柄 | `string` | `""` なら該当なし |
| 反転フラグ | `bool` | 逆順で解決したか |
| 推奨方向 | `ENUM_TRADE_DIRECTION` | BUY / SELL / NONE |
| 方向テキスト | `string` | `EURJPY BUY` 等 |

### 9.5 Display

- `Best Pair  EURJPY ▲` のように銘柄と方向を併記
- 該当なしの場合は `Best Pair  N/A`
- **表示された銘柄はクリックでチャート遷移できるようにする**（利便性が大きく向上する。`ChartOpen()` または `ChartSetSymbolPeriod()`）

### 9.6 Class Interface

```cpp
enum ENUM_TRADE_DIRECTION { DIR_NONE = 0, DIR_BUY = 1, DIR_SELL = -1 };

class CBestPair : public IEngine
{
private:
   string                m_symbol;
   bool                  m_inverted;
   ENUM_TRADE_DIRECTION  m_direction;
   bool                  m_ready;

public:
   bool                  Init(CCurrencyStrength *cs, CAssetDetection *assets);
   bool                  Calculate(void);
   bool                  IsReady(void) { return m_ready; }
   string                GetName(void) { return "BestPair"; }

   string                GetSymbol(void)    { return m_symbol; }
   bool                  IsInverted(void)   { return m_inverted; }
   ENUM_TRADE_DIRECTION  GetDirection(void) { return m_direction; }
   string                GetDisplayText(void);      // "EURJPY BUY"
   bool                  OpenChart(void);           // クリック時のチャート遷移
};
```

### 9.7 Implementation Notes

- 反転時の方向解釈を間違えるのは、このエンジンで最も起きやすいバグである。`USDJPY`（USD最強・JPY最弱 → BUY）と、`CHF`最強・`USD`最弱で `USDCHF` を採用したケース（→ SELL）の両方をテストする
- 1位と8位の点差が小さいときの推奨は信頼できない。正規化スコアの点差が `Inp_BestPairMinSpread`（既定20）未満なら方向を `NONE` にする（**必須**）

### 9.8 Future Expansion

- 上位3候補の提示（1位×8位、1位×7位、2位×8位）
- スプレッド・スワップを考慮した実用性フィルタ
- 過去の推奨の的中率トラッキング

---

## 10. アノマリー・エンジン（Anomaly Engine）

### 10.0 実装フェーズ分割

暦だけで判定できるものと、外部データが必要なものを分ける。前者は今すぐ動く。後者は環境依存があるため後回しにする。

| フェーズ | 対象 | 理由 |
|---|---|---|
| **[2.11]** | 五十日 / 月末 / 四半期末 / 年末 / 年始 / Halloween / Sell in May / Turn of the Month / Santa Claus / January / 曜日効果 / Weekend Effect | 日付と時刻だけで判定できる。外部データ不要 |
| **[2.20]** | FOMC前 / CPI前 / 雇用統計前 / 連休前 | MQL5の `CalendarValueHistory()` はブローカー依存で使えない環境がある。祝日判定も同様 |
| **[2.20]** | VIX急騰 → 金 | Money Flow Engine の結果が必要 |
| **[3.00]** | 実績に基づく重みの自動調整 | シグナル履歴の蓄積が前提 |

[2.20] の規則は表に**登録済みだが `implemented = false`** としてある。判定関数がまだ無いため加点されない。実装するときは判定を1つ書き、このフラグを `true` にするだけで済む。

---

### 10.1 Purpose

暦から決まる統計的な偏りを点数化し、「今どちらが強いか」とは別の軸として提示する。

通貨強弱が示すのは「今この瞬間の力関係」である。それが分かっても、その日が五十日なのか、9月なのか、年末で流動性が枯れているのかで、同じ強弱の意味は変わる。この章のエンジンは、その**時間的な文脈**だけを担当する。

---

### 10.2 なぜ独立したエンジンにするのか

Currency Strength に組み込まない理由は3つある。

**1. 入力の種類が違う**

強弱は価格を読む。アノマリーは暦しか読まない。混ぜると「価格が取れないから季節性も出せない」という不要な依存が生まれる。実際このエンジンは、ブローカーに1銘柄も存在しなくても正常に動く。

**2. 検証の方法が違う**

強弱の検算は「合計が理論値に近いか」で行う。アノマリーの検算は「特定の日付を与えたら期待した規則が発火するか」で行う。前者は実データが必要で、後者は日付を渡すだけで完全に再現できる。テストの性質が違うものは、別のファイルに置いたほうが両方とも書きやすい。

**3. 増え方が違う**

強弱の計算式はほぼ固定である。アノマリーは今後も増える。増えるものと増えないものを同じファイルに置くと、変更のたびに固定部分まで読み直すことになる。

---

### 10.3 Inputs

| 名前 | 型 | 既定 | 意味 |
|---|---|---|---|
| `Inp_EnableAnomaly` | `bool` | `true` | エンジン全体のON/OFF |
| `Inp_AnomalyMinStars` | `int` | `4` | この星数未満の規則を無効にする |
| `Inp_ServerGmtOffset` | `int` | `3` | サーバ時刻のGMT差。五十日の判定に必須 |
| `Inp_UseSeasonScore` | `bool` | `true` | 月別季節性を使うか |
| `Inp_AnomalyToConfidence` | `bool` | `false` | 信頼度の数値に加算するか（8.9参照） |

`Inp_ServerGmtOffset` を入力にしている理由は 10.6 に書く。

---

### 10.4 規則表

規則は**表として持つ**。判定を `if` の羅列で書くと、1つ足すたびに関数が伸びて、どこを触ればよいか分からなくなる。

各規則は次の6つを持つ。

| 項目 | 意味 |
|---|---|
| `code` | 内部識別子。`"GOTOBI"` など |
| `label` | 表示名。`"五十日"` |
| `scope` | **どの資産に効く話か** |
| `score` | 該当時の加点（符号付き） |
| `stars` | 根拠の強さ 1〜5 |
| `implemented` | `false` なら [2.20] 以降の予約枠 |

#### 10.4.1 登録済みの規則

| code | 表示名 | scope | 点 | 星 | 実装 |
|---|---|---|---|---|---|
| `GOTOBI` | 五十日 | JPY | +3 | ★5 | [2.11] |
| `MONTH_END` | 月末 | FX | +2 | ★5 | [2.11] |
| `QUARTER_END` | 四半期末 | FX | +3 | ★5 | [2.11] |
| `YEAR_END` | 年末（流動性低下） | FX | **-2** | ★5 | [2.11] |
| `YEAR_START` | 年始 | FX | +2 | ★5 | [2.11] |
| `HALLOWEEN` | Halloween Effect | Equity | +3 | ★5 | [2.11] |
| `SELL_IN_MAY` | Sell in May | Equity | -3 | ★5 | [2.11] |
| `TURN_MONTH` | Turn of the Month | Equity | +2 | ★5 | [2.11] |
| `SANTA` | Santa Claus Rally | Equity | +3 | ★5 | [2.11] |
| `JANUARY` | January Effect | Equity | +2 | ★4 | [2.11] |
| `MONDAY` | Monday Effect | Equity | -1 | ★3 | [2.11] |
| `FRIDAY` | Friday Effect | Equity | +1 | ★3 | [2.11] |
| `WEEKEND_BTC` | Weekend Effect | Crypto | -1 | ★3 | [2.11] |
| `PRE_FOMC` | FOMC前 | Bond | +2 | ★4 | [2.20] |
| `PRE_CPI` | CPI前 | Bond | -2 | ★4 | [2.20] |
| `PRE_NFP` | 雇用統計前 | Bond | -3 | ★5 | [2.20] |
| `PRE_HOLIDAY` | 連休前 | FX | -2 | ★4 | [2.20] |
| `VIX_SPIKE` | VIX急騰 → 金 | Metal | +3 | ★4 | [2.20] |

#### 10.4.2 年末を減点にした理由

年末は**加点ではなく減点**とした。機関投資家が休みに入り、流動性が落ちる。値幅は出るが、それは方向感ではなく板の薄さによるものである。「動きやすい」と「読みやすい」は別で、このエンジンが示すべきは後者である。

#### 10.4.3 曜日効果を星3にした理由

Monday Effect と Friday Effect は、1980年代までの米国株データでは確認されていたが、2000年代以降のデータでは有意性が大きく落ちている。広く知られた結果、先回りされて消えたと説明されることが多い。

そこで**星3**とし、`Inp_AnomalyMinStars = 4`（既定）では**自動的に無効になる**ようにした。使いたければ星の閾値を下げれば有効になる。消さずに残しているのは、後で検証したくなったときに表から復活させられるようにするためである。

---

### 10.5 Calculation

#### 10.5.1 適用範囲（scope）による分離

**これがこのエンジンで最も重要な仕組みである。**

Sell in May は株価指数の話である。これを USDJPY の判断に足してはいけない。同じ「5月」でも、株にとっての5月と円にとっての5月は違う現象を指す。

そこで各規則は必ず `scope` を持ち、集計も scope ごとに独立して行う。

```text
SCOPE_FX      通貨ペア全般
SCOPE_JPY     円が絡むペアのみ（五十日など）
SCOPE_EQUITY  株価指数
SCOPE_BOND    債券
SCOPE_METAL   金・銀
SCOPE_CRYPTO  暗号資産
```

`SCOPE_JPY` は `SCOPE_FX` の**部分集合**として扱う。円のペアを見ているときは、FXの規則（月末など）と円の規則（五十日）の両方が乗る。

\[
Score_{JPY} = \sum_{scope = JPY} score + \sum_{scope = FX} score
\]

USDJPY のチャートでは五十日が乗り、EURUSD のチャートでは乗らない。これが正しい挙動である。

#### 10.5.2 星による選別

`stars < Inp_AnomalyMinStars` の規則は、該当していても加点しない。根拠の強さで足切りする仕組みである。

#### 10.5.3 合計の打ち止め

\[
Score_{final} = \mathrm{clip}(Score_{raw},\ -15,\ +15)
\]

上限は `GMD_ANOMALY_CAP = 15`。

**アノマリーは重ねれば重ねるほど当たるものではない。** 条件が5つ揃った日は、1つだけ揃った日より5倍有利、ということはない。むしろ「条件を並べていけばいくらでも都合のよい日を作れる」というのがアノマリー分析の典型的な失敗である。上限を置くのは、その暴走を仕組みとして止めるためである。

#### 10.5.4 排他になる規則

Halloween Effect（11月〜4月）と Sell in May（5月〜10月）は、同じ現象の裏表である。したがって**どちらか片方しか成立しない**。両方を足して打ち消し合うことはない。実装では `if / else` で分岐させている。

---

### 10.6 五十日（ごとうび）の判定

★5 の中で唯一、日付だけでは判定できない規則である。

#### 10.6.1 判定条件

```text
1. 東京時間で日付を取る
2. 日が5の倍数、または月末
3. 土日にあたる場合は前営業日（金曜）へ繰り上げ
4. 東京 8:00 〜 10:30 の時間帯のみ有効
```

#### 10.6.2 東京時間で判定する理由

五十日は**日本企業の決済日**である。判定する暦は日本の暦でなければならない。

MT5のサーバ時刻は多くの業者でGMT+2〜+3である。GMT+3のサーバで日本時間の朝9時は、サーバ時刻では前日の3時にあたる。**サーバ時刻の日付をそのまま使うと、月初と月末で1日ずれる。** 25日を五十日と判定すべき朝に、サーバはまだ24日を指している。

そこで `Inp_ServerGmtOffset` を入力に置き、サーバ時刻から一度GMTへ戻し、そこへ+9時間して東京時間を作る。

\[
T_{tokyo} = T_{server} - offset + 9
\]

`TimeGMT()` を使わないのは、ストラテジーテスター内では実時間が返るためである。過去日付の検証ができなくなる。

#### 10.6.3 時間帯を限定する理由

五十日の効果は**仲値（東京 9:55）に向けた実需の買い**として現れる。仲値を過ぎれば材料は消える。にもかかわらず終日加点すると、ロンドン時間やニューヨーク時間にも「五十日だから買い」という誤った表示が出続ける。

そのため 8:00〜10:30 の窓を設けた。この窓を出たら、五十日は該当しない扱いになる。

#### 10.6.4 営業日の繰り上げ

25日が土曜なら、決済は前営業日の金曜24日に行われる。したがって金曜日には、翌日・翌々日が五十日かどうかも見る。

月をまたぐ繰り上げ（月末が日曜で、決済が金曜になる場合）は、[2.11] では扱っていない。判定の複雑さに対して効果が小さいためである。34章の制約に記載した。

---

### 10.7 Market Season Score（月別季節性）

月ごとに期待値を持たせる。

| 月 | 点 | 根拠 |
|---|---|---|
| 1月 | +1 | January Effect |
| 2月 | +1 | Halloween 期間内 |
| 3月 | 0 | |
| 4月 | 0 | |
| 5月 | -1 | Sell in May の入口 |
| 6月 | 0 | |
| 7月 | 0 | |
| 8月 | -2 | 夏枯れ。流動性が薄い |
| 9月 | -2 | 統計上もっとも弱い月 |
| 10月 | 0 | |
| 11月 | +2 | Halloween Effect の入口 |
| 12月 | +2 | |

この表は `SetSeasonScore(month, score)` で実行時に変更できる。値をハードコードせず変えられるようにしたのは、自分の検証結果で上書きできるようにするためである。

**この表は株価指数の季節性である。** したがって加算先は `SCOPE_EQUITY` に限定する。9月が弱いのは株の話であって、USDJPY が9月に下がるという話ではない。

季節性の状態は3つに丸めて表示する。

```text
score > 0  → Bull
score = 0  → Neutral
score < 0  → Bear
```

---

### 10.8 Output

| 名前 | 型 | 意味 |
|---|---|---|
| `GetScore(scope)` | `int` | 打ち止め後のスコア。**外に出すのはこれ** |
| `GetRawScore(scope)` | `int` | 打ち止め前の素点。検証用 |
| `GetHitCount()` | `int` | 該当した規則の数 |
| `GetHitLabel(i)` | `string` | i番目の該当規則名 |
| `GetHitScore(i)` | `int` | i番目の点 |
| `GetSeason()` | `ENUM_SEASON_STATE` | Bull / Neutral / Bear |
| `GetSeasonScore()` | `int` | 当月の季節性スコア |

---

### 10.9 Display

```text
Anomaly +5  (五十日, 月末)
```

表示は「合計」と「根拠」を必ず並べる。`+5` だけでは、なぜ5なのか後から説明できない。該当が多い日は先頭2件までを出し、全件はログへ回す。

色は 15章の原則どおり3色に収める。

| 条件 | 色 |
|---|---|
| `score >= +3` | 赤 |
| `score <= -3` | 青 |
| それ以外 | 白 |
| 未計算 | 灰 |

該当が0件のときは `Anomaly   0` と出す。空欄にはしない。空欄は「機能していない」と「該当なし」の区別がつかない。

---

### 10.10 Class Interface

```cpp
class CAnomalyEngine : public IEngine
{
private:
   CLogger           *m_log;
   SAnomalyRule       m_rules[GMD_ANOMALY_MAX];
   int                m_ruleCount;
   SAnomalyHit        m_hits[GMD_ANOMALY_MAX];
   int                m_hitCount;
   int                m_serverGmtOffset;
   int                m_minStars;
   bool               m_useSeason;
   int                m_seasonTable[13];
   int                m_scopeScore[7];
   ENUM_SEASON_STATE  m_season;
   bool               m_ready;

public:
   bool               Init(CLogger *logger,
                           const int serverGmtOffset = 3,
                           const int minStars = 4,
                           const bool useSeason = true);

   void               SetRuleEnabled(const string code, const bool enabled);
   void               SetSeasonScore(const int month, const int score);

   bool               Calculate(void);
   bool               IsReady(void) { return m_ready; }
   string             GetName(void) { return "Anomaly"; }

   int                GetScore(const ENUM_ANOMALY_SCOPE scope);
   int                GetRawScore(const ENUM_ANOMALY_SCOPE scope);
   int                GetHitCount(void);
   string             GetHitLabel(const int index);
   int                GetHitScore(const int index);
   ENUM_SEASON_STATE  GetSeason(void);
   int                GetSeasonScore(void);

   string             GetDisplayText(const ENUM_ANOMALY_SCOPE scope = SCOPE_FX);
   string             BuildDetailText(const ENUM_ANOMALY_SCOPE scope = SCOPE_FX);
   color              GetColor(const ENUM_ANOMALY_SCOPE scope = SCOPE_FX);
};
```

---

### 10.11 Implementation Notes

- **価格を一切読まない。** `SymbolInfo*` も `CopyClose` も呼ばない。したがって `AssetDetection` に依存せず、銘柄が1つも見つからない口座でも動く
- `Calculate()` は常に成功する。`IsReady()` が false になるのは `Calculate()` を1度も呼んでいないときだけ
- 計算量は規則数に比例するだけで、実測で1ms未満に収まる。毎ティック呼んでも問題ないが、日付が変わらなければ結果も変わらないため、他エンジンと同じ更新間隔に合わせている
- 規則の追加は `BuildRuleTable()` に `AddRule()` を1行足す。判定は `Calculate()` に1行足す。**他のファイルは触らない**

#### 10.11.1 このエンジンの限界を明記しておく

アノマリーは、その性質上、次の危険を抱えている。設計者が自覚していないと、数字が出ているだけで信じてしまう。

**1. 検証していない**

上記の点数（+3, -2 など）は、公開されている研究や経験則に基づく初期値であり、**このプロジェクトで統計検証した数値ではない**。星の数も同様である。実データでの検証は Ver3 の課題とし、それまでは「仮の重み」として扱う。

**2. 後追いで消える**

広く知られたアノマリーは、参加者が先回りすることで縮小する。曜日効果がその典型である。過去に効いた事実は、今後も効く保証にならない。

**3. 条件を足せば何でも言える**

「五十日かつ月曜かつ月末」のような条件を重ねれば、サンプル数が数件になる。数件で高い勝率が出るのは当たり前で、それは発見ではない。打ち止め（10.5.3）と星による選別（10.5.2）は、この危険に対する構造的な歯止めである。

---

### 10.12 Future Expansion

- **[2.20]** 経済カレンダー連携。`CalendarValueHistory()` が使えるか起動時に判定し、使えない環境では該当規則を自動で無効化する
- **[2.20]** 祝日判定。`SymbolInfoSessionTrade()` から取引時間のない日を拾って連休を推定する
- **[3.00]** 的中率の記録。各規則が発火した日の翌日リターンを蓄積し、点数を自動調整する
- **[3.00]** 通貨別の季節性。現在は株価指数の季節性のみを持つが、通貨ごとの月別傾向を別表として追加する

---

## 11. 画面構成・表示モード（Display Modes）

> 旧仕様書の5章・12章が重複していたため、本章に統合した。

| モード | 内容 |
|---|---|
| Mode 1: Chart | チャート＋移動平均＋BB＋Pivot（通常のチャート分析画面） |
| Mode 2: Dashboard | Market Dashboardのみ表示（チャート要素なし） |
| Mode 3: Hybrid | チャート＋Dashboardを同時表示 |
| Mode 4: Minimal | 通貨強弱ランキングのみの最小表示 |

モード切替は右下のボタン、または入力パラメータ`Inp_DisplayMode`から行う。

---

## 12. マーケットオープン・カウントダウン

東京・ロンドン・ニューヨークの各市場について、「開場中」または「開場まであとX時間X分」を表示する。

- サーバー時間とセッション時刻のズレ（サマータイム含む）を考慮した計算ロジックを`Core/Utils.mqh`に共通化すること
- 過去の開発経験上、サーバー時間とNYクローズ時刻の対応関係はブローカーごとに異なるため、**セッション境界時刻をオフセットとして入力パラメータ化**しておくと、環境が変わっても調整しやすい

---

## 13. 経済指標イベント（Economic Events）

- CPI・FOMCなど主要イベントまでの残り時間を表示
- データソース（カレンダーAPI／手動登録／MT5標準のイベントカレンダー流用）を要選定
- 更新頻度は60秒毎（20章参照）

---

## 14. ダッシュボード レイアウト（イメージ）

```
┌──────────────────────────────┐
│ GLOBAL MARKET DASHBOARD      │
├──────────────────────────────┤
│ Risk ON        82%           │
│ Confidence     91%           │
│ Best Pair      EURJPY        │
├──────────────────────────────┤
│ Currency Strength             │
│ USD █████                     │
│ EUR ████                      │
│ GBP ███                       │
│ AUD ██                        │
│ JPY █                         │
├──────────────────────────────┤
│ Money Flow                    │
│ Stocks      ↑↑                │
│ Gold        ↓                 │
│ Bond        ↓                 │
│ Crypto      ↑↑↑               │
├──────────────────────────────┤
│ Tokyo   OPEN                  │
│ London  03:12                 │
│ NewYork 09:54                 │
├──────────────────────────────┤
│ CPI      2h14m                │
│ FOMC     1d03h                │
└──────────────────────────────┘
```

表示の描画順（更新順）：Market Summary → Currency Strength → Best Pair → Money Flow → Market Open → Economic Events

---

## 15. 色分けルール（Color Rules）

### 15.1 原則：色は3つまで

> **色を増やすほど判断は遅くなる。**

GMDの目的は一瞬で資金の流れを判断することである。多段階のグラデーションは「きれい」だが、見た人は色の意味を思い出す必要が生じ、かえって遅くなる。**基本は白、両端だけ赤と青**とする。

| 用途 | 色 | 定数 |
|---|---|---|
| 最強・強い上昇・Risk ON | 赤 | `clrRed` |
| 中立・その他すべて | 白 | `clrWhite` |
| 最弱・強い下降・Risk OFF | 青 | `clrDodgerBlue` |
| データなし・無効 | 灰 | `clrGray` |

白基調にすることで、黒背景・白背景のどちらのチャートでも読める。

### 15.2 通貨強弱ランキング（5.5.2）

| 対象 | 色 |
|---|---|
| 1位（最強） | 赤 |
| 8位（最弱） | 青 |
| 2〜7位 | 白 |
| データ不足時 | 全体を灰 |

段階的なグラデーション（赤→橙→黄→白→水色→青）は**v1.3で廃止した**。中間順位の情報は数字と矢印が担う。

### 15.3 その他の要素

| 要素 | 色の割り当て |
|---|---|
| Market Regime | Risk ON = 赤 / Neutral = 白 / Risk OFF = 青 |
| Money Flow | 流入 = 赤 / 中立 = 白 / 流出 = 青 |
| Confidence | High = 白（太字）/ Medium = 白 / Low = 灰 |
| Best Pair 方向 | BUY = 赤 / SELL = 青 / NONE = 灰 |
| アセット状態 | OK = 白 / PENDING = 灰 / UNAVAILABLE = 灰（取り消し線相当の薄さ） |

> **注意**：Confidence には赤・青を使わない。信頼度は方向ではなく確度であり、方向色と混ざると誤読を招く。

### 15.4 実装規約

- 色の分岐を Display 側に書かない。**各Engineが `GetColor()` を提供する**（30.3）
- 色定数をコード中に直接書かず、`Types.mqh` の定数か Engine の getter を経由する
- 5章の強弱色（`GetStrengthColor()`）と方向シグナル色（`GetSignalColor()`）は関数名で明確に分離する

---

## 16. パフォーマンス設計

| 項目 | 方針 |
|---|---|
| 更新間隔 | 通貨強弱：1秒毎 or 新しいバーのみ／株価指数・Gold：5秒毎／債券：10秒毎／経済指標・市場オープン：60秒毎（20章参照） |
| CPU負荷 | 可能な限り低く抑える |
| オブジェクト数 | 最小限に抑える |
| 描画方式 | 差分更新（変化があった部分だけ再描画） |

### 16.1 実装上の重要な注意点（実体験より）

- **毎ティック全銘柄を再計算するのは避ける**。1秒間に何度もティックが来る通貨ペアでは、`GetTickCount()`等で前回更新時刻を記録し、指定間隔を超えた時だけ再計算するタイマー方式にする
- **オブジェクトは「作り直す」のではなく「位置・テキストだけ更新」する**。`ObjectDelete`→`ObjectCreate`を毎回繰り返すとちらつき・負荷増の原因になる。`ObjectFind`で存在確認し、無ければ作成、あれば`ObjectSetString`/`ObjectSetInteger`で更新、という設計にする
- **初回起動時のヒストリーデータ未取得への対策**：ブローカーからのデータ取得は非同期のため、インジケーター起動直後は必要な本数のバーが揃っていないことがある。「データが揃うまで待って、揃ってから一括描画する」フラグ管理（例：`g_dataReady`）を各エンジンに用意し、揃うまでは空欄／「準備中」表示にする
- **週末・市場休止中の挙動**：新しい価格が来ないため、ティック起動の再計算処理が走らない。市場が閉まっている間もカウントダウン表示等は動き続けられるよう、`OnTimer()`を併用し、価格更新に依存しない部分は別途タイマーで更新する

---

## 17. バージョン履歴

| バージョン | 内容 |
|---|---|
| Project Specification v0.1 | 初版（本ドキュメントのベース） |
| Project Specification v0.2 | 重複章の統合、各エンジンの計算式明文化、実装上の落とし穴と対策を追加 |
| Project Specification v0.3 | 本改訂版。**26章 Asset Detection Flow を新設**（Detect / Validation / Availability / Cache の5段階パイプライン、状態モデル、データ構造、公開API、ログ・エラーコード、テストケース）。付録Aに `AssetDetection.mqh` 実装スケルトンを追加。Asset Detection をVer2.20から**Ver2.11の基盤として前倒し**、ロードマップを再定義 |
| Project Specification **v1.0 Draft** | 本改訂版。全体を6パートに再構成し目次を追加。**0章「本書の読み方」**（章テンプレート・用語統一・要求レベル）を新設。5〜10章の各エンジンを Purpose / Inputs / Calculation / Output / Display / Class Interface / Implementation Notes / Future Expansion の統一構成に書き換え、全エンジンのクラス定義と入出力表を明記。**29〜35章を新設**（Class Diagram / Data Flow / Error Handling / Performance Benchmark / Release Checklist / Known Limitations / ドキュメント体系）。27章をTest Planとして3層構造に拡充。付録Bに共通データ構造リファレンスを追加 |
| Project Specification **v1.1** | 実装者レビューを反映したスコープ調整版。**0.3「実装フェーズの表記」** を新設し、全機能に `[2.11]` / `[2.20]` / `[2.30+]` を明示。**26.0「実装フェーズ分割」** を新設し、AssetDetection を Ver2.11（Detect + Validation + Availability + Refresh）と Ver2.20（Retry / Cache / Stale）に分割。`ENUM_ASSET_ID` をVer2.11の8資産に絞り、残り6資産はコメント枠として保持。27章に **27.0 最小スモークテスト** を追加し、27.1以降を実装後に確定する暫定案と位置づけ。25.1に「Ver2.11に含めないもの」の表を追加。34章にL9〜L11、35.4に「仕様書の育て方」を追加 |
| Project Specification **v1.2** | **4章に Architecture Diagram を新設**（MT5 → Core → Engines → Display → Chart の全体図、Ver2.11で動く範囲の明示）。26.0のキャッシュを **L1メモリ[2.11] / L2 CSV[2.20] / 高度な管理[3.00]** の3段階に再定義し、L1をVer2.11へ前倒し。高度なAvailability を Ver2.20、性能最適化を Ver3.00 に整理。以降、仕様書の更新は実装で判明した差分のみに絞る |
| Project Specification **v1.3** | **Currency Strength Engine v2 へ全面改訂**（5章）。対象を **8通貨・28ペア**（NZD追加）に確定し、「7通貨・28ペア」の誤りを訂正。判定を直近1本の陰陽線から **直近N本の重み付き集計**（既定3本・重み1:2:3）に変更。勢い（-7〜+7）と**7段階の矢印**を新設。**15章の配色を赤・白・青の3色に簡素化**し、6段階グラデーションを廃止。8.3.1に **Ver2.11用のConfidence暫定式** を追加。9.3のBest Pair解決フローを `GetFxSymbol()` ベースに書き換え、反転時は方向をSELLに変換する規則を明記 |

| Project Specification **v1.4** | **10章に Anomaly Engine を新設**（規則表方式、scope による資産分離、五十日の東京時間判定、月別 Market Season Score、合計の打ち止め ±15、星による選別）。旧10章「アセット検出 概要」を **26.16へ移設**し、Part II を6エンジン構成に整理。**8.9** を新設し、アノマリーを Confidence の数値に既定で加算しない理由を明記。エラーコードに `AN`（701-799）を追加。4章の図と27.0のスモークテストにアノマリーを反映。34章に L12〜L14 を追加 |

---

## 18. モジュール構成（System Modules Architecture）

将来の拡張（Ver3, Ver4〜）に耐えられるよう、役割ごとにディレクトリを分離する。

```text
src/
└── Modules/
    ├── Engines/                  // 分析・計算ロジック
    │   ├── CurrencyStrength.mqh  // 28通貨ペアの強弱スコア計算
    │   ├── MoneyFlow.mqh         // アセット間の資金流出入分析
    │   ├── MarketRegime.mqh      // Risk Score (0-100) および Risk ON/OFF判定
    │   ├── Confidence.mqh        // 総合確信度 (0-100%) 計算
    │   ├── BestPair.mqh          // 最強vs最弱の「ベストペア」自動選定
    │   └── AnomalyEngine.mqh     // 暦の文脈を点数化（価格を読まない）
    │
    ├── Display/                  // UI描画・表示制御
    │   ├── Dashboard.mqh         // レイアウトと更新の統括
    │   └── DrawObjects.mqh       // オブジェクトの生成・差分更新・一括削除
    │                             // ※ Ver2.11の表示は1枚パネル。パネル単位で
    │                             //   3分割せず「描画の下請け」と「レイアウト」で切る
    │
    └── Core/                     // システム共通基盤・ユーティリティ
        ├── Types.mqh              // 全モジュール共通の列挙型・構造体・IEngine（付録B）
        ├── AssetDetection.mqh     // ブローカー固有銘柄の自動検出（優先順位リスト方式）
        ├── Logger.mqh             // 動作ログ・エラーハンドリング・デバッグ出力
        └── Utils.mqh              // 配列操作・型変換・時刻計算等の汎用補助関数
```

### 18.1 モジュール間インターフェースの原則（27章と統合）
- `Dashboard.mqh`は各Engineを**呼び出すだけ**で、計算ロジックを持たない
- 各Engineは`Calculate()`または`Update()`を実行し、**計算結果だけ**を返す（描画処理を持たない）
- Engine間の直接依存は最小限にし、必要なデータはCoreの共通構造体経由で受け渡す

---

## 19. データ更新ポリシー

| データ種別 | 更新間隔 |
|---|---|
| 通貨強弱 | 1秒毎 |
| 株価指数 | 5秒毎 |
| Gold | 5秒毎 |
| 債券 | 10秒毎 |
| 経済指標イベント | 60秒毎 |
| マーケットオープン | 60秒毎 |

---

## 20. シンボル優先順位（Symbol Priority）

例：Gold
```
XAUUSD → GOLD → GOLDmicro → XAUUSD.r
```

この優先順位リストは`Core/AssetDetection.mqh`内で銘柄カテゴリごとに定義し、**設定ファイルまたは入力パラメータで上書きできる**ようにしておくと、未知のブローカー表記にも対応しやすい。

> 全アセットの候補リスト完全版は **26.6.1** に集約した。候補を追加する際は26.6.1の表を更新し、本章は参照だけに留める（二重管理を避ける）。

---

## 21. 設定項目（Settings）

- Update Interval（更新間隔）
- Currency Timeframe（通貨強弱判定に使う時間足）
- Color Theme（配色テーマ）
- Display Mode（11章の4モード）
- Auto Detect Symbols（銘柄自動検出のON/OFF）
- Show Events（経済指標表示のON/OFF）
- Show Market Open（マーケットオープン表示のON/OFF）

### 21.1 Asset Detection 関連の入力パラメータ

> `[2.20]` 印のものは Ver2.11 では定義せず、該当機能の実装時に追加する。**使わないパラメータを先に並べると、利用者が設定に迷う。**

| パラメータ名 | 型 | 既定値 | 説明 |
|---|---|---|---|
| `Inp_AutoDetectSymbols` | bool | true | falseにすると以下の手動指定のみを使う |
| `Inp_SymbolSuffix` | string | "" | ブローカー共通サフィックスの手動指定。空なら自動推定（26.6.2） |
| `Inp_SymbolPrefix` | string | "" | ブローカー共通プレフィックスの手動指定 |
| `Inp_OverrideGold` | string | "" | Goldの銘柄名を強制指定（検出失敗時の逃げ道） |
| `Inp_OverrideIndices` | string | "" | 指数の強制指定。`US30=DJ30;NAS100=USTEC` 形式のセミコロン区切り |
| `Inp_OverrideCrypto` | string | "" | 暗号資産の強制指定。同形式 |
| `Inp_ValidationMinBars` | int | 100 | Validationで要求する最小バー本数（26.7） |
| `Inp_ValidationMaxAgeSec` | int | 86400 | `[2.20]` 最終ティックがこれ以上古ければStale判定（週末考慮で24h） |
| `Inp_CacheTTLMinutes` | int | 0 | `[2.20]` キャッシュの有効期限。0 = セッション中は無期限（26.9） |
| `Inp_CachePersist` | bool | true | `[2.20]` 検出結果を永続化し、次回起動を瞬時化 |
| `Inp_DetectLogLevel` | enum | INFO | 検出処理のログ粒度（OFF/ERROR/WARN/INFO/DEBUG） |
| `Inp_ShowUnavailable` | bool | true | 未対応銘柄を `Unavailable` として表示するか、行ごと非表示にするか |

### 21.2 Anomaly Engine 関連の入力パラメータ

| パラメータ名 | 型 | 既定値 | 説明 |
|---|---|---|---|
| `Inp_EnableAnomaly` | bool | true | アノマリー・エンジン全体のON/OFF |
| `Inp_AnomalyMinStars` | int | 4 | この星数未満の規則を無効化。既定では曜日効果が外れる（10.4.3） |
| `Inp_ServerGmtOffset` | int | 3 | サーバ時刻のGMT差。**五十日の判定精度に直結する**（10.6.2） |
| `Inp_UseSeasonScore` | bool | true | 月別 Market Season Score を使うか |
| `Inp_AnomalyToConfidence` | bool | **false** | 信頼度の数値に加算するか。既定はfalse（8.9） |

`Inp_ServerGmtOffset` は口座を変えたら見直す。ここがずれると五十日が1日ずれる。MT5の「気配値」で表示時刻とPCの時刻を比べれば確認できる。

---

## 22. 用語集（Glossary）

| 用語 | 説明 |
|---|---|
| Risk ON | 投資家がリスク資産へ資金を移す状態 |
| Risk OFF | 投資家が安全資産へ資金を移す状態 |
| Money Flow | 市場間の資金循環 |
| Confidence | 売買シグナルの信頼度 |
| Market Regime | 市場全体の状態（Risk ON/OFF/Neutral） |

---

## 23. コーディング規約（Coding Standards）

| 対象 | 規約 |
|---|---|
| クラス | `CMarketRegime`、`CCurrencyStrength`のようにPascalCase＋`C`プレフィックス |
| 変数 | メンバ変数`m_`、グローバル変数`g_`、入力パラメータ`Inp`プレフィックス |
| 関数 | `Calculate()`、`Update()`、`Draw()`、`Detect()`のように役割を表す動詞で統一 |
| ファイル名 | PascalCase |
| コメント | 日本語可 |
| ヘッダー | すべての`.mqh`ファイル冒頭に、役割を説明するコメントを記載する |

### 23.1 追加推奨事項
- チャートオブジェクト名は、モジュールごとに一意なプレフィックス（例：`GMD_Rank_`, `GMD_Flow_`）を付け、`OnDeinit()`で`ObjectsDeleteAll`により確実に削除できるようにする
- グローバル変数（MT5の`GlobalVariable`）を使う場合は、プレフィックスにインジケーター名＋バージョンを含め、他のインジケーターとの衝突を避ける

---

## 24. 将来的な分析エンジン（Future Analytics Engine）

- 統計分析（相関・クラスタリング）
- 機械学習によるMarket Pattern検出
- Money Rotation（資金循環）分析
- Correlation Engine（相関エンジン）
- Probability / Recommendation（確率・推奨）

---

## 25. 開発ロードマップ

| バージョン | 内容 |
|---|---|
| Ver2.11 | **Core基盤（Types / Logger / Utils / AssetDetection〈Detect + Validation + L1キャッシュ〉）** + Currency Strength / Best Pair / Confidence / Dashboard基本表示。対象8資産 + FX28ペア |
| Ver2.20 | Money Flow / Market Regime / MoneyFlowPanel + **AssetDetection の L2キャッシュ / Retry / Stale / 高度なAvailability** + 対象資産6種追加（GER40 / UK100 / US10Y / US30Y / DXY / VIX） |
| Ver2.30 | Market Open / Economic Events / Display Mode |
| Ver3.00 | Flow Analysis / Correlation Engine / Bond Analysis |
| Ver4.00 | Analytics Engine / Prediction / Portfolio Analysis |

### 25.1 Ver2.11 の完成定義（Definition of Done）

Ver2.11は「全部入り」を目指さず、**上に積める土台を完成させるバージョン**と位置づける。以下がすべて安定稼働した時点で完成とする。

1. シンボル自動検出（26.0の[2.11]範囲）が、最低2社以上の異なるブローカー環境で動作する
2. 未対応銘柄があってもクラッシュせず `Unavailable` 表示で継続する
3. 通貨強弱・ランキング・Best Pair・Confidence が整合した値を表示する
4. Dashboardがちらつきなく差分更新される
5. 24時間連続稼働でオブジェクト数・メモリが増え続けない

**Ver2.11に含めないもの（意図的な除外）**

| 除外するもの | 送り先 |
|---|---|
| Money Flow / Market Regime | Ver2.20 |
| AssetDetection の L2キャッシュ（CSV永続化）/ Retry / Stale判定 | Ver2.20 |
| キャッシュの世代管理・並列検出などの性能最適化 | Ver3.00 |
| GER40 / UK100 / US10Y / US30Y / DXY / VIX の検出 | Ver2.20 |
| 本格的なテスト計画（27.1〜27.5） | Ver2.11完成後に整備 |
| Market Open / Economic Events / 表示モード切替 | Ver2.30 |

土台を先に固める方が、結果的に長く使えるソフトになる。**「作れるから作る」ではなく「今必要だから作る」で判断する。**

---

## 26. Asset Detection Flow（詳細設計）

> 本章はVer2.11の最初の実装対象である `Core/AssetDetection.mqh` の完全仕様である。このモジュールは全エンジンの上流に位置し、ここが不安定だと下流すべてが崩れる。したがって、最も厳密に仕様を固める。
>
> **ただし、本章のすべてをVer2.11で作るわけではない。** 26.0のフェーズ分割に従うこと。

### 26.0 実装フェーズ分割

Detect / Validation / Availability / Cache / Retry をすべて同時に作ると、どこで失敗しているのかが切り分けられなくなる。**Ver2.11では「検出して、使えるかを判定する」までを完成させ、キャッシュと再試行はVer2.20に回す。**

| 機能 | フェーズ | 理由 |
|---|---|---|
| Detect（優先順位リスト検索 + サフィックス推定） | **[2.11]** | これが無いと何も始まらない |
| Validation（4ゲート検証） | **[2.11]** | 「使えるか」の判定は必須 |
| Availability（OK / Unavailable / Pending の3状態） | **[2.11]** | 表示に必要 |
| Refresh（手動再検出） | **[2.11]** | 実装が容易で、開発中のデバッグに有用 |
| **Cache L1（メモリ内レジストリ）** | **[2.11]** | `SAssetRegistry` を保持すること自体がL1キャッシュである。実質コスト0 |
| Retry（PENDING の自動再試行） | `[2.20]` | 起動直後の同期待ちは Refresh で代替できる |
| Cache L2（CSVへの永続化） | `[2.20]` | 起動が0.5秒遅いだけ。ファイルI/Oは不具合の温床でもある |
| Stale判定（最終更新の鮮度チェック） | `[2.20]` | 週末表示の改善であり、必須ではない |
| 高度なAvailability（代替銘柄への自動フォールバック） | `[2.20]` | 基本の3状態判定で当面足りる |
| キャッシュの世代管理・自動無効化・並列検出 | `[3.00]` | 性能最適化。動くものができてから考える |

#### キャッシュの3段階

「キャッシュ」と一言で書くと重く見えるが、実際は3段階に分かれる。**Ver2.11で作るのは最も軽いL1だけ**である。

| 段階 | 実体 | フェーズ | 実装量 |
|---|---|---|---|
| L1 メモリ | `SAssetRegistry` を保持し、2回目以降は `GetSymbol()` で即返す | **[2.11]** | 数行（構造体を持つだけ） |
| L2 ファイル | `MQL5/Files/GMD/symbols_<broker>.csv` に保存・復元 | `[2.20]` | 100行程度 |
| L3 管理 | TTL・世代・自動無効化・整合性チェック | `[3.00]` | 相応 |

#### Ver2.11 で作るパイプライン（簡略版）

```text
OnInit()
   ↓
[1] Detect      … 全銘柄一覧取得 → サフィックス推定 → 候補名で照合
   ↓
[2] Validation  … SymbolSelect → 同期確認 → 気配値 → バー本数
   ↓
[3] Availability… OK / PENDING / UNAVAILABLE を確定
   ↓
[4] Engineへ引き渡し
```

**Ver2.11 では起動のたびにフル検出する（L2キャッシュが無いため）。** 銘柄数2,000で500ms程度であり、起動時1回だけなら許容範囲である。検出後は `SAssetRegistry`（L1）に保持するので、稼働中に再検索が走ることはない。

#### 状態モデルの扱い

26.3では5状態を定義するが、**Ver2.11で実際に使うのは `UNKNOWN` / `OK` / `PENDING` / `UNAVAILABLE` の4つ**である。`STALE` はenumに定義だけしておき、判定ロジックはVer2.20で実装する。定義を先に入れておけば、後から状態を追加するときに `switch` 文を書き換えずに済む。

#### アセット範囲

Ver2.11の検出対象は **Gold / Silver / US30 / NAS100 / SPX500 / JP225 / BTC / ETH の8資産 + FX 28ペア** とする。GER40・UK100・US10Y・US30Y・DXY・VIX を外すのは、**これらを消費するのが Money Flow と Market Regime（ともにVer2.20）だけ**だからである。エンジンが無いのに検出だけ実装しても、動作確認ができない。

### 26.1 位置づけと責務

**責務（これだけをやる）**

- ブローカー固有の銘柄名を、GMD内部の論理名（`ASSET_GOLD` など）に対応付ける
- その銘柄が**実際に使える**かを検証する
- 結果をキャッシュし、各エンジンに**確定した銘柄名**を提供する

**責務外（これはやらない）**

- 価格の計算・分析（→ Enginesの仕事）
- 画面描画（→ Displayの仕事。状態を返すだけ）
- エラーでの処理中断（→ 常に状態を返して継続する）

### 26.2 5段階パイプライン（全体フロー・最終形）

> 以下はVer2.20時点の最終形である。Ver2.11では `[0] Cache復元` と `[4] Cache保存` を実装せず、常に `[1] Detect` から開始する。

```text
Terminal起動 / OnInit()
        ↓
[0] Cache復元判定  ── 有効なキャッシュあり ──┐
        ↓ なし                              │
[1] Detect（検出）                          │
    │  シンボル全一覧取得（SymbolsTotal(false)）
    │  サフィックス/プレフィックス自動推定       │
    ├─ FX 28ペア検索                          │
    ├─ Metals検索   (Gold, Silver)            │
    ├─ Index検索    (US30/NAS100/SPX500/JP225/GER40/UK100)
    ├─ Crypto検索   (BTC, ETH)                │
    └─ Bond検索     (US10Y, US30Y)            │
        ↓                                     │
[2] Validation（検証）                        │
    │  Market Watch登録 → 同期確認 → 気配値 → バー本数
        ↓                                     │
[3] Availability（可用性確定）                 │
    │  OK / Unavailable / Stale の3状態を確定    │
        ↓                                     │
[4] Cache（保存）                             │
    │  メモリ保持 + 任意で永続化                │
        ↓ ←────────────────────────────┘
[5] Engineへ引き渡し
    GetSymbol(ASSET_GOLD) → "XAUUSD.a"
    IsAvailable(ASSET_US10Y) → false
```

重要な原則：**このパイプライン全体は原則として起動時に1回だけ実行する**。`OnCalculate()` や `OnTimer()` から毎回呼ばない。

### 26.3 状態モデル（これが仕様の中核）

各アセットは常に以下のいずれか1つの状態を持つ。「存在する/しない」の2値ではなく**5状態**とすることで、表示側が適切なメッセージを出し分けられる。

| 状態 | 値 | 意味 | Dashboard表示例 |
|---|---|---|---|
| `ASSET_UNKNOWN` | 0 | 未検出（初期値） | `---` |
| `ASSET_OK` | 1 | 検出・検証ともに成功。使用可 | 通常表示 |
| `ASSET_PENDING` | 2 | 銘柄はあるがヒストリー同期待ち | `Loading...`（灰） |
| `ASSET_STALE` | 3 | 銘柄ありだが最終更新が古い（市場休止等） | 値を灰色表示し `*` を付与 |
| `ASSET_UNAVAILABLE` | 4 | ブローカーに存在しない・使用不可 | `Unavailable`（暗灰） |

`ASSET_PENDING` を設けているのが重要である。MT5はヒストリーを非同期で取得するため、起動直後に `ASSET_UNAVAILABLE` と確定させてしまうと、**本来使える銘柄を永久に切り捨ててしまう**。PENDINGの銘柄のみ、後述の再試行対象とする。

#### 状態遷移図

```text
UNKNOWN ──Detect成功──▶ PENDING ──Validation成功──▶ OK
   │                       │                         │
   │                       └──タイムアウト(N回)──▶ UNAVAILABLE
   │                                                 │
   └──Detect失敗──▶ UNAVAILABLE                      │
                                                     ▼
                                   最終ティックが古い → STALE
                                   新しいティック到着 → OKに復帰
```

### 26.4 データ構造

> ここに示す型はすべて `Core/Types.mqh` に置く（付録B）。`AssetDetection.mqh` 内に直接定義しないこと。

```cpp
//--- 論理アセットID（内部では常にこのIDで参照する）
enum ENUM_ASSET_ID
{
   //--- [2.11] 実装対象。まずはこの8つだけ
   ASSET_GOLD=0, ASSET_SILVER,
   ASSET_US30, ASSET_NAS100, ASSET_SPX500, ASSET_JP225,
   ASSET_BTC, ASSET_ETH,

   //--- [2.20] 追加予定。今はコメントのまま残す（消さない）
   // ASSET_GER40, ASSET_UK100,
   // ASSET_US10Y, ASSET_US30Y,
   // ASSET_DXY,   ASSET_VIX,

   ASSET_COUNT               // 常に末尾。配列サイズとして使う
};

enum ENUM_ASSET_STATE { ASSET_UNKNOWN, ASSET_OK, ASSET_PENDING, ASSET_STALE, ASSET_UNAVAILABLE };

enum ENUM_ASSET_CATEGORY { CAT_FX, CAT_METAL, CAT_INDEX, CAT_CRYPTO, CAT_BOND, CAT_OTHER };

//--- 1アセットの検出結果
struct SAssetInfo
{
   ENUM_ASSET_ID        id;            // 論理ID
   ENUM_ASSET_CATEGORY  category;      // カテゴリ
   string               logicalName;   // "Gold" など表示用名称
   string               symbol;        // 検出された実銘柄名 "XAUUSD.a"
   ENUM_ASSET_STATE     state;         // 26.3の状態
   int                  digits;        // 小数桁数
   int                  barsAvailable; // 検証時のバー本数
   datetime             lastTickTime;  // 最終ティック時刻
   datetime             detectedAt;    // 検出確定時刻（キャッシュTTL判定用）
   int                  retryCount;    // PENDINGからの再試行回数
   string               note;          // 失敗理由等（ログ・ツールチップ用）
};

//--- 全アセットのレジストリ（これがEngineに渡る唯一の窓口）
struct SAssetRegistry
{
   SAssetInfo  assets[ASSET_COUNT];
   string      fxPairs[28];       // 検出済みFXペアの実銘柄名
   int         fxPairCount;       // 実際に使えたFXペア数（5.6のConfidence入力）
   string      detectedSuffix;    // 推定されたサフィックス
   string      detectedPrefix;    // 推定されたプレフィックス
   datetime    builtAt;           // レジストリ構築時刻
   int         okCount;
   int         unavailableCount;
};
```

> **設計意図**：エンジンは決して銘柄名を文字列リテラルで書かない。常に `GetSymbol(ASSET_GOLD)` 経由で取得する。この規約を守ることで、ブローカー依存コードが `AssetDetection.mqh` の1ファイルに完全に隔離される。

### 26.5 起動シーケンス

```text
OnInit()
  │
  ├─ 1. Logger初期化
  ├─ 2. g_assets.Init()          ← 候補テーブル構築（この時点ではI/Oなし）
  ├─ 3. g_assets.LoadCache()     ← 永続化キャッシュがあれば復元
  ├─ 4. g_assets.DetectAll()     ← Detect → Validation → Availability
  ├─ 5. g_assets.SaveCache()
  ├─ 6. Logger.PrintSummary()    ← 検出結果サマリをエキスパートに1回出力
  └─ 7. EventSetTimer(1)

OnTimer()  ← 1秒毎
  └─ g_assets.RetryPending()     ← PENDINGの銘柄のみ再検証（最大60秒・30回）
```

全検出は `OnInit()` で行うが、**`OnInit()` をブロックして待たない**。`Sleep()` でヒストリー取得を待つ実装は、ターミナル全体を固まらせる原因になるため禁止とする。揃わないものはPENDINGとし、`OnTimer()` で非同期に埋める。

### 26.6 Detect（検出）詳細

#### 26.6.1 候補リスト方式

カテゴリごとに優先順位付きの候補名を定義し、上から順に試す。

| アセット | 候補（優先順） |
|---|---|
| Gold | `XAUUSD` → `GOLD` → `GOLDmicro` → `GOLD.spot` → `XAU/USD` |
| Silver | `XAGUSD` → `SILVER` → `SILVERmicro` |
| US30 | `US30` → `DJ30` → `DJI30` → `USA30` → `WS30` → `DOW` → `US30Cash` |
| NAS100 | `NAS100` → `USTEC` → `NDX100` → `US100` → `NASDAQ` → `NAS100Cash` |
| SPX500 | `SPX500` → `US500` → `SP500` → `USA500` → `SPX` |
| JP225 | `JP225` → `JPN225` → `NIKKEI` → `N225` → `JP225Cash` |
| GER40 | `GER40` → `DE40` → `DAX40` → `GER30` → `DE30` → `DAX` |
| UK100 | `UK100` → `FTSE100` → `GB100` → `UK100Cash` |
| BTC | `BTCUSD` → `BTCUSDT` → `BITCOIN` → `BTC/USD` → `XBTUSD` |
| ETH | `ETHUSD` → `ETHUSDT` → `ETHEREUM` → `ETH/USD` |
| US10Y | `US10Y` → `USTBOND10` → `TNOTE10` → `UST10Y` → `US10YT` |
| US30Y | `US30Y` → `USTBOND` → `TBOND` → `UST30Y` |
| DXY | `DXY` → `USDX` → `USDIDX` → `USDOLLAR` |
| VIX | `VIX` → `VIXX` → `VOLX` → `US_VIX` |

各候補には、後述のサフィックス・プレフィックスが自動的に組み合わされる。

> **現実的な見通し**：債券（US10Y/US30Y）とVIXは、国内FX業者の多くでは提供されていない。**検出できないのが正常ケース**として設計し、Market Regime Engineはこれら抜きでもスコアを算出できるよう重み再配分（8.2）を行う。

#### 26.6.2 サフィックス・プレフィックスの自動推定

候補リストを手書きで増やすのには限界があるため、ブローカー共通の飾り文字を自動で割り出す。

```text
1. 現在チャートの _Symbol を取得        例: "EURUSD.a"
2. 先頭から基準パターン（[A-Z]{6}）を探す  → "EURUSD"
3. 前後に残った文字列を prefix / suffix とする → suffix=".a"
4. 確信度検証：Market Watch全銘柄のうち、同じsuffixを持つものが
   全体の50%以上あれば「共通サフィックス」として採用
5. Inp_SymbolSuffix が空でなければ、自動推定より手動指定を優先
```

推定したサフィックスはすべての候補に自動適用する。つまり `XAUUSD` を試す際に `XAUUSD.a` も自動で試される。

#### 26.6.3 検索の3段階フォールバック

```text
【第1段】完全一致
    候補名 そのもの / 候補名+suffix / prefix+候補名+suffix
    → SymbolInfoInteger(name, SYMBOL_EXIST) で確認
         ↓ 見つからなければ
【第2段】正規化部分一致
    全銘柄をループし、大文字化・非英数除去した上で
    候補名を含むものを探す（"XAU/USD" → "XAUUSD" として一致）
    複数ヒット時は、文字列長が最短のものを採用
    （理由："XAUUSD" と "XAUUSD_FUTURES_DEC" なら前者が目的の現物）
         ↓ 見つからなければ
【第3段】入力パラメータの強制指定（Inp_Override*）
         ↓ それでもなければ
    ASSET_UNAVAILABLE で確定（エラーにしない）
```

除外ルール：銘柄名に `FUT`, `SWAP`, `CFD_EXP`, `_DEC`, `_MAR` などの月限表記を含むものは、第2段の候補から除外する（限月物はロールオーバーで銘柄名が変わるため不適）。

#### 26.6.4 FX 28ペアの検出

8通貨の組み合わせ28ペアについて、**正序・逆序の両方を試し、見つかった方の向きを記録する**。

```cpp
struct SFxPair
{
   string base;      // "EUR"
   string quote;     // "USD"
   string symbol;    // 実銘柄名 "EURUSD.a"
   bool   inverted;  // 逆序で見つかったか（強弱計算で符号反転が必要）
   bool   available;
};
```

`inverted` フラグはCurrency Strength Engine（5.3）とBest Pair Engine（9.3-4）の両方で使う。これをDetection層で一元管理することで、各エンジンが個別に逆序判定する重複実装を防ぐ。

検出できたペア数 `fxPairCount` はConfidence Engineの入力になる（5.6）。

### 26.7 Validation（検証）詳細

名前が見つかっただけでは採用しない。4つのゲートを順に通す。

| # | ゲート | 使うAPI | 失敗時の状態 |
|---|---|---|---|
| 1 | Market Watch登録 | `SymbolSelect(sym, true)` | UNAVAILABLE |
| 2 | データ同期 | `SymbolIsSynchronized(sym)` | PENDING（再試行） |
| 3 | 気配値の健全性 | `SymbolInfoTick(sym, tick)` で `tick.bid > 0` | PENDING |
| 4 | ヒストリー本数 | `Bars(sym, tf) >= Inp_ValidationMinBars` | PENDING |

全ゲート通過後、**鮮度チェック**を行う。

```text
if (TimeCurrent() - tick.time) > Inp_ValidationMaxAgeSec
    → ASSET_STALE（使うが、表示に「古いデータ」印を付ける）
else
    → ASSET_OK
```

> **週末の扱い**：土日は全銘柄のtick.timeが古くなるため、STALEをエラー扱いしてはならない。既定の24時間は、金曜クローズ後の土曜日中まではOK扱いとなるよう意図的に長めに取っている。

#### 再試行ポリシー

```text
PENDING の銘柄のみ、OnTimer()（1秒）で再検証
初回は 1秒間隔、失敗ごとに間隔を ×1.5（指数バックオフ、上限10秒）
最大30回 または 60秒経過で打ち切り → UNAVAILABLE で確定
確定後も、手動再検出（ダッシュボードのRefreshボタン）でリセット可能
```

### 26.8 Availability（可用性）と縮退運転

**基本方針：見つからないことはエラーではない。表示するだけ。**

```text
───────────────────────────────
Money Flow
  Stocks       ↑↑
  Gold         ↓
  Crypto       ↑↑↑
  Bond         Unavailable      ← クラッシュしない、空白にもしない
───────────────────────────────
```

具体規則：

1. `Alert()` や `MessageBox()` で検出失敗を通知しない（起動のたびにポップアップが出るのはストレスになる）。エキスパートログに1行出すだけ
2. `OnInit()` は検出失敗を理由に `INIT_FAILED` を返さない。返すのは致命的な問題（メモリ確保失敗等）のみ
3. Engine側は必ず `IsAvailable(id)` を確認してから計算に入る
4. アセットが欠けた場合、そのアセットに割り当てられていた**重みは他に再配分**する（7章・8章）
5. カテゴリ内の全銘柄がUnavailableなら、そのパネルセクションごと非表示にしてもよい（`Inp_ShowUnavailable=false` 時）

#### 最低稼働要件

以下を満たさない場合のみ、ダッシュボード全体に警告バナーを出す。

| 機能 | 最低要件 | 満たさない時 |
|---|---|---|
| Currency Strength | FXペア 20以上 | ランキングをグレーアウトし「Limited data」表示 |
| Best Pair | Currency Strengthが有効 | `N/A` |
| Money Flow | カテゴリ1つ以上がOK | パネル非表示 |
| Market Regime | 入力指標 3つ以上がOK | `Regime: Insufficient data` |

### 26.9 Cache（キャッシュ）詳細

#### 26.9.1 なぜ必須か

銘柄検索は全シンボルループ（ブローカーによっては2,000銘柄以上）を伴う。これを毎秒実行するのは完全な無駄であり、CPU負荷の主因になる。**初回のみ検出し、以降はメモリ上のレジストリを参照する。**

#### 26.9.2 2層キャッシュ

| 層 | 実体 | 寿命 | 目的 |
|---|---|---|---|
| L1：メモリ | `SAssetRegistry g_registry` | インジケーター稼働中 | 毎回の参照をO(1)にする |
| L2：永続化 | `MQL5/Files/GMD/symbols_<broker>.csv` | ターミナル再起動を跨ぐ | 2回目以降の起動を瞬時化 |

L2のキーはブローカーを一意に識別する値とする。

```cpp
string cacheKey = AccountInfoString(ACCOUNT_COMPANY) + "_" + AccountInfoString(ACCOUNT_SERVER);
```

これにより、複数のMT5を使い分けてもキャッシュが混ざらない。

#### 26.9.3 CSVフォーマット

```csv
# GMD Symbol Cache v1
# broker=XMTrading-MT5 3, saved=2026.08.04 09:30:00, suffix=
GOLD,XAUUSD,OK,5,2026.08.04 09:29:58
US30,US30Cash,OK,2,2026.08.04 09:29:58
US10Y,,UNAVAILABLE,0,
```

#### 26.9.4 キャッシュ破棄（再検出）条件

以下のいずれかに該当した場合、キャッシュを破棄して全検出をやり直す。

1. キャッシュ内のブローカー識別キーが現在の接続先と一致しない
2. キャッシュ保存時のGMDバージョンが現在と異なる
3. `Inp_CacheTTLMinutes > 0` で、`builtAt` からTTLを超過した
4. キャッシュされた銘柄名が現在 `SYMBOL_EXIST` で否定された（ブローカー側の銘柄名変更）
5. ユーザーがRefreshボタンを押した、または検出関連の入力パラメータを変更した

なお、キャッシュ復元時も**Validationのゲート1・2だけは必ず再実行する**（存在確認のみなので軽い）。全信頼はしない。

### 26.10 公開API（このシグネチャを確定させる）

```cpp
class CAssetDetection
{
public:
   //--- ライフサイクル
   bool               Init(void);                 // 候補テーブル構築
   bool               DetectAll(void);            // Detect→Validation→Availability→Cache
   void               RetryPending(void);         // OnTimerから毎秒呼ぶ
   void               Refresh(void);              // キャッシュ破棄して再検出
   void               Deinit(void);

   //--- 参照（Engineが使うのは主にここ）
   string             GetSymbol(ENUM_ASSET_ID id);        // 実銘柄名。未検出なら ""
   bool               IsAvailable(ENUM_ASSET_ID id);      // OK or STALE なら true
   ENUM_ASSET_STATE   GetState(ENUM_ASSET_ID id);
   string             GetStateText(ENUM_ASSET_ID id);     // "OK" / "Unavailable" 等表示用
   SAssetInfo         GetInfo(ENUM_ASSET_ID id);

   //--- FX専用
   int                GetFxPairCount(void);
   string             GetFxSymbol(string base, string quote, bool &inverted);
   bool               ResolvePair(string cur1, string cur2, string &outSymbol, bool &inverted);

   //--- 汎用（Best Pair Engine と共通化・10.2参照）
   string             FindFirstExisting(string &candidates[]);
   string             NormalizeSymbolName(string raw);

   //--- 診断
   int                CountByState(ENUM_ASSET_STATE st);
   string             BuildSummaryText(void);             // ログ・設定画面表示用
};
```

**契約**

- `GetSymbol()` は失敗時もクラッシュせず空文字列を返す。`NULL` は返さない
- すべての参照系メソッドは**副作用なし**でO(1)。内部で検索を走らせない
- `DetectAll()` はセッション中に何度呼んでも安全（冪等）

### 26.11 ログ出力仕様

起動時に以下のサマリをエキスパートへ**1回だけ**出力する。これがあるとブローカー変更時の切り分けが一瞬でできる。

```text
[GMD] ===== Asset Detection Summary =====
[GMD] Broker    : XMTrading-MT5 3
[GMD] Suffix    : (none)   Prefix: (none)
[GMD] FX Pairs  : 28 / 28
[GMD] Metals    : Gold=XAUUSD  Silver=XAGUSD
[GMD] Indices   : US30=US30Cash  NAS100=USTECCash  SPX500=US500Cash
[GMD]             JP225=JP225Cash  GER40=GER40Cash  UK100=UK100Cash
[GMD] Crypto    : BTC=BTCUSD  ETH=ETHUSD
[GMD] Bonds     : US10Y=(unavailable)  US30Y=(unavailable)
[GMD] Result    : OK=12  Pending=0  Unavailable=2
[GMD] Elapsed   : 184 ms
[GMD] ===================================
```

ログレベルは `Inp_DetectLogLevel` で制御し、DEBUG時のみ候補ごとの試行結果を全出力する。

### 26.12 エラーコード

`Logger.mqh` と共有するコード体系を定義し、ログの検索性を上げる。

| コード | 意味 | 重大度 |
|---|---|---|
| `AD-001` | 候補リストに一致する銘柄なし | WARN |
| `AD-002` | `SymbolSelect()` 失敗 | WARN |
| `AD-003` | 同期未完了（PENDINGへ） | INFO |
| `AD-004` | ヒストリー本数不足 | INFO |
| `AD-005` | ティック取得失敗・bid=0 | WARN |
| `AD-006` | 鮮度切れ（STALE） | INFO |
| `AD-007` | 再試行上限到達・UNAVAILABLE確定 | WARN |
| `AD-008` | キャッシュ読み込み失敗・形式不正 | WARN |
| `AD-009` | キャッシュ保存失敗（ファイルI/O） | WARN |
| `AD-010` | FXペア検出数が最低要件未満 | ERROR |

すべてWARN以下は処理を継続する。ERRORでもインジケーター自体は停止しない。

### 26.13 パフォーマンス目標

| 項目 | 目標値 | 測定方法 |
|---|---|---|
| 初回全検出時間（キャッシュなし・2,000銘柄環境） | 500ms 以内 | `GetMicrosecondCount()` |
| キャッシュ復元起動 | 50ms 以内 | 同上 |
| `GetSymbol()` 1回呼出し | 単なる配列参照で完了 | ループベンチ |
| 定常時のCPU使用 | 検索を走らせない（ゼロ） | — |

全シンボルループは `DetectAll()` 内で**1回だけ**行い、全銘柄名を一度配列に読み込んでから候補マッチを行う（アセットごとに全ループを回すのはO(n×m)になるため禁止）。

### 26.14 テストケース（AssetDetection専用）

| # | ケース | 期待結果 |
|---|---|---|
| AD-T01 | 標準的な国内FX業者（債券なし） | FX/Gold/指数がOK、債券がUnavailableで継続 |
| AD-T02 | サフィックス付き口座（`.a` `.r` `m` 等） | サフィックスを自動推定して全銘柄検出 |
| AD-T03 | Market Watchが空の状態で起動 | `SymbolSelect()` で自動登録され検出成功 |
| AD-T04 | ヒストリー未取得状態で起動 | PENDING表示後、数秒でOKに遷移 |
| AD-T05 | 土日（全市場クローズ）に起動 | クラッシュせず、24h以内ならOK扱い |
| AD-T06 | 存在しない銘柄をOverrideで強制指定 | AD-001をログに出しUnavailable。クラッシュなし |
| AD-T07 | 2回目起動（キャッシュあり） | 50ms以内に復元、検出ログは「from cache」 |
| AD-T08 | キャッシュ後にブローカーを変更 | キャッシュ破棄を検知し自動で全再検出 |
| AD-T09 | 銘柄数 3,000以上のブローカー | 初回検出 500ms以内 |
| AD-T10 | 同インジケーターを3チャート同時起動 | キャッシュファイルの同時書き込みで破損しない |
| AD-T11 | Refreshボタン押下 | 全状態がリセットされ再検出される |
| AD-T12 | US10YだけUnavailableの状態でMarket Regime実行 | 重み再配分されスコアが算出される |

### 26.15 実装順序（今日からの作業単位）

```text
Step 1  enum / struct 定義 だけを書いてコンパイルを通す
        → この時点でビルドエラー0を確認
Step 2  候補テーブル Init() を実装し、Printで中身を確認
Step 3  全シンボル一覧の取得とログ出力（何銘柄あるか目視で確認）
Step 4  FindFirstExisting() を実装し、Goldだけ検出させて確認
Step 5  サフィックス自動推定を追加
Step 6  全カテゴリのDetectを実装
Step 7  Validation 4ゲートを追加
Step 8  状態確定（OK / PENDING / UNAVAILABLE）と Refresh() を追加
Step 9  BuildSummaryText() でログを整える
────────── ここまでで Ver2.11 の AssetDetection は完成 ──────────
Step 10 [2.20] RetryPending() を追加
Step 11 [2.20] Cache（L1→L2の順）を追加
Step 12 [2.20] Stale判定を追加
```

各Stepの終わりで必ずコンパイルを通し、27.0の最小スモークテストを実行してから次に進む。一気に全部書かない。**Step 9 まで到達したら、いったん手を止めてCurrency Strength Engineに移る。** AssetDetectionを100%完成させるより、エンジンまで繋げて画面に値が出る状態を早く作る方が、設計の誤りを早く発見できる。

---

### 26.16 アセット検出の概要（v1.4でPart IIから移設）

> **重要**：本章は概要である。実装に使う詳細設計（状態モデル・データ構造・公開API・テストケース）は **26章 Asset Detection Flow** に集約した。`Core/AssetDetection.mqh` を実装する際は26章を正とする。

#### 26.16.1 Purpose

ブローカーごとに異なる銘柄名の違いを吸収し、GMD内部では常に論理名（`ASSET_GOLD` 等）だけで資産を参照できるようにする。ブローカー依存コードを1ファイルに隔離するための層である。

#### 26.16.2 処理フロー

旧仕様の単純な1本道フローを、**5段階パイプライン**に拡張する。

```text
Detect → Validation → Availability → Cache → Engineへ引き渡し
```

名前が見つかっただけでは不十分である。名前が存在しても、ヒストリーが0本、気配値が0、Market Watchに未登録、といった「名前だけある銘柄」が実在するため、**実際にデータが取れるかを検証する工程（Validation）を必須とする**。

#### 26.16.3 ブローカー間の表記ゆれ対応

同じ資産でも銘柄名が異なるため、**優先順位付きの候補リストから最初に見つかったものを採用**する。

```text
例：Gold
XAUUSD → GOLD → GOLDmicro → XAUUSD.r → XAUUSD.a ...
```

この「候補から実在するものを探す」ロジックは Best Pair Engine（9章）とも共通化し、`Core/AssetDetection.mqh` 内の汎用関数1箇所にまとめる（重複実装を避ける）。

候補リストを手書きで増やし続けるのには限界があるため、**ブローカー共通サフィックスの自動推定**（例：現在チャートが `EURUSD.a` なら `.a` を全候補に自動付与）と**正規化部分一致検索**を併用する。詳細は26.6。

#### 26.16.4 カテゴリ別 対象銘柄例

| カテゴリ | 代表銘柄例 |
|---|---|
| FX | USDJPY, EURUSD, GBPUSD 他28ペア |
| 貴金属 | Gold, Silver |
| 株価指数 | SPX500, NAS100, US30, JP225, GER40, UK100 |
| 暗号資産 | BTC, ETH |
| 債券 | US10Y, US30Y |

#### 26.16.5 Class Interface

26.10 を参照。

---

## 27. Test Plan（テスト計画）

> **本章は暫定である。** テスト項目は、コードを書く前に机上で作ると必ず的外れになる。本章の詳細はVer2.11の実装完了後に、実際に発生した不具合をもとに確定させる（そのとき本書を `v1.2` に更新する）。
>
> **Ver2.11の実装中に守るのは 27.0 の最小スモークテストだけでよい。**

### 27.0 最小スモークテスト（[2.11] これだけは毎回やる）

モジュールを1つ実装するたびに、以下5項目を確認する。所要時間は5分程度である。

| # | 確認 | 合格条件 |
|---|---|---|
| S1 | コンパイル | 警告0・エラー0 |
| S2 | チャートに適用 | エキスパートログにエラーが出ない |
| S3 | 検出結果のログ出力 | 検出した銘柄名と状態が全件出力される |
| S4 | 存在しない銘柄を含む口座で起動 | クラッシュせず `Unavailable` として継続する |
| S5 | インジケーター削除 | チャートに `GMD_` オブジェクトが残らない |
| S6 | アノマリーの発火 | 該当規則名と合計点がログに出る。0件の日は `Anomaly   0` と表示される |

**S4とS5だけは絶対に省略しない。** この2つが、後から最も直しにくい不具合の発生源である。

---

以下 27.1〜27.5 は、Ver2.11完成後に整備する本格的なテスト計画の設計案である。

### 27.1 テストの3層構造

| 層 | 対象 | 実行方法 | 頻度 |
|---|---|---|---|
| L1 単体テスト | 各 `.mqh` の関数単位 | テスト用スクリプト `Tests/Test_<Module>.mq5` | モジュール実装ごと |
| L2 結合テスト | Engine → Display の連携 | 実チャートで目視＋ログ確認 | 各バージョンの区切り |
| L3 実環境テスト | ブローカー・時間帯・稼働時間 | 複数口座で実運用 | リリース前 |

### 27.2 L1：単体テストケース

| モジュール | 検証内容 |
|---|---|
| AssetDetection | 26.14 の AD-T01〜T12 |
| CurrencyStrength | 陽線/陰線の加点、inverted ペアの符号、全通貨同点時のゼロ除算回避 |
| MoneyFlow | 変化率計算、しきい値境界（ちょうど0.30%）、Close=0 時のゼロ除算回避 |
| MarketRegime | Z-score（stddev=0時）、重み再配分の合計が1.0になるか、tanh のスケーリング |
| Confidence | 全エンジン欠損時に `--` を返すか、0〜100 のクリップ |
| BestPair | 正順・逆順の両解決、反転時の方向、点差不足時の N/A |
| Utils | サマータイム跨ぎの時刻計算、文字列正規化 |

### 27.3 L2：結合テストケース

| 項目 | 確認内容 |
|---|---|
| 呼び出し順序 | AssetDetection → 各Engine → Confidence → Display の順で実行されるか（30章） |
| 差分更新 | 値が変わっていないオブジェクトを再描画していないか |
| 表示モード切替 | 4モードを往復してもオブジェクトが残留しないか |
| Refresh動作 | 再検出後、全パネルが正しく再構築されるか |

### 27.4 L3：実環境テストマトリクス

| # | 環境 | 確認内容 |
|---|---|---|
| E1 | サフィックスなしの口座 | 全銘柄検出 |
| E2 | サフィックス付き口座（`.a` `.r` `micro`） | 自動推定が効くか |
| E3 | 債券・VIX非対応のブローカー | Unavailable表示で継続 |
| E4 | 銘柄数3,000以上のブローカー | 初回検出500ms以内 |
| E5 | 週末（全市場クローズ） | フリーズしない、カウントダウンは動く |
| E6 | 初回起動（ヒストリー未取得） | 空白・エラーにならずPENDING表示 |
| E7 | 複数チャート同時起動（3枚） | オブジェクト名・キャッシュファイルが衝突しない |
| E8 | 72時間連続稼働 | メモリ・オブジェクト数が増え続けない |
| E9 | 低スペックPC（2コア） | CPU負荷が許容範囲（32章の基準） |

### 27.5 回帰テスト

バージョンを上げるたびに、**最低限 E1・E3・E6・E7 を再実行する**。過去に直したバグが再発していないかを確認するため、修正したバグは必ず27.2の表にテストケースとして追加する。

---

## 28. 未確定事項（Open Issues）


改善にあたり、以下は仕様として未確定のため、開発着手前に確定させることを推奨する。

1. Currency Strength Engineの得点方式（非対称加点 vs 対称加点）
2. Money Flow Engineの「流入/中立/流出」を分けるしきい値の具体的な数値
3. Market Regime Engineの各指標の重み付け初期値
4. Confidence Engineの各エンジンへの重み配分
5. 経済指標カレンダーのデータソース

### 28.1 本改訂（v0.3）で確定した事項

- Asset Detection のパイプライン構成・状態モデル・公開API（26章）
- Asset Detection をVer2.11の基盤として前倒しすること（25章）
- 検出失敗をエラーとせず Unavailable 状態として扱う方針（3章・26.8）

### 28.2 Asset Detection に関する残課題

| # | 課題 | 推奨する選択 |
|---|---|---|
| A | DXY・VIXを必須にするか | 任意扱い。未対応ブローカーが多いため重み再配分で吸収 |
| B | 債券が取れない環境での代替指標 | TLT等のETF、またはUSDJPYを金利プロキシとして流用するか要検討 |
| C | キャッシュの保存先 | ファイル（CSV）を推奨。GlobalVariableは型がdoubleのみで文字列を持てないため |
| D | マルチチャート時のキャッシュ競合 | 書き込みは最初に起動した1チャートのみに限定する案 |

---

## 29. Class Diagram（クラス構成）

### 29.1 全体構造

```text
                       ┌─────────────────────────┐
                       │   GlobalMarketDashboard  │  ← .mq5（エントリポイント）
                       │   OnInit / OnCalculate   │
                       │   OnTimer / OnDeinit     │
                       └───────────┬─────────────┘
                                   │ 所有
                       ┌───────────▼─────────────┐
                       │      CDashboard          │  Display統括
                       └───────────┬─────────────┘
              ┌────────────────────┼────────────────────┐
              │                    │                    │
     ┌────────▼───────┐  ┌─────────▼────────┐  ┌────────▼────────┐
     │ CSummaryPanel  │  │  CRankingPanel   │  │ CMoneyFlowPanel │
     └────────────────┘  └──────────────────┘  └─────────────────┘
              │  参照（読むだけ・計算しない）
   ┌──────────┴──────────────────────────────────────────┐
   │                     IEngine（インターフェース）        │
   └──────────┬──────────────────────────────────────────┘
   ┌──────────┼──────────┬───────────┬───────────┐
   │          │          │           │           │
┌──▼───────┐ ┌▼────────┐ ┌▼────────┐ ┌▼────────┐ ┌▼─────────┐
│CCurrency │ │CMoney   │ │CMarket  │ │CConfid  │ │CBestPair │
│Strength  │ │Flow     │ │Regime   │ │ence     │ │          │
└──┬───────┘ └┬────────┘ └┬────────┘ └┬────────┘ └┬─────────┘
   └──────────┴───────────┴───────────┴───────────┘
                          │ 全Engineが依存
              ┌───────────▼─────────────┐
              │    CAssetDetection       │  Core
              └───────────┬─────────────┘
                 ┌────────┴────────┐
           ┌─────▼─────┐    ┌──────▼─────┐
           │  CLogger  │    │   CUtils   │
           └───────────┘    └────────────┘
```

### 29.2 依存の方向（重要な設計規約）

```text
Display  ──依存──▶  Engines  ──依存──▶  Core
```

- 矢印は**一方通行**である。CoreがEnginesを、EnginesがDisplayを参照してはならない
- Engine同士の依存は Confidence → 他3エンジン、BestPair → CurrencyStrength の2つだけに限定する
- この規約を守れば、Engineを単体でテスト用スクリプトから呼び出せる

### 29.3 共通インターフェース

すべてのエンジンは同じインターフェースを実装する。Dashboard側がエンジンを一律に扱えるようになり、エンジン追加時の変更箇所が減る。

```cpp
//+------------------------------------------------------------------+
//| すべての分析エンジンが実装する共通インターフェース                 |
//+------------------------------------------------------------------+
interface IEngine
{
   bool    Calculate(void);     // 計算実行。成功でtrue
   bool    IsReady(void);       // 表示可能な状態か
   string  GetName(void);       // ログ用の名前
};
```

Dashboardからの呼び出しは配列で一括処理できる。

```cpp
IEngine *engines[5] = { &g_strength, &g_flow, &g_regime, &g_bestPair, &g_confidence };

for(int i=0; i<5; i++)
{
   if(!engines[i].Calculate())
      g_logger.Warn(engines[i].GetName() + " calculation skipped");
}
```

### 29.4 ファイルとクラスの対応

| ファイル | クラス | 依存先 |
|---|---|---|
| `Core/AssetDetection.mqh` | `CAssetDetection` | Logger のみ |
| `Core/Logger.mqh` | `CLogger` | なし |
| `Core/Utils.mqh` | （関数群） | なし |
| `Engines/CurrencyStrength.mqh` | `CCurrencyStrength` | AssetDetection |
| `Engines/MoneyFlow.mqh` | `CMoneyFlow` | AssetDetection |
| `Engines/MarketRegime.mqh` | `CMarketRegime` | AssetDetection |
| `Engines/BestPair.mqh` | `CBestPair` | AssetDetection, CurrencyStrength |
| `Engines/Confidence.mqh` | `CConfidence` | CurrencyStrength, MoneyFlow, MarketRegime |
| `Display/Dashboard.mqh` | `CDashboard` | 全Engine |
| `Display/SummaryPanel.mqh` | `CSummaryPanel` | Dashboard経由 |
| `Display/RankingPanel.mqh` | `CRankingPanel` | Dashboard経由 |
| `Display/MoneyFlowPanel.mqh` | `CMoneyFlowPanel` | Dashboard経由 |

---

## 30. Data Flow（データフロー）

### 30.1 起動時（OnInit）

```text
OnInit()
  │
  ├─▶ CLogger::Init()
  ├─▶ CAssetDetection::Init() → LoadCache() → DetectAll() → SaveCache()
  │        └─ 結果：SAssetRegistry（確定した銘柄名の一覧）
  ├─▶ 各Engine::Init(&g_assets)      ← レジストリの参照を渡すだけ
  ├─▶ CDashboard::Init()             ← パネル枠のみ作成、値は空
  ├─▶ CLogger::PrintSummary()
  └─▶ EventSetTimer(1)
```

### 30.2 定常稼働時（OnTimer / OnCalculate）

```text
OnTimer()（1秒毎）
  │
  ├─▶ CAssetDetection::RetryPending()    ← PENDING銘柄のみ
  │
  ├─▶ 更新間隔チェック（19章）
  │     通貨強弱 1秒 / 指数・Gold 5秒 / 債券 10秒 / イベント 60秒
  │
  ├─▶【計算フェーズ】※この順序は固定
  │     1. CCurrencyStrength::Calculate()
  │     2. CMoneyFlow::Calculate()
  │     3. CMarketRegime::Calculate()
  │     4. CBestPair::Calculate()        ← 1の結果を使う
  │     5. CConfidence::Calculate()      ← 1〜3の結果を使う
  │
  └─▶【描画フェーズ】
        CDashboard::Update()
          ├─ CSummaryPanel::Draw()      Regime / Confidence / BestPair
          ├─ CRankingPanel::Draw()      通貨強弱
          ├─ CMoneyFlowPanel::Draw()    アセット別フロー
          ├─ MarketOpen 描画
          └─ EconomicEvents 描画
```

**計算と描画を完全に分離すること。** 計算フェーズ中に描画APIを呼ばない。これを守ると、描画だけを差し替えたり、計算結果をCSV出力するといった拡張が容易になる。

### 30.3 データの受け渡し形式

```text
CAssetDetection ──[SAssetRegistry]──▶ Engines
Engines         ──[各Engineのgetter]──▶ CDashboard
CDashboard      ──[文字列と色]──────▶ ChartObject
```

- Engine間で構造体をコピーして渡さない。**getter経由で必要な値だけ読む**（コピーコストとメモリ増加を避ける）
- Displayは値を加工しない。加工が必要ならEngine側にgetterを追加する

### 30.4 終了時（OnDeinit）

```text
OnDeinit()
  ├─▶ EventKillTimer()
  ├─▶ CDashboard::Deinit()   → ObjectsDeleteAll(0, "GMD_")
  ├─▶ CAssetDetection::SaveCache()
  └─▶ CLogger::Deinit()      → 稼働時間・警告件数のサマリを出力
```

`OnDeinit()` でのオブジェクト削除漏れは、チャートにゴミが残る最も典型的な不具合である。プレフィックス `GMD_` での一括削除を**必須**とする。

---

## 31. Error Handling（エラーハンドリング方針）

### 31.1 基本原則

> **エラーで止めない。状態として表示する。**

GMDは発注を行わない表示専用インジケーターである。したがって、データが欠けたときに「止まる」より「欠けていることを正しく見せる」方が常に正しい。

### 31.2 重大度の定義

| レベル | 定義 | 動作 | 出力先 |
|---|---|---|---|
| `DEBUG` | 開発時の詳細追跡 | 継続 | エキスパートログ（Inp_LogLevel=DEBUG時のみ） |
| `INFO` | 正常範囲の状態変化 | 継続 | エキスパートログ |
| `WARN` | 機能の一部が使えない | 該当機能のみ縮退 | エキスパートログ |
| `ERROR` | 主要機能が使えない | 該当パネルを警告表示 | エキスパートログ |
| `FATAL` | 継続不可能 | `INIT_FAILED` を返す | ログ＋Alert |

**`FATAL` に該当するのはメモリ確保失敗などごく一部のみ**である。銘柄が見つからない、データが揃わない、といったものはすべて `WARN` 以下として扱う。

### 31.3 エラーコード体系

`<モジュール略号>-<3桁>` で統一する。

| 略号 | モジュール | 割当範囲 |
|---|---|---|
| `AD` | AssetDetection | 001-099（26.12で定義済み） |
| `CS` | CurrencyStrength | 101-199 |
| `MF` | MoneyFlow | 201-299 |
| `MR` | MarketRegime | 301-399 |
| `CF` | Confidence | 401-499 |
| `BP` | BestPair | 501-599 |
| `AN` | Anomaly | 701-799 |
| `DP` | Display | 601-699 |
| `SY` | System / Core | 901-999 |

主要コード：

| コード | 意味 | 重大度 |
|---|---|---|
| `CS-101` | 使用可能ペアが20未満 | WARN |
| `CS-102` | 全通貨同点（スコア差なし） | INFO |
| `MF-201` | カテゴリ内の全アセットがUnavailable | WARN |
| `MF-202` | 基準足のCloseが0（ゼロ除算回避） | WARN |
| `MR-301` | 使用可能指標が3未満 | WARN |
| `MR-302` | 標準偏差0による標準化スキップ | INFO |
| `CF-401` | 全エンジン欠損により算出不可 | WARN |
| `BP-501` | 正順・逆順ともに銘柄が存在しない | INFO |
| `BP-502` | 点差不足のため推奨を見送り | INFO |
| `AN-701` | 規則表が上限に達した | WARN |
| `AN-702` | 未知のアノマリーcodeを指定 | WARN |
| `DP-601` | オブジェクト作成失敗 | ERROR |
| `SY-901` | メモリ確保失敗 | FATAL |

### 31.4 Logger の最小仕様

```cpp
enum ENUM_LOG_LEVEL { LOG_OFF, LOG_ERROR, LOG_WARN, LOG_INFO, LOG_DEBUG };

class CLogger
{
public:
   bool   Init(ENUM_LOG_LEVEL level, bool toFile = false);
   void   Debug(string msg);
   void   Info (string msg);
   void   Warn (string code, string msg);
   void   Error(string code, string msg);
   void   Fatal(string code, string msg);

   int    GetWarnCount(void);
   int    GetErrorCount(void);
   void   PrintSummary(void);
};
```

出力書式は固定する。ログを後から検索・集計できるようにするためである。

```text
[GMD][WARN][CS-101] Currency pairs available: 18/28 (limited data)
```

### 31.5 やってはいけないこと

- `Alert()` / `MessageBox()` を通常のエラー通知に使う（起動のたびにポップアップが出る）
- `Print()` を直接呼ぶ（レベル制御が効かなくなるため、必ず `CLogger` 経由）
- 同じ警告を毎ティック出力する（**同一コードの連続出力は抑制する**。初回のみ出し、以降はカウントのみ）
- エラー時に `ExpertRemove()` を呼ぶ

---

## 32. Performance Benchmark（性能基準）

### 32.1 目標値

| 項目 | 目標 | 上限（これを超えたら不合格） |
|---|---|---|
| 初回検出（キャッシュなし・2,000銘柄） | 500ms | 1,000ms |
| 初回検出（キャッシュあり） | 50ms | 150ms |
| 1回の全エンジン計算 | 20ms | 50ms |
| 1回の全パネル描画（差分更新時） | 5ms | 15ms |
| 定常時CPU使用率（4コア環境） | 1%未満 | 3% |
| チャートオブジェクト総数 | 120以下 | 200 |
| メモリ増加量（72時間稼働） | 0 | +5MB |

### 32.2 測定方法

```cpp
ulong t0 = GetMicrosecondCount();
g_strength.Calculate();
ulong elapsed = GetMicrosecondCount() - t0;
g_logger.Debug(StringFormat("CurrencyStrength: %.2f ms", elapsed / 1000.0));
```

`Inp_EnableProfiling = true` のときのみ計測コードを走らせる（**推奨**）。計測自体が負荷にならないようにする。

### 32.3 負荷を作らないための実装規約

| 規約 | 理由 |
|---|---|
| 毎ティック全銘柄を再計算しない | `GetTickCount()` で前回実行時刻を記録し、指定間隔を超えたときだけ計算する |
| オブジェクトは作り直さず更新する | `ObjectDelete`→`ObjectCreate` の繰り返しはちらつきと負荷の原因。`ObjectFind` で存在確認し、あれば `ObjectSetString` / `ObjectSetInteger` で更新 |
| 全シンボルループは起動時1回だけ | 26.13 |
| 値が変わっていないなら描画しない | 前回値を保持し、差分のみ更新 |
| `CopyClose` の呼び出し回数を最小化 | 1エンジンにつき1銘柄1回。使い回す |
| 文字列連結をループ内で多用しない | MQL5の文字列操作は相対的に重い |

### 32.4 週末・市場休止中の挙動

新しいティックが来ないため、ティック駆動の処理は走らない。カウントダウン等の時刻依存表示は `OnTimer()` で更新し、**価格更新に依存しない部分を必ず分離する**。

---

## 33. Release Checklist（リリースチェックリスト）

各バージョンをリリースする前に、以下をすべて満たしていることを確認する。チェックが1つでも欠けている場合はリリースしない。

### 33.1 コード

- [ ] コンパイル警告0（エラーは当然0）
- [ ] `Print()` の直接呼び出しが残っていない（`CLogger` 経由に統一）
- [ ] デバッグ用のコメントアウトコード・仮の数値が残っていない
- [ ] すべての `.mqh` 冒頭に役割コメントがある（23章）
- [ ] 命名規約（`Inp_` / `g_` / `m_` / `C` / `S`）に違反がない

### 33.2 動作

- [ ] 27.4 の E1・E3・E6・E7 を実行済み
- [ ] `OnDeinit()` 後にチャートにオブジェクトが残らない
- [ ] 表示モード4種すべてで表示崩れがない
- [ ] 32.1 の性能目標を満たしている
- [ ] 24時間以上の連続稼働を確認済み

### 33.3 ドキュメント

- [ ] 本仕様書のバージョン履歴（17章）を更新した
- [ ] `CHANGELOG.md` に変更点を記載した
- [ ] `ROADMAP.md` の該当項目にチェックを入れた
- [ ] 新しい入力パラメータを21章に追記した
- [ ] 未解決の問題を34章（Known Limitations）に記載した

### 33.4 リリース作業

- [ ] Gitタグを打つ（`v2.11.0` 形式）
- [ ] `.ex5` をビルドして動作確認
- [ ] 設定ファイル（`.set`）の既定値を確認

---

## 34. Known Limitations（既知の制約）

隠さず明記する。制約を書いてあるドキュメントの方が信頼される。

| # | 制約 | 理由 | 回避策 | 解消予定 |
|---|---|---|---|---|
| L1 | 債券（US10Y / US30Y）は多くの国内FX業者で取得できない | ブローカーが提供していない | Unavailable表示で継続。重み再配分で吸収 | 未定（ブローカー依存） |
| L2 | VIX・DXYも同様に非対応環境が多い | 同上 | 同上 | 未定 |
| L3 | 通貨強弱は8通貨・28ペアに固定 | 計算量と表示領域の制約 | — | Ver3.00で拡張検討 |
| L4 | 経済指標カレンダーのデータソースが未確定 | MT5標準カレンダーはブローカーにより内容が異なる | 手動登録で暫定運用 | Ver2.30 |
| L5 | サマータイム境界の自動判定は完全ではない | サーバー時間の扱いがブローカーごとに異なる | オフセットを入力パラメータ化 | Ver2.30 |
| L6 | 複数チャート同時起動時、キャッシュ書き込みは1チャートのみ | ファイル競合の回避 | 2枚目以降は読み取り専用 | 検討中（28.2 D） |
| L7 | バックテスト（ストラテジーテスター）では正しく動作しない | 他銘柄のデータ取得がテスターでは制限される | リアルタイム稼働専用として扱う | 非対応の方針 |
| L8 | 表示は英語のみ | 実装の単純化 | — | Ver2.30で日本語表示を検討 |
| L9 | Ver2.11では起動のたびに全銘柄を再検出する | L2キャッシュ（CSV永続化）が未実装（26.0） | 起動が0.3〜0.5秒遅いだけ。稼働中はL1で解決済み | Ver2.20 |
| L10 | Ver2.11ではPENDINGの自動再試行を行わない | Retry未実装（26.0） | 手動Refreshで再検出 | Ver2.20 |
| L11 | Ver2.11の検出対象は8資産 + FX28ペアのみ | 消費するエンジンがVer2.20のため | — | Ver2.20 |
| L12 | アノマリーの点数と星は統計検証していない | 公開研究と経験則に基づく初期値（10.11.1） | 「仮の重み」として扱う。`SetSeasonScore()` と `SetRuleEnabled()` で上書き可能 | Ver3.00で実データ検証 |
| L13 | 五十日の月をまたぐ営業日繰り上げは未対応 | 月末が日曜で決済が前月末金曜になる場合を扱っていない | 該当は年数回。判定の複雑さに対して効果が小さい | Ver2.20 |
| L14 | 経済指標系アノマリー（FOMC前・CPI前・雇用統計前・連休前）は未実装 | `CalendarValueHistory()` がブローカー依存で使えない環境がある | 規則表に登録済み。`implemented` を立てるだけで有効化できる | Ver2.20 |

---

## 35. ドキュメント体系とリポジトリ構成

本プロジェクトは「1本のインジケーター」ではなく1つのソフトウェアプロジェクトとして扱う。したがって、コード以外の文書も同じリポジトリで管理する。

### 35.1 リポジトリ構成

```text
GlobalMarketDashboard/
├── README.md                 // プロジェクトの顔。概要・スクリーンショット・導入手順
├── CHANGELOG.md              // バージョンごとの変更履歴
├── ROADMAP.md                // 25章の抜粋。進捗チェックボックス付き
├── LICENSE
├── docs/
│   ├── SPECIFICATION.md      // 本書
│   ├── USER_MANUAL.md        // 利用者向け。設定項目と画面の見方
│   ├── DEVELOPER_GUIDE.md    // 開発者向け。ビルド手順とモジュール解説
│   └── images/               // スクリーンショット・図
├── src/
│   ├── GlobalMarketDashboard.mq5
│   └── Modules/
│       ├── Core/
│       ├── Engines/
│       └── Display/
└── tests/
    └── Test_AssetDetection.mq5 ほか
```

### 35.2 各文書の役割分担

| 文書 | 読者 | 内容 | 更新タイミング |
|---|---|---|---|
| `README.md` | 初めて見る人 | 何ができるか・導入方法 | 機能追加時 |
| `SPECIFICATION.md`（本書） | 開発者・将来の自分 | 仕様の唯一の正 | 設計変更時 |
| `USER_MANUAL.md` | 利用者 | 設定と画面の見方 | UI変更時 |
| `DEVELOPER_GUIDE.md` | 開発者 | ビルド・モジュール追加手順 | 構成変更時 |
| `CHANGELOG.md` | 全員 | 変更履歴 | リリースごと |
| `ROADMAP.md` | 全員 | 今後の予定と進捗 | 計画変更時 |

### 35.3 バージョン番号の規約

```text
Ver <メジャー>.<マイナー><パッチ>
     2   .   11
```

| 位置 | 上げる条件 |
|---|---|
| メジャー | 設計思想・アーキテクチャの大変更 |
| マイナー | 機能追加（新エンジン・新パネル） |
| パッチ | バグ修正・調整のみ |

仕様書のバージョンは、ソフト本体とは独立して `v1.0` `v1.1` … と進める（35.4）。本体のリリースと仕様書のバージョンを一致させようとしないこと。文書は実装より先に進むことも後から追いつくこともあり、無理に同期させると更新されなくなる。

### 35.4 仕様書の育て方

本書を「完成させる」ことを目標にしない。**実装しながら更新し続ける文書**として扱う。

```text
v1.0 Draft  設計を一通り書き切った状態
    ↓  実装者レビューを反映（スコープ調整）
v1.1        ← 現在地
    ↓  Ver2.11 実装で判明した現実を反映
v1.2        テスト計画の確定・エラーコードの実績反映
    ↓  Ver2.11 リリース
v1.3        Known Limitations の更新
    ↓  Ver2.20（Money Flow / Market Regime / Cache）
v2.0        アーキテクチャ変更を伴う改訂
```

更新のルールは3つだけとする。

| ルール | 内容 |
|---|---|
| 実装が仕様と違ったら、**仕様書を直す** | コード側を無理に仕様へ合わせない。実装のほうが正しいことが多い |
| 章は消さず、**フェーズ表記を変える** | 「やらないことにした」も記録として価値がある |
| 更新したら17章のバージョン履歴に**1行足す** | 何をいつ変えたかが追えなくなるのを防ぐ |

「コードを書いたら仕様が変わった」は失敗ではなく、設計が現実と接続された証拠である。

### 35.5 CHANGELOG の書式

```markdown
## [2.11.0] - 2026-XX-XX
### Added
- Core/AssetDetection.mqh：銘柄自動検出（Detect/Validation/Availability/Cache）
- Currency Strength Engine（8通貨・28ペア・N本重み付き集計）
### Changed
- Asset Detection を Ver2.20 から Ver2.11 へ前倒し
### Fixed
- （該当なし：初回リリース）
### Known Issues
- 債券未対応環境では Bond行が Unavailable（仕様書 L1）
```

---

## 付録A. `Core/AssetDetection.mqh` 実装スケルトン

以下は26章の仕様をそのままコードの骨格に落としたものである。Step 1（26.15）はこのとおり貼り付けてコンパイルを通すところから始める。

```cpp
//+------------------------------------------------------------------+
//|                                              AssetDetection.mqh  |
//|  Global Market Dashboard Ultimate                                |
//|  役割：ブローカー固有の銘柄名を検出・検証・キャッシュし、        |
//|        各Engineに確定した銘柄名を提供する（仕様書26章）          |
//+------------------------------------------------------------------+
#property strict

//==================================================================
// 1. 定義（仕様書 26.3 / 26.4）
//==================================================================
enum ENUM_ASSET_ID
{
   //--- [2.11] 実装対象
   ASSET_GOLD=0, ASSET_SILVER,
   ASSET_US30, ASSET_NAS100, ASSET_SPX500, ASSET_JP225,
   ASSET_BTC, ASSET_ETH,

   //--- [2.20] 追加枠（コメントを外すだけで有効化できる）
   // ASSET_GER40, ASSET_UK100,
   // ASSET_US10Y, ASSET_US30Y,
   // ASSET_DXY,   ASSET_VIX,

   ASSET_COUNT
};

enum ENUM_ASSET_STATE
{
   ASSET_UNKNOWN=0, ASSET_OK, ASSET_PENDING, ASSET_STALE, ASSET_UNAVAILABLE
};

enum ENUM_ASSET_CATEGORY { CAT_FX=0, CAT_METAL, CAT_INDEX, CAT_CRYPTO, CAT_BOND, CAT_OTHER };

struct SAssetInfo
{
   ENUM_ASSET_ID       id;
   ENUM_ASSET_CATEGORY category;
   string              logicalName;
   string              symbol;
   ENUM_ASSET_STATE    state;
   int                 digits;
   int                 barsAvailable;
   datetime            lastTickTime;
   datetime            detectedAt;
   int                 retryCount;
   string              note;
};

struct SFxPair
{
   string base, quote, symbol;
   bool   inverted, available;
};

//==================================================================
// 2. クラス本体
//==================================================================
class CAssetDetection
{
private:
   SAssetInfo  m_assets[ASSET_COUNT];
   SFxPair     m_fx[28];
   int         m_fxCount;
   string      m_allSymbols[];      // 全銘柄キャッシュ（ループは1回だけ）
   int         m_allSymbolsTotal;
   string      m_suffix, m_prefix;
   datetime    m_builtAt;
   bool        m_ready;

   //--- 内部ヘルパー
   void        LoadAllSymbols(void);
   void        DetectAffixes(void);                    // 26.6.2
   bool        DetectOne(ENUM_ASSET_ID id, string &cands[]);
   bool        Validate(SAssetInfo &a);                // 26.7
   void        DetectFxPairs(void);                    // 26.6.4
   string      MakeCacheFileName(void);                // 26.9.2

public:
                     CAssetDetection(void);
                    ~CAssetDetection(void);

   bool              Init(void);
   bool              DetectAll(void);
   void              RetryPending(void); // [2.20]
   void              Refresh(void);
   void              Deinit(void);

   bool              LoadCache(void);   // [2.20]
   bool              SaveCache(void);   // [2.20]

   string            GetSymbol(ENUM_ASSET_ID id);
   bool              IsAvailable(ENUM_ASSET_ID id);
   ENUM_ASSET_STATE  GetState(ENUM_ASSET_ID id);
   string            GetStateText(ENUM_ASSET_ID id);

   int               GetFxPairCount(void) { return m_fxCount; }
   bool              ResolvePair(string c1, string c2, string &outSym, bool &inverted);

   string            FindFirstExisting(string &candidates[]);
   string            NormalizeSymbolName(string raw);

   int               CountByState(ENUM_ASSET_STATE st);
   string            BuildSummaryText(void);
};

//------------------------------------------------------------------
// GetSymbol : 失敗しても空文字列を返す（絶対に落ちない）
//------------------------------------------------------------------
string CAssetDetection::GetSymbol(ENUM_ASSET_ID id)
{
   if(id < 0 || id >= ASSET_COUNT) return "";
   if(m_assets[id].state == ASSET_OK || m_assets[id].state == ASSET_STALE)
      return m_assets[id].symbol;
   return "";
}

//------------------------------------------------------------------
// FindFirstExisting : 優先順に実在確認（仕様書 26.6.3 第1段）
//   ※ Best Pair Engine もこの関数を使うこと（10.2）
//------------------------------------------------------------------
string CAssetDetection::FindFirstExisting(string &candidates[])
{
   int n = ArraySize(candidates);
   for(int i=0; i<n; i++)
   {
      string variants[3];
      variants[0] = candidates[i];
      variants[1] = candidates[i] + m_suffix;
      variants[2] = m_prefix + candidates[i] + m_suffix;

      for(int v=0; v<3; v++)
      {
         if(StringLen(variants[v]) == 0) continue;
         if(SymbolInfoInteger(variants[v], SYMBOL_EXIST))
            return variants[v];
      }
   }
   return "";   // 見つからなくてもエラーにしない
}

//------------------------------------------------------------------
// Validate : 4ゲート検証（仕様書 26.7）
//------------------------------------------------------------------
bool CAssetDetection::Validate(SAssetInfo &a)
{
   if(StringLen(a.symbol) == 0)
   { a.state = ASSET_UNAVAILABLE; a.note = "AD-001 not found"; return false; }

   // Gate 1 : Market Watch 登録
   if(!SymbolSelect(a.symbol, true))
   { a.state = ASSET_UNAVAILABLE; a.note = "AD-002 select failed"; return false; }

   // Gate 2 : 同期確認
   if(!SymbolIsSynchronized(a.symbol))
   { a.state = ASSET_PENDING; a.note = "AD-003 not synchronized"; return false; }

   // Gate 3 : 気配値
   MqlTick tick;
   if(!SymbolInfoTick(a.symbol, tick) || tick.bid <= 0.0)
   { a.state = ASSET_PENDING; a.note = "AD-005 no valid tick"; return false; }

   // Gate 4 : ヒストリー本数
   int bars = Bars(a.symbol, _Period);
   if(bars < Inp_ValidationMinBars)
   { a.state = ASSET_PENDING; a.note = "AD-004 bars=" + IntegerToString(bars); return false; }

   a.barsAvailable = bars;
   a.lastTickTime  = tick.time;
   a.digits        = (int)SymbolInfoInteger(a.symbol, SYMBOL_DIGITS);
   a.detectedAt    = TimeCurrent();

   // 鮮度チェック
   if((TimeCurrent() - tick.time) > Inp_ValidationMaxAgeSec)
   { a.state = ASSET_STALE; a.note = "AD-006 stale data"; return true; }

   a.state = ASSET_OK;
   a.note  = "";
   return true;
}

//--- グローバルインスタンス（規約：g_ プレフィックス・23章）
CAssetDetection g_assets;
```

> 上記は骨格であり、`DetectAll()` / `LoadCache()` / `SaveCache()` / `DetectFxPairs()` の中身は26.15のStep順に埋めていく。このファイルだけは他モジュールに一切依存させない（Loggerを除く）ことで、単体テストが可能になる。

---

## 付録B. 共通データ構造リファレンス

本書に登場する列挙型・構造体・インターフェースを1箇所に集約したものである。**これらはすべて `Core/Types.mqh` に置き、各モジュールはこのファイルだけをインクルードする。** 型定義が複数ファイルに散らばると、後から必ず二重定義とコンパイルエラーの原因になる。

```cpp
//+------------------------------------------------------------------+
//|                                                       Types.mqh  |
//|  GMD共通型定義。すべてのモジュールがこれをインクルードする         |
//+------------------------------------------------------------------+
#property strict

//========================= アセット関連 ============================
enum ENUM_ASSET_ID
{
   //--- [2.11] 実装対象
   ASSET_GOLD=0, ASSET_SILVER,
   ASSET_US30, ASSET_NAS100, ASSET_SPX500, ASSET_JP225,
   ASSET_BTC, ASSET_ETH,

   //--- [2.20] 追加枠（コメントを外すだけで有効化できる）
   // ASSET_GER40, ASSET_UK100,
   // ASSET_US10Y, ASSET_US30Y,
   // ASSET_DXY,   ASSET_VIX,

   ASSET_COUNT
};

enum ENUM_ASSET_STATE     { ASSET_UNKNOWN=0, ASSET_OK, ASSET_PENDING, ASSET_STALE, ASSET_UNAVAILABLE };
enum ENUM_ASSET_CATEGORY  { CAT_FX=0, CAT_METAL, CAT_INDEX, CAT_CRYPTO, CAT_BOND, CAT_OTHER };

//========================= エンジン出力 ============================
enum ENUM_FLOW_STATE
{
   FLOW_STRONG_OUTFLOW=-2, FLOW_OUTFLOW=-1, FLOW_NEUTRAL=0,
   FLOW_INFLOW=1, FLOW_STRONG_INFLOW=2, FLOW_UNAVAILABLE=99
};

enum ENUM_REGIME            { REGIME_RISK_OFF=-1, REGIME_NEUTRAL=0, REGIME_RISK_ON=1 };
enum ENUM_CONFIDENCE_LEVEL  { CONF_LOW=0, CONF_MEDIUM, CONF_HIGH };
enum ENUM_TRADE_DIRECTION   { DIR_NONE=0, DIR_BUY=1, DIR_SELL=-1 };

//========================= システム ================================
enum ENUM_LOG_LEVEL   { LOG_OFF=0, LOG_ERROR, LOG_WARN, LOG_INFO, LOG_DEBUG };
enum ENUM_DISPLAY_MODE{ MODE_CHART=0, MODE_DASHBOARD, MODE_HYBRID, MODE_MINIMAL };

//========================= 構造体 ==================================
struct SAssetInfo
{
   ENUM_ASSET_ID       id;
   ENUM_ASSET_CATEGORY category;
   string              logicalName;
   string              symbol;
   ENUM_ASSET_STATE    state;
   int                 digits;
   int                 barsAvailable;
   datetime            lastTickTime;
   datetime            detectedAt;
   int                 retryCount;
   string              note;
};

struct SFxPair
{
   string  base, quote, symbol;
   bool    inverted, available;
};

struct SAssetRegistry
{
   SAssetInfo  assets[ASSET_COUNT];
   SFxPair     fxPairs[28];
   int         fxPairCount;
   string      detectedSuffix;
   string      detectedPrefix;
   datetime    builtAt;
   int         okCount;
   int         unavailableCount;
};

//========================= インターフェース ========================
interface IEngine
{
   bool    Calculate(void);
   bool    IsReady(void);
   string  GetName(void);
};
```

### B.1 型の使い分け早見表

| 場面 | 使う型 | 使ってはいけない書き方 |
|---|---|---|
| アセットを指定する | `ENUM_ASSET_ID` | `"XAUUSD"` などの文字列リテラル |
| 銘柄名を取得する | `GetSymbol(ASSET_GOLD)` | `_Symbol` の直接加工 |
| 可用性を判定する | `IsAvailable(id)` | `SymbolInfoInteger()` の直接呼び出し |
| フロー方向を返す | `ENUM_FLOW_STATE` | `int` の +1 / -1 |
| 色を返す | `GetFlowColor()` 等のgetter | Display側での色分岐のハードコード |

### B.2 インクルード順序

```cpp
#include "Core/Types.mqh"          // 1. 型（依存なし）
#include "Core/Logger.mqh"         // 2. ログ
#include "Core/Utils.mqh"          // 3. 汎用関数
#include "Core/AssetDetection.mqh" // 4. 銘柄検出
#include "Engines/..."             // 5. 各エンジン
#include "Display/..."             // 6. 表示
```

この順序を守る。逆順や相互インクルードは循環参照を生む。

---

以上、Project Specification v1.3 として改訂した。

**本書の大幅な改訂はここで一区切りとする。** これ以降は実装を主軸に置き、仕様書はコードとの差分が出た箇所だけを更新する。

本書は完成版ではなく、実装しながら育てる文書である（35.4）。Ver2.11の実装で判明したことを反映して `v1.2` に更新する。

次のステップは、**付録Bの `Core/Types.mqh` を作ってコンパイルを通す**こと。これが26.15のStep 1にあたる。そこからStep 9までを一直線に進め、AssetDetectionのCache・Retryには手を付けずにCurrency Strength Engineへ移る。

