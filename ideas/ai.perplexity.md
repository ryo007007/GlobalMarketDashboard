[GlobalMarketDashboard_Spec_v0.3 perplexity.md](https://github.com/user-attachments/files/30683733/GlobalMarketDashboard_Spec_v0.3.perplexity.md)

# Global Market Dashboard Ultimate Edition — プロジェクト仕様書

| 項目 | 内容 |
|---|---|
| Project | Global Market Dashboard Ultimate |
| Platform | MetaTrader 5 (MT5) |
| Language | MQL5 |
| Repository | GlobalMarketDashboard |
| Current Version | 2.11 Ultimate (Development) |
| Document Version | Project Specification **v0.3** |
| Author | Ryoutarou Kadono |
| Status | In Development（設計30% / 実装70%フェーズへ移行） |
| Last Update | 2026-08-04 |

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

---

## 5. 通貨強弱エンジン（Currency Strength Engine）

### 5.1 対象通貨
USD / EUR / JPY / GBP / CHF / AUD / CAD の主要7通貨。

### 5.2 対象通貨ペア
上記7通貨の組み合わせで作れる **28通貨ペア**（7C2 = 21ペア + クロス円等を含む一般的な組み合わせ）。実際に使用するペアは、9章のシンボル自動検出ロジックで、ブローカーに実在するものだけに絞り込む。

### 5.3 判定ロジック（明文化）
- 判定時間足：`Inp_StrengthTimeframe`（既定 M1、設定変更可）
- 各通貨ペアについて、**直近の確定済み1本**（形成中の最新足は使わない）の始値・終値を比較する
  - 終値 > 始値（陽線）→ 分子（ベース通貨）に **+1点**
  - 終値 < 始値（陰線）→ 分母（クオート通貨）に **+1点**
  - 同値の場合は加点なし
- 全28ペアの判定結果を通貨ごとに合算し、スコアとする

> **設計メモ**：得点を「勝った側だけに加点」する非対称ロジックにするか、「上昇側+1・下落側-1」の対称ロジックにするかは要件確定が必要。本仕様では前者（非対称・加点のみ）を既定仕様とする。対称ロジックにする場合は`Inp_SymmetricScoring`のようなON/OFFスイッチを設けて両対応にする。

### 5.4 ランキング表示
- 7通貨をスコア降順に並べ、1位〜7位を表示
- 表示形式は横並び1行（縦積みは画面を圧迫するため非推奨。実装経験上、横並びの方が視認性が高い）

### 5.5 色分け
- 既定は「最強＝赤、最弱＝青」のグラデーション
- ただし文字が小さいパネル上では**色分けよりも白文字＋数字ランク表示の方が視認性が高い**ケースがあるため、`Inp_UseStrengthColor`で色分け自体のON/OFFを用意すること

### 5.6 信頼度（Confidence）との関係
現時点では「検討中」とされているが、最低限、**判定に使った通貨ペア数（28ペア中、実際にブローカーで取得できたペア数）** を信頼度計算の入力に含めることを推奨する。取得できたペアが少ない状態（例：週末や一部銘柄が休止中）でランキングを表示すると誤解を招くため、`取得成功ペア数 < 20` の場合はランキングにグレーアウト表示や注意書きを出す設計にする。

---

## 6. マネーフロー・エンジン（Money Flow Engine）

### 6.1 目的
FX以外の主要市場（株価指数・貴金属・暗号資産・債券）を対象に、資金が「入ってきているか」「出て行っているか」を可視化する。

### 6.2 対象市場・代表銘柄

| 市場 | 代表銘柄 |
|---|---|
| 株価指数 | US30, NAS100, SPX500, JP225, GER40, UK100 |
| 貴金属 | Gold(XAUUSD), Silver(XAGUSD) |
| 暗号資産 | BTC, ETH |
| 債券 | US10Y, US30Y |

### 6.3 判定ロジック（要具体化）
現行仕様は「一定時間の上昇/下降を判定」としか書かれていないため、以下を最低限明記する。

- 判定時間足・判定期間（例：直近N本の終値変化率）
- 「↑資金流入」「↓資金流出」「→中立」を分ける**しきい値**（例：直近N本の変化率が+0.3%以上で↑、-0.3%以下で↓、それ以外は→）
- 複数の資産をまたいで比較する場合は、**変化率（%）で正規化**すること（価格そのものの上昇幅では、株価指数とGoldでは桁が違うため比較できない）

### 6.4 表示
- ↑（緑）／→（灰）／↓（赤）の記号で、各アセットの状態を一覧表示

---

## 7. 市場レジーム・エンジン（Market Regime Engine）

### 7.1 入力
SP500, NASDAQ, US10Y, Gold, USDJPY, BTC, ETH, VIX, DXY

### 7.2 出力
Risk ON / Risk OFF / Neutral の3値、および 0-100 のスコア

### 7.3 判定ロジック（要具体化）
現行仕様には計算式がないため、以下のような**加重スコア方式**を推奨する。

```
Score = Σ( 指標iの標準化された変化率 × 重みi )
```

- 各指標を直近N本の変化率に変換し、Z-score等で標準化（単位を揃える）
- 株式・BTC・ETHの上昇、VIX・US10Yの低下 → Risk ONに寄与（正の重み）
- VIX・US10Yの上昇、金の急騰（安全資産への逃避） → Risk OFFに寄与（負の重み）
- 合成スコアが一定の閾値（例：+20以上でRisk ON、-20以下でRisk OFF、その間はNeutral）で3値に変換

重みの初期値は経験則で仮設定し、将来的にVer4.00の分析エンジンで最適化する前提とする。

---

## 8. 信頼度エンジン（Confidence Engine）

現行仕様は「現在検討中」のままだが、最低限のたたき台として以下を提案する。

### 8.1 判定材料
- Currency Strength（最強・最弱の点差が大きいほど信頼度が上がる）
- Money Flow（複数資産の方向が一致しているほど信頼度が上がる）
- Market Regime Score（極端な値ほど、その方向への確信度が高い）
- Momentum（直近の値動きの継続性）

### 8.2 計算方針
```
Confidence(%) = Σ( 各エンジンの正規化スコア × 重み ) を 0〜100 にスケーリング
```
- 各エンジンの出力を同じスケール（0〜100）に正規化してから加重平均する
- どれか1つのエンジンのデータが取得できない場合（例：債券データが取得不可）は、その分の重みを他のエンジンに再配分するフォールバックを用意する

---

## 9. ベストペア・エンジン（Best Pair Engine）

### 9.1 入力
Currency Strength Engineの結果（最強通貨・最弱通貨）

### 9.2 出力
おすすめ通貨ペア（例：EUR最強・JPY最弱 → EURJPY）

### 9.3 実装上の注意点（実体験に基づく重要事項）
最強・最弱を単純に文字列結合しただけでは、**そのペアがブローカーに存在しない場合がある**（例：CHFUSDは無いがUSDCHFはある、など基軸通貨の並びは通貨ごとに慣習が決まっている）。

以下の解決フローを必ず実装すること。

1. `最強通貨+最弱通貨`（例：USDJPY）が実在するか `SymbolInfoInteger(symbol, SYMBOL_EXIST)` で確認
2. 存在しなければ、逆順（`最弱通貨+最強通貨`）を試す
3. どちらも存在しない場合（間に他の通貨を挟む必要がある場合）は、「該当ペアなし」を明示する
4. 逆順を採用した場合、**方向の解釈も反転する**（強い通貨が分母に来るため、そのペア自体は下落方向が「強い通貨側の勝ち」を意味する）ことを表示に反映する
5. 表示された銘柄はクリックでチャート遷移できるようにする（利便性が大きく向上する）

---

## 10. アセット検出（Asset Detection）—— 概要

> **重要**：本章は概要であり、実装に使う詳細設計（状態モデル・データ構造・公開API・テストケース）は **26章 Asset Detection Flow** に集約した。`Core/AssetDetection.mqh` を実装する際は26章を正とする。

### 10.1 処理フロー
旧仕様の単純な1本道フローを、**5段階パイプライン**に拡張する。

```
Detect → Validation → Availability → Cache → Engineへ引き渡し
```

従来の「名前が見つかったら採用」だけでは不十分である。名前が存在しても、ヒストリーが0本、気配値が0、Market Watchに未登録、といった「名前だけある銘柄」が実在するため、**実際にデータが取れるかを検証する工程（Validation）を必須とする**。

### 10.2 ブローカー間の表記ゆれ対応（優先順位リスト）
ブローカーによって同じ資産でも銘柄名が異なるため、**優先順位付きの候補リストから最初に見つかったものを採用**する方式にする。

例：Gold
```
XAUUSD → GOLD → GOLDmicro → XAUUSD.r → XAUUSD.a ...
```

この「候補から実在するものを探す」ロジックは、Best Pair Engine（9章）とも共通化し、`Core/AssetDetection.mqh`内に汎用関数として1箇所にまとめること（重複実装を避ける）。

なお、候補リストを手書きで増やし続けるのには限界があるため、**ブローカー共通サフィックスの自動推定**（例：現在チャートが `EURUSD.a` なら `.a` を全候補に自動付与）と、**正規化部分一致検索**を併用する。詳細は 26.6 を参照。

### 10.3 カテゴリ別 対象銘柄例
| カテゴリ | 代表銘柄例 |
|---|---|
| FX | USDJPY, EURUSD, GBPUSD 他28ペア |
| 貴金属 | Gold, Silver |
| 株価指数 | SP500, NAS100, US30, JP225, GER40, UK100 |
| 暗号資産 | BTC, ETH |
| 債券 | US10Y, US30Y |

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

| シグナル | 色 |
|---|---|
| Strong Buy | 赤 |
| Buy | オレンジ |
| Neutral | 白 |
| Sell | 水色 |
| Strong Sell | 青 |

> **注意**：5章の通貨強弱の色分け（最強=赤/最弱=青）と、本章のシグナル色（Strong Buy=赤/Strong Sell=青）は意味が異なるため、実装時に混同しないよう変数名・関数名を明確に分離すること（例：`GetStrengthColor()`と`GetSignalColor()`）。

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

### 21.1 Asset Detection 関連の入力パラメータ（Ver2.11で実装）

| パラメータ名 | 型 | 既定値 | 説明 |
|---|---|---|---|
| `Inp_AutoDetectSymbols` | bool | true | falseにすると以下の手動指定のみを使う |
| `Inp_SymbolSuffix` | string | "" | ブローカー共通サフィックスの手動指定。空なら自動推定（26.6.2） |
| `Inp_SymbolPrefix` | string | "" | ブローカー共通プレフィックスの手動指定 |
| `Inp_OverrideGold` | string | "" | Goldの銘柄名を強制指定（検出失敗時の逃げ道） |
| `Inp_OverrideIndices` | string | "" | 指数の強制指定。`US30=DJ30;NAS100=USTEC` 形式のセミコロン区切り |
| `Inp_OverrideCrypto` | string | "" | 暗号資産の強制指定。同形式 |
| `Inp_ValidationMinBars` | int | 100 | Validationで要求する最小バー本数（26.7） |
| `Inp_ValidationMaxAgeSec` | int | 86400 | 最終ティックがこれ以上古ければStale判定（週末考慮で24h） |
| `Inp_CacheTTLMinutes` | int | 0 | キャッシュの有効期限。0 = セッション中は無期限（26.9） |
| `Inp_CachePersist` | bool | true | 検出結果をGlobalVariable/ファイルに永続化し、次回起動を瞬時化 |
| `Inp_DetectLogLevel` | enum | INFO | 検出処理のログ粒度（OFF/ERROR/WARN/INFO/DEBUG） |
| `Inp_ShowUnavailable` | bool | true | 未対応銘柄を `Unavailable` として表示するか、行ごと非表示にするか |

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
| Ver2.11 | **Core基盤（AssetDetection / Logger / Utils）** + Currency Strength / Best Pair / Confidence / Dashboard基本表示 |
| Ver2.20 | Money Flow / Market Regime / MoneyFlowPanel |
| Ver2.30 | Market Open / Economic Events / Display Mode |
| Ver3.00 | Flow Analysis / Correlation Engine / Bond Analysis |
| Ver4.00 | Analytics Engine / Prediction / Portfolio Analysis |

### 25.1 Ver2.11 の完成定義（Definition of Done）

Ver2.11は「全部入り」を目指さず、**上に積める土台を完成させるバージョン**と位置づける。以下がすべて安定稼働した時点で完成とする。

1. シンボル自動検出（26章）が、最低2社以上の異なるブローカー環境で動作する
2. 未対応銘柄（例：US10Y）があってもクラッシュせず `Unavailable` 表示で継続する
3. 通貨強弱・ランキング・Best Pair・Confidence が整合した値を表示する
4. Dashboardがちらつきなく差分更新される
5. 24時間連続稼働でオブジェクト数・メモリが増え続けない

Money Flow と Market Regime はVer2.20に先送りする。土台を先に固める方が、結果的に長く使えるソフトになる。

---

## 26. Asset Detection Flow（詳細設計）

> 本章はVer2.11の最初の実装対象である `Core/AssetDetection.mqh` の完全仕様である。このモジュールは全エンジンの上流に位置し、ここが不安定だと下流すべてが崩れる。したがって、最も厳密に仕様を固める。

### 26.1 位置づけと責務

**責務（これだけをやる）**

- ブローカー固有の銘柄名を、GMD内部の論理名（`ASSET_GOLD` など）に対応付ける
- その銘柄が**実際に使える**かを検証する
- 結果をキャッシュし、各エンジンに**確定した銘柄名**を提供する

**責務外（これはやらない）**

- 価格の計算・分析（→ Enginesの仕事）
- 画面描画（→ Displayの仕事。状態を返すだけ）
- エラーでの処理中断（→ 常に状態を返して継続する）

### 26.2 5段階パイプライン（全体フロー）

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

```cpp
//--- 論理アセットID（内部では常にこのIDで参照する）
enum ENUM_ASSET_ID
{
   ASSET_GOLD, ASSET_SILVER,
   ASSET_US30, ASSET_NAS100, ASSET_SPX500,
   ASSET_JP225, ASSET_GER40, ASSET_UK100,
   ASSET_BTC,  ASSET_ETH,
   ASSET_US10Y, ASSET_US30Y,
   ASSET_DXY,  ASSET_VIX,
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

7通貨の組み合わせ21ペアについて、**正序・逆序の両方を試し、見つかった方の向きを記録する**。

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
Step 8  状態遷移と RetryPending() を追加
Step 9  Cache（L1→L2の順）を追加
Step 10 BuildSummaryText() でログを整えて完成
```

各Stepの終わりで必ずコンパイルを通し、エキスパートの出力を目で確認してから次に進む。一気に全部書かない。

---

## 27. テスト・QA計画

旧仕様書に欠けていた項目。アセット検出固有のテストは26.14を参照。実運用前に最低限、以下を検証する。

| 項目 | 確認内容 |
|---|---|
| 銘柄非対応時の挙動 | 一部銘柄がブローカーに存在しない場合でもクラッシュせず、該当項目を「データなし」表示にできるか |
| 週末・市場休止中の挙動 | 新規ティックが来ない状態で、ダッシュボードがフリーズしないか |
| 初回起動時の挙動 | ヒストリーデータ未取得の状態で、エラーや空白パネルにならないか |
| 複数チャートでの同時起動 | 同じインジケーターを複数チャートで起動した際、オブジェクト名・グローバル変数が衝突しないか |
| 長時間稼働 | 数日間放置した際にメモリリーク・オブジェクト数の増加がないか |
| 高負荷時のパフォーマンス | 全28ペア＋主要資産を同時監視した状態でのCPU負荷・遅延 |

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
   ASSET_GOLD=0, ASSET_SILVER,
   ASSET_US30, ASSET_NAS100, ASSET_SPX500,
   ASSET_JP225, ASSET_GER40, ASSET_UK100,
   ASSET_BTC, ASSET_ETH,
   ASSET_US10Y, ASSET_US30Y,
   ASSET_DXY, ASSET_VIX,
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
   void              RetryPending(void);
   void              Refresh(void);
   void              Deinit(void);

   bool              LoadCache(void);
   bool              SaveCache(void);

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

以上、v0.3として改訂した。

次のステップは、**26.15のStep 1（enum / struct 定義のコンパイル通し）から `Core/AssetDetection.mqh` の実装に着手する**こと。設計はここで一区切りとし、28章の未確定事項は実装しながら埋めていく。
