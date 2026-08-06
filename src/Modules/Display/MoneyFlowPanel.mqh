//+------------------------------------------------------------------+
//|                                               MoneyFlowPanel.mqh |
//|                        Global Market Dashboard Ultimate (GMD)     |
//|                                                                   |
//|  役割 : Money Flow 行（Stocks / Gold / Bond / Crypto）の描画。   |
//|  状態 : [2.20] 骨格のみ。MoneyFlow Engine 実装後に本実装する。    |
//|  依存 : DrawObjects / Types                                       |
//+------------------------------------------------------------------+
#property strict

#ifndef __GMD_MONEYFLOW_PANEL_MQH__
#define __GMD_MONEYFLOW_PANEL_MQH__

#include "../Core/Types.mqh"
#include "../Core/Utils.mqh"
#include "../Core/Logger.mqh"
#include "DrawObjects.mqh"

//+------------------------------------------------------------------+
class CMoneyFlowPanel
  {
private:
   CLogger      *m_log;
   CDrawObjects *m_draw;
   string        m_prefix;
   int           m_x;
   int           m_y;
   int           m_rowHeight;
   bool          m_built;

public:
                 CMoneyFlowPanel(void)
                   : m_log(NULL), m_draw(NULL), m_prefix("GMD_Flow_"),
                     m_x(0), m_y(0), m_rowHeight(16), m_built(false) {}
                ~CMoneyFlowPanel(void) {}

   bool          Init(CLogger *logger, CDrawObjects *draw,
                      const int x, const int y, const int rowH,
                      const string prefix = "GMD_Flow_")
     {
      m_log       = logger;
      m_draw      = draw;
      m_x         = x;
      m_y         = y;
      m_rowHeight = rowH;
      m_prefix    = prefix;
      return(true);
     }

   bool          Build(void)
     {
      m_built = true;
      return(true);
     }

   bool          Update(void)
     {
      if(!m_built) return(false);
      // [2.20] MoneyFlow Engine 接続後に実装
      return(true);
     }

   void          Destroy(void) { m_built = false; }
   string        GetName(void) { return("MoneyFlowPanel"); }
  };

#endif // __GMD_MONEYFLOW_PANEL_MQH__
//+------------------------------------------------------------------+
