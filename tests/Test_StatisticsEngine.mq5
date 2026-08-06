//+------------------------------------------------------------------+
//|                                          Test_StatisticsEngine.mq5 |
//|                        Global Market Dashboard Ultimate (GMD)      |
//|                                                                    |
//|  役割 : Statistics Engine の枠が壊れていないことを確認する         |
//|  状態 : [3.00] 予約。置き場所の確保。                              |
//+------------------------------------------------------------------+
#property copyright "GMD Project"
#property version   "0.10"
#property script_show_inputs
#property strict

#include "../src/Modules/Core/Types.mqh"
#include "../src/Modules/Core/Logger.mqh"
#include "../src/Modules/Engines/StatisticsEngine.mqh"

input ENUM_LOG_LEVEL Inp_LogLevel = LOG_INFO;

CLogger           g_logger;
CStatisticsEngine g_stats;

//+------------------------------------------------------------------+
void OnStart()
  {
   Print("========================================");
   Print(" GMD StatisticsEngine - placeholder test [3.00]");
   Print("========================================");

   g_logger.Init(Inp_LogLevel);
   g_stats.Init(GetPointer(g_logger));
   g_stats.Calculate();

   PrintFormat("  name     : %s", g_stats.GetName());
   PrintFormat("  IsReady  : %s (expected: false)",
               (g_stats.IsReady() ? "true" : "false"));
   PrintFormat("  display  : %s", g_stats.GetDisplayText());

   if(!g_stats.IsReady() && g_stats.GetName() == "StatisticsEngine")
      Print("  STUB PASS: engine is correctly inactive.");
   else
      Print("  STUB FAIL");

   g_logger.Deinit();
   Print("========================================");
  }
//+------------------------------------------------------------------+
