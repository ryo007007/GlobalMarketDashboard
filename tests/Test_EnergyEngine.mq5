//+------------------------------------------------------------------+
//|                                             Test_EnergyEngine.mq5 |
//|                        Global Market Dashboard Ultimate (GMD)      |
//|                                                                    |
//|  役割 : 圧縮の点数と状態遷移が壊れていないことを確認する           |
//|  仕様 : Project Specification v1.5 第37章                          |
//|                                                                    |
//|  このテストは「点数が当たっているか」を見るものではない。          |
//|  圧縮の正解は存在しないので、当たり外れは検証できない。            |
//|                                                                    |
//|  検証できるのは次の3つである。                                     |
//|                                                                    |
//|    1. 銘柄をまたいで比較可能か                                     |
//|       絶対値で判定していると USDJPY と XAUUSD と BTCUSD で         |
//|       まったく別の意味になる。パーセンタイル化してあれば           |
//|       どの銘柄でも 0〜100 に収まる。                               |
//|                                                                    |
//|    2. 材料が足りないとき 0 を返していないか                        |
//|       0 は「圧縮していない」という意味を持つ。                     |
//|       「分からない」を 0 で表すと、分からないときに                |
//|       「圧縮していない」と嘘をつくことになる。                     |
//|                                                                    |
//|    3. RELEASED が1回しか立たないか                                 |
//|       水準（Energy 90）は数日続くが、事象（解けた瞬間）は1回。     |
//+------------------------------------------------------------------+
#property copyright "GMD Project"
#property version   "1.00"
#property script_show_inputs
#property strict

#include "../src/Modules/Core/Types.mqh"
#include "../src/Modules/Core/Logger.mqh"
#include "../src/Modules/Core/Utils.mqh"
#include "../src/Modules/Engines/EnergyEngine.mqh"

input ENUM_LOG_LEVEL Inp_LogLevel   = LOG_INFO;       // ログレベル
input ENUM_TIMEFRAMES Inp_Timeframe = PERIOD_M15;     // 判定時間足
input int            Inp_Lookback   = 100;            // 比較する母数（本）

CLogger       g_logger;
CEnergyEngine g_energy;

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
//| 点数と3軸が範囲に収まっていること                                 |
//+------------------------------------------------------------------+
void TestRange()
  {
   Print("---- value ranges ----");

   g_energy.Calculate();

   const int e = g_energy.GetEnergy();

   PrintFormat("  energy = %d", e);
   Check("energy is 0..100", e >= 0 && e <= 100);

   Check("axis squeeze is 0..100",
         g_energy.GetAxisSqueeze() >= 0 && g_energy.GetAxisSqueeze() <= 100);
   Check("axis notrend is 0..100",
         g_energy.GetAxisNoTrend() >= 0 && g_energy.GetAxisNoTrend() <= 100);
   Check("axis volume is 0..100",
         g_energy.GetAxisVolume() >= 0 && g_energy.GetAxisVolume() <= 100);

   Print("  detail : " + g_energy.BuildDetailText());
  }

//+------------------------------------------------------------------+
//| 材料不足のときは 0 ではなく UNAVAILABLE を返すこと                |
//+------------------------------------------------------------------+
void TestUnavailableIsNotZero()
  {
   Print("---- unavailable is not zero ----");

   //--- 母数を極端に大きくして、意図的に本数不足を起こす
   CEnergyEngine e;
   e.Init(GetPointer(g_logger), _Symbol, Inp_Timeframe,
          14, 20, 14, 100000);
   const bool ok = e.Calculate();

   PrintFormat("  Calculate()=%s  state=%s  energy=%d",
               (ok ? "true" : "false"),
               EnergyStateToString(e.GetState()),
               e.GetEnergy());

   if(!ok)
     {
      Check("state is UNAVAILABLE when bars are short",
            e.GetState() == ENERGY_UNAVAILABLE);
      Check("display does not show a fake number",
            StringFind(e.GetDisplayText(), "--") >= 0);
     }
   else
     {
      Print("  SKIP  この銘柄には10万本の履歴がある。判定を飛ばす");
     }

   e.Deinit();

   Print("  note: 0 は「圧縮していない」の意味。「不明」に流用しない。");
  }

