//+------------------------------------------------------------------+
//|                                               BollingerEngine.mqh |
//|                        Global Market Dashboard Ultimate (GMD)     |
//|                                                                   |
//|  役割 : 複数期間 BB の帯と価格位置を数値で返す（描画は Overlay） |
//|  仕様 : Project Specification v2.0 第45.1章                       |
//|  状態 : [2.30+] 骨格                                              |
//|                                                                   |
//|  20BB = ボラ / 200BB = 大きな居場所（役割を混ぜない）             |
//+------------------------------------------------------------------+
#property strict

#ifndef __GMD_BOLLINGER_ENGINE_MQH__
#define __GMD_BOLLINGER_ENGINE_MQH__

#include "../Core/Types.mqh"
#include "../Core/Logger.mqh"
#include "../Interfaces/IEngine.mqh"

class CBollingerEngine : public IEngine
  {
private:
   CLogger *m_log;
   string   m_symbol;
   bool     m_ready;

public:
            CBollingerEngine(void) : m_log(NULL), m_symbol(""), m_ready(false) {}
           ~CBollingerEngine(void) {}

   bool     Init(CLogger *logger, const string symbol)
     {
      m_log = logger; m_symbol = symbol; m_ready = false;
      if(m_log != NULL) m_log.Info("BollingerEngine: reserved [2.30+]");
      return(true);
     }

   bool     Calculate(void) override { m_ready = false; return(false); }
   bool     IsReady(void) override   { return(m_ready); }
   string   GetName(void) override   { return("Bollinger"); }
   string   GetDisplayText(void)     { return("BB  --  (Ver2.30+)"); }
  };

#endif
//+------------------------------------------------------------------+
