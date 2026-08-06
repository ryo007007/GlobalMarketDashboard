//+------------------------------------------------------------------+
//|                                               Test_PivotEngine.mq5 |
//|                        Global Market Dashboard Ultimate (GMD)      |
//|                                                                    |
//|  役割 : Pivot Engine の枠が壊れていないことを確認する              |
//|  状態 : [2.20+] 未実装。置き場所の確保。                           |
//+------------------------------------------------------------------+
#property copyright "GMD Project"
#property version   "0.10"
#property script_show_inputs
#property strict

#include "../src/Modules/Core/Types.mqh"
#include "../src/Modules/Core/Logger.mqh"
#include "../src/Modules/Engines/PivotEngine.mqh"

input ENUM_LOG_LEVEL Inp_LogLevel = LOG_INFO;

CLogger      g_logger;
CPivotEngine g_pivot;

//+------------------------------------------------------------------+
void OnStart()
  {
   Print("========================================");
   Print(" GMD PivotEngine - placeholder test [2.20+]");
   Print("========================================");

   g_logger.Init(Inp_LogLevel);
   g_pivot.Init(GetPointer(g_logger), _Symbol);
   g_pivot.SetAxes(true, true, true, false);
   g_pivot.SetAlertThresholds(20, 10, 5);
   g_pivot.Calculate();

   PrintFormat("  name     : %s", g_pivot.GetName());
   PrintFormat("  IsReady  : %s (expected: false)",
               (g_pivot.IsReady() ? "true" : "false"));
   PrintFormat("  display  : %s", g_pivot.GetDisplayText());
   PrintFormat("  levels   : %d", g_pivot.GetLevelCount());

   if(!g_pivot.IsReady() && g_pivot.GetName() == "Pivot")
      Print("  STUB PASS: engine is correctly inactive.");
   else
      Print("  STUB FAIL");

   g_logger.Deinit();
   Print("========================================");
  }
//+------------------------------------------------------------------+
