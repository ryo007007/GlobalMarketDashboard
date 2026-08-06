//+------------------------------------------------------------------+
//|                                                        Types.mqh |
//|                        Global Market Dashboard Ultimate (GMD)     |
//|                                                                   |
//|  役割 : 全モジュール共通の列挙型・構造体・インターフェース定義     |
//|  依存 : なし（このファイルが依存の最下層）                        |
//|  仕様 : Project Specification v1.2 付録B                          |
//|                                                                   |
//|  重要 : 型定義は必ずこのファイルに集約する。                      |
//|         各モジュール内で個別に enum / struct を定義しないこと。   |
//+------------------------------------------------------------------+
#property copyright "GMD Project"
#property strict

#ifndef __GMD_TYPES_MQH__
#define __GMD_TYPES_MQH__

//+------------------------------------------------------------------+
//| 定数                                                              |
//+------------------------------------------------------------------+
#define GMD_VERSION          "2.11.0"
#define GMD_OBJ_PREFIX       "GMD_"      // 全チャートオブジェクトの接頭辞
#define GMD_FX_PAIR_MAX      28          // 8C2 = 28ペア
#define GMD_CURRENCY_COUNT   8           // USD/EUR/GBP/JPY/AUD/CAD/CHF/NZD
#define GMD_CANDIDATE_MAX    12          // 1アセットあたりの候補名の最大数
#define GMD_ANOMALY_MAX      24          // 登録できるアノマリー規則の上限
#define GMD_ANOMALY_CAP      15          // 合計加点の上限（±）。積み上げの暴走防止
#define GMD_RISK_BIAS_CAP     5          // 季節性から導くリスク志向バイアスの上限（±）
                                         //  株の季節性→リスク志向は二次推論のため
                                         //  アノマリー本体より狭い範囲に抑える
#define GMD_SESSION_MAX       4          // 東京 / ロンドン / NY / シドニー
#define GMD_ENERGY_LOOKBACK 100          // 圧縮度をパーセンタイル化する母数（本）
#define GMD_ENERGY_MIN_BARS 120          // これ未満しか履歴が無ければ算出しない

//+------------------------------------------------------------------+
//| 通貨インデックス                                                  |
//+------------------------------------------------------------------+
enum ENUM_CURRENCY
  {
   CUR_USD = 0,
   CUR_EUR,
   CUR_GBP,
   CUR_JPY,
   CUR_AUD,
   CUR_CAD,
   CUR_CHF,
   CUR_NZD,
   CUR_COUNT                       // 常に末尾（= 8）
  };

//+------------------------------------------------------------------+
//| 論理アセットID                                                    |
//|  内部では常にこのIDで参照し、生の銘柄文字列は使わない            |
//+------------------------------------------------------------------+
enum ENUM_ASSET_ID
  {
   //--- [2.11] 実装対象。まずはこの8つだけ
   ASSET_GOLD = 0,
   ASSET_SILVER,
   ASSET_US30,
   ASSET_NAS100,
   ASSET_SPX500,
   ASSET_JP225,
   ASSET_BTC,
   ASSET_ETH,

   //--- [2.20] 追加予定。コメントを外すだけで有効化できる（消さないこと）
   // ASSET_GER40,
   // ASSET_UK100,
   // ASSET_US10Y,
   // ASSET_US30Y,
   // ASSET_DXY,
   // ASSET_VIX,

   ASSET_COUNT                     // 常に末尾。配列サイズとして使う
  };

//+------------------------------------------------------------------+
//| アセットの状態                                                    |
//|  [2.11] UNKNOWN / OK / PENDING / UNAVAILABLE を使用              |
//|  [2.20] STALE の判定ロジックを追加                                |
//+------------------------------------------------------------------+
enum ENUM_ASSET_STATE
  {
   ASSET_UNKNOWN = 0,              // 未検出（初期値）
   ASSET_OK,                       // 検証通過。使用可能
   ASSET_PENDING,                  // 銘柄はあるがヒストリー同期待ち
   ASSET_STALE,                    // [2.20] 銘柄はあるが情報が古い
   ASSET_UNAVAILABLE               // このブローカーには存在しない
  };

//+------------------------------------------------------------------+
//| アセットのカテゴリ                                                |
//+------------------------------------------------------------------+
enum ENUM_ASSET_CATEGORY
  {
   CAT_FX = 0,
   CAT_METAL,
   CAT_INDEX,
   CAT_CRYPTO,
   CAT_BOND,
   CAT_OTHER
  };

