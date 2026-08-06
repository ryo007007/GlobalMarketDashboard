# Roadmap — Global Market Dashboard Ultimate

本ファイルは実装の優先順位と到達目標を示す。  
詳細仕様は `docs/ProjectSpecification.md` を正本とする。

---

## Ver2.11 — 基盤固め（現在）

**成功基準**：通貨強弱・ランキング・Best Pair・Confidence・シンボル自動検出・Dashboard が安定して動くこと。全部入りを目指さない。

| モジュール | 状態 | 備考 |
|------------|------|------|
| Asset Detection | ✅ | 接尾辞検出・Validation・Cache |
| Currency Strength | ✅ | 8通貨・28ペア・重み付き集計 |
| Best Pair | ✅ | 最強×最弱・方向解釈 |
| Confidence | ✅ | 暫定式 0〜100% |
| Anomaly Engine | ✅ | 暦規則・季節性・scope 分離 |
| Energy Engine | ✅ | 3軸パーセンタイル・状態機械 |
| Adaptive Update | ✅ | Idle / Normal / Alert の3段 |
| Session Clock | ✅ | 現地時刻・地域別夏時間 |
| Dashboard | ✅ | 1枚パネル統括 |
| Display 分割パネル | 🟡 骨格 | Summary / Ranking / MoneyFlow / StatusBar / ChartOverlay |
| 単体テスト群 | ✅ | tests/ 配下 |

---

## Ver2.20 — 資金フローとレジーム

| モジュール | 内容 |
|------------|------|
| Money Flow | 株・貴金属・暗号・債券の資金流出入判定 |
| Market Regime | Risk ON / OFF / Neutral の合成スコア |
| Symbol Cache (L2) | CSV 永続化キャッシュ |
| Session Manager | 多市場セッション統括の受け皿を本格化 |
| MoneyFlowPanel | Display 側の本実装 |

---

## Ver2.30 — 状態と通知

| モジュール | 内容 |
|------------|------|
| Market State | Quiet / Building / Expansion / Trending の4状態 |
| Alert Engine | 遷移検出・ヒステリシス・冷却付き通知 |
| Display Mode | Chart / Dashboard / Hybrid / Minimal の完成 |
| ChartOverlay | Hybrid モード用チャート要素 |
| Economic Events | 主要指標カウントダウン |

---

## Ver3.00 — 分析拡張

| モジュール | 内容 |
|------------|------|
| **Correlation Engine** | 主要アセット間の相関係数 |
| **Statistics Engine** | 勝率・ATR・曜日/月別統計 |
| Flow Analysis | Money Rotation（資金循環） |
| Bond Analysis | 債券特化分析 |

---

## Ver4.00 — 予測とポートフォリオ

| モジュール | 内容 |
|------------|------|
| Analytics Engine | 統計・クラスタリング |
| Prediction | パターン検出・確率推奨 |
| Portfolio Analysis | 複数ポジション文脈 |

---

## 実装の進め方（推奨順）

1. Currency Strength / Best Pair / Confidence の安定化とテスト強化
2. Asset Detection のエッジケース（週末・未対応銘柄）固め
3. Dashboard の見た目と差分更新の磨き込み
4. Display パネルへの段階的切り出し
5. Ver2.20 の Money Flow / Market Regime 実装

> 新しいフォルダを増やすより、**各 Engine を1つずつ完成させてテストを書き、Dashboard につなぐ**ことに集中する。
