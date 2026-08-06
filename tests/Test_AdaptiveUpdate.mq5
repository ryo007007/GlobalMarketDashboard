//+------------------------------------------------------------------+
//|                                            Test_AdaptiveUpdate.mq5 |
//|                        Global Market Dashboard Ultimate (GMD)      |
//|                                                                    |
//|  役割 : 更新間隔の段が正しく決まり、暴れないことを確認する         |
//|  仕様 : Project Specification v1.5 第36章                          |
//|                                                                    |
//|  このモジュールで一番危ないのは「速くならないこと」ではなく       |
//|  「切り替わりすぎること」である。                                  |
//|  段の判定を素直に書くと、セッション境界で条件が往復するたびに      |
//|  EventKillTimer / EventSetMillisecondTimer を叩き続ける。          |
//|  張り直しのたびにイベントが1回落ちるので、速くしたつもりで         |
//|  かえって更新が飛ぶ。                                              |
//|                                                                    |
//|  よって検証の主眼は                                                |
//|    1. 段は3つだけか（増やすと何msで回っているか分からなくなる）    |
//|    2. 滞留時間が効いているか                                       |
//|    3. 速くする方向は即時に通るか（遅らせる方向だけ待たせる）       |
//+------------------------------------------------------------------+
#property copyright "GMD Project"
#property version   "1.00"
#property script_show_inputs
#property strict

#include "../src/Modules/Core/Types.mqh"
#include "../src/Modules/Core/Logger.mqh"
#include "../src/Modules/Core/Utils.mqh"
#include "../src/Modules/Core/SessionClock.mqh"
#include "../src/Modules/Engines/AdaptiveUpdate.mqh"

input ENUM_LOG_LEVEL Inp_LogLevel     = LOG_INFO;  // ログレベル
input int            Inp_MsNormal     = 1000;      // 通常
input int            Inp_MsAlert      = 300;       // 警戒
input int            Inp_MsIdle       = 2000;      // 静穏
input int            Inp_DwellSec     = 60;        // 最低滞留秒

CLogger         g_logger;
CSessionClock   g_clock;
CAdaptiveUpdate g_adaptive;

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
//| 段は3つだけであること                                             |
//+------------------------------------------------------------------+
void TestTierCount()
  {
   Print("---- tier definition ----");

   Check("TIER_IDLE   == 0", (int)TIER_IDLE   == 0);
   Check("TIER_NORMAL == 1", (int)TIER_NORMAL == 1);
   Check("TIER_ALERT  == 2", (int)TIER_ALERT  == 2);

   Check("idle is the slowest",  Inp_MsIdle  > Inp_MsNormal);
   Check("alert is the fastest", Inp_MsAlert < Inp_MsNormal);

   Print("  note: 1000/750/500/300/250 のような細かい段は作らない。");
   Print("        いま何msで回っているのか分からなくなるのが実害。");
  }

//+------------------------------------------------------------------+
//| 100ms より速くしないこと（下限の保護）                             |
//+------------------------------------------------------------------+
void TestFloor()
  {
   Print("---- lower bound ----");

   CAdaptiveUpdate a;
   a.Init(GetPointer(g_logger), GetPointer(g_clock), 50, 10, 20, 5);

   Check("interval never goes under 100ms", a.GetIntervalMs() >= 100);
  }

//+------------------------------------------------------------------+
//| 無効化したときは通常間隔で固定されること                          |
//+------------------------------------------------------------------+
void TestDisabled()
  {
   Print("---- disabled ----");

   CAdaptiveUpdate a;
   a.Init(GetPointer(g_logger), GetPointer(g_clock),
          Inp_MsNormal, Inp_MsAlert, Inp_MsIdle, Inp_DwellSec);
   a.SetEnabled(false);

   a.RequestAlert(true);
   a.Evaluate();

   Check("stays at normal when disabled", a.GetIntervalMs() == Inp_MsNormal);
   Check("tier is NORMAL when disabled",  a.GetTier() == TIER_NORMAL);
  }

