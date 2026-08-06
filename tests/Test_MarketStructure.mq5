//+------------------------------------------------------------------+
//|                                            Test_MarketStructure.mq5 |
//|                        Global Market Dashboard Ultimate (GMD)      |
//|  状態 : [2.30+] プレースホルダ                                     |
//+------------------------------------------------------------------+
#property copyright "GMD Project"
#property version   "0.10"
#property script_show_inputs
#property strict

#include "../src/Modules/Core/Types.mqh"
#include "../src/Modules/Core/Logger.mqh"
#include "../src/Modules/Engines/MarketStructure.mqh"

input ENUM_LOG_LEVEL Inp_LogLevel = LOG_INFO;

CLogger          g_logger;
CMarketStructure g_ms;

void OnStart()
  {
   Print("========================================");
   Print(" GMD MarketStructure - placeholder [2.30+]");
   Print("========================================");
   g_logger.Init(Inp_LogLevel);
   g_ms.Init(GetPointer(g_logger), _Symbol);
   g_ms.Calculate();
   PrintFormat("  name=%s  ready=%s  display=%s",
               g_ms.GetName(),
               (g_ms.IsReady() ? "true" : "false"),
               g_ms.GetDisplayText());
   if(!g_ms.IsReady() && g_ms.GetName() == "MarketStructure")
      Print("  STUB PASS");
   else
      Print("  STUB FAIL");
   g_logger.Deinit();
  }
//+------------------------------------------------------------------+
