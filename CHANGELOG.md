# Changelog

## Test Coverage & Docs (2026-08-06)

### tests（Engine 1:1 対応）

- `Test_BestPair.mq5` 追加（実在銘柄・inverted・点差）
- `Test_AlertEngine.mq5` 追加（[2.30] プレースホルダ）
- `Test_MarketState.mq5` 追加（[2.30] プレースホルダ）
- `Test_CorrelationEngine.mq5` 追加（[3.00] プレースホルダ）
- `Test_StatisticsEngine.mq5` 追加（[3.00] プレースホルダ）

### docs

- `docs/EngineIndex.md` 追加（Engine ↔ Test 対応表）
- README のテスト一覧を全エンジン対応に更新

### 方針の再確認

- `MarketDashboard_Ultimate.mq5` は結線のみ。計算はすべて Engine 側
- 未実装 Engine のテストは「落ちない・IsReady=false」を確認するだけ

---

## Structural Improvements (2026-08-06)

### Display 分割

- `SummaryPanel.mqh` 追加（Best Pair / Confidence / Regime 行の受け皿）
- `RankingPanel.mqh` 追加（通貨強弱ランキング 8 行の受け皿）
- `MoneyFlowPanel.mqh` 追加（[2.20] 資金フロー行の受け皿）
- `StatusBar.mqh` 追加（フッター：更新間隔・段・時刻）
- `ChartOverlay.mqh` 追加（[2.30+] Hybrid モード用チャート要素）
- 原則：先に動く Dashboard を壊さず、骨格を置いて段階的に切り出す

### Engines（将来予約）

- `CorrelationEngine.mqh` 追加（[3.00] 相関係数エンジンの枠）
- `StatisticsEngine.mqh` 追加（[3.00] 統計エンジンの枠）

### Docs / README

- `README.md` を強化（Features 表・Screenshots 枠・インストール・構成・Roadmap）
- `ROADMAP.md` を詳細化（Ver2.11〜4.00 の到達目標と推奨実装順）
- `docs/Architecture.md` を Display 分割・将来 Engine に同期
- `examples/README.md` / `docs/images/README.md` を追加（配置ガイド）

---

## v2.11

Project Started

Initial Repository

### Core

- `Types.mqh` 追加。全モジュール共通の enum / struct / `IEngine` を一箇所に集約
- `Logger.mqh` 追加。5段階のログレベルとエラーコード（`[GMD][WARN][CS-101]` 形式）
- `AssetDetection.mqh` 追加。接尾辞の自動検出、8アセット・28通貨ペアの検証
- `Utils.mqh` 追加。桁揃え・時間足表記・更新間隔判定などの汎用関数
- `SessionClock.mqh` 追加。セッションを**現地時刻**で定義し、GMT差と夏時間から
  現在の局面（Off / Pre / Open / Core）を判定
  - 夏時間は 欧州 / 米国 / 豪州 を**独立に**計算。フラグ1つでは足りない。
    米国は3月第2日曜に始まり11月第1日曜に終わる、欧州は3月最終日曜〜10月最終日曜。
    年3週間ほど両者はずれ、その間ロンドン・ニューヨークの時差は5時間ではなく4時間になる
  - ニューヨークのセッション開始は **08:30 ET**。CPI・雇用統計・小売売上高は
    すべてこの時刻に出る。株式の 09:30 ET は「節目」として別に保持
  - 東京は 09:00 開始・夏時間なし・09:55 を仲値の節目として保持
  - GMT は `TimeGMT()` ではなく `TimeCurrent()` からサーバGMT差を引いて求める。
    `TimeGMT()` はストラテジーテスターで端末の現在時刻を返すため使えない
  - `DstEuropeAt()` / `DstUsAt()` を検証用に公開。夏時間の境界は年4回しか
    来ないので、実運用だけでは正しさを確認できない

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
- `AdaptiveUpdate.mqh` 追加。更新間隔を市場の状況で切り替える
  - 段は **3つだけ**（Idle 2000ms / Normal 1000ms / Alert 300ms）。
    細かく刻むと不具合報告時に「何msで回っていたか」を再現できなくなる
  - 目的は速くすることではなく**無駄をやめること**。どこも開いていない時間を
    2000msに落とすほうが先。1日の総計算回数は約86,400から約60,000に減る（推定）
  - ヒステリシス（既定60秒）は**遅くする方向にのみ**適用。速くする方向は即時。
    両方向に効かせると急変に乗り遅れ、両方向を即時にすると境界で暴れる
  - `Evaluate()` は段が変わったときだけ true を返す。タイマーの張り直しは
    本体が行う。張り直しの瞬間にイベントが1回落ちることがあるため回数を絞る
  - 内部で 100ms を下限に丸める。MT5のタイマーはそれより細かい保証をしない
