//+------------------------------------------------------------------+
//|                                              StatisticsEngine.mqh |
//|                        Global Market Dashboard Ultimate (GMD)     |
//|                                                                   |
//|  役割 : 勝率・平均値幅・ATR・曜日/月別統計など、履歴ベースの     |
//|        統計情報を担当する。[3.00] 予約枠。                        |
//|  状態 : 骨格のみ。IsReady() は常に false。                        |
//|  依存 : Types / Logger                                            |
//+------------------------------------------------------------------+
#property strict

#ifndef __GMD_STATISTICS_ENGINE_MQH__
#define __GMD_STATISTICS_ENGINE_MQH__

#include "../Core/Types.mqh"
#include "../Core/Logger.mqh"
#include "../Interfaces/IEngine.mqh"

//+------------------------------------------------------------------+
class CStatisticsEngine : public IEngine
  {
private:
   CLogger *m_log;
   bool     m_ready;

public:
            CStatisticsEngine(void) : m_log(NULL), m_ready(false) {}
           ~CStatisticsEngine(void) {}

   bool     Init(CLogger *logger)
     {
      m_log   = logger;
      m_ready = false;
      return(true);
     }

   bool     Calculate(void) override
     {
      m_ready = false;
      return(false);
     }

   bool     IsReady(void) override { return(m_ready); }
   string   GetName(void) override { return("StatisticsEngine"); }

   string   GetDisplayText(void)
     {
      return("Statistics  --  (Ver3.00)");
     }
  };

#endif // __GMD_STATISTICS_ENGINE_MQH__
//+------------------------------------------------------------------+
