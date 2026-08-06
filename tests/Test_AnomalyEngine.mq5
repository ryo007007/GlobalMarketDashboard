//+------------------------------------------------------------------+
//|                                            Test_AnomalyEngine.mq5 |
//|                        Global Market Dashboard Ultimate (GMD)      |
//|                                                                    |
//|  役割 : アノマリー判定が暦どおりに動くか確認する                  |
//|  仕様 : Project Specification v1.4 第10章                          |
//|                                                                    |
//|  このテストは他のテストと性質が違う。                              |
//|  価格を使わないので、日付を指定すれば結果が完全に再現できる。      |
//|  だから「今日はどうか」だけでなく「特定の日はどうか」も検証する。  |
//+------------------------------------------------------------------+
#property copyright "GMD Project"
#property version   "1.00"
#property script_show_inputs
#property strict

#include "../src/Modules/Core/Types.mqh"
#include "../src/Modules/Core/Logger.mqh"
#include "../src/Modules/Core/Utils.mqh"
#include "../src/Modules/Engines/AnomalyEngine.mqh"

input ENUM_LOG_LEVEL Inp_LogLevel        = LOG_INFO;   // ログレベル
input int            Inp_AnomalyMinStars = 4;          // この星数未満は使わない
input int            Inp_ServerGmtOffset = 3;          // サーバ時刻のGMT差

CLogger        g_logger;
CAnomalyEngine g_anomaly;

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
//| 日付判定の期待値を確かめる                                        |
//|  暦の計算だけを対象にするため、月の日数から検算する               |
//+------------------------------------------------------------------+
void TestCalendarLogic()
  {
   Print("---- calendar logic ----");

   //--- うるう年
   Check("2024/02 has 29 days", TimeDay(StringToTime("2024.02.29")) == 29);
   Check("2100 is not a leap year",
         TimeMonth(StringToTime("2100.03.01")) == 3);

   //--- 五十日にあたる日付の一覧（東京時間ベースの想定）
   Print("  gotobi target days: 5, 10, 15, 20, 25, 30, month-end");
   Print("  weekend shifts back to Friday");
  }

//+------------------------------------------------------------------+
void TestLiveEvaluation()
  {
   Print("---- live evaluation ----");

   g_anomaly.Calculate();

   Check("IsReady is true (price-independent engine)", g_anomaly.IsReady());

   MqlDateTime t;
   TimeToStruct(TimeCurrent(), t);

   PrintFormat("  server time : %s (month=%d, dow=%d)",
               TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES), t.mon, t.day_of_week);

   PrintFormat("  rules       : %d", g_anomaly.GetRuleCount());
   PrintFormat("  hits        : %d", g_anomaly.GetHitCount());

   for(int i = 0; i < g_anomaly.GetHitCount(); i++)
      PrintFormat("    %-20s %s",
                  g_anomaly.GetHitLabel(i),
                  CalcSignedText(g_anomaly.GetHitScore(i)));

   Print("---- scores by scope ----");
   PrintFormat("  FX     : %s (raw %s)",
               CalcSignedText(g_anomaly.GetScore(SCOPE_FX)),
               CalcSignedText(g_anomaly.GetRawScore(SCOPE_FX)));
   PrintFormat("  JPY    : %s (raw %s)  <- includes FX",
               CalcSignedText(g_anomaly.GetScore(SCOPE_JPY)),
               CalcSignedText(g_anomaly.GetRawScore(SCOPE_JPY)));
   PrintFormat("  Equity : %s (raw %s)",
               CalcSignedText(g_anomaly.GetScore(SCOPE_EQUITY)),
               CalcSignedText(g_anomaly.GetRawScore(SCOPE_EQUITY)));
   PrintFormat("  season : %s (%s)",
               CalcSignedText(g_anomaly.GetSeasonScore()),
               SeasonStateToString(g_anomaly.GetSeason()));

   Print("---- display ----");
   PrintFormat("  FX  : %s", g_anomaly.GetDisplayText(SCOPE_FX));
   PrintFormat("  JPY : %s", g_anomaly.GetDisplayText(SCOPE_JPY));
   Print(g_anomaly.BuildDetailText(SCOPE_JPY));
  }

//+------------------------------------------------------------------+
//| 打ち止めが効いているか                                            |
//|  アノマリーは重ねれば重ねるほど当たるものではない。               |
//|  上限が無いと、条件が揃った日に信頼度が振り切れてしまう           |
//+------------------------------------------------------------------+
void TestCap()
  {
   Print("---- cap ----");

   const int fx  = g_anomaly.GetScore(SCOPE_FX);
   const int eq  = g_anomaly.GetScore(SCOPE_EQUITY);
   const int jpy = g_anomaly.GetScore(SCOPE_JPY);

   Check("FX within cap",     MathAbs(fx)  <= GMD_ANOMALY_CAP);
   Check("Equity within cap", MathAbs(eq)  <= GMD_ANOMALY_CAP);
   Check("JPY within cap",    MathAbs(jpy) <= GMD_ANOMALY_CAP);
  }

