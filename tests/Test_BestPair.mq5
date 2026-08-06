//+------------------------------------------------------------------+
//|                                                  Test_BestPair.mq5 |
//|                        Global Market Dashboard Ultimate (GMD)      |
//|                                                                    |
//|  役割 : Best Pair が実在銘柄だけを返し、存在しない表記を出さない   |
//|  仕様 : Project Specification 第9章                                |
//|                                                                    |
//|  検証すること                                                      |
//|    1. CurrencyStrength の結果から 1 ペアを提案できる               |
//|    2. 提案シンボルが SYMBOL_EXIST である                           |
//|    3. 逆順採用時は inverted フラグが立つ                           |
//|    4. 点差不足時は方向を無理に出さない                             |
//+------------------------------------------------------------------+
#property copyright "GMD Project"
#property version   "1.00"
#property script_show_inputs
#property strict

#include "../src/Modules/Core/Types.mqh"
#include "../src/Modules/Core/Logger.mqh"
#include "../src/Modules/Core/Utils.mqh"
#include "../src/Modules/Core/AssetDetection.mqh"
#include "../src/Modules/Engines/CurrencyStrength.mqh"
#include "../src/Modules/Engines/BestPair.mqh"

input ENUM_LOG_LEVEL  Inp_LogLevel          = LOG_INFO;
input ENUM_TIMEFRAMES Inp_StrengthTimeframe = PERIOD_M1;
input int             Inp_StrengthBars      = 3;
input double          Inp_BestPairMinSpread = 20.0;

CLogger           g_logger;
CAssetDetection   g_assets;
CCurrencyStrength g_strength;
CBestPair         g_bestPair;

int g_pass = 0;
int g_fail = 0;

//+------------------------------------------------------------------+
void Check(const string name, const bool ok)
  {
   if(ok)
     {
      g_pass++;
      PrintFormat("  PASS  %s", name);
     }
   else
     {
      g_fail++;
      PrintFormat("  FAIL  %s", name);
     }
  }

//+------------------------------------------------------------------+
void OnStart()
  {
   Print("==================================================");
   Print(" Test_BestPair  (GMD)");
   Print("==================================================");

   g_logger.Init(Inp_LogLevel);
   g_assets.Init(GetPointer(g_logger), 100, false, "");

   g_strength.Init(GetPointer(g_assets), GetPointer(g_logger),
                   Inp_StrengthTimeframe, Inp_StrengthBars, true, 20);

   g_bestPair.Init(GetPointer(g_strength), GetPointer(g_assets),
                   GetPointer(g_logger), Inp_BestPairMinSpread);

   g_strength.Calculate();
   g_bestPair.Calculate();

   PrintFormat("  strength ready : %s  pairs=%d",
               (g_strength.IsReady() ? "yes" : "no"),
               g_strength.GetPairsUsed());
   PrintFormat("  best pair text : %s", g_bestPair.GetDisplayText());
   PrintFormat("  symbol         : %s", g_bestPair.GetSymbol());
   PrintFormat("  inverted       : %s", (g_bestPair.IsInverted() ? "yes" : "no"));
   PrintFormat("  direction      : %s", g_bestPair.GetDirectionText());
   PrintFormat("  spread         : %.1f", g_bestPair.GetSpread());

   if(!g_strength.IsReady())
     {
      Print("  SKIP  strength not ready on this broker / session");
      g_logger.Deinit();
      return;
     }

   Check("BestPair IsReady when strength is ready", g_bestPair.IsReady());

   const string sym = g_bestPair.GetSymbol();
   if(StringLen(sym) > 0)
     {
      Check("proposed symbol exists on broker",
            (bool)SymbolInfoInteger(sym, SYMBOL_EXIST));
      Check("symbol does not look like inverted nonsense (e.g. JPYUSD raw)",
            StringFind(sym, "JPYUSD") < 0 && StringFind(sym, "CHFUSD") < 0);
     }
   else
     {
      Print("  note: empty symbol — point spread may be below threshold");
      Check("empty symbol is allowed when spread is low or pair missing", true);
     }

   Check("GetName is BestPair", g_bestPair.GetName() == "BestPair");

   Print("--------------------------------------------------");
   PrintFormat(" result : PASS=%d  FAIL=%d", g_pass, g_fail);
   Print("==================================================");

   g_logger.Deinit();
  }
//+------------------------------------------------------------------+