//+------------------------------------------------------------------+
//| 速くする方向は待たされないこと                                    |
//|                                                                    |
//|  滞留時間は「遅くする」判断を遅らせるためにある。                 |
//|  速くする判断まで遅らせると、いちばん見たい瞬間に間に合わない。   |
//+------------------------------------------------------------------+
void TestSpeedUpBypassesDwell()
  {
   Print("---- speeding up bypasses dwell ----");

   CAdaptiveUpdate a;
   a.Init(GetPointer(g_logger), GetPointer(g_clock),
          Inp_MsNormal, Inp_MsAlert, Inp_MsIdle, 600);   // 滞留10分
   a.SetEnabled(true);

   const int before = a.GetIntervalMs();

   a.RequestAlert(true);
   const bool changed = a.Evaluate();

   PrintFormat("  before=%dms  after=%dms  changed=%s",
               before, a.GetIntervalMs(), (changed ? "yes" : "no"));

   Check("goes to alert immediately", a.GetIntervalMs() == Inp_MsAlert);
   Check("tier is ALERT",             a.GetTier() == TIER_ALERT);

   //--- 直後に要求を下げても、滞留時間が明けるまで戻らない
   a.RequestAlert(false);
   a.Evaluate();

   Check("does not fall back within dwell", a.GetIntervalMs() == Inp_MsAlert);

   Print("  note: 遅くする方向だけ待たせる。これで境界の往復が消える。");
  }

//+------------------------------------------------------------------+
//| Evaluate は「変わったときだけ」true を返すこと                    |
//+------------------------------------------------------------------+
void TestEvaluateReturnsOnlyOnChange()
  {
   Print("---- Evaluate returns true only on change ----");

   CAdaptiveUpdate a;
   a.Init(GetPointer(g_logger), GetPointer(g_clock),
          Inp_MsNormal, Inp_MsAlert, Inp_MsIdle, 1);
   a.SetEnabled(true);
   a.RequestAlert(true);

   const bool first  = a.Evaluate();
   const bool second = a.Evaluate();
   const bool third  = a.Evaluate();

   Check("first call reports a change",  first);
   Check("second call reports no change", !second);
   Check("third call reports no change",  !third);

   PrintFormat("  change count = %d (expected 1)", a.GetChangeCount());
   Check("change count is 1", a.GetChangeCount() == 1);
  }

//+------------------------------------------------------------------+
//| 現在のセッション状況で段を決めてみる                              |
//+------------------------------------------------------------------+
void TestLive()
  {
   Print("---- live state ----");

   g_clock.Refresh();
   g_adaptive.RequestAlert(false);
   g_adaptive.Evaluate();

   Check("IsReady", g_adaptive.IsReady());

   PrintFormat("  session : %s", g_clock.GetDisplayText());
   PrintFormat("  tier    : %s", UpdateTierToString(g_adaptive.GetTier()));
   PrintFormat("  interval: %d ms", g_adaptive.GetIntervalMs());
   Print("  display : " + g_adaptive.GetDisplayText());

   Check("interval is one of the three tiers",
         g_adaptive.GetIntervalMs() == Inp_MsNormal ||
         g_adaptive.GetIntervalMs() == Inp_MsAlert  ||
         g_adaptive.GetIntervalMs() == Inp_MsIdle);
  }

//+------------------------------------------------------------------+
void OnStart()
  {
   Print("==================================================");
   Print(" Test_AdaptiveUpdate  (GMD " + GMD_VERSION + ")");
   Print("==================================================");

   g_logger.Init(Inp_LogLevel);
   g_clock.Init(GetPointer(g_logger), 2, true, 15, 30);
   g_adaptive.Init(GetPointer(g_logger), GetPointer(g_clock),
                   Inp_MsNormal, Inp_MsAlert, Inp_MsIdle, Inp_DwellSec);
   g_adaptive.SetEnabled(true);

   TestTierCount();
   TestFloor();
   TestDisabled();
   TestSpeedUpBypassesDwell();
   TestEvaluateReturnsOnlyOnChange();
   TestLive();

   Print("--------------------------------------------------");
   PrintFormat(" result : PASS=%d  FAIL=%d", g_pass, g_fail);
   Print("==================================================");

   g_logger.Deinit();
  }
//+------------------------------------------------------------------+
