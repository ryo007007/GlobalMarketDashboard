//+------------------------------------------------------------------+
//|                                                    CycleEngine.mqh |
//|                        Global Market Dashboard Ultimate (GMD)     |
//|                                                                   |
//|  役割 : サイクル位相の記述（日数断定ではなくフェーズ表示）         |
//|  仕様 : Project Specification v2.0 第45.2章                       |
//|  状態 : [2.30+] 骨格。特定市販理論の再現は要件にしない。          |
//+------------------------------------------------------------------+
#property strict

#ifndef __GMD_CYCLE_ENGINE_MQH__
#define __GMD_CYCLE_ENGINE_MQH__

#include "../Core/Types.mqh"
#include "../Core/Logger.mqh"
#include "../Interfaces/IEngine.mqh"

class CCycleEngine : public IEngine
  {
private:
   CLogger *m_log;
   bool     m_ready;

public:
            CCycleEngine(void) : m_log(NULL), m_ready(false) {}
           ~CCycleEngine(void) {}

   bool     Init(CLogger *logger)
     {
      m_log = logger; m_ready = false;
      if(m_log != NULL) m_log.Info("CycleEngine: reserved [2.30+]");
      return(true);
     }

   bool     Calculate(void) override { m_ready = false; return(false); }
   bool     IsReady(void) override   { return(m_ready); }
   string   GetName(void) override   { return("Cycle"); }
   string   GetPhaseText(void)       { return("--"); }
   string   GetDisplayText(void)     { return("Cycle  --  (Ver2.30+)"); }
  };

#endif
//+------------------------------------------------------------------+