//+------------------------------------------------------------------+
//| エンジン出力用                                                    |
//+------------------------------------------------------------------+
enum ENUM_FLOW_STATE               // [2.20] Money Flow Engine
  {
   FLOW_STRONG_OUTFLOW = -2,
   FLOW_OUTFLOW        = -1,
   FLOW_NEUTRAL        =  0,
   FLOW_INFLOW         =  1,
   FLOW_STRONG_INFLOW  =  2,
   FLOW_UNAVAILABLE    = 99
  };

enum ENUM_REGIME                   // [2.20] Market Regime Engine
  {
   REGIME_RISK_OFF = -1,
   REGIME_NEUTRAL  =  0,
   REGIME_RISK_ON  =  1
  };

enum ENUM_CONFIDENCE_LEVEL         // [2.11] Confidence Engine
  {
   CONF_LOW = 0,
   CONF_MEDIUM,
   CONF_HIGH
  };

enum ENUM_TRADE_DIRECTION          // [2.11] Best Pair Engine
  {
   DIR_NONE =  0,
   DIR_BUY  =  1,
   DIR_SELL = -1
  };

//+------------------------------------------------------------------+
//| アノマリーの適用範囲                            [2.11] Anomaly    |
//|  Sell in May は株の話で、通貨強弱に足してはいけない。            |
//|  どの資産に効く話なのかを規則自身に持たせて、混ぜないようにする。 |
//+------------------------------------------------------------------+
enum ENUM_ANOMALY_SCOPE
  {
   SCOPE_NONE   = 0,
   SCOPE_FX     = 1,        // 通貨ペア全般
   SCOPE_JPY    = 2,        // 円が絡むペアのみ（五十日など）
   SCOPE_EQUITY = 3,        // 株価指数
   SCOPE_BOND   = 4,        // 債券
   SCOPE_METAL  = 5,        // 金・銀
   SCOPE_CRYPTO = 6         // 暗号資産
  };

//+------------------------------------------------------------------+
//| 季節性の状態                                    [2.11] Anomaly    |
//+------------------------------------------------------------------+
enum ENUM_SEASON_STATE
  {
   SEASON_BEAR    = -1,
   SEASON_NEUTRAL =  0,
   SEASON_BULL    =  1
  };

//+------------------------------------------------------------------+
//| リスク志向バイアス                              [2.11] Anomaly    |
//|  株の季節性から「リスクを取りやすい季節か」だけを導く。          |
//|  どの通貨が買われるかは言わない。それは価格を読む               |
//|  CurrencyStrength の担当である（仕様書10.13）。                  |
//+------------------------------------------------------------------+
enum ENUM_RISK_BIAS
  {
   RISK_BIAS_OFF  = -1,
   RISK_BIAS_FLAT =  0,
   RISK_BIAS_ON   =  1
  };

//+------------------------------------------------------------------+
//| 市場セッション                                  [2.11] Session    |
//+------------------------------------------------------------------+
enum ENUM_SESSION
  {
   SESSION_SYDNEY = 0,
   SESSION_TOKYO,
   SESSION_LONDON,
   SESSION_NEWYORK,
   SESSION_COUNT                   // 常に末尾（= 4）
  };

//+------------------------------------------------------------------+
//| セッションに対する現在位置                      [2.11] Session    |
//|  Pre  : 開始前の警戒帯（既定15分前から）                          |
//|  Open : 開始直後の急変帯（既定30分間）                            |
//|  Core : 通常の取引時間内                                          |
//|  Off  : 時間外                                                    |
//+------------------------------------------------------------------+
enum ENUM_SESSION_PHASE
  {
   PHASE_OFF = 0,
   PHASE_PRE,
   PHASE_OPEN,
   PHASE_CORE
  };

//+------------------------------------------------------------------+
//| 更新間隔の段                                    [2.11] Adaptive   |
//|  「速い＝良い」ではない。段は3つに絞る。                          |
//|  段を増やすと、いま何msで動いているのか誰も追えなくなる。         |
//+------------------------------------------------------------------+
enum ENUM_UPDATE_TIER
  {
   TIER_IDLE   = 0,                // 静かな時間帯。負荷を落とす
   TIER_NORMAL = 1,                // 平常
   TIER_ALERT  = 2                 // セッション開始前後・高圧縮時
  };

//+------------------------------------------------------------------+
//| エネルギー（圧縮）の状態                        [2.20] Energy     |
//|                                                                   |
//|  重要 : このエンジンは「どちらへ動くか」を一切示さない。          |
//|         示すのは「動く準備ができているか」だけである。            |
//|         方向を知りたければ CurrencyStrength を見る。              |
//+------------------------------------------------------------------+
enum ENUM_ENERGY_STATE
  {
   ENERGY_UNAVAILABLE = 0,         // 履歴不足などで算出できない
   ENERGY_NORMAL,                  // 圧縮していない
   ENERGY_BUILDING,                // 圧縮が進んでいる
   ENERGY_LOADED,                  // 高圧縮が継続している
   ENERGY_RELEASED                 // 圧縮が解けた直後。ここが事象である
  };

