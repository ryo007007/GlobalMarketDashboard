[GlobalMarketDashboard_仕様書_v0.3.md](https://github.com/user-attachments/files/30686774/GlobalMarketDashboard_._v0.3.md)

# Global Market Dashboard Ultimate Edition — プロジェクト仕様書

| 項目 | 内容 |
|---|---|
| Project | Global Market Dashboard Ultimate |
| Platform | MetaTrader 5 (MT5) |
| Language | MQL5 |
| Repository | GlobalMarketDashboard |
| Current Version | 2.11 Ultimate (Development) |
| Document Version | **Project Specification v0.3** |
| Author | Ryoutarou Kadono |
| Status | In Development |

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
- **壊れにくいこと**：ブローカーごとの銘柄表記の違い、週末のデータ欠損、通貨ペアの非存在など、実運用で必ず起きる例外を前提に設計すること（詳細は9章・10章・29章）
- **基盤優先**：Ver2.11では「全部入り」ではなく、Asset Detection を含むコア基盤を安定させることを最優先とする

---

## 4. システム概要

GMDは以下の5つの分析エンジンと、それらを束ねるダッシュボード表示層で構成される。

| エンジン | 役割 |
|---|---|
| Currency Strength Engine | 主要7通貨・28通貨ペアの強弱をスコア化 |
| Money Flow Engine | 株式・貴金属・暗号資産・債券などアセット間の資金流出入を判定 |
| Market Regime Engine | 複数指標を合成し、Risk ON / Risk OFF / Neutralを判定 |
| Confidence Engine | 各エンジンの一致度から、シグナル全体の信頼度を算出 |
| Best Pair Engine | 通貨強弱から、最も分かりやすいトレンドが出やすい通貨ペアを提案 |

これらの結果を `Display/Dashboard.mqh` が受け取り、選択された表示モード（12章）に応じて画面に描画する。

**処理の大まかな流れ**

```
Asset Detection（初回のみ + キャッシュ）
        ↓
各 Engine の Calculate / Update
        ↓
Confidence Engine
        ↓
Dashboard / Panel 群による描画
```

---

## 5. 通貨強弱エンジン（Currency Strength Engine）

### 5.1 Purpose
主要7通貨の相対的な強弱を、28通貨ペアの陽線/陰線判定から数値化し、ランキングとして提示する。

### 5.2 Inputs
| 項目 | 内容 |
|---|---|
| 対象通貨 | USD / EUR / JPY / GBP / CHF / AUD / CAD |
| 対象通貨ペア | 上記7通貨から構成される最大28ペア（ブローカーに実在するもののみ） |
| 時間足 | `Inp_StrengthTimeframe`（既定: M1） |
| 判定バー | 直近の**確定済み1本**（形成中バーは使用しない） |

### 5.3 Calculation
- 各通貨ペアについて、確定済み1本の始値・終値を比較する
  - 終値 > 始値（陽線）→ ベース通貨に **+1点**
  - 終値 < 始値（陰線）→ クオート通貨に **+1点**
  - 同値の場合は加点なし
- 全ペアの結果を通貨ごとに合算し、スコアとする

> **設計メモ**：得点を「勝った側だけに加点」する非対称ロジックを既定とする。対称ロジック（上昇側+1・下落側-1）への切り替えは `Inp_SymmetricScoring` で対応可能な設計とする。

### 5.4 Output
| 項目 | 型 | 説明 |
|---|---|---|
| Score[7] | int | 各通貨の得点 |
| Ranking[7] | string | スコア降順の通貨コード |
| RankPosition[7] | int | 1〜7位 |
| ValidPairs | int | 実際に取得できたペア数 |
| IsReliable | bool | ValidPairs >= 20 の場合 true |

### 5.5 Display
- 7通貨をスコア降順に横並び1行で表示
- 色分けは `Inp_UseStrengthColor` でON/OFF可能（最強=赤、最弱=青のグラデーション）
- ValidPairs < 20 の場合はグレーアウトまたは注意書きを表示

### 5.6 Class Outline
```cpp
class CCurrencyStrength
{
public:
   bool              Initialize();
   void              Calculate();
   int               GetScore(const string currency);
   void              GetRanking(string &ranking[]);
   int               GetValidPairs();
   bool              IsReliable();
   // 描画は持たない（Display層に委譲）
};
```

### 5.7 Future Expansion
- 複数時間足の加重平均
- 出来高やATRを加味した加重スコア

---

## 6. マネーフロー・エンジン（Money Flow Engine）

### 6.1 Purpose
FX以外の主要市場（株価指数・貴金属・暗号資産・債券）について、資金が「流入しているか／流出しているか」を可視化する。

### 6.2 Inputs
| 項目 | 内容 |
|---|---|
| 対象アセット | Asset Detection で検出された銘柄群 |
| 時間足 | 設定可能（既定: H1 など） |
| 判定期間 | 直近 N 本 |
| しきい値 | 変化率ベース（例: ±0.3%） |

### 6.3 Calculation
- 各アセットの直近N本の終値変化率（%）を算出
- 変化率で正規化し、しきい値で判定
  - +threshold 以上 → ↑ 資金流入
  - -threshold 以下 → ↓ 資金流出
  - それ以外 → → 中立

### 6.4 Output
| 項目 | 型 | 説明 |
|---|---|---|
| Direction | enum { FLOW_UP, FLOW_NEUTRAL, FLOW_DOWN } | 各アセットの方向 |
| ChangePct | double | 変化率（%） |
| IsAvailable | bool | データ取得可否 |

### 6.5 Display
- ↑（緑）／→（灰）／↓（赤）の記号で一覧表示

### 6.6 Class Outline
```cpp
class CMoneyFlow
{
public:
   bool              Initialize(const CAssetDetection &assets);
   void              Calculate();
   ENUM_FLOW_DIR     GetDirection(const string category);
   double            GetChangePct(const string category);
   bool              IsAvailable(const string category);
};
```

### 6.7 Future Expansion
- 複数時間足の合成
- 資金回転（Money Rotation）分析への拡張

---

## 7. 市場レジーム・エンジン（Market Regime Engine）

### 7.1 Purpose
複数指標を合成し、現在の市場が Risk ON / Risk OFF / Neutral のいずれかを定量的に判定する。

### 7.2 Inputs
| 指標 | 寄与の方向（初期案） |
|---|---|
| SP500 / NASDAQ / BTC / ETH | 上昇 → Risk ON |
| VIX / US10Y | 上昇 → Risk OFF |
| Gold | 急騰 → Risk OFF（安全資産逃避） |
| USDJPY / DXY | 補助指標 |

### 7.3 Calculation
```
Score = Σ( 指標iの標準化された変化率 × 重みi )
```
- 各指標を直近N本の変化率に変換し、Z-score等で標準化
- 合成スコアを閾値で3値に変換（例: +20以上 Risk ON、-20以下 Risk OFF、それ以外 Neutral）

### 7.4 Output
| 項目 | 型 | 説明 |
|---|---|---|
| Regime | enum { RISK_ON, RISK_OFF, NEUTRAL } | 判定結果 |
| Score | double | 0〜100 のスコア |
| ConfidenceContribution | double | Confidence Engine への寄与値 |

### 7.5 Class Outline
```cpp
class CMarketRegime
{
public:
   bool              Initialize(const CAssetDetection &assets);
   void              Calculate();
   ENUM_REGIME       GetRegime();
   double            GetScore();
};
```

### 7.6 Future Expansion
- Ver4.00 の分析エンジンによる重み最適化
- 機械学習によるパターン検出

---

## 8. 信頼度エンジン（Confidence Engine）

### 8.1 Purpose
各エンジンの出力の一致度・極端さから、シグナル全体の信頼度を 0〜100% で算出する。

### 8.2 Inputs
- Currency Strength: 最強・最弱の点差、ValidPairs
- Money Flow: 複数資産の方向一致度
- Market Regime: Score の極端さ
- Momentum（将来）: 直近値動きの継続性

### 8.3 Calculation
```
Confidence(%) = Σ( 各エンジンの正規化スコア × 重み ) を 0〜100 にスケーリング
```
- データが取得できないエンジンがある場合は、その重みを他エンジンに再配分するフォールバックを実装する

### 8.4 Output
| 項目 | 型 | 説明 |
|---|---|---|
| Confidence | double | 0〜100 |
| Breakdown | string | 内訳（デバッグ用） |

### 8.5 Class Outline
```cpp
class CConfidence
{
public:
   bool              Initialize();
   void              Calculate(const CCurrencyStrength &cs,
                               const CMoneyFlow &mf,
                               const CMarketRegime &mr);
   double            GetConfidence();
};
```

---

## 9. ベストペア・エンジン（Best Pair Engine）

### 9.1 Purpose
Currency Strength の最強・最弱通貨から、トレンドが出やすい通貨ペアを提案する。

### 9.2 Inputs
- Currency Strength Engine の Ranking 結果

### 9.3 Calculation / Resolution Flow
1. `最強通貨 + 最弱通貨` が実在するか `SymbolInfoInteger(symbol, SYMBOL_EXIST)` で確認
2. 存在しなければ逆順を試す
3. どちらも存在しない場合は「該当ペアなし」を明示
4. 逆順を採用した場合は方向解釈も反転して表示に反映
5. 表示銘柄はクリックでチャート遷移可能にする

### 9.4 Output
| 項目 | 型 | 説明 |
|---|---|---|
| BestPair | string | 推奨通貨ペア |
| Direction | enum | 強い側がベースかクオートか |
| IsValid | bool | ペアが実在するか |

### 9.5 Class Outline
```cpp
class CBestPair
{
public:
   bool              Initialize(const CAssetDetection &assets);
   void              Calculate(const CCurrencyStrength &cs);
   string            GetBestPair();
   bool              IsValid();
};
```

---

## 10. アセット検出（Asset Detection）★ 基盤モジュール

> **本モジュールは全エンジンの基礎となる最重要基盤である。**  
> Ver2.11 ではここを最優先で安定させる。

### 10.1 Purpose
ブローカーごとに異なる銘柄表記を吸収し、各エンジンが必要とするシンボルを自動検出し、検証し、キャッシュして提供する。

### 10.2 処理フロー（Asset Detection Flow）

```
Terminal 起動 / インジケーター OnInit
        ↓
シンボル一覧取得（SymbolsTotal / SymbolName）
        ↓
カテゴリ別検索
   ├── Gold / Silver
   ├── Indices (US30, NAS100, SPX500, JP225, GER40, UK100 ...)
   ├── Crypto (BTC, ETH ...)
   ├── Bonds (US10Y, US30Y ...)
   └── FX 28ペア
        ↓
Validation（実際にバーデータが取得できるか確認）
        ↓
Availability 判定
   ├── Available → キャッシュに登録
   └── Unavailable → 「データなし」フラグを立てる（エラーで止めない）
        ↓
Cache 保存（以降は再検索せずキャッシュを使用）
        ↓
各 Engine へ渡す
```

### 10.3 Validation
検出したシンボルが「名前として存在する」だけでなく、**実際に価格データが取得可能か**を確認する。

```cpp
// 例: 直近バーが取得できるか
bool ValidateSymbol(const string symbol)
{
   if(!SymbolSelect(symbol, true)) return false;
   MqlRates rates[];
   int copied = CopyRates(symbol, PERIOD_M1, 0, 5, rates);
   return (copied > 0);
}
```

結果例:
```
Gold     ✓ OK
BTC      ✓ OK
US10Y    × 未対応（ブローカーに存在しない or データなし）
```

### 10.4 Availability
見つからなかった、または Validation に失敗したアセットは **Unavailable** として扱う。

- ダッシュボード上では「Bond: Unavailable」などと表示するだけにする
- プログラムを停止させない（フォールトトレラント設計）
- Confidence Engine では当該エンジンの重みを再配分する

### 10.5 Cache
- 検出結果は一度だけ行い、以降はメモリ上のキャッシュを使用する
- 毎秒の再検索を禁止し、パフォーマンスを確保する
- 必要に応じて「強制再検出」パラメータを用意する

### 10.6 ブローカー間表記ゆれ対応（優先順位リスト）
同じ資産でもブローカーごとに名前が異なるため、**優先順位付き候補リストから最初に見つかったものを採用**する。

**例: Gold**
```
XAUUSD → GOLD → GOLDmicro → XAUUSD.r → XAUUSD.a → GOLD.r ...
```

**例: US30**
```
US30 → DJ30 → WallStreet30 → US30.cash → US30m ...
```

このロジックは `Core/AssetDetection.mqh` 内に汎用関数として集約し、Best Pair Engine とも共通化する。

### 10.7 カテゴリ別 対象銘柄

| カテゴリ | 代表銘柄例 |
|---|---|
| FX | USDJPY, EURUSD, GBPUSD 他 最大28ペア |
| 貴金属 | Gold, Silver |
| 株価指数 | SP500, NAS100, US30, JP225, GER40, UK100 |
| 暗号資産 | BTC, ETH |
| 債券 | US10Y, US30Y |

### 10.8 Class Outline
```cpp
class CAssetDetection
{
private:
   struct AssetInfo
   {
      string   category;      // "Gold", "BTC", "US30" など
      string   symbol;        // 実際に検出されたシンボル名
      bool     available;     // Validation 結果
      datetime detectedAt;
   };
   AssetInfo         m_assets[];
   bool              m_initialized;

public:
   bool              Initialize();                 // 全カテゴリ検出 + Validation + Cache
   string            GetSymbol(const string category);
   bool              IsAvailable(const string category);
   int               GetAvailableCount();
   void              ForceRedetect();              // 強制再検出（任意）
   void              GetAllAvailable(string &symbols[]);
};
```

### 10.9 実装上の注意点
- 初回起動時はヒストリーデータが揃っていないことがあるため、Validation はリトライ可能な設計にする
- 週末や市場休止中でも「Unavailable」ではなく「最後に取得できた状態」を維持するオプションを検討する
- 優先順位リストは入力パラメータまたは設定ファイルで上書き可能にしておく

---

## 11. 画面構成・表示モード（Display Modes）

| モード | 内容 |
|---|---|
| Mode 1: Chart | チャート＋移動平均＋BB＋Pivot（通常のチャート分析画面） |
| Mode 2: Dashboard | Market Dashboardのみ表示（チャート要素なし） |
| Mode 3: Hybrid | チャート＋Dashboardを同時表示 |
| Mode 4: Minimal | 通貨強弱ランキングのみの最小表示 |

モード切替は右下のボタン、または入力パラメータ `Inp_DisplayMode` から行う。

---

## 12. マーケットオープン・カウントダウン

東京・ロンドン・ニューヨークの各市場について、「開場中」または「開場まであとX時間X分」を表示する。

- サーバー時間とセッション時刻のズレ（サマータイム含む）を考慮した計算ロジックを `Core/Utils.mqh` に共通化すること
- セッション境界時刻をオフセットとして入力パラメータ化しておくと、環境が変わっても調整しやすい

---

## 13. 経済指標イベント（Economic Events）

- CPI・FOMCなど主要イベントまでの残り時間を表示
- データソース（カレンダーAPI／手動登録／MT5標準のイベントカレンダー流用）を要選定
- 更新頻度は60秒毎（19章参照）

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
│ Bond        Unavailable       │
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

| シグナル | 色 |
|---|---|
| Strong Buy | 赤 |
| Buy | オレンジ |
| Neutral | 白 |
| Sell | 水色 |
| Strong Sell | 青 |

> **注意**：通貨強弱の色分け（最強=赤/最弱=青）と、シグナル色（Strong Buy=赤/Strong Sell=青）は意味が異なるため、実装時に `GetStrengthColor()` と `GetSignalColor()` のように関数名を明確に分離すること。

---

## 16. パフォーマンス設計

| 項目 | 方針 |
|---|---|
| 更新間隔 | 通貨強弱：1秒毎 or 新しいバーのみ／株価指数・Gold：5秒毎／債券：10秒毎／経済指標・市場オープン：60秒毎 |
| CPU負荷 | 可能な限り低く抑える |
| オブジェクト数 | 最小限に抑える |
| 描画方式 | 差分更新（変化があった部分だけ再描画） |

### 16.1 実装上の重要な注意点
- **毎ティック全銘柄を再計算するのは避ける**。`GetTickCount()` 等で前回更新時刻を記録し、指定間隔を超えた時だけ再計算するタイマー方式にする
- **オブジェクトは「作り直す」のではなく「位置・テキストだけ更新」する**。`ObjectFind` → 無ければ作成、あれば `ObjectSetString` / `ObjectSetInteger` で更新
- **初回起動時のヒストリーデータ未取得への対策**：`g_dataReady` フラグを各エンジンに用意し、揃うまでは「準備中」表示にする
- **週末・市場休止中の挙動**：`OnTimer()` を併用し、価格更新に依存しない部分は別途タイマーで更新する
- **Asset Detection のキャッシュ**：毎秒の再検索を禁止する

---

## 17. バージョン履歴

| バージョン | 内容 |
|---|---|
| Project Specification v0.1 | 初版 |
| Project Specification v0.2 | 重複章の統合、各エンジンの計算式明文化、実装上の落とし穴と対策を追加 |
| Project Specification v0.3 | Asset Detection を大幅拡充（Validation / Availability / Cache / Flow）。各エンジンに Purpose / Inputs / Calculation / Output / Class Outline を追加。構造整理。 |

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
    │   └── BestPair.mqh          // 最強vs最弱の「ベストペア」自動選定
    │
    ├── Display/                  // UI描画・表示制御
    │   ├── Dashboard.mqh         // 画面全体のUIコントロール・レイアウト統括
    │   ├── SummaryPanel.mqh      // Market Summary描画
    │   ├── RankingPanel.mqh      // 通貨強弱ランキング描画
    │   └── MoneyFlowPanel.mqh    // マネーフロー・アセット状況描画
    │
    └── Core/                     // システム共通基盤・ユーティリティ
        ├── AssetDetection.mqh     // ★ ブローカー固有銘柄の自動検出・Validation・Cache
        ├── Logger.mqh             // 動作ログ・エラーハンドリング・デバッグ出力
        └── Utils.mqh              // 配列操作・型変換・時刻計算等の汎用補助関数
```

### 18.1 モジュール間インターフェースの原則
- `Dashboard.mqh` は各 Engine を**呼び出すだけ**で、計算ロジックを持たない
- 各 Engine は `Calculate()` または `Update()` を実行し、**計算結果だけ**を返す（描画処理を持たない）
- Engine 間の直接依存は最小限にし、必要なデータは Core の共通構造体経由で受け渡す
- **AssetDetection は全 Engine の依存先**となる基盤モジュールとする

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
| Asset Detection | 初回のみ（強制再検出時を除く） |

---

## 20. シンボル優先順位（Symbol Priority）

優先順位リストは `Core/AssetDetection.mqh` 内で銘柄カテゴリごとに定義し、**設定ファイルまたは入力パラメータで上書きできる**ようにする。

例：Gold
```
XAUUSD → GOLD → GOLDmicro → XAUUSD.r → XAUUSD.a → GOLD.r
```

---

## 21. 設定項目（Settings）

- Update Interval（更新間隔）
- Currency Timeframe（通貨強弱判定に使う時間足）
- Color Theme（配色テーマ）
- Display Mode（11章の4モード）
- Auto Detect Symbols（銘柄自動検出のON/OFF）
- Force Redetect（強制再検出）
- Show Events（経済指標表示のON/OFF）
- Show Market Open（マーケットオープン表示のON/OFF）
- Symmetric Scoring（通貨強弱の対称/非対称切替）

---

## 22. 用語集（Glossary）

| 用語 | 説明 |
|---|---|
| Risk ON | 投資家がリスク資産へ資金を移す状態 |
| Risk OFF | 投資家が安全資産へ資金を移す状態 |
| Money Flow | 市場間の資金循環 |
| Confidence | 売買シグナルの信頼度 |
| Market Regime | 市場全体の状態（Risk ON/OFF/Neutral） |
| Asset Detection | ブローカー固有の銘柄表記を吸収し、利用可能シンボルを自動検出する仕組み |
| Validation | 検出したシンボルが実際にデータ取得可能かを確認する処理 |
| Availability | アセットが利用可能かどうかの状態 |
| Cache | 一度検出したシンボル情報を保持し、再検索を避ける仕組み |

---

## 23. コーディング規約（Coding Standards）

| 対象 | 規約 |
|---|---|
| クラス | `CMarketRegime`、`CCurrencyStrength`、`CAssetDetection` のように PascalCase＋`C`プレフィックス |
| 変数 | メンバ変数`m_`、グローバル変数`g_`、入力パラメータ`Inp`プレフィックス |
| 関数 | `Calculate()`、`Update()`、`Draw()`、`Detect()`、`Validate()` のように役割を表す動詞で統一 |
| ファイル名 | PascalCase |
| コメント | 日本語可 |
| ヘッダー | すべての`.mqh`ファイル冒頭に、役割を説明するコメントを記載する |

### 23.1 追加推奨事項
- チャートオブジェクト名は、モジュールごとに一意なプレフィックス（例：`GMD_Rank_`、`GMD_Flow_`）を付け、`OnDeinit()`で`ObjectsDeleteAll`により確実に削除できるようにする
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
| **Ver2.11** | **基盤固め**：Asset Detection / Currency Strength / Best Pair / Confidence / Dashboard / Ranking |
| Ver2.20 | Money Flow / Market Regime |
| Ver2.30 | Market Open / Economic Events / Display Mode 完成 |
| Ver3.00 | Flow Analysis / Correlation Engine / Bond Analysis |
| Ver4.00 | Analytics Engine / Prediction / Portfolio Analysis |

> Ver2.11 の完成時点で「通貨強弱・ランキング・Best Pair・Confidence・シンボル自動検出・Dashboard表示」が安定して動けば大成功とする。全部入りを目指さない。

---

## 26. Asset Detection Flow（詳細）

本章は第10章の補足として、実装時に迷わないための詳細フローを定義する。

```text
[OnInit]
    │
    ├─ CAssetDetection::Initialize()
    │       │
    │       ├─ シンボル一覧取得
    │       │
    │       ├─ カテゴリごとに優先順位リストで検索
    │       │     Gold / Silver / Indices / Crypto / Bonds / FX28
    │       │
    │       ├─ Validation（CopyRates 等でデータ取得確認）
    │       │
    │       ├─ Availability フラグ設定
    │       │
    │       └─ Cache に保存
    │
    ├─ 各 Engine::Initialize(assetDetection)
    │
    └─ Dashboard::Initialize()

[OnTick / OnTimer]
    │
    ├─ キャッシュを参照して各 Engine::Calculate()
    │     （Asset Detection の再検索は行わない）
    │
    └─ Dashboard::Update()  （差分更新）
```

**エラーハンドリング方針**
- 検出失敗 → Unavailable として扱い、処理継続
- Validation 失敗 → リトライ回数を設け、上限超過で Unavailable
- クラッシュさせないことを最優先とする

---

## 27. テスト・QA計画

実運用前に最低限、以下を検証する。

| 項目 | 確認内容 |
|---|---|
| 銘柄非対応時の挙動 | 一部銘柄がブローカーに存在しない場合でもクラッシュせず、該当項目を「Unavailable」表示にできるか |
| 週末・市場休止中の挙動 | 新規ティックが来ない状態で、ダッシュボードがフリーズしないか |
| 初回起動時の挙動 | ヒストリーデータ未取得の状態で、エラーや空白パネルにならないか |
| Asset Detection キャッシュ | 2回目以降の起動で再検索が発生せず、正しくキャッシュが使われているか |
| 複数チャートでの同時起動 | 同じインジケーターを複数チャートで起動した際、オブジェクト名・グローバル変数が衝突しないか |
| 長時間稼働 | 数日間放置した際にメモリリーク・オブジェクト数の増加がないか |
| 高負荷時のパフォーマンス | 全28ペア＋主要資産を同時監視した状態でのCPU負荷・遅延 |

---

## 28. 未確定事項（Open Issues）

改善にあたり、以下は仕様として未確定のため、開発着手前に確定させることを推奨する。

1. Currency Strength Engine の得点方式（非対称加点 vs 対称加点） → `Inp_SymmetricScoring` で両対応とする方向
2. Money Flow Engine の「流入/中立/流出」を分けるしきい値の具体的な数値
3. Market Regime Engine の各指標の重み付け初期値
4. Confidence Engine の各エンジンへの重み配分
5. 経済指標カレンダーのデータソース
6. Asset Detection の優先順位リストの最終確定（主要ブローカー調査後）

---

## 29. エラーハンドリング方針（新規）

| 状況 | 対応 |
|---|---|
| シンボルが存在しない | Unavailable 表示。処理継続 |
| データ取得失敗 | リトライ → 上限超過で Unavailable |
| ヒストリー不足 | 「準備中」表示。データが揃うまで待機 |
| オブジェクト作成失敗 | ログ出力。可能な限り表示を継続 |
| 複数チャート衝突 | オブジェクト名にチャートIDを含める |

---

## 30. 今後追加を検討する章（参考）

- Class Diagram
- Data Flow（全体シーケンス図）
- Performance Benchmark
- Release Checklist
- Known Limitations
- User Manual

これらは Ver2.11 実装後、必要に応じて追加する。

---

以上、**Project Specification v0.3** として改訂した。

### 次のステップ（推奨）

1. 本章で固めた **Asset Detection** の仕様に基づき、`Core/AssetDetection.mqh` の実装を開始する
2. 動作確認後、Currency Strength → Best Pair → Confidence → Dashboard の順で積み上げる
3. Ver2.11 完成時点で「基盤が安定して動く」ことを成功基準とする

設計フェーズは一区切りとし、ここからは **設計30%・実装70%** の比率で進めていきましょう。

---

*Document Version: Project Specification v0.3*  
*Last Updated: 2026-08-04*
