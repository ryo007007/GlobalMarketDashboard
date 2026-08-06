//+------------------------------------------------------------------+
//|                                              PriceLevelEngine.mqh |
//|                        Global Market Dashboard Ultimate (GMD)     |
//|                                                                   |
//|  役割 : 重要価格帯（日/週/月の高安）と現在価格の距離を数値化する |
//|  仕様 : Project Specification v1.7 第40章                         |
//|  状態 : [2.20+] 骨格。IsReady() は常に false。                    |
//|                                                                   |
//|  方針                                                             |
//|    ・今見ているチャート1本（_Symbol）に限定（既定）               |
//|    ・アラートの鳴らし方は持たない → AlertEngine に委譲            |
//|    ・確率表記はしない（Energy と同じ）                            |
//|    ・強弱の赤青とは別の接近色を使う                               |
//+------------------------------------------------------------------+
#property strict

#ifndef __GMD_PRICELEVEL_ENGINE_MQH__
#define __GMD_PRICELEVEL_ENGINE_MQH__

#include "../Core/Types.mqh"
#include "../Core/Logger.mqh"
#include "../Interfaces/IEngine.mqh"

//+------------------------------------------------------------------+
enum ENUM_PRICE_WATCH
  {
   PRICE_WATCH_NONE = 0,
   PRICE_WATCH_BREAKOUT,
   PRICE_WATCH_BREAKDOWN
  };

//+------------------------------------------------------------------+
struct SPriceLevel
  {
   string label;           // "TH","TL","YH","YL","WH","WL","MH","ML"
   double price;
   double distancePips;
   int    side;            // +1 upper, -1 lower
   color  proximityColor;
  };

//+------------------------------------------------------------------+
class CPriceLevelEngine : public IEngine
  {
private:
   CLogger *m_log;
   string   m_symbol;
   int      m_weeklyDays;
   int      m_monthlyDays;
   int      m_warn20;
   int      m_warn10;
   int      m_warn5;
   bool     m_enToday;
   bool     m_enYesterday;
   bool     m_enWeekly;
   bool     m_enMonthly;
   bool     m_ready;

public:
            CPriceLevelEngine(void)
              : m_log(NULL), m_symbol(""), m_weeklyDays(7), m_monthlyDays(30),
                m_warn20(20), m_warn10(10), m_warn5(5),
                m_enToday(true), m_enYesterday(true),
                m_enWeekly(true), m_enMonthly(true),
                m_ready(false) {}
           ~CPriceLevelEngine(void) {}

   bool     Init(CLogger *logger, const string symbol,
                 const int weeklyDays = 7, const int monthlyDays = 30)
     {
      m_log         = logger;
      m_symbol      = symbol;
      m_weeklyDays  = (weeklyDays < 1 ? 7 : weeklyDays);
      m_monthlyDays = (monthlyDays < 1 ? 30 : monthlyDays);
      m_ready       = false;
      if(m_log != NULL)
         m_log.Info("PriceLevelEngine: reserved for [2.20+]");
      return(true);
     }

   void     SetAlertThresholds(const int warn20, const int warn10, const int warn5)
     {
      m_warn20 = warn20;
      m_warn10 = warn10;
      m_warn5  = warn5;
     }

   void     SetEnabledLevels(const bool today, const bool yesterday,
                             const bool weekly, const bool monthly)
     {
      m_enToday     = today;
      m_enYesterday = yesterday;
      m_enWeekly    = weekly;
      m_enMonthly   = monthly;
     }

   //--- IEngine
   bool     Calculate(void) override
     {
      // [2.20+] CopyRates で日足高安を集め、距離と色を埋める
      m_ready = false;
      return(false);
     }

   bool     IsReady(void) override { return(m_ready); }
   string   GetName(void) override { return("PriceLevel"); }

   int      GetLevelCount(void) { return(0); }

   bool     GetLevel(const int /*index*/, SPriceLevel &out)
     {
      out.label = "";
      out.price = 0.0;
      out.distancePips = 0.0;
      out.side = 0;
      out.proximityColor = clrGray;
      return(false);
     }

   bool     GetNearest(SPriceLevel &out)
     {
      return(GetLevel(0, out));
     }

   ENUM_PRICE_WATCH GetWatchFlag(void) { return(PRICE_WATCH_NONE); }

   string   GetDisplayText(void)
     {
      return("Price Levels  --  (Ver2.20+)");
     }

   string   GetWatchText(void) { return(""); }
  };

#endif // __GMD_PRICELEVEL_ENGINE_MQH__
//+------------------------------------------------------------------+