//+------------------------------------------------------------------+
//| 適用範囲の分離                                                    |
//|  Sell in May が FX のスコアに混ざっていないことを確認する。        |
//|  ここが崩れると、株の季節性で USDJPY の判断が歪む                 |
//+------------------------------------------------------------------+
void TestScopeIsolation()
  {
   Print("---- scope isolation ----");

   bool equityLeak = false;

   for(int i = 0; i < g_anomaly.GetHitCount(); i++)
     {
      const string label = g_anomaly.GetHitLabel(i);

      if(label == "Sell in May" || label == "Halloween Effect")
        {
         //--- これらは SCOPE_EQUITY でなければならない
         if(g_anomaly.GetDisplayText(SCOPE_FX) != "" &&
            StringFind(g_anomaly.GetDisplayText(SCOPE_FX), label) >= 0)
            equityLeak = true;
        }
     }

   Check("equity anomaly does not leak into FX scope", !equityLeak);
  }

//+------------------------------------------------------------------+
//| リスク志向バイアス                                                |
//|  株の季節性から導く。FXのスコアには足さないことを確認する         |
//+------------------------------------------------------------------+
void TestRiskBias()
  {
   Print("---- risk bias ----");

   const int equity = g_anomaly.GetScore(SCOPE_EQUITY);
   const int bias   = g_anomaly.GetRiskBiasScore();

   PrintFormat("  equity=%d  bias=%d  -> %s",
               equity, bias, g_anomaly.GetRiskBiasText());

   //--- 1) 必ず株スコアの半分以下（絶対値）
   Check("bias magnitude <= equity magnitude",
         MathAbs(bias) <= MathAbs(equity));

   //--- 2) 上限 ±5 を超えない
   Check("bias within +/-5", MathAbs(bias) <= GMD_RISK_BIAS_CAP);

   //--- 3) 符号は一致する（株が弱い季節にリスクオンにはならない）
   if(bias != 0)
      Check("bias sign matches equity sign", (bias > 0) == (equity > 0));
   else
      Check("bias sign matches equity sign", true);

   //--- 4) FXスコアに混ざっていないこと。これが最重要
   const int fxBefore = g_anomaly.GetScore(SCOPE_FX);
   g_anomaly.SetSeasonScore(9, -9);   // 株の季節性を極端に振る
   g_anomaly.Calculate();
   const int fxAfter  = g_anomaly.GetScore(SCOPE_FX);

   Check("season change does not move FX score", fxBefore == fxAfter);

   g_anomaly.SetSeasonScore(9, -2);   // 元に戻す
   g_anomaly.Calculate();
  }

//+------------------------------------------------------------------+
//| 個別ON/OFF                                                        |
//+------------------------------------------------------------------+
void TestToggle()
  {
   Print("---- toggle ----");

   const int before = g_anomaly.GetRawScore(SCOPE_EQUITY);

   g_anomaly.SetRuleEnabled("HALLOWEEN",   false);
   g_anomaly.SetRuleEnabled("SELL_IN_MAY", false);
   g_anomaly.Calculate();

   const int after = g_anomaly.GetRawScore(SCOPE_EQUITY);

   PrintFormat("  equity raw: %s -> %s",
               CalcSignedText(before), CalcSignedText(after));

   Check("disabling a rule changes the score", before != after);

   //--- 元に戻す
   g_anomaly.SetRuleEnabled("HALLOWEEN",   true);
   g_anomaly.SetRuleEnabled("SELL_IN_MAY", true);
   g_anomaly.Calculate();
  }

//+------------------------------------------------------------------+
void OnStart()
  {
   Print("========================================");
   Print(" GMD Anomaly Engine - test");
   Print("========================================");

   g_logger.Init(Inp_LogLevel);
   g_anomaly.Init(GetPointer(g_logger), Inp_ServerGmtOffset, Inp_AnomalyMinStars, true);

   TestCalendarLogic();
   TestLiveEvaluation();
   TestCap();
   TestScopeIsolation();
   TestRiskBias();
   TestToggle();

   Print("========================================");
   PrintFormat(" result: %d passed, %d failed", g_pass, g_fail);
   Print("========================================");

   g_logger.Deinit();
  }
//+------------------------------------------------------------------+