//+------------------------------------------------------------------+
//| 銘柄をまたいでも同じ尺度で並ぶこと                                |
//|                                                                    |
//|  絶対値で判定していると、ここで値が桁ごと変わる。                 |
//|  パーセンタイル化してあれば、どの銘柄でも 0〜100 に入る。          |
//+------------------------------------------------------------------+
void TestCrossSymbolComparability()
  {
   Print("---- cross-symbol comparability ----");

   string syms[];
   ArrayResize(syms, 4);
   syms[0] = _Symbol;
   syms[1] = "EURUSD";
   syms[2] = "USDJPY";
   syms[3] = "XAUUSD";

   int tested = 0;

   for(int i = 0; i < ArraySize(syms); i++)
     {
      if(!SymbolSelect(syms[i], true))
         continue;

      CEnergyEngine e;
      if(!e.Init(GetPointer(g_logger), syms[i], Inp_Timeframe,
                 14, 20, 14, Inp_Lookback))
        {
         e.Deinit();
         continue;
        }

      if(e.Calculate())
        {
         PrintFormat("  %-10s energy=%3d  state=%-11s  squeeze=%3d",
                     syms[i], e.GetEnergy(),
                     EnergyStateToString(e.GetState()),
                     e.GetAxisSqueeze());

         Check(StringFormat("%s energy in 0..100", syms[i]),
               e.GetEnergy() >= 0 && e.GetEnergy() <= 100);
         tested++;
        }
      else
         PrintFormat("  %-10s unavailable", syms[i]);

      e.Deinit();
     }

   PrintFormat("  symbols evaluated : %d", tested);
   Check("at least one symbol evaluated", tested >= 1);
  }

//+------------------------------------------------------------------+
//| 状態遷移：RELEASED は連続して立たないこと                         |
//+------------------------------------------------------------------+
void TestStateMachine()
  {
   Print("---- state machine ----");

   //--- 同じ足の中で何度呼んでも状態が飛ばないこと
   const ENUM_ENERGY_STATE s1 = g_energy.GetState();
   g_energy.Calculate();
   const ENUM_ENERGY_STATE s2 = g_energy.GetState();

   PrintFormat("  state : %s -> %s",
               EnergyStateToString(s1), EnergyStateToString(s2));

   Check("state stays within the enum",
         (int)s2 >= (int)ENERGY_UNAVAILABLE && (int)s2 <= (int)ENERGY_RELEASED);

   //--- RELEASED はエッジ。2回連続で IsReleasedNow が true にならない
   if(g_energy.IsReleasedNow())
     {
      g_energy.Calculate();
      Check("released does not fire twice in a row", !g_energy.IsReleasedNow());
     }
   else
      Print("  SKIP  いまは解放の瞬間ではない");

   Print("  note: 水準（Energy 90）は数日続く。事象（解けた瞬間）は1回。");
  }

//+------------------------------------------------------------------+
//| 表示の形が崩れていないこと                                        |
//+------------------------------------------------------------------+
void TestDisplay()
  {
   Print("---- display ----");

   const string bar = g_energy.GetBarText();

   PrintFormat("  bar    : [%s] len=%d", bar, StringLen(bar));
   Check("bar has 8 cells", StringLen(bar) == 8);

   Print("  display: " + g_energy.GetDisplayText());

   //--- 色は 赤・白・青・灰 のみ（仕様書15.1）
   const color c = g_energy.GetColor();
   Check("color is one of red / white / blue / gray",
         c == clrRed || c == clrWhite || c == clrDodgerBlue || c == clrGray);

   Print("  note: 「%」とは書かない。0〜100は確率ではないので。");
  }

//+------------------------------------------------------------------+
void OnStart()
  {
   Print("==================================================");
   Print(" Test_EnergyEngine  (GMD " + GMD_VERSION + ")");
   Print("==================================================");
   PrintFormat(" symbol=%s  timeframe=%s",
               _Symbol, CalcTimeframeText(Inp_Timeframe));

   g_logger.Init(Inp_LogLevel);

   if(!g_energy.Init(GetPointer(g_logger), _Symbol, Inp_Timeframe,
                     14, 20, 14, Inp_Lookback))
     {
      Print(" FATAL : Init failed");
      g_logger.Deinit();
      return;
     }

   TestRange();
   TestUnavailableIsNotZero();
   TestCrossSymbolComparability();
   TestStateMachine();
   TestDisplay();

   Print("--------------------------------------------------");
   PrintFormat(" result : PASS=%d  FAIL=%d", g_pass, g_fail);
   Print("==================================================");

   g_energy.Deinit();
   g_logger.Deinit();
  }
//+------------------------------------------------------------------+
