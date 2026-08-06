//+------------------------------------------------------------------+
//|                                                   Constants.mqh   |
//|                        Global Market Dashboard Ultimate (GMD)     |
//|                                                                   |
//|  役割 : マジックナンバーと共通定数の集約                          |
//|  依存 : なし                                                      |
//|  導入 : レビュー指摘に基づき Types から分離                       |
//+------------------------------------------------------------------+
#property strict

#ifndef __GMD_CONSTANTS_MQH__
#define __GMD_CONSTANTS_MQH__

#define GMD_VERSION          "2.11.0"
#define GMD_OBJ_PREFIX       "GMD_"      // 全チャートオブジェクトの接頭辞
#define GMD_FX_PAIR_MAX      28          // 8C2 = 28ペア
#define GMD_CURRENCY_COUNT   8           // USD/EUR/GBP/JPY/AUD/CAD/CHF/NZD
#define GMD_CANDIDATE_MAX    12          // 1アセットあたりの候補名の最大数
#define GMD_ANOMALY_MAX      24          // 登録できるアノマリー規則の上限
#define GMD_ANOMALY_CAP      15          // 合計加点の上限（±）
#define GMD_RISK_BIAS_CAP     5          // 季節性から導くリスク志向バイアスの上限（±）
#define GMD_SESSION_MAX       4          // 東京 / ロンドン / NY / シドニー
#define GMD_ENERGY_LOOKBACK 100          // 圧縮度をパーセンタイル化する母数（本）
#define GMD_ENERGY_MIN_BARS 120          // これ未満しか履歴が無ければ算出しない

#endif // __GMD_CONSTANTS_MQH__
//+------------------------------------------------------------------+
