//+------------------------------------------------------------------+
//|                                         Test_CorrelationEngine.mq5 |
//|                        Global Market Dashboard Ultimate (GMD)      |
//|                                                                    |
//|  役割 : Correlation Engine の枠が壊れていないことを確認する        |
//|  状態 : [3.00] 予約。置き場所の確保。                              |
//+------------------------------------------------------------------+
#property copyright "GMD Project"
#property version   "0.10"
#property script_show_inputs
#property strict

#include "../src/Modules/Core/Types.mqh"
#include "../src/Modules/Core/Logger.mqh"
#include "../src/Modules/Core/AssetDetection.mqh"
#include "../src/Modules/Engines/CorrelationEngine.mqh"

input ENUM_LOG_LEVEL Inp_LogLevel = LOG_INFO;

CLogger             g_logger;
CAssetDetection     g_assets;
CCorrelationEngine  g_corr;

//+------------------------------------------------------------------+
void OnStart()
  {
   Print("========================================");
   Print(" GMD CorrelationEngine - placeholder test [3.00]");
   Print("========================================");

   g_logger.Init(Inp_LogLevel);
   g_assets.Init(GetPointer(g_logger), 100, false, "");

   g_corr.Init(GetPointer(g_assets), GetPointer(g_logger));
   g_corr.Calculate();

   PrintFormat("  name     : %s", g_corr.GetName());
   PrintFormat("  IsReady  : %s (expected: false)",
               (g_corr.IsReady() ? "true" : "false"));
   PrintFormat("  display  : %s", g_corr.GetDisplayText());

   if(!g_corr.IsReady() && g_corr.GetName() == "CorrelationEngine")
      Print("  STUB PASS: engine is correctly inactive.");
   else
      Print("  STUB FAIL");

   g_logger.Deinit();
   Print("========================================");
  }
//+------------------------------------------------------------------+