//+------------------------------------------------------------------+
//| 市場状態                                        [2.30] MarketState|
//|                                                                   |
//|  観測できるものだけを状態にする。                                 |
//|  「天井」「反転」は後から振り返って初めて分かるため、             |
//|  現在の状態としては表示しない（仕様書38.3）。                     |
//+------------------------------------------------------------------+
enum ENUM_MARKET_STATE
  {
   STATE_UNKNOWN = 0,
   STATE_QUIET,                    // 静か。圧縮も方向も無い
   STATE_BUILDING,                 // 圧縮が進行
   STATE_EXPANSION,                // 圧縮が解けて値幅が出た
   STATE_TRENDING                  // 方向が継続している
  };

//+------------------------------------------------------------------+
//| 通知の重大度                                    [2.30] Alert      |
//+------------------------------------------------------------------+
enum ENUM_ALERT_LEVEL
  {
   ALERT_INFO = 0,
   ALERT_NOTICE,
   ALERT_IMPORTANT
  };

//+------------------------------------------------------------------+
//| システム                                                          |
//+------------------------------------------------------------------+
enum ENUM_LOG_LEVEL
  {
   LOG_OFF = 0,
   LOG_ERROR,
   LOG_WARN,
   LOG_INFO,
   LOG_DEBUG
  };

enum ENUM_DISPLAY_MODE             // [2.30] 表示モード切替
  {
   MODE_CHART = 0,
   MODE_DASHBOARD,
   MODE_HYBRID,
   MODE_MINIMAL
  };

//+------------------------------------------------------------------+
//| 構造体：1アセットの検出結果                                       |
//+------------------------------------------------------------------+
struct SAssetInfo
  {
   ENUM_ASSET_ID       id;             // 論理ID
   ENUM_ASSET_CATEGORY category;       // カテゴリ
   string              logicalName;    // 表示用の名前（"Gold" 等）
   string              symbol;         // 実際の銘柄名（"XAUUSD.a" 等）
   ENUM_ASSET_STATE    state;          // 現在の状態
   int                 digits;         // 小数点以下桁数
   int                 barsAvailable;  // 利用可能なバー本数
   datetime            lastTickTime;   // 最終ティック時刻
   datetime            detectedAt;     // 検出した時刻
   int                 retryCount;     // [2.20] 再試行回数
   string              note;           // 補足（エラーコード等）
  };

//+------------------------------------------------------------------+
//| 構造体：FX 1ペアの情報                                            |
//+------------------------------------------------------------------+
struct SFxPair
  {
   ENUM_CURRENCY       base;           // 基軸通貨
   ENUM_CURRENCY       quote;          // 決済通貨
   string              symbol;         // 実際の銘柄名
   bool                inverted;       // 逆順で見つかった場合 true
   bool                available;      // 使用可能か
  };

//+------------------------------------------------------------------+
//| アノマリー規則の1件                             [2.11] Anomaly    |
//|  規則は「表」として持つ。判定を if の羅列で書くと、               |
//|  1つ足すたびに関数が伸びて、どこを触ればよいか分からなくなる。    |
//+------------------------------------------------------------------+
struct SAnomalyRule
  {
   string              code;           // 識別子 "GOTOBI" など
   string              label;          // 表示名 "五十日"
   ENUM_ANOMALY_SCOPE  scope;          // どの資産に効く話か
   int                 score;          // 該当時の加点（符号付き）
   int                 stars;          // 根拠の強さ 1〜5（表示と選別用）
   bool                enabled;        // 個別ON/OFF
   bool                implemented;    // false = [2.20]以降の予約
  };

//+------------------------------------------------------------------+
//| 判定結果1件                                     [2.11] Anomaly    |
//+------------------------------------------------------------------+
struct SAnomalyHit
  {
   string              code;
   string              label;
   int                 score;
   ENUM_ANOMALY_SCOPE  scope;
  };

//+------------------------------------------------------------------+
//| 構造体：検出結果レジストリ（= L1キャッシュの実体）                |
//+------------------------------------------------------------------+
struct SAssetRegistry
  {
   SAssetInfo          assets[ASSET_COUNT];
   SFxPair             fxPairs[GMD_FX_PAIR_MAX];
   int                 fxPairCount;    // 実際に見つかったペア数
   string              detectedSuffix; // 推定したサフィックス（".a" 等）
   string              detectedPrefix; // 推定したプレフィックス
   datetime            builtAt;        // 構築時刻
   int                 okCount;        // OK状態の数
   int                 unavailableCount;
  };