- `EnergyEngine.mqh` 追加。値幅の圧縮の蓄積を 0〜100 で数値化
  - **「%」と呼ばない。** 0〜100は確率ではない。`Energy 92%` と書くと
    「92%の確率でブレイクする」と誤読される
  - 材料を **3軸に畳んだ**（圧縮50 / 無方向30 / 参加20）。ATR・BB幅・ADX・
    レンジ継続は同じ現象を4つの角度から見ているだけで、足すと四重計上になり
    指標が 0 か 100 の二値に張り付く
  - 軸1では ATR比 と BB幅 を足さず **min** を取る。両者は互いを裏付ける関係で、
    min にすると「両方が縮んでいるときだけ高い」という厳しい判定になる
  - すべて過去100本の**パーセンタイル順位**に変換。絶対値では USDJPY と
    XAUUSD と BTCUSD を同じ閾値で扱えない。銘柄・時間足を変えても調整不要
  - 材料不足は `ENERGY_UNAVAILABLE` で灰色表示。**0 を返さない**。
    0 は「圧縮していない」の意味であり、「不明」に流用できない
  - 状態機械 NORMAL → BUILDING → LOADED → **RELEASED**。
    水準（Energy 92）は数日続くが、事象は「解けた瞬間」だけ。赤は RELEASED のみ。
    LOADED を赤にするとパネルが数日赤いままになり、赤の意味が消える
  - **方向は予測しない。** 巻いたバネが上に跳ぶか下に跳ぶかは巻き具合から
    分からない。分かるのは「跳ぶ準備ができているか」だけ
- `MoneyFlow.mqh` / `MarketRegime.mqh` は枠のみ（Ver2.20で実装）
- `MarketState.mqh` / `AlertEngine.mqh` は枠のみ（Ver2.30で実装）
  - MarketState は観測できる4状態（Quiet / Building / Expansion / Trending）に限定。
    Exhaustion と Reversal は下がったあとにしか言えないため、現在の状態として
    表示しない。表示すると「いちばん外してほしくない場面でいちばん自信ありげに
    間違える」。事後ラベルとしてログに残す方式を Ver3.00 で検討
  - AlertEngine は水準ではなく**遷移**で発火。エッジ検出・ヒステリシス・冷却を
    Engine の内部に持つ。呼び出し側に置くと通知を増やすたびに書き忘れる。
    既定チャネルはパネル表示と Print のみ。`Alert()` と音は明示的に有効化

### Display

- `DrawObjects.mqh` 追加。オブジェクトの生成・差分更新・一括削除
- `Dashboard.mqh` 追加。ランキング8行 + Best Pair + Confidence + Anomaly
  + Season + **Energy** + **Session** + Regime の1枚パネル（全20行）
- フッターに現在の更新間隔と段を常時表示（`1000ms Normal`）。
  可変にした以上、隠すと性能問題の切り分けができない

### Main

- `MarketDashboard_Ultimate.mq5` 追加。Core → Engines → Display の結線
- 更新はタイマー方式。毎ティック計算しない
- 足の確定時のみ更新するモードを追加
- `ApplyAdaptiveTimer()` を追加。段が変わったときだけ `EventKillTimer()` /
  `EventSetMillisecondTimer()` を呼ぶ
- `OnDeinit` で `g_energy.Deinit()` を呼び、指標ハンドルを必ず返す

### Docs

- `docs/ProjectSpecification.md` を v1.5 に更新

---

## 仕様変更の記録

### v1.5 (仕様書)

- **Part VII（36〜39章）を新設**
  - 36. Adaptive Update Engine — 3段の可変更新、現地時刻でのセッション定義、
    地域別の夏時間、NY 08:30 ET、非対称ヒステリシス
  - 37. Energy Engine — 3軸のパーセンタイル化、min の採用、「%」と呼ばない、
    RELEASED のみを事象として扱う状態機械
  - 38. Market State Engine `[2.30]` — 観測可能な4状態に限定した理由
  - 39. Alert Engine `[2.30]` — 通知機能で必ず起きる5つの失敗と対策
- 4章の図に SessionClock / EnergyEngine / AdaptiveUpdate を追記
- 18章のツリーに新規5ファイルを追加。時刻判定を SessionClock に集約する原則を明記
- 21.3〜21.5 に入力パラメータ表を追加（Session / Adaptive / Energy）
- 27.0 に S8〜S10、27.6 にテストスクリプト一覧を追加
- 31.3 に `EN` / `SC` / `AU` / `MS` / `AL` を追加
- 34章に L16〜L20 を追加（相対順位の限界、ティック数の業者依存、1銘柄制限、
  祝日テーブル未対応、サーバGMT差の入力が2系統ある問題）

### v1.3 (仕様書)

- 通貨強弱を「1本の陰陽線」から「直近N本の重み付き集計」に変更
- 矢印を水準ではなく勢いの指標として分離（7段階）
- 段階色（6色グラデーション）を廃止し、赤・白・青の3色に簡素化
- 7通貨・28ペアという記述の誤りを修正（28ペアは8通貨の組み合わせ）
- NZD を対象通貨に追加
