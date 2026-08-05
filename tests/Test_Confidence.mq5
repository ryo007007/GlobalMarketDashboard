//+------------------------------------------------------------------+
//|                                              Test_Confidence.mq5 |
//|                        Global Market Dashboard Ultimate (GMD)     |
//|                                                                   |
//|  役割 : Confidence の暫定式が仕様どおりか確認する                 |
//|  仕様 : Project Specification v1.3 第8章 8.3.1                    |
//|                                                                   |
//|  確認する3点                                                      |
//|    1. 実データでの算出結果                                        |
//|    2. 0〜100 の範囲を外れないこと                                 |
//|    3. 強弱が出ていないとき 0% ではなく「算出不可」になること      |
//+------------------------------------------------------------------+
#property copyright "GMD Project"
#property version   "1.00"
#property script_show_inputs
#property strict

#include "../src/Modules/Core/Types.mqh"
#include "../src/Modules/Core/Logger.mqh"
#include "../src/Modules/Core/AssetDetection.mqh"
#include "../src/Modules/Engines/CurrencyStrength.mqh"
#include "../src/Modules/Engines/Confidence.mqh"

input ENUM_LOG_LEVEL  Inp_LogLevel          = LOG_WARN;    // ログレベル
input ENUM_TIMEFRAMES Inp_StrengthTimeframe = PERIOD_M1;   // 判定時間足
input int             Inp_StrengthBars      = 3;           // 判定本数
input int             Inp_StrengthMinPairs  = 20;          // 最低ペア数

CLogger           g_logger;
CAssetDetection   g_assets;
CCurrencyStrength g_strength;
CConfidence       g_confidence;

//+------------------------------------------------------------------+
void OnStart()
  {
   Print("========================================");
   Print(" GMD Confidence - test");
   Print("========================================");

   g_logger.Init(Inp_LogLevel);
   g_assets.Init(GetPointer(g_logger), 100, false, "");

   g_strength.Init(GetPointer(g_assets), GetPointer(g_logger),
                   Inp_StrengthTimeframe, Inp_StrengthBars,
                   true, Inp_StrengthMinPairs);

   g_confidence.Init(GetPointer(g_strength), GetPointer(g_logger));

   //--- 1. 実データ
   g_strength.Calculate();
   g_confidence.Calculate();

   Print("---- live ----");
   PrintFormat("  pairs used : %d / %d", g_strength.GetPairsUsed(), GMD_FX_PAIR_MAX);
   PrintFormat("  spread     : %.1f", g_strength.GetSpread());
   PrintFormat("  %s", g_confidence.GetDisplayText());
   PrintFormat("  breakdown  : %s", g_confidence.GetBreakdownText());
   PrintFormat("  level      : %s", g_confidence.GetLevelText());

   //--- 2. 範囲チェック
   const double v = g_confidence.GetConfidence();

   if(v < 0.0 || v > 100.0)
      PrintFormat("  RANGE FAIL : %.2f is out of 0-100", v);
   else
      Print("  RANGE PASS");

   //--- 3. 強弱が無いとき
   Print("---- unavailable case ----");
   CCurrencyStrength empty;          // Calculate() を呼んでいない = IsReady() false
   CConfidence       conf2;

   conf2.Init(GetPointer(empty), GetPointer(g_logger));
   conf2.Calculate();

   PrintFormat("  IsAvailable : %s (expected: false)",
               (conf2.IsAvailable() ? "true" : "false"));
   PrintFormat("  display     : %s (expected: \"Confidence  --\")",
               conf2.GetDisplayText());

   if(!conf2.IsAvailable() && conf2.GetConfidence() == 0.0)
      Print("  FALLBACK PASS");
   else
      Print("  FALLBACK FAIL");

   g_logger.Deinit();

   Print("========================================");
   Print(" test finished");
   Print("========================================");
  }
//+------------------------------------------------------------------+
