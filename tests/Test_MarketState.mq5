//+------------------------------------------------------------------+
//|                                               Test_MarketState.mq5 |
//|                        Global Market Dashboard Ultimate (GMD)      |
//|                                                                    |
//|  役割 : Market State の枠が壊れていないことを確認する              |
//|  状態 : [2.30] 未実装。置き場所の確保。                            |
//+------------------------------------------------------------------+
#property copyright "GMD Project"
#property version   "0.10"
#property script_show_inputs
#property strict

#include "../src/Modules/Core/Types.mqh"
#include "../src/Modules/Core/Logger.mqh"
#include "../src/Modules/Engines/MarketState.mqh"

input ENUM_LOG_LEVEL Inp_LogLevel = LOG_INFO;

CLogger      g_logger;
CMarketState g_state;

//+------------------------------------------------------------------+
void OnStart()
  {
   Print("========================================");
   Print(" GMD MarketState - placeholder test [2.30]");
   Print("========================================");

   g_logger.Init(Inp_LogLevel);
   g_state.Init(GetPointer(g_logger));
   g_state.Calculate();

   PrintFormat("  name     : %s", g_state.GetName());
   PrintFormat("  IsReady  : %s (expected: false)",
               (g_state.IsReady() ? "true" : "false"));
   PrintFormat("  display  : %s", g_state.GetDisplayText());

   if(!g_state.IsReady() && g_state.GetName() == "MarketState")
      Print("  STUB PASS: engine is correctly inactive.");
   else
      Print("  STUB FAIL");

   g_logger.Deinit();
   Print("========================================");
  }
//+------------------------------------------------------------------+
