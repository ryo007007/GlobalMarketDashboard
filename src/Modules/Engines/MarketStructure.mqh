//+------------------------------------------------------------------+
//|                                               MarketStructure.mqh |
//|                        Global Market Dashboard Ultimate (GMD)     |
//|                                                                   |
//|  役割 : 大波・中波・小波、200BBの位置、サイクル位相を一つの       |
//|        「相場構造」として記述する                                 |
//|  仕様 : Project Specification v1.9 第42章                         |
//|  状態 : [2.30+] 骨格。IsReady() は常に false。                    |
//|                                                                   |
//|  これはシグナルエンジンではない。構造の記述だけを返す。           |
//+------------------------------------------------------------------+
#property strict

#ifndef __GMD_MARKET_STRUCTURE_MQH__
#define __GMD_MARKET_STRUCTURE_MQH__

#include "../Core/Types.mqh"
#include "../Core/Logger.mqh"
#include "../Interfaces/IEngine.mqh"

//+------------------------------------------------------------------+
enum ENUM_WAVE_DIR
  {
   WAVE_FLAT = 0,
   WAVE_UP,
   WAVE_DOWN,
   WAVE_TURN_UP,
   WAVE_TURN_DOWN
  };

//+------------------------------------------------------------------+
class CMarketStructure : public IEngine
  {
private:
   CLogger         *m_log;
   string           m_symbol;
   ENUM_TIMEFRAMES  m_macroTf;
   ENUM_TIMEFRAMES  m_interTf;
   ENUM_TIMEFRAMES  m_microTf;
   int              m_bbPeriod;
   bool             m_ready;

public:
                    CMarketStructure(void)
                      : m_log(NULL), m_symbol(""),
                        m_macroTf(PERIOD_D1), m_interTf(PERIOD_H4),
                        m_microTf(PERIOD_M15), m_bbPeriod(200),
                        m_ready(false) {}
                   ~CMarketStructure(void) {}

   bool             Init(CLogger *logger, const string symbol,
                         const ENUM_TIMEFRAMES macroTf = PERIOD_D1,
                         const ENUM_TIMEFRAMES interTf = PERIOD_H4,
                         const ENUM_TIMEFRAMES microTf = PERIOD_M15,
                         const int bbPeriod = 200)
     {
      m_log      = logger;
      m_symbol   = symbol;
      m_macroTf  = macroTf;
      m_interTf  = interTf;
      m_microTf  = microTf;
      m_bbPeriod = (bbPeriod < 20 ? 200 : bbPeriod);
      m_ready    = false;
      if(m_log != NULL)
         m_log.Info("MarketStructure: reserved for [2.30+]");
      return(true);
     }

   bool             Calculate(void) override
     {
      m_ready = false;
      return(false);
     }

   bool             IsReady(void) override { return(m_ready); }
   string           GetName(void) override { return("MarketStructure"); }

   ENUM_WAVE_DIR    GetMacro(void)         { return(WAVE_FLAT); }
   ENUM_WAVE_DIR    GetIntermediate(void)  { return(WAVE_FLAT); }
   ENUM_WAVE_DIR    GetMicro(void)         { return(WAVE_FLAT); }

   string           GetStructureLabel(void)   { return("--"); }
   string           GetCyclePhaseText(void)   { return("--"); }
   string           GetBb200PositionText(void){ return("--"); }

   string           GetDisplayText(void)
     {
      return("Market Structure  --  (Ver2.30+)");
     }
  };

#endif // __GMD_MARKET_STRUCTURE_MQH__
//+------------------------------------------------------------------+
