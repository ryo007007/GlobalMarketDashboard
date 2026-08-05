//+------------------------------------------------------------------+
//|                                        Test_CurrencyStrength.mq5 |
//|                        Global Market Dashboard Ultimate (GMD)     |
//|                                                                   |
//|  役割 : Currency Strength v2 / Best Pair / Confidence の確認      |
//|  仕様 : Project Specification v1.3 第5章・第8章・第9章            |
//|                                                                   |
//|  使い方 :                                                         |
//|    1. MetaEditor でコンパイル（警告0・エラー0）                   |
//|    2. 任意のチャートにドラッグ&ドロップ                           |
//|    3. 「エキスパート」タブでランキングを確認                      |
//+------------------------------------------------------------------+
#property copyright "GMD Project"
#property version   "1.00"
#property script_show_inputs
#property strict

#include "../src/Modules/Core/Types.mqh"
#include "../src/Modules/Core/Logger.mqh"
#include "../src/Modules/Core/AssetDetection.mqh"
#include "../src/Modules/Engines/CurrencyStrength.mqh"
#include "../src/Modules/Engines/BestPair.mqh"
#include "../src/Modules/Engines/Confidence.mqh"

//--- 入力パラメータ
input ENUM_LOG_LEVEL   Inp_LogLevel            = LOG_INFO;    // ログレベル
input ENUM_TIMEFRAMES  Inp_StrengthTimeframe   = PERIOD_M1;   // 判定時間足
input int              Inp_StrengthBars        = 3;           // 判定本数
input bool             Inp_UseWeighting        = true;        // 重み付け（1:2:3）
input int              Inp_StrengthMinPairs    = 20;          // 最低ペア数
input double           Inp_BestPairMinSpread   = 20.0;        // 方向を出す最低点差
input int              Inp_ValidationMinBars   = 100;         // 銘柄検証の最低バー数

//--- グローバル
CLogger           g_logger;
CAssetDetection   g_assets;
CCurrencyStrength g_strength;
CBestPair         g_bestPair;
CConfidence       g_confidence;

//+------------------------------------------------------------------+
void OnStart()
  {
   Print("========================================");
   Print(" GMD Currency Strength v2 - test");
   Print("========================================");

   //--- Core
   g_logger.Init(Inp_LogLevel);
   g_assets.Init(GetPointer(g_logger), Inp_ValidationMinBars, false, "");

   Print("FX pairs detected: ", g_assets.GetFxPairCount(), " / 28");

   //--- Engines
   g_strength.Init(GetPointer(g_assets), GetPointer(g_logger),
                   Inp_StrengthTimeframe, Inp_StrengthBars,
                   Inp_UseWeighting, Inp_StrengthMinPairs);

   g_bestPair.Init(GetPointer(g_strength), GetPointer(g_assets),
                   GetPointer(g_logger), Inp_BestPairMinSpread);

   g_confidence.Init(GetPointer(g_strength), GetPointer(g_logger));

   //--- 計算（仕様書30.2の固定順序）
   const uint t0 = GetTickCount();

   g_strength.Calculate();
   g_bestPair.Calculate();
   g_confidence.Calculate();

   const uint elapsed = GetTickCount() - t0;

   //--- 結果表示
   if(!g_strength.IsReady())
     {
      Print("Currency strength is NOT ready. pairs used = ", g_strength.GetPairsUsed());
      g_logger.Deinit();
      return;
     }

   Print("---- currency strength ranking ----");
   for(int r = 1; r <= CUR_COUNT; r++)
     {
      const ENUM_CURRENCY c = g_strength.GetByRank(r);

      string mark = "  ";
      if(r == 1)           mark = "R ";     // 赤で表示される通貨
      if(r == CUR_COUNT)   mark = "B ";     // 青で表示される通貨

      PrintFormat("  %s%d  %-4s  score=%3d  raw=%2d  mom=%+d  %s",
                  mark,
                  r,
                  CurrencyToString(c),
                  (int)MathRound(g_strength.GetScore(c)),
                  g_strength.GetRawScore(c),
                  g_strength.GetMomentum(c),
                  g_strength.GetArrow(c));
     }

   Print("---- summary ----");
   PrintFormat("  pairs used : %d / 28", g_strength.GetPairsUsed());
   PrintFormat("  spread     : %.1f  (rank1 - rank8)", g_strength.GetSpread());
   PrintFormat("  strongest  : %s", CurrencyToString(g_strength.GetStrongest()));
   PrintFormat("  weakest    : %s", CurrencyToString(g_strength.GetWeakest()));
   PrintFormat("  best pair  : %s", g_bestPair.GetDisplayText());
   PrintFormat("  inverted   : %s", (g_bestPair.IsInverted() ? "yes" : "no"));
   PrintFormat("  %s", g_confidence.GetDisplayText());
   PrintFormat("  breakdown  : %s", g_confidence.GetBreakdownText());
   PrintFormat("  elapsed    : %u ms", elapsed);

   //--- 検算：正規化スコアの合計は理論上400に近づく
   double total = 0.0;
   for(int i = 0; i < CUR_COUNT; i++)
      total += g_strength.GetScore((ENUM_CURRENCY)i);
   PrintFormat("  score total: %.1f  (theoretical max 400, lower if flat bars exist)", total);

   //--- 性能（仕様書32.1：全エンジン計算 20ms目標 / 50ms上限）
   if(elapsed <= 20)
      Print("  PERF PASS: ", elapsed, " ms");
   else
      if(elapsed <= 50)
         Print("  PERF WARN: ", elapsed, " ms (over target)");
      else
         Print("  PERF FAIL: ", elapsed, " ms (over 50 ms limit)");

   g_logger.Deinit();

   Print("========================================");
   Print(" test finished");
   Print("========================================");
  }
//+------------------------------------------------------------------+
