//+------------------------------------------------------------------+
//|                                                  AlertManager.mqh |
//|                        Global Market Dashboard Ultimate (GMD)     |
//|                                                                   |
//|  役割 : 各 Engine の通知要求を集約し、AlertEngine に渡す          |
//|  仕様 : Project Specification v2.0 第44.3章                       |
//|  状態 : [2.30+] 骨格。分析 Engine は Alert()/PlaySound を直接呼ばない |
//+------------------------------------------------------------------+
#property strict

#ifndef __GMD_ALERT_MANAGER_MQH__
#define __GMD_ALERT_MANAGER_MQH__

#include "Types.mqh"
#include "Logger.mqh"
#include "../Engines/AlertEngine.mqh"

//+------------------------------------------------------------------+
class CAlertManager
  {
private:
   CLogger      *m_log;
   CAlertEngine *m_alert;
   bool          m_ready;

public:
                 CAlertManager(void)
                   : m_log(NULL), m_alert(NULL), m_ready(false) {}
                ~CAlertManager(void) {}

   bool          Init(CLogger *logger, CAlertEngine *alert)
     {
      m_log   = logger;
      m_alert = alert;
      m_ready = false;   // [2.30] で本実装
      if(m_log != NULL)
         m_log.Info("AlertManager: reserved for [2.30+]");
      return(true);
     }

   // key 例: "pivot.wr1.approach" / "energy.released"
   bool          NotifyRequest(const string key, const string message,
                               const ENUM_ALERT_LEVEL level = ALERT_NOTICE)
     {
      if(!m_ready || m_alert == NULL)
         return(false);
      return(m_alert.Raise(key, message, level));
     }

   bool          IsReady(void) const { return(m_ready); }
   string        GetName(void)       { return("AlertManager"); }
  };

#endif // __GMD_ALERT_MANAGER_MQH__
//+------------------------------------------------------------------+
