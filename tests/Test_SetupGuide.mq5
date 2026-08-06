//+------------------------------------------------------------------+
//|                                                Test_SetupGuide.mq5 |
//|                        Global Market Dashboard Ultimate (GMD)      |
//|  状態 : [3.00] プレースホルダ。シグナルではないことを確認する。  |
//+------------------------------------------------------------------+
#property copyright "GMD Project"
#property version   "0.10"
#property script_show_inputs
#property strict

#include "../src/Modules/Core/Types.mqh"
#include "../src/Modules/Core/Logger.mqh"
#include "../src/Modules/Engines/SetupGuide.mqh"

input ENUM_LOG_LEVEL Inp_LogLevel = LOG_INFO;

CLogger     g_logger;
CSetupGuide g_setup;

void OnStart()
  {
   Print("========================================");
   Print(" GMD SetupGuide - placeholder [3.00]");
   Print("========================================");
   g_logger.Init(Inp_LogLevel);
   g_setup.Init(GetPointer(g_logger));
   g_setup.Calculate();
   PrintFormat("  name=%s  ready=%s  stars=%d  title=%s",
               g_setup.GetName(),
               (g_setup.IsReady() ? "true" : "false"),
               g_setup.GetStars(),
               g_setup.GetSetupTitle());
   PrintFormat("  display=%s", g_setup.GetDisplayText());
   if(!g_setup.IsReady() && g_setup.GetStars() == 0)
      Print("  STUB PASS: inactive and not presenting a fake setup");
   else
      Print("  STUB FAIL");
   g_logger.Deinit();
  }
//+------------------------------------------------------------------+
