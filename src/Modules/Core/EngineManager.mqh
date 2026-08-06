//+------------------------------------------------------------------+
//|                                                 EngineManager.mqh |
//|                        Global Market Dashboard Ultimate (GMD)     |
//|                                                                   |
//|  役割 : 全 Engine の登録・更新順・ON/OFF・縮退を一箇所で管理する  |
//|  仕様 : Project Specification v2.0 第44章                         |
//|  状態 : [2.20+] 骨格。Ver2.11 は本体 CalcAll() が同等の役割。     |
//|                                                                   |
//|  Dashboard は分析 Engine を直接並べず、将来はここだけを呼ぶ。     |
//+------------------------------------------------------------------+
#property strict

#ifndef __GMD_ENGINE_MANAGER_MQH__
#define __GMD_ENGINE_MANAGER_MQH__

#include "Types.mqh"
#include "Logger.mqh"
#include "../Interfaces/IEngine.mqh"

#define GMD_ENGINE_MANAGER_MAX 24

//+------------------------------------------------------------------+
class CEngineManager
  {
private:
   CLogger  *m_log;
   IEngine  *m_engines[GMD_ENGINE_MANAGER_MAX];
   bool      m_enabled[GMD_ENGINE_MANAGER_MAX];
   int       m_count;
   bool      m_ready;

public:
             CEngineManager(void) : m_log(NULL), m_count(0), m_ready(false)
     {
      for(int i = 0; i < GMD_ENGINE_MANAGER_MAX; i++)
        {
         m_engines[i] = NULL;
         m_enabled[i] = false;
        }
     }
            ~CEngineManager(void) {}

   bool      Init(CLogger *logger)
     {
      m_log   = logger;
      m_count = 0;
      m_ready = true;
      if(m_log != NULL)
         m_log.Info("EngineManager: skeleton [2.20+] — Ver2.11 uses CalcAll()");
      return(true);
     }

   bool      Register(IEngine *engine, const bool enabled = true)
     {
      if(engine == NULL || m_count >= GMD_ENGINE_MANAGER_MAX)
         return(false);
      m_engines[m_count] = engine;
      m_enabled[m_count] = enabled;
      m_count++;
      return(true);
     }

   // 登録順 = 更新順。依存順は Register する側（本体）が保証する
   bool      CalculateAll(void)
     {
      bool any = false;
      for(int i = 0; i < m_count; i++)
        {
         if(!m_enabled[i] || m_engines[i] == NULL)
            continue;
         if(m_engines[i].Calculate())
            any = true;
        }
      return(any);
     }

   int       GetCount(void) const { return(m_count); }
   bool      IsReady(void) const  { return(m_ready); }
   string    GetName(void)        { return("EngineManager"); }
  };

#endif // __GMD_ENGINE_MANAGER_MQH__
//+------------------------------------------------------------------+
