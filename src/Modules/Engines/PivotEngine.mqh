//+------------------------------------------------------------------+
//|                                                   PivotEngine.mqh |
//|                        Global Market Dashboard Ultimate (GMD)     |
//|                                                                   |
//|  役割 : Daily/Weekly/Monthly/Yearly のフロアピボットを計算し、   |
//|        現在価格との距離を数値化する                               |
//|  仕様 : Project Specification v1.8 第41章                         |
//|  状態 : [2.20+] 骨格。IsReady() は常に false。                    |
//|                                                                   |
//|  方針                                                             |
//|    ・Weekly を最優先表示                                          |
//|    ・Price Level とは独立。Nearest 統合は Dashboard 側            |
//|    ・Alert は自前で鳴らさない → AlertEngine に委譲                |
//|    ・確率表記はしない                                             |
//+------------------------------------------------------------------+
#property strict

#ifndef __GMD_PIVOT_ENGINE_MQH__
#define __GMD_PIVOT_ENGINE_MQH__

#include "../Core/Types.mqh"
#include "../Core/Logger.mqh"
#include "../Interfaces/IEngine.mqh"

//+------------------------------------------------------------------+
struct SPivotLevel
  {
   string axis;            // "D","W","M","Y"
   string name;            // "PP","R1","R2","R3","S1","S2","S3"
   double price;
   double distancePips;
   int    side;            // +1 R側, -1 S側, 0=PP
   color  proximityColor;
  };

//+------------------------------------------------------------------+
class CPivotEngine : public IEngine
  {
private:
   CLogger *m_log;
   string   m_symbol;
   bool     m_daily;
   bool     m_weekly;
   bool     m_monthly;
   bool     m_yearly;
   int      m_warn20;
   int      m_warn10;
   int      m_warn5;
   bool     m_ready;

public:
            CPivotEngine(void)
              : m_log(NULL), m_symbol(""),
                m_daily(true), m_weekly(true), m_monthly(true), m_yearly(false),
                m_warn20(20), m_warn10(10), m_warn5(5),
                m_ready(false) {}
           ~CPivotEngine(void) {}

   bool     Init(CLogger *logger, const string symbol)
     {
      m_log    = logger;
      m_symbol = symbol;
      m_ready  = false;
      if(m_log != NULL)
         m_log.Info("PivotEngine: reserved for [2.20+], Weekly preferred");
      return(true);
     }

   void     SetAxes(const bool daily, const bool weekly,
                    const bool monthly, const bool yearly)
     {
      m_daily   = daily;
      m_weekly  = weekly;
      m_monthly = monthly;
      m_yearly  = yearly;
     }

   void     SetAlertThresholds(const int warn20, const int warn10, const int warn5)
     {
      m_warn20 = warn20;
      m_warn10 = warn10;
      m_warn5  = warn5;
     }

   bool     Calculate(void) override
     {
      // [2.20+] 前期間 H/L/C からフロアピボットを計算
      m_ready = false;
      return(false);
     }

   bool     IsReady(void) override { return(m_ready); }
   string   GetName(void) override { return("Pivot"); }

   int      GetLevelCount(void) { return(0); }

   bool     GetLevel(const int /*index*/, SPivotLevel &out)
     {
      out.axis = "";
      out.name = "";
      out.price = 0.0;
      out.distancePips = 0.0;
      out.side = 0;
      out.proximityColor = clrGray;
      return(false);
     }

   bool     GetNearest(SPivotLevel &out)
     {
      return(GetLevel(0, out));
     }

   string   GetDisplayText(void)
     {
      return("Weekly Pivot  --  (Ver2.20+)");
     }

   string   GetCompactText(void)
     {
      return("");
     }
  };

#endif // __GMD_PIVOT_ENGINE_MQH__
//+------------------------------------------------------------------+
