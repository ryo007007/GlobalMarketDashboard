//+------------------------------------------------------------------+
//|                                              SessionManager.mqh   |
//|                        Global Market Dashboard Ultimate (GMD)     |
//|                                                                   |
//|  役割 : 将来の複合セッション制御の受け皿                           |
//|  依存 : SessionClock.mqh, Logger.mqh                              |
//|  状態 : [2.20+] で育てる。Ver2.11では SessionClock を正式採用      |
//+------------------------------------------------------------------+
#property strict

#ifndef __GMD_SESSIONMANAGER_MQH__
#define __GMD_SESSIONMANAGER_MQH__

#include "SessionClock.mqh"
#include "Logger.mqh"

class CSessionManager
  {
private:
   CLogger *m_log;
   bool     m_ready;

public:
                    CSessionManager(void);
                   ~CSessionManager(void);

   bool             Init(CLogger *logger)
     {
      m_log   = logger;
      m_ready = false;   // Ver2.11では SessionClock を使う
      return(true);
     }

   bool             IsReady(void) const { return(m_ready); }
   string           GetDisplayText(void) { return("SessionManager [reserved]"); }
  };

CSessionManager::CSessionManager(void) : m_log(NULL), m_ready(false) {}
CSessionManager::~CSessionManager(void) {}

#endif // __GMD_SESSIONMANAGER_MQH__
//+------------------------------------------------------------------+