//+------------------------------------------------------------------+
//| インターフェース：すべての分析エンジンが実装する                  |
//+------------------------------------------------------------------+
interface IEngine
  {
   bool    Calculate(void);        // 計算実行。成功で true
   bool    IsReady(void);          // 表示可能な状態か
   string  GetName(void);          // ログ用の名前
  };

//+------------------------------------------------------------------+
//| 共通ヘルパー：列挙型 → 文字列                                     |
//+------------------------------------------------------------------+
string AssetStateToString(const ENUM_ASSET_STATE state)
  {
   switch(state)
     {
      case ASSET_OK:          return("OK");
      case ASSET_PENDING:     return("PENDING");
      case ASSET_STALE:       return("STALE");
      case ASSET_UNAVAILABLE: return("UNAVAILABLE");
      default:                return("UNKNOWN");
     }
  }

string CurrencyToString(const ENUM_CURRENCY cur)
  {
   switch(cur)
     {
      case CUR_USD: return("USD");
      case CUR_EUR: return("EUR");
      case CUR_GBP: return("GBP");
      case CUR_JPY: return("JPY");
      case CUR_AUD: return("AUD");
      case CUR_CAD: return("CAD");
      case CUR_CHF: return("CHF");
      case CUR_NZD: return("NZD");
      default:      return("???");
     }
  }

string AnomalyScopeToString(const ENUM_ANOMALY_SCOPE scope)
  {
   switch(scope)
     {
      case SCOPE_FX:     return("FX");
      case SCOPE_JPY:    return("JPY");
      case SCOPE_EQUITY: return("Equity");
      case SCOPE_BOND:   return("Bond");
      case SCOPE_METAL:  return("Metal");
      case SCOPE_CRYPTO: return("Crypto");
      default:           return("None");
     }
  }

string SeasonStateToString(const ENUM_SEASON_STATE s)
  {
   switch(s)
     {
      case SEASON_BULL: return("Bull");
      case SEASON_BEAR: return("Bear");
      default:          return("Neutral");
     }
  }

string RiskBiasToString(const ENUM_RISK_BIAS b)
  {
   switch(b)
     {
      case RISK_BIAS_ON:  return("risk-on bias");
      case RISK_BIAS_OFF: return("risk-off bias");
      default:            return("no bias");
     }
  }

string SessionToString(const ENUM_SESSION s)
  {
   switch(s)
     {
      case SESSION_SYDNEY:  return("Sydney");
      case SESSION_TOKYO:   return("Tokyo");
      case SESSION_LONDON:  return("London");
      case SESSION_NEWYORK: return("NewYork");
      default:              return("?");
     }
  }

string SessionPhaseToString(const ENUM_SESSION_PHASE p)
  {
   switch(p)
     {
      case PHASE_PRE:  return("Pre");
      case PHASE_OPEN: return("Open");
      case PHASE_CORE: return("Core");
      default:         return("Off");
     }
  }

string UpdateTierToString(const ENUM_UPDATE_TIER t)
  {
   switch(t)
     {
      case TIER_IDLE:  return("Idle");
      case TIER_ALERT: return("Alert");
      default:         return("Normal");
     }
  }

string EnergyStateToString(const ENUM_ENERGY_STATE e)
  {
   switch(e)
     {
      case ENERGY_NORMAL:   return("Normal");
      case ENERGY_BUILDING: return("Building");
      case ENERGY_LOADED:   return("Loaded");
      case ENERGY_RELEASED: return("Released");
      default:              return("--");
     }
  }

string MarketStateToString(const ENUM_MARKET_STATE m)
  {
   switch(m)
     {
      case STATE_QUIET:     return("Quiet");
      case STATE_BUILDING:  return("Building");
      case STATE_EXPANSION: return("Expansion");
      case STATE_TRENDING:  return("Trending");
      default:              return("--");
     }
  }

string AssetCategoryToString(const ENUM_ASSET_CATEGORY cat)
  {
   switch(cat)
     {
      case CAT_FX:     return("FX");
      case CAT_METAL:  return("Metal");
      case CAT_INDEX:  return("Index");
      case CAT_CRYPTO: return("Crypto");
      case CAT_BOND:   return("Bond");
      default:         return("Other");
     }
  }

#endif // __GMD_TYPES_MQH__
//+------------------------------------------------------------------+
