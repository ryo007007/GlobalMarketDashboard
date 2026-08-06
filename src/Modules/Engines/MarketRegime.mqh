//+------------------------------------------------------------------+
//|                                                 MarketRegime.mqh |
//|                        Global Market Dashboard Ultimate (GMD)     |
//|                                                                   |
//|  役割 : 相場全体が Risk-On か Risk-Off かを1つの値で示す          |
//|  依存 : Types.mqh, Logger.mqh, AssetDetection.mqh                 |
//|  仕様 : Project Specification v1.6 第7章                          |
//|                                                                   |
//|  状態 : [2.20] 未実装。枠のみ。                                   |
//|                                                                   |
//|  Ver2.20 で実装する内容                                           |
//|    ・VIX / JPY / Gold / 株価指数 の組み合わせで判定する           |
//|    ・REGIME_RISK_ON / NEUTRAL / RISK_OFF を返す                   |
//|    ・材料が足りないときは NEUTRAL ではなく IsReady()=false にする |
//|      （「中立」と「わからない」は別物として扱う）                 |
//+------------------------------------------------------------------+
#property strict

#ifndef __GMD_MARKETREGIME_MQH__
#define __GMD_MARKETREGIME_MQH__

#include "../Core/Types.mqh"
#include "../Core/Logger.mqh"
#include "../Core/AssetDetection.mqh"

//+------------------------------------------------------------------+
class CMarketRegime : public IEngine
  {
private:
   CAssetDetection *m_assets;
   CLogger         *m_log;

   ENUM_REGIME      m_regime;
   bool             m_ready;

public:
                     CMarketRegime(void);
                    ~CMarketRegime(void);

   bool              Init(CAssetDetection *assets, CLogger *logger);

   //--- IEngine
   bool              Calculate(void);
   bool              IsReady(void) { return(m_ready); }
   string            GetName(void) { return("MarketRegime"); }

   //--- 参照
   ENUM_REGIME       GetRegime(void)      { return(m_regime); }
   string            GetDisplayText(void) { return("Regime  --  [2.20]"); }
   color             GetColor(void)       { return(clrGray); }
  };

//+------------------------------------------------------------------+
CMarketRegime::CMarketRegime(void) : m_assets(NULL),
                                     m_log(NULL),
                                     m_regime(REGIME_NEUTRAL),
                                     m_ready(false)
  {
  }

//+------------------------------------------------------------------+
CMarketRegime::~CMarketRegime(void)
  {
  }

//+------------------------------------------------------------------+
bool CMarketRegime::Init(CAssetDetection *assets, CLogger *logger)
  {
   m_assets = assets;
   m_log    = logger;
   m_regime = REGIME_NEUTRAL;
   m_ready  = false;

   if(m_log != NULL)
      m_log.Debug("MarketRegime: reserved for Ver2.20. Not active.");

   return(true);
  }

//+------------------------------------------------------------------+
//| [2.20] 未実装。IsReady() は false のまま                          |
//+------------------------------------------------------------------+
bool CMarketRegime::Calculate(void)
  {
   m_ready = false;
   return(true);
  }

#endif // __GMD_MARKETREGIME_MQH__
//+------------------------------------------------------------------+
