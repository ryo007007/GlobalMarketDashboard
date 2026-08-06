//+------------------------------------------------------------------+
//|                                                  MarketState.mqh |
//|                        Global Market Dashboard Ultimate (GMD)     |
//|                                                                   |
//|  役割 : 各エンジンの結果を1つの「市場の状態」に畳む              |
//|  依存 : Types.mqh, Logger.mqh, CurrencyStrength, Energy, Anomaly  |
//|  仕様 : Project Specification v1.5 第38章                         |
//|                                                                   |
//|  状態 : [2.30] 未実装。枠だけ置いてある。                         |
//|                                                                   |
//|  ============ なぜ Ver2.30 まで待つのか ============              |
//|                                                                   |
//|  このエンジンは他の4つ（Strength / Flow / Energy / Anomaly）の    |
//|  出力を材料にする。材料が揃っていない段階で統合層を書くと、       |
//|  材料側の仕様が変わるたびにここを書き直すことになる。             |
//|  MoneyFlow が動くのが Ver2.20 なので、その次が最短である。        |
//|                                                                   |
//|  ============ 状態を4つに絞った理由 ============                  |
//|                                                                   |
//|  提案では                                                         |
//|    Normal → Quiet → Energy Building → Breakout →                  |
//|    Trend → Exhaustion → Reversal                                  |
//|  という7段の流れになっていた。前半5つは観測できる。               |
//|  だが Exhaustion（天井）と Reversal（転換）は違う。               |
//|                                                                   |
//|  「ここが天井だった」と言えるのは、下がったあとである。           |
//|  下がる前に天井だと言い切れるなら、それは指標ではなく予言である。 |
//|  現在の状態として画面に出すと、いちばん外してほしくない場面で     |
//|  いちばん自信ありげに間違える。                                   |
//|                                                                   |
//|  よって実装するのは、いま観測できる4つだけとする。                |
//|                                                                   |
//|    STATE_QUIET     圧縮も方向も無い                               |
//|    STATE_BUILDING  圧縮が進行している（Energy >= 60）             |
//|    STATE_EXPANSION 圧縮が解けて値幅が出た（Energy RELEASED）      |
//|    STATE_TRENDING  方向が継続している（ADX上昇 + 強弱の偏り）     |
//|                                                                   |
//|  Exhaustion / Reversal は「事後ラベル」として                     |
//|  ログにだけ残す方式を Ver3.00 で検討する（38.5）。                |
//|                                                                   |
//|  ============ 実装時の判定材料 ============                       |
//|                                                                   |
//|    Energy         : 圧縮の水準と RELEASED の有無                  |
//|    CurrencyStrength : 1位と8位の点差（方向の明確さ）              |
//|    MoneyFlow      : リスクの向き                                  |
//|    Anomaly        : 季節の追い風（従。単独で状態を変えない）      |
//|                                                                   |
//|  重み配分は 38.4 に定める。暦（Anomaly）が価格を上回る影響を      |
//|  持ってはならない、という原則は 10.13.5 と同じである。            |
//+------------------------------------------------------------------+
#property strict

#ifndef __GMD_MARKETSTATE_MQH__
#define __GMD_MARKETSTATE_MQH__

#include "../Core/Types.mqh"
#include "../Core/Logger.mqh"

//+------------------------------------------------------------------+
class CMarketState : public IEngine
  {
private:
   CLogger          *m_log;
   ENUM_MARKET_STATE m_state;
   ENUM_MARKET_STATE m_prev;
   int               m_barsInState;
   bool              m_ready;

public:
                     CMarketState(void);
                    ~CMarketState(void);

   bool              Init(CLogger *logger);

   bool              Calculate(void);
   bool              IsReady(void) { return(m_ready); }
   string            GetName(void) { return("MarketState"); }

   ENUM_MARKET_STATE GetState(void)      { return(m_state); }
   int               GetBarsInState(void){ return(m_barsInState); }
   bool              HasChanged(void)    { return(m_state != m_prev); }

   string            GetDisplayText(void);
   string            GetAdviceText(void);
   color             GetColor(void);
  };

//+------------------------------------------------------------------+
CMarketState::CMarketState(void) : m_log(NULL),
                                   m_state(STATE_UNKNOWN),
                                   m_prev(STATE_UNKNOWN),
                                   m_barsInState(0),
                                   m_ready(false)
  {
  }

CMarketState::~CMarketState(void) {}

//+------------------------------------------------------------------+
bool CMarketState::Init(CLogger *logger)
  {
   m_log   = logger;
   m_state = STATE_UNKNOWN;
   m_ready = false;      // [2.30] で true にする

   if(m_log != NULL)
      m_log.Info("MarketState: reserved for [2.30]");
   return(true);
  }

//+------------------------------------------------------------------+
bool CMarketState::Calculate(void)
  {
   //--- [2.30] で実装
   m_prev  = m_state;
   m_state = STATE_UNKNOWN;
   return(false);
  }

//+------------------------------------------------------------------+
string CMarketState::GetDisplayText(void)
  {
   if(!m_ready)
      return("State   --  [2.30]");

   return(StringFormat("State   %s", MarketStateToString(m_state)));
  }

//+------------------------------------------------------------------+
//| 状態に対応する一言。売買指示ではなく「いま何を待つ場面か」        |
//+------------------------------------------------------------------+
string CMarketState::GetAdviceText(void)
  {
   switch(m_state)
     {
      case STATE_QUIET:     return("待機");
      case STATE_BUILDING:  return("ブレイク待ち");
      case STATE_EXPANSION: return("方向確認中");
      case STATE_TRENDING:  return("追随可");
      default:              return("--");
     }
  }

//+------------------------------------------------------------------+
color CMarketState::GetColor(void)
  {
   if(!m_ready)
      return(clrGray);

   switch(m_state)
     {
      case STATE_EXPANSION: return(clrRed);
      case STATE_QUIET:     return(clrDodgerBlue);
      default:              return(clrWhite);
     }
  }

#endif // __GMD_MARKETSTATE_MQH__
//+------------------------------------------------------------------+
