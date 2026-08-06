//+------------------------------------------------------------------+
//|                                          Test_PriceLevelEngine.mq5 |
//|                        Global Market Dashboard Ultimate (GMD)      |
//|                                                                    |
//|  役割 : Price Level Engine の枠が壊れていないことを確認する        |
//|  状態 : [2.20+] 未実装。置き場所の確保。                           |
//+------------------------------------------------------------------+
#property copyright "GMD Project"
#property version   "0.10"
#property script_show_inputs
#property strict

#include "../src/Modules/Core/Types.mqh"
#include "../src/Modules/Core/Logger.mqh"
#include "../src/Modules/Engines/PriceLevelEngine.mqh"

input ENUM_LOG_LEVEL Inp_LogLevel = LOG_INFO;

CLogger           g_logger;
CPriceLevelEngine g_levels;

//+------------------------------------------------------------------+
void OnStart()
  {
   Print("========================================");
   Print(" GMD PriceLevelEngine - placeholder test [2.20+]");
   Print("========================================");

   g_logger.Init(Inp_LogLevel);
   g_levels.Init(GetPointer(g_logger), _Symbol, 7, 30);
   g_levels.SetAlertThresholds(20, 10, 5);
   g_levels.Calculate();

   PrintFormat("  name     : %s", g_levels.GetName());
   PrintFormat("  IsReady  : %s (expected: false)",
               (g_levels.IsReady() ? "true" : "false"));
   PrintFormat("  display  : %s", g_levels.GetDisplayText());
   PrintFormat("  watch    : %s", g_levels.GetWatchText());
   PrintFormat("  levels   : %d", g_levels.GetLevelCount());

   if(!g_levels.IsReady() && g_levels.GetName() == "PriceLevel")
      Print("  STUB PASS: engine is correctly inactive.");
   else
      Print("  STUB FAIL");

   g_logger.Deinit();
   Print("========================================");
  }
//+------------------------------------------------------------------+
