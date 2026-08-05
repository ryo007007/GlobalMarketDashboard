//+------------------------------------------------------------------+
//|                                                Test_MoneyFlow.mq5 |
//|                        Global Market Dashboard Ultimate (GMD)     |
//|                                                                   |
//|  役割 : Money Flow の枠が壊れていないことだけを確認する           |
//|  状態 : [2.20] エンジン未実装。ここは「置き場所の確保」。         |
//|                                                                   |
//|  今この時点で確認できること                                       |
//|    ・include の解決が通る                                         |
//|    ・IEngine として呼び出せる                                     |
//|    ・未実装でも IsReady() が false を返し、落ちない               |
//|                                                                   |
//|  Ver2.20 で判定ロジックを入れたら、この中身を書き換える。         |
//+------------------------------------------------------------------+
#property copyright "GMD Project"
#property version   "0.10"
#property script_show_inputs
#property strict

#include "../src/Modules/Core/Types.mqh"
#include "../src/Modules/Core/Logger.mqh"
#include "../src/Modules/Core/AssetDetection.mqh"
#include "../src/Modules/Engines/MoneyFlow.mqh"

input ENUM_LOG_LEVEL Inp_LogLevel = LOG_INFO;   // ログレベル

CLogger         g_logger;
CAssetDetection g_assets;
CMoneyFlow      g_moneyFlow;

//+------------------------------------------------------------------+
void OnStart()
  {
   Print("========================================");
   Print(" GMD MoneyFlow - placeholder test [2.20]");
   Print("========================================");

   g_logger.Init(Inp_LogLevel);
   g_assets.Init(GetPointer(g_logger), 100, false, "");

   g_moneyFlow.Init(GetPointer(g_assets), GetPointer(g_logger));
   g_moneyFlow.Calculate();

   PrintFormat("  name     : %s", g_moneyFlow.GetName());
   PrintFormat("  IsReady  : %s (expected: false)",
               (g_moneyFlow.IsReady() ? "true" : "false"));
   PrintFormat("  state    : %d (expected: %d = FLOW_UNAVAILABLE)",
               (int)g_moneyFlow.GetState(), (int)FLOW_UNAVAILABLE);
   PrintFormat("  display  : %s", g_moneyFlow.GetDisplayText());

   if(!g_moneyFlow.IsReady() && g_moneyFlow.GetState() == FLOW_UNAVAILABLE)
      Print("  STUB PASS: engine is correctly inactive.");
   else
      Print("  STUB FAIL");

   g_logger.Deinit();
   Print("========================================");
  }
//+------------------------------------------------------------------+
