//+------------------------------------------------------------------+
//|                                             Test_MarketRegime.mq5 |
//|                        Global Market Dashboard Ultimate (GMD)     |
//|                                                                   |
//|  役割 : Market Regime の枠が壊れていないことだけを確認する        |
//|  状態 : [2.20] エンジン未実装。ここは「置き場所の確保」。         |
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
#include "../src/Modules/Engines/MarketRegime.mqh"

input ENUM_LOG_LEVEL Inp_LogLevel = LOG_INFO;   // ログレベル

CLogger         g_logger;
CAssetDetection g_assets;
CMarketRegime   g_marketRegime;

//+------------------------------------------------------------------+
void OnStart()
  {
   Print("========================================");
   Print(" GMD MarketRegime - placeholder test [2.20]");
   Print("========================================");

   g_logger.Init(Inp_LogLevel);
   g_assets.Init(GetPointer(g_logger), 100, false, "");

   g_marketRegime.Init(GetPointer(g_assets), GetPointer(g_logger));
   g_marketRegime.Calculate();

   PrintFormat("  name     : %s", g_marketRegime.GetName());
   PrintFormat("  IsReady  : %s (expected: false)",
               (g_marketRegime.IsReady() ? "true" : "false"));
   PrintFormat("  display  : %s", g_marketRegime.GetDisplayText());

   //--- 「わからない」を「中立」と混同しないこと
   if(!g_marketRegime.IsReady())
      Print("  STUB PASS: unknown is not reported as REGIME_NEUTRAL.");
   else
      Print("  STUB FAIL");

   g_logger.Deinit();
   Print("========================================");
  }
//+------------------------------------------------------------------+
