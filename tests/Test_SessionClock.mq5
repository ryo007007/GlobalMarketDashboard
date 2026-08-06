//+------------------------------------------------------------------+
//|                                              Test_SessionClock.mq5 |
//|                        Global Market Dashboard Ultimate (GMD)      |
//|                                                                    |
//|  役割 : セッション時計と夏時間の切り替わりを確認する              |
//|  仕様 : Project Specification v1.5 第36章                          |
//|                                                                    |
//|  このテストの主目的は「今日」の判定ではない。                      |
//|  夏時間の境界は1年に4回しか来ないので、実運用で回しているだけでは |
//|  切り替わりの正しさを確認できないまま何か月も過ぎる。              |
//|  だから境界日を直接指定して検証する。                              |
//|                                                                    |
//|  特に見たいのは「欧州と米国がずれる3週間」である。                |
//|  3月の第2日曜〜最終日曜、11月の第1日曜〜10月最終日曜のあいだ、     |
//|  ロンドンとニューヨークの時差は5時間ではなく4時間になる。          |
//|  夏時間フラグを1つで済ませていると、ここで静かに1時間ずれる。      |
//+------------------------------------------------------------------+
#property copyright "GMD Project"
#property version   "1.00"
#property script_show_inputs
#property strict

#include "../src/Modules/Core/Types.mqh"
#include "../src/Modules/Core/Logger.mqh"
#include "../src/Modules/Core/Utils.mqh"
#include "../src/Modules/Core/SessionClock.mqh"

input ENUM_LOG_LEVEL Inp_LogLevel           = LOG_INFO;  // ログレベル
input int            Inp_ServerStdGmtOffset = 2;         // 冬時間のサーバGMT差
input bool           Inp_ServerFollowsEuDst = true;      // サーバが欧州夏時間に追従

CLogger       g_logger;
CSessionClock g_clock;

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
//| 欧州の夏時間：3月最終日曜 01:00 UTC 〜 10月最終日曜 01:00 UTC     |
//+------------------------------------------------------------------+
void TestDstEurope()
  {
   Print("---- DST Europe ----");

   //--- 2026年：3月最終日曜は 3/29、10月最終日曜は 10/25
   Check("2026.03.29 00:30 UTC is still winter",
         !g_clock.DstEuropeAt(StringToTime("2026.03.29 00:30")));
   Check("2026.03.29 01:30 UTC is summer",
         g_clock.DstEuropeAt(StringToTime("2026.03.29 01:30")));
   Check("2026.07.01 is summer",
         g_clock.DstEuropeAt(StringToTime("2026.07.01 12:00")));
   Check("2026.10.25 00:30 UTC is still summer",
         g_clock.DstEuropeAt(StringToTime("2026.10.25 00:30")));
   Check("2026.10.25 01:30 UTC is winter",
         !g_clock.DstEuropeAt(StringToTime("2026.10.25 01:30")));
   Check("2026.01.15 is winter",
         !g_clock.DstEuropeAt(StringToTime("2026.01.15 12:00")));
  }

//+------------------------------------------------------------------+
//| 米国の夏時間：3月第2日曜 07:00 UTC 〜 11月第1日曜 06:00 UTC       |
//+------------------------------------------------------------------+
void TestDstUS()
  {
   Print("---- DST United States ----");

   //--- 2026年：3月第2日曜は 3/8、11月第1日曜は 11/1
   Check("2026.03.08 06:30 UTC is still winter",
         !g_clock.DstUsAt(StringToTime("2026.03.08 06:30")));
   Check("2026.03.08 07:30 UTC is summer",
         g_clock.DstUsAt(StringToTime("2026.03.08 07:30")));
   Check("2026.11.01 05:30 UTC is still summer",
         g_clock.DstUsAt(StringToTime("2026.11.01 05:30")));
   Check("2026.11.01 06:30 UTC is winter",
         !g_clock.DstUsAt(StringToTime("2026.11.01 06:30")));
  }

