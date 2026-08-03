2026-07-31

chatGPTの宿題で精一杯

GitHubまだまだ分からない事だらけ。でも楽しい。トレード負けにくくなった。ストップ注文出せるようになった。

2026/08/03

① Design Philosophy

ここは絶対に残しましょう。

「相場を見る」のではなく

「世界のお金の流れを見る」

これは、このソフトの「存在意義」です。

私はREADMEの最初にもこの一文を書きたいくらいです。

② Asset Detection → Market Regime Engine の流れ

ここが一番気に入りました。

Asset Detection
      ↓
データ取得
      ↓
Market Regime Engine
      ↓
Money Flow Engine
      ↓
Dashboard

これは設計として非常に分かりやすいです。

私なら、このままアーキテクチャ図として Architecture.md にも載せます。

③ Currency Strength

ロジックがシンプルです。

上昇
→ 分子 +1

下降
→ 分母 +1

後から

重み付け
ATR
ボラティリティ
Confidence

を追加しやすい設計です。
