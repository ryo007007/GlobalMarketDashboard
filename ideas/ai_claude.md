[GlobalMarketDashboard_仕様書_v1.0_Draft.md](https://github.com/user-attachments/files/30700075/GlobalMarketDashboard_._v1.0_Draft.md)
# 🌐 Global Market Dashboard Ultimate Edition
> Integrated Market Analysis Platform for MetaTrader 5

---

## 📌 Project Metadata

| Item | Details |
|---|---|
| Project Name | Global Market Dashboard Ultimate |
| Platform | MetaTrader 5 (MT5) |
| Language | MQL5 |
| Repository | `GlobalMarketDashboard` |
| Current Version | `2.11 Ultimate` (Development) |
| **Document Version** | **Project Specification v1.0 Draft** |
| Author | Ryoutarou Kadono |
| Status | In Development |

### 改訂履歴
| Version | 内容 |
|---|---|
| v0.1 | 初版。理念・各エンジン概要・モジュール構成・ロードマップ |
| v0.2 | 重複章の統合、各エンジンの計算式明文化、実装上の落とし穴と対策、テスト計画・未確定事項を追加 |
| v0.3 | Asset Detection Flow（5段階パイプライン）、Risk Score区分表、Confidence寄与率、Money Flow Liquidity Score定義を追加 |
| **v1.0 Draft（本書）** | 各エンジンを **Purpose / Inputs / Calculation / Output / Display / Future Expansion** の統一構成に再編。クラス設計（メソッドシグネチャ）を明記。Class Diagram・Data Flow・Error Handling・Performance Benchmark・Test Plan・Release Checklist・Known Limitationsを新設 |

> Ver2.11の実装が完了し、実機での動作確認が取れた時点で、本書は**Project Specification v1.0**（Draft外し）に昇格する。

---

## 1. Project Overview & Philosophy

### 1.1 ビジョン
単なるMT5用インジケーターではなく、FX・株式・Gold・暗号資産・債券をクロスアセットで統合分析し、**市場全体の資金循環（マネーフロー）を1画面で可視化する統合マーケット分析プラットフォーム**を目指す。

> 「相場を見る」のではなく「世界のお金の流れを見る」
> 市場の状態そのものを数値化するMarket Analytics Engineである。

### 1.2 開発目的
1. 複数市場の状態を1画面で同時に把握できるようにする
2. 通貨強弱・資金フロー・リスクオン/オフを定量化し、裁量判断の根拠を数値で補強する
3. 手動でのチャート切替・指標見比べの手間を削減する
4. 将来の統計・相関分析・機械学習拡張に耐えるモジュール構成にする

### 1.3 設計思想
- **1画面完結**：チャート切替なしで市場全体を把握できること
- **数値化優先**：「なんとなく」ではなくスコア・％で根拠を残すこと
- **軽量であること**：多数銘柄・多数指標を同時に扱うため、CPU負荷とオブジェクト数を常に意識する（7章・16章参照）
- **壊れにくいこと**：ブローカーごとの表記差、週末のデータ欠損、銘柄非対応を前提に設計する（4章・31章参照）

---

## 2. System Architecture & Flow

### 2.1 全体処理パイプライン

```text
               [ Data Layer ]
         Asset Detection (自動判定・キャッシュ)
                    │
                    ▼
            [ Analysis Layer ]
 ┌──────────────────────────────────────┐
 │ 1. Currency Strength Engine           │
 │ 2. Market Regime Engine (Risk Score)  │
 │ 3. Money Flow Engine                  │
 │ 4. Confidence Engine                  │
 │ 5. Best Pair Engine                   │
 └──────────────────┬─────────────────────┘
                    │
                    ▼
          [ Presentation Layer ]
 ┌──────────────────────────────────────┐
 │ Dashboard UI / Multi-Panel Display    │
 └──────────────────────────────────────┘
```

### 2.2 レイヤーの責務分離（重要原則）
- **Data Layer**（Core/AssetDetection.mqh）：銘柄の存在確認・正規化・キャッシュのみを担当し、分析ロジックを持たない
- **Analysis Layer**（Engines/）：各`Calculate()`は**計算結果だけ**を返し、描画処理を持たない
- **Presentation Layer**（Display/）：Engineを**呼び出すだけ**で、独自の計算ロジックを持たない

この分離により、将来Engineを差し替えたり、UIだけ作り直したりする際の影響範囲を最小化する。

---

## 3. Core Engine Detailed Specifications

各エンジンは以下の統一フォーマットで記述する：**Purpose / Inputs / Calculation / Output / Display / Future Expansion**

---

### 3.1 🔀 Currency Strength Engine（`CCurrencyStrength`）

#### Purpose
主要7通貨の相対的な強弱関係を、実際の値動きから定量化する。

#### Inputs
| 項目 | 型 | 説明 |
|---|---|---|
| `InpStrengthTimeframe` | ENUM_TIMEFRAMES | 判定に使う時間足（既定 M1） |
| `InpSymmetricScoring` | bool | 対称加点方式（上昇+1/下降-1）を使うか。falseなら非対称（勝った側のみ+1） |
| 対象通貨 | string[7] | USD, EUR, JPY, GBP, CHF, AUD, CAD（固定） |
| 対象ペア | string[28] | 上記7通貨の組み合わせで作れる全28ペア（Asset Detectionで実在確認済みのもののみ使用） |

#### Calculation
1. 各ペアについて、`InpStrengthTimeframe`の**直近確定足**（形成中の最新足は除く）の始値・終値を取得
2. 終値 > 始値 → 分子（ベース通貨）に+1点、`InpSymmetricScoring=true`なら分母に-1点
3. 終値 < 始値 → 分母（クオート通貨）に+1点、`InpSymmetricScoring=true`なら分子に-1点
4. 7通貨のスコアを合算し、降順にソートして順位を確定

#### Output
| 項目 | 型 | 説明 |
|---|---|---|
| `Score[7]` | double | 通貨ごとの合計スコア |
| `Rank[7]` | int | 1位〜7位の順位 |
| `ValidPairCount` | int | 実際に計算に使えたペア数（28ペア中）。Confidence Engineへの入力にもなる |

#### Display
- 横並び1行で1位〜7位を表示（縦積みは画面を圧迫するため非推奨）
- 色分けは既定OFFも可（`InpUseStrengthColor`）。ONの場合は最強=赤系、最弱=青系のグラデーション
- `ValidPairCount < 20`の場合は「データ不足」の注意書きを表示

#### Future Expansion（Ver2.20〜）
- 通貨ペアごとの重み付け（流動性の高いペアを重視 等）
- ATR・ボラティリティを加味したスコアリング

#### クラス設計
```mql5
class CCurrencyStrength
{
public:
   bool   Initialize(ENUM_TIMEFRAMES tf, bool symmetric);
   void   Calculate();               // 毎更新サイクルで呼ぶ
   int    GetRank(string currency);  // 1〜7を返す
   double GetScore(string currency);
   int    GetValidPairCount();
   void   Draw(int x, int y);        // Display層から呼ばれる場合のみ使用
};
```

---

### 3.2 🌊 Money Flow & Liquidity Engine（`CMoneyFlow`）

#### Purpose
FX以外の主要アセット（株価指数・貴金属・暗号資産・債券）間の資金流出入と、機関投資家の「現金化圧力」を判定する。

#### Inputs
| 項目 | 型 | 説明 |
|---|---|---|
| `InpFlowLookbackBars` | int | 変化率算出に使う本数 |
| `InpFlowThresholdPct` | double | ↑/↓と判定する変化率のしきい値（％、例：0.3） |
| 対象アセット | string[] | 株価指数、Gold、Silver、暗号資産、債券（Asset Detectionで解決済みの銘柄） |

#### Calculation
1. 各アセットについて、直近`InpFlowLookbackBars`本の**変化率（％）**を算出（価格差そのものではなく％で正規化。株価指数とGoldは桁が違うため必須）
2. 変化率 ≥ `+InpFlowThresholdPct` → ↑（資金流入）
3. 変化率 ≤ `-InpFlowThresholdPct` → ↓（資金流出）
4. それ以外 → →（中立）
5. 変化率の大きさに応じて↑↑（強い流入）／↓↓（強い流出）の2段階表示にも対応

#### Liquidity Score（現金化圧力の判定）
| パターン | 判定 |
|---|---|
| `Gold↑` + `Bond↑` + `JPY↑` + `VIX↑` | **Cash Preference**（現金化圧力の急増） |
| `Stocks/NASDAQ↑` + `Crypto/BTC↑` + `Gold↓` + `JPY↓` | **Risk-Seeking**（リスク資産への資金流入） |

> 上記2パターンは代表例であり、実装時には各条件の一致数に応じたスコア化（例：4条件中何個一致したか）にすることを推奨する。

#### Output
| 項目 | 型 | 説明 |
|---|---|---|
| `FlowDirection[]` | int (-2〜+2) | アセットごとの流入/流出方向 |
| `LiquidityState` | enum | `CASH_PREFERENCE` / `RISK_SEEKING` / `NEUTRAL` |

#### Display
- ↑↑/↑（緑）、→（灰）、↓/↓↓（赤）の記号で一覧表示

#### Future Expansion（Ver2.20〜）
- アセット間の相関係数を加味した資金ローテーション分析

#### クラス設計
```mql5
class CMoneyFlow
{
public:
   bool  Initialize(int lookbackBars, double thresholdPct);
   void  Calculate();
   int   GetFlowDirection(string assetName); // -2..+2
   int   GetLiquidityState();                // enum
};
```

---

### 3.3 🛡️ Market Regime Engine（`CMarketRegime`）

#### Purpose
マクロ市場9指標から総合的なリスクセンチメントを測定し、Risk Score(0〜100)を算出する。

#### Inputs
| 項目 | 型 | 説明 |
|---|---|---|
| 指標 | string[9] | SP500, NASDAQ, US10Y, Gold, USDJPY, BTC, ETH, VIX, DXY |
| `InpRegimeWeights[9]` | double[] | 各指標の重み（初期値は経験則、将来Ver4.00で最適化） |

#### Calculation
```
Score = Σ( 指標iの標準化変化率 × 重みi )
```
- 各指標を直近N本の変化率に変換し、Z-score等で標準化（単位を揃える）
- 株式・BTC・ETHの上昇、VIX・US10Yの低下 → 正の重み（Risk ON方向）
- VIX・US10Yの上昇、Goldの急騰（安全資産への逃避） → 負の重み（Risk OFF方向）
- 合成スコアを0〜100にスケーリング

#### Risk Score 区分テーブル
| Score | Status | 判定テキスト | 市場状況 |
|---|---|---|---|
| 80–100 | 🔥 Strong Risk ON | 強いリスクオン | 株・クリプト急騰、安全資産（円・金）売却 |
| 60–79 | 🟢 Risk ON | リスクオン | リスク資産選好、トレンド継続 |
| 40–59 | ⚪ Neutral | 中立・レンジ | 銘柄間で強弱拮抗、方向感なし |
| 20–39 | 🔴 Risk OFF | リスクオフ | リスク資産売却、安全資産へ避難 |
| 0–19 | ❄️ Strong Risk OFF | 強いリスクオフ | 全面リスク回避・パニック・現金化の進行 |

#### Output
| 項目 | 型 | 説明 |
|---|---|---|
| `RiskScore` | double (0-100) | 総合スコア |
| `RiskStatus` | enum | 上記5区分 |

#### Display
- スコアとステータステキストをダッシュボード上部に表示

#### Future Expansion（Ver3.00〜）
- 重みの動的最適化（相関分析・機械学習）

#### クラス設計
```mql5
class CMarketRegime
{
public:
   bool   Initialize(double &weights[]);
   void   Calculate();
   double GetRiskScore();
   int    GetRiskStatus(); // enum
};
```

---

### 3.4 🎯 Confidence Engine（`CConfidence`）

#### Purpose
各エンジンの判定結果を寄与率で合算し、現在の相場環境に対する総合確信度（0〜100%）を算出する。

#### Inputs
| 項目 | 型 | 説明 |
|---|---|---|
| `InpWeightStrength` | double | Currency Strength一致率の寄与率（既定40%） |
| `InpWeightFlow` | double | Money Flowの寄与率（既定30%） |
| `InpWeightRegime` | double | Market Regimeの寄与率（既定20%） |
| `InpWeightMomentum` | double | Momentumの寄与率（既定10%） |

#### Calculation
```
Confidence(%) = ( StrengthScore×0.40 + FlowScore×0.30 + RegimeScore×0.20 + MomentumScore×0.10 )
```
- 各エンジンの出力を0〜100に正規化してから加重平均する
- いずれかのエンジンのデータが取得できない場合（例：債券データ取得不可）、そのエンジンの重みを**他のエンジンへ按分して再配分**するフォールバックを実装する（重み合計は常に100%を維持）

#### Output
| 項目 | 型 | 説明 |
|---|---|---|
| `ConfidencePct` | double (0-100) | 総合確信度 |
| `WeightBreakdown[]` | double[] | 実際に使われた寄与率の内訳（フォールバック再配分後） |

#### Display
- 例：`Confidence 91%`

#### Future Expansion（Ver4.00〜）
- 過去のシグナルとその後の値動きを検証し、寄与率を自動調整（学習）

#### クラス設計
```mql5
class CConfidence
{
public:
   bool   Initialize(double wStrength, double wFlow, double wRegime, double wMomentum);
   void   Calculate(CCurrencyStrength &cs, CMoneyFlow &mf, CMarketRegime &mr, double momentumScore);
   double GetConfidence();
};
```

---

### 3.5 🏆 Best Pair Engine（`CBestPair`）

#### Purpose
最強通貨・最弱通貨を組み合わせ、最もトレンドが出やすい通貨ペアを自動抽出する。

#### Inputs
| 項目 | 型 | 説明 |
|---|---|---|
| Currency Strength Engineの出力 | - | 最強通貨・最弱通貨 |

#### Calculation（実装上の必須手順）
1. `最強通貨+最弱通貨`（例：USDJPY）が実在するか`SymbolInfoInteger(symbol, SYMBOL_EXIST)`で確認
2. 存在しなければ逆順（`最弱通貨+最強通貨`）を試す
3. どちらも存在しなければ「該当ペアなし」とする
4. 逆順を採用した場合、**方向の解釈も反転する**ことを記録する（強い通貨が分母に来るため）

#### Output
| 項目 | 型 | 説明 |
|---|---|---|
| `BestPairSymbol` | string | 実在する銘柄名（例：EURJPY） |
| `IsReversed` | bool | 逆順採用フラグ |
| `Direction` | int | 想定方向（+1=上昇想定、-1=下降想定） |

#### Display
- 例：`Best Pair EURJPY`。**クリックでそのチャートに遷移**できるようにする（利便性が大きく向上する）

#### Future Expansion（Ver2.20〜）
- 2位・3位の候補ペアも合わせて表示

#### クラス設計
```mql5
class CBestPair
{
public:
   void   Calculate(CCurrencyStrength &cs, CAssetDetection &ad);
   string GetSymbol();
   bool   IsReversed();
   int    GetDirection();
};
```

---

## 4. Asset Detection Specifications（`CAssetDetection`）

### 4.1 Purpose
ブローカーごとの銘柄表記揺れ（シンボル名）を自動判定・正規化し、全エンジン共通のフォーマットでデータを提供する。

### 4.2 Symbol Priority（優先順位リスト）
| カテゴリ | 優先順位 |
|---|---|
| Gold | `XAUUSD` → `GOLD` → `GOLDmicro` → `GOLD.r` → `XAUUSD.a` |
| Equity Index | `SPX500` / `US500` / `US30` / `NAS100` / `JP225` / `GER40` / `UK100` |
| Crypto | `BTCUSD` / `BTCUSDT` / `ETHUSD` |
| Bond | `US10Y` / `US30Y` |

この優先順位リストは、Best Pair Engine（3.5章）とも共通化し、`Core/AssetDetection.mqh`内の汎用関数に1箇所だけ実装する（重複実装を避ける）。

### 4.3 Asset Detection Flow（5段階パイプライン）

```text
[ Terminal 起動 / OnInit ]
           │
           ▼
   1. Symbol Scan (ブローカー提供銘柄の一括検索)
           │
           ▼
   2. Detection (カテゴリ別エイリアス照合)
      (Gold / Index / Crypto / Bond)
           │
           ▼
   3. Validation (データ取得可能性の検証)
           │
           ▼
   4. Availability (非対応銘柄のステータス割り当て)
           │
           ▼
   5. Cache (検索結果のメモリ保持)
           │
           ▼
 [ Analysis Engine へ参照引き渡し ]
```

#### 段階別詳細
1. **Symbol Scan**：`SymbolsTotal()`等でブローカーが提供する全銘柄を一括取得
2. **Detection**：優先順位リスト（4.2章）と照合し、カテゴリごとに候補銘柄を特定
3. **Validation**：検出した銘柄が`SymbolInfoDouble()`等で実際に価格を取得できるか検証する。ヒストリーデータが0本の銘柄（実質的に取引されていない銘柄）もここで弾く
4. **Availability**：取引不可・データ取得不可の銘柄は、システムを停止させず **`Unavailable`フラグ**を立てて処理をスキップする。UI上は「N/A」等で安全に表示する
5. **Cache**：検出結果を構造体配列としてメモリに保持する。毎ティックの再検索処理を排除し、パフォーマンスを向上させる（キャッシュは`OnInit`時、または銘柄リスト変更時にのみ再構築する）

### 4.4 Output
| 項目 | 型 | 説明 |
|---|---|---|
| `ResolvedSymbol[category]` | string | カテゴリごとの実銘柄名 |
| `Availability[category]` | enum | `AVAILABLE` / `UNAVAILABLE` |

### 4.5 クラス設計
```mql5
class CAssetDetection
{
public:
   bool   Initialize();                       // OnInitで1度だけ呼ぶ（Symbol Scan〜Cacheまで実行）
   string Resolve(string category);            // キャッシュから解決済み銘柄名を返す
   bool   IsAvailable(string category);
   void   Rebuild();                           // 銘柄リスト変更時に再スキャン
};
```

---

## 5. UI & Display Specifications

### 5.1 Display Modes
| モード | 内容 |
|---|---|
| Mode 1: Chart | チャートメイン表示（MA・BB・Pivot等） |
| Mode 2: Dashboard | 分析パネルのみ全画面表示 |
| Mode 3: Hybrid（推奨） | チャート＋ダッシュボード併用 |
| Mode 4: Minimal | 強弱ランキング等、最低限のみ表示 |

### 5.2 Dashboard Layout（イメージ）
```text
┌──────────────────────────────┐
│ GLOBAL MARKET DASHBOARD       │
├──────────────────────────────┤
│ Risk ON        82%            │
│ Confidence     91%            │
│ Best Pair      EURJPY         │
├──────────────────────────────┤
│ Currency Strength              │
│ USD █████                      │
│ EUR ████                       │
│ GBP ███                        │
│ AUD ██                         │
│ JPY █                          │
├──────────────────────────────┤
│ Money Flow                     │
│ Stocks      ↑↑                 │
│ Gold        ↓                  │
│ Bond        ↓                  │
│ Crypto      ↑↑↑                │
├──────────────────────────────┤
│ Tokyo   OPEN                   │
│ London  03:12                  │
│ NewYork 09:54                  │
├──────────────────────────────┤
│ CPI      2h14m                 │
│ FOMC     1d03h                 │
└──────────────────────────────┘
```
描画順（更新順）：Market Summary → Currency Strength → Best Pair → Money Flow → Market Open → Economic Events

### 5.3 マーケットオープン・カウントダウン
東京・ロンドン・ニューヨーク各市場について「開場中」または「開場まであとX時間X分」を表示。サーバー時間とセッション境界のズレ（サマータイム含む）は`Core/Utils.mqh`に共通化し、オフセットを入力パラメータ化する（ブローカーごとに調整可能にする）。

### 5.4 経済指標イベント
CPI・FOMC等の主要イベントまでの残り時間を表示。データソース（カレンダーAPI／手動登録／MT5標準イベント流用）は未確定（35章参照）。

---

## 6. Color System & Rules

| シグナル | 色 |
|---|---|
| 🔴 Strong Buy | 赤 `clrRed` |
| 🟠 Buy | オレンジ `clrDarkOrange` |
| ⚪ Neutral | 白/灰 `clrGainsboro` |
| 🩵 Sell | 水色 `clrDeepSkyBlue` |
| 🔵 Strong Sell | 青 `clrBlue` |

> **注意**：Currency Strengthの色分け（最強=赤/最弱=青）と、本章のシグナル色（Strong Buy=赤/Strong Sell=青）は**意味が異なる**。実装時は`GetStrengthColor()`と`GetSignalColor()`のように関数名を明確に分離すること（混同すると誤ったシグナルに見える事故につながる）。

---

## 7. System Architecture & Directory Structure

```text
src/
└── Modules/
    ├── Core/                     // [基盤・ユーティリティ (第1段階)]
    │   ├── AssetDetection.mqh     // ブローカー表記揺れ自動検出・キャッシュ
    │   ├── Logger.mqh             // 初期化・検出・エラー・ロード等のログ管理
    │   └── Utils.mqh              // 共通関数・配列操作・型変換・時刻計算
    │
    ├── Engines/                  // [計算・判定ロジック (第2段階)]
    │   ├── CurrencyStrength.mqh   // 通貨強弱スコア計算
    │   ├── BestPair.mqh           // 最強vs最弱ペア自動選定
    │   ├── Confidence.mqh         // 寄与率合算・確信度計算
    │   ├── MarketRegime.mqh       // Risk Score & 地合い判定
    │   └── MoneyFlow.mqh          // 資金流出入・マネーフロー分析
    │
    └── Display/                  // [UI描画・描画制御 (第3段階)]
        ├── Dashboard.mqh          // GUI全体の統括制御
        ├── SummaryPanel.mqh       // Market Summary描画
        ├── RankingPanel.mqh       // 強弱ランキングパネル描画
        └── MoneyFlowPanel.mqh     // マネーフロー・アセット描画
```

実装順序は **Core → Engines → Display** を推奨する（下位層から上位層へ）。

---

## 8. Performance & Update Policy

| 分析対象 | 更新間隔 | 理由 |
|---|---|---|
| Currency Strength | 1秒 | FX短期トレンドの即時追従 |
| Equity Index / Gold | 5秒 | ボラティリティ監視 |
| Bond | 10秒 | マクロ金利動向の監視 |
| Economic Events / Market Open | 60秒 | タイマーカウントダウン制御 |

### 8.1 実装上の重要な注意点
- 毎ティック全銘柄を再計算しない。`GetTickCount()`等で前回更新時刻を記録し、間隔を超えた時だけ再計算する
- チャートオブジェクトは`ObjectDelete`→`ObjectCreate`を毎回繰り返さない。`ObjectFind`で存在確認し、無ければ作成、あれば値だけ更新する
- 初回起動時はヒストリーデータが揃っていないことがあるため、「データが揃うまで待って一括描画」というフラグ管理（`g_dataReady`等）を各エンジンに用意する
- 週末・市場休止中は新規ティックが来ないため、価格依存の処理は止まってよいが、カウントダウン等の時間依存処理は`OnTimer()`で別途動かす

（詳細な数値目標は32章 Performance Benchmarkで定義する）

---

## 9. Coding & Architecture Standards

### 9.1 命名規則
| 対象 | 規約 |
|---|---|
| クラス名 | 先頭に`C`（例：`CAssetDetection`, `CCurrencyStrength`） |
| メンバー変数 | 先頭に`m_`（例：`m_goldSymbol`） |
| グローバル変数 | 先頭に`g_`（例：`g_logger`） |
| 入力パラメータ | 先頭に`Inp`（例：`InpUpdateInterval`） |
| 主要メソッド | 役割を表す動詞で統一（`Detect()`, `Validate()`, `Calculate()`, `Draw()`） |
| ファイル名 | PascalCase |
| コメント | 日本語可 |
| ヘッダー | すべての`.mqh`冒頭に役割説明を記載 |

### 9.2 追加推奨事項
- チャートオブジェクト名はモジュールごとに一意なプレフィックス（例：`GMD_Rank_`, `GMD_Flow_`）を付け、`OnDeinit()`で`ObjectsDeleteAll`により確実に削除する
- MT5の`GlobalVariable`を使う場合、プレフィックスにインジケーター名＋バージョンを含め、他インジケーターとの衝突を避ける

---

## 10. Development Roadmap & Milestones

```text
 [Ver2.11 (基盤&核心部)] → [Ver2.20 (分析拡張)] → [Ver2.30 (マクロ統合)] → [Ver3.00+]
  Core → Engines → Display    Regime/Flow           Events/Modes          Advanced
```

| バージョン | 内容 |
|---|---|
| Ver2.11 | Core構築（AssetDetection/Logger/Utils）→ Engines構築（CurrencyStrength/BestPair/Confidence）→ Display構築（Dashboard基本表示） |
| Ver2.20 | Money Flow / Market Regime / Asset Detection拡張 |
| Ver2.30 | Market Open / Economic Events / Display Mode |
| Ver3.00 | Flow Analysis / Correlation Engine / Bond Analysis |
| Ver4.00 | Analytics Engine / Prediction / Portfolio Analysis |

---

## 📖 用語集（Glossary）

| 用語 | 説明 |
|---|---|
| Risk ON | 投資家がリスク資産へ資金を移す状態 |
| Risk OFF | 投資家が安全資産へ資金を移す状態 |
| Money Flow | 市場間の資金循環 |
| Confidence | 売買シグナルの信頼度 |
| Market Regime | 市場全体の状態（Risk ON/OFF/Neutral） |
| Asset Detection | ブローカー固有の銘柄名を識別・検証し、全エンジン共通フォーマットに正規化する層 |
| Availability | 銘柄・データが存在しない場合にシステム停止を防ぐフォールバック設計 |
| Liquidity Score | Money Flow Engineが算出する、現金化圧力／リスク選好度の判定指標 |

---

## 29. Class Diagram（新設）

```text
                 ┌─────────────────────┐
                 │   CAssetDetection    │
                 │  (Core / Data Layer) │
                 └──────────┬───────────┘
                            │ 提供
      ┌─────────────────────┼─────────────────────┐
      ▼                     ▼                     ▼
┌───────────────┐   ┌───────────────┐   ┌───────────────┐
│CCurrencyStrength│   │  CMoneyFlow    │   │ CMarketRegime  │
└───────┬────────┘   └───────┬────────┘   └───────┬────────┘
        │                    │                     │
        └─────────┬──────────┴──────────┬──────────┘
                   ▼                     ▼
             ┌───────────┐       ┌──────────────┐
             │ CBestPair │       │ CConfidence   │
             └─────┬──────┘       └──────┬────────┘
                   │                      │
                   └──────────┬───────────┘
                              ▼
                     ┌─────────────────┐
                     │   CDashboard     │
                     │ (Display Layer)  │
                     └─────────────────┘
```

- `CDashboard`は全Engineインスタンスを保持し、`OnCalculate`／`OnTimer`から各`Calculate()`→`Draw()`を呼び出す司令塔
- Engine同士は直接依存せず、必要なデータは`CAssetDetection`と、Engineの`Get〜()`メソッド経由でのみ受け渡す

---

## 30. Data Flow（新設）

```text
[OnInit]
   └→ CAssetDetection.Initialize()  … Symbol Scan〜Cache（1回のみ）

[OnCalculate / OnTimer]
   └→ 更新間隔チェック（8章の更新ポリシーに従う）
        └→ CCurrencyStrength.Calculate()
        └→ CMoneyFlow.Calculate()
        └→ CMarketRegime.Calculate()
        └→ CConfidence.Calculate(cs, mf, mr, momentum)
        └→ CBestPair.Calculate(cs, assetDetection)
   └→ CDashboard.Draw()  … 上記すべての Get〜() を読み取って画面更新
```

- データは常に「Engineが計算→Dashboardが読み取る」の一方向。Dashboard側からEngineの内部状態を書き換えることはしない
- `OnCalculate`は価格ティックに依存するため、市場休止中は呼ばれない。カウントダウン等の時間依存表示は`OnTimer`を別途使用する（8章参照）

---

## 31. Error Handling（新設）

| ケース | 対応方針 |
|---|---|
| 銘柄が存在しない | `CAssetDetection`が`Unavailable`フラグを立て、依存するEngineはその銘柄をスコア計算から除外する（クラッシュさせない） |
| ヒストリーデータ不足（本数不足） | 該当エンジンは「準備中」状態を保持し、必要本数が揃うまで計算をスキップする |
| `CopyRates`等の戻り値が-1 | `GetLastError()`を`Logger.mqh`経由で記録し、当該ティックはスキップして次回に再試行する |
| 週末・市場休止 | 価格依存処理は自然に停止するが、パネル自体は最後の状態を表示し続ける（ブランクにしない） |
| 複数チャートでの同時起動 | オブジェクト名・GlobalVariable名にインジケーター固有プレフィックスを必須化し、衝突を防ぐ（9.2章） |
| 入力パラメータの不正値（重み合計≠100%等） | `OnInit`内でバリデーションし、不正な場合は既定値にフォールバックしてログに警告を出す（`INIT_SUCCEEDED`は維持し、動作は止めない） |

---

## 32. Performance Benchmark（新設）

実装後、以下の指標を計測し記録する（目標値は開発初期の暫定値。実測して調整する）。

| 指標 | 目標値 |
|---|---|
| 1ティックあたりの処理時間（全Engine合計） | 10ms未満 |
| チャートオブジェクト総数 | 200個未満 |
| メモリ使用量の増加（24時間稼働後） | ほぼ横ばい（リークなし） |
| OnInit完了までの時間（Asset Detection含む） | 3秒未満 |

計測方法：`GetMicrosecondCount()`を`OnCalculate`の開始・終了に仕込み、`Logger.mqh`経由で定期的にログ出力する。

---

## 33. Test Plan（26章から拡張・新設）

| 項目 | 確認内容 |
|---|---|
| 銘柄非対応時の挙動 | 一部銘柄がブローカーに存在しない場合でもクラッシュせず「N/A」表示にできるか |
| 週末・市場休止中の挙動 | 新規ティックが来ない状態でダッシュボードがフリーズしないか |
| 初回起動時の挙動 | ヒストリーデータ未取得の状態でエラーや空白パネルにならないか |
| 複数チャートでの同時起動 | オブジェクト名・GlobalVariableが衝突しないか |
| 長時間稼働 | 数日間放置でメモリリーク・オブジェクト数増加がないか |
| 高負荷時のパフォーマンス | 全28ペア＋主要資産を同時監視した状態でのCPU負荷・遅延（32章の目標値と比較） |
| フォールバック再配分 | Confidence Engineで1エンジンのデータが欠損した際、重みが正しく再配分されるか |
| Best Pair逆順処理 | 最強/最弱の組み合わせが逆順でしか存在しない場合、方向解釈が正しく反転するか |
| 複数ブローカーでの動作確認 | 少なくとも2〜3社の異なるブローカー環境で、Asset Detectionが正しく解決できるか |

---

## 34. Release Checklist（新設）

Ver2.11リリース前に、以下を確認する。

- [ ] 33章のTest Planを全て実施し、致命的な不具合がない
- [ ] 27章（旧）／本書の未確定事項（35章 Known Limitations）が解消済み、または既知の制限として明記されている
- [ ] `CHANGELOG.md`に変更内容を記載
- [ ] 全入力パラメータにコメント（説明文）が付与されている
- [ ] User Manual（別紙）が最新の機能に対応している
- [ ] コンパイル時に0 errors, 0 warningsであること
- [ ] デモ口座で最低1週間の実地動作確認を行っている

---

## 35. Known Limitations / 未確定事項（27章を統合・拡張）

| # | 内容 | 状態 |
|---|---|---|
| 1 | Money Flow Engineの↑/→/↓を分けるしきい値（`InpFlowThresholdPct`）の具体的な初期値 | 未確定（暫定0.3%） |
| 2 | Market Regime Engineの9指標それぞれの重み初期値 | 未確定（経験則で仮設定、Ver4.00で最適化予定） |
| 3 | Liquidity Score（Cash Preference / Risk-Seeking）の判定を4条件一致数でスコア化する具体的な計算式 | 未確定 |
| 4 | 経済指標カレンダーのデータソース | 未確定（カレンダーAPI／手動登録／MT5標準流用のいずれか要選定） |
| 5 | Currency Strength Engineの対称/非対称スコアリングどちらを既定にするか | `InpSymmetricScoring`で両対応済みだが、既定値は非対称のまま。運用しながら決定 |
| 6 | 複数ブローカー環境での実機テスト | 未実施（34章のRelease Checklistに含めた） |

---

以上、v1.0 Draftとして再構成した。次のアクションとしては、35章の未確定事項（特に#1〜#3の具体的なしきい値・重み）を先に仮決定し、7章のディレクトリ構成に沿って `Core/AssetDetection.mqh` から実装に着手するのが良いと思います。