//+------------------------------------------------------------------+
//| 本命：欧州と米国がずれる期間があること                            |
//|                                                                    |
//|  ここが FAIL するなら、夏時間を1つのフラグで扱っているか、        |
//|  切り替え日の式が間違っている。                                    |
//+------------------------------------------------------------------+
void TestDstDivergence()
  {
   Print("---- DST divergence (the reason two flags exist) ----");

   //--- 2026.03.15：米国は夏時間、欧州はまだ冬時間
   const datetime springGap = StringToTime("2026.03.15 12:00");
   Check("2026.03.15  US=summer",  g_clock.DstUsAt(springGap));
   Check("2026.03.15  EU=winter", !g_clock.DstEuropeAt(springGap));
   Check("2026.03.15  the two differ",
         g_clock.DstUsAt(springGap) != g_clock.DstEuropeAt(springGap));

   //--- 2026.10.28：欧州は冬時間に戻ったが、米国はまだ夏時間
   const datetime autumnGap = StringToTime("2026.10.28 12:00");
   Check("2026.10.28  US=summer",  g_clock.DstUsAt(autumnGap));
   Check("2026.10.28  EU=winter", !g_clock.DstEuropeAt(autumnGap));
   Check("2026.10.28  the two differ",
         g_clock.DstUsAt(autumnGap) != g_clock.DstEuropeAt(autumnGap));

   //--- 真夏と真冬は一致する
   Check("2026.07.01  both summer",
         g_clock.DstUsAt(StringToTime("2026.07.01 12:00")) &&
         g_clock.DstEuropeAt(StringToTime("2026.07.01 12:00")));
   Check("2026.01.15  both winter",
         !g_clock.DstUsAt(StringToTime("2026.01.15 12:00")) &&
         !g_clock.DstEuropeAt(StringToTime("2026.01.15 12:00")));

   Print("  note: during the gap London-NY is 4 hours, not 5");
  }

//+------------------------------------------------------------------+
//| 年をまたいでも式が壊れないこと                                    |
//+------------------------------------------------------------------+
void TestMultiYear()
  {
   Print("---- multi-year sanity ----");

   //--- 2025：EU 3/30・10/26、US 3/9・11/2
   Check("2025.03.20  US=summer EU=winter",
         g_clock.DstUsAt(StringToTime("2025.03.20 12:00")) &&
         !g_clock.DstEuropeAt(StringToTime("2025.03.20 12:00")));

   //--- 2027：EU 3/28・10/31、US 3/14・11/7
   Check("2027.03.20  US=summer EU=winter",
         g_clock.DstUsAt(StringToTime("2027.03.20 12:00")) &&
         !g_clock.DstEuropeAt(StringToTime("2027.03.20 12:00")));

   Check("2027.11.03  US=winter",
         !g_clock.DstUsAt(StringToTime("2027.11.03 12:00")));
  }

//+------------------------------------------------------------------+
//| 現在時刻での動作                                                  |
//+------------------------------------------------------------------+
void TestLive()
  {
   Print("---- live state ----");

   g_clock.Refresh();

   Check("IsReady", g_clock.IsReady());

   PrintFormat("  server time : %s",
               TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES));
   PrintFormat("  GMT (calc)  : %s",
               TimeToString(g_clock.GmtNow(), TIME_DATE | TIME_MINUTES));
   PrintFormat("  Tokyo       : %s",
               TimeToString(g_clock.TokyoNow(), TIME_DATE | TIME_MINUTES));
   PrintFormat("  DST  EU=%s  US=%s",
               (g_clock.IsDstEurope() ? "on" : "off"),
               (g_clock.IsDstUS()     ? "on" : "off"));

   for(int i = 0; i < SESSION_COUNT; i++)
     {
      const ENUM_SESSION s = (ENUM_SESSION)i;
      PrintFormat("  %-8s local=%s  phase=%-4s  toOpen=%d min",
                  SessionToString(s),
                  TimeToString(g_clock.LocalNow(s), TIME_MINUTES),
                  SessionPhaseToString(g_clock.GetPhase(s)),
                  g_clock.GetMinutesToOpen(s));
     }

   //--- 4市場すべてが同時に開くことはない
   Check("open count is 0..3", g_clock.GetOpenCount() >= 0 &&
                               g_clock.GetOpenCount() <= 3);

   Print("  display : " + g_clock.GetDisplayText());
   Print("  detail  : " + g_clock.BuildDetailText());
  }

//+------------------------------------------------------------------+
void OnStart()
  {
   Print("==================================================");
   Print(" Test_SessionClock  (GMD " + GMD_VERSION + ")");
   Print("==================================================");

   g_logger.Init(Inp_LogLevel);

   g_clock.Init(GetPointer(g_logger),
                Inp_ServerStdGmtOffset,
                Inp_ServerFollowsEuDst,
                15, 30);

   TestDstEurope();
   TestDstUS();
   TestDstDivergence();
   TestMultiYear();
   TestLive();

   Print("--------------------------------------------------");
   PrintFormat(" result : PASS=%d  FAIL=%d", g_pass, g_fail);
   Print("==================================================");

   g_logger.Deinit();
  }
//+------------------------------------------------------------------+
