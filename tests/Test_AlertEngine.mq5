//+------------------------------------------------------------------+
//|                                               Test_AlertEngine.mq5 |
//|                        Global Market Dashboard Ultimate (GMD)      |
//|                                                                    |
//|  役割 : Alert Engine の枠が壊れていないことだけを確認する          |
//|  状態 : [2.30] エンジン未実装。置き場所の確保。                    |
//|                                                                    |
//|  今確認できること                                                  |
//|    ・include が通る                                                |
//|    ・Init / Raise / IsReady / GetDisplayText が呼べる              |
//|    ・未実装でも落ちず、IsReady() は false                          |
//|                                                                    |
//|  Ver2.30 でエッジ検出・ヒステリシス・冷却を入れたら中身を書く。    |
//+------------------------------------------------------------------+
#property copyright "GMD Project"
#property version   "0.10"
#property script_show_inputs
#property strict

#include "../src/Modules/Core/Types.mqh"
#include "../src/Modules/Core/Logger.mqh"
#include "../src/Modules/Engines/AlertEngine.mqh"

input ENUM_LOG_LEVEL Inp_LogLevel = LOG_INFO;

CLogger      g_logger;
CAlertEngine g_alert;

//+------------------------------------------------------------------+
void OnStart()
  {
   Print("========================================");
   Print(" GMD AlertEngine - placeholder test [2.30]");
   Print("========================================");

   g_logger.Init(Inp_LogLevel);
   g_alert.Init(GetPointer(g_logger));

   const bool raised = g_alert.Raise("test", "placeholder", ALERT_NOTICE);

   PrintFormat("  IsReady      : %s (expected: false)",
               (g_alert.IsReady() ? "true" : "false"));
   PrintFormat("  Raise()      : %s (expected: false until 2.30)",
               (raised ? "true" : "false"));
   PrintFormat("  fired count  : %d", g_alert.GetFiredCount());
   PrintFormat("  display      : \"%s\"", g_alert.GetDisplayText());

   if(!g_alert.IsReady() && !raised && g_alert.GetFiredCount() == 0)
      Print("  STUB PASS: engine is correctly inactive.");
   else
      Print("  STUB FAIL");

   g_logger.Deinit();
   Print("========================================");
  }
//+------------------------------------------------------------------+
