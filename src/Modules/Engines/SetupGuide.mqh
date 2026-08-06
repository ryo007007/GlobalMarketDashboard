//+------------------------------------------------------------------+
//|                                                   SetupGuide.mqh |
//|                        Global Market Dashboard Ultimate (GMD)     |
//|                                                                   |
//|  役割 : 複数エンジンを統合し「今日噛み合いやすい戦略の型」を      |
//|        ガイド表示する。売買強制シグナルではない。                 |
//|  仕様 : Project Specification v1.9 第43章                         |
//|  状態 : [3.00] 骨格。IsReady() は常に false。                     |
//|                                                                   |
//|  星は「材料の揃い」であり勝率・確率ではない。                     |
//+------------------------------------------------------------------+
#property strict

#ifndef __GMD_SETUP_GUIDE_MQH__
#define __GMD_SETUP_GUIDE_MQH__

#include "../Core/Types.mqh"
#include "../Core/Logger.mqh"
#include "../Interfaces/IEngine.mqh"

//+------------------------------------------------------------------+
class CSetupGuide : public IEngine
  {
private:
   CLogger *m_log;
   bool     m_ready;

public:
            CSetupGuide(void) : m_log(NULL), m_ready(false) {}
           ~CSetupGuide(void) {}

   bool     Init(CLogger *logger)
     {
      m_log   = logger;
      m_ready = false;
      if(m_log != NULL)
         m_log.Info("SetupGuide: reserved for [3.00] — not a trade signal");
      return(true);
     }

   // 将来: SetStructure / SetStrength / SetEnergy ... でポインタを受け取る

   bool     Calculate(void) override
     {
      m_ready = false;
      return(false);
     }

   bool     IsReady(void) override { return(m_ready); }
   string   GetName(void) override { return("SetupGuide"); }

   string   GetSetupTitle(void) { return("--"); }
   int      GetStars(void)      { return(0); }   // 材料の揃い。勝率ではない

   string   GetDisplayText(void)
     {
      return("Today's Setup  --  (Ver3.00)");
     }
  };

#endif // __GMD_SETUP_GUIDE_MQH__
//+------------------------------------------------------------------+
