//+------------------------------------------------------------------+
//|                                                 ChartOverlay.mqh |
//|                        Global Market Dashboard Ultimate (GMD)     |
//|                                                                   |
//|  役割 : Hybrid / Chart モード時のチャート上オーバーレイ          |
//|        （移動平均・BB・Pivot 等）を担当する受け皿。              |
//|  状態 : [2.30+] 骨格のみ。表示モード拡張時に本実装する。         |
//|  依存 : DrawObjects / Types                                       |
//+------------------------------------------------------------------+
#property strict

#ifndef __GMD_CHART_OVERLAY_MQH__
#define __GMD_CHART_OVERLAY_MQH__

#include "../Core/Types.mqh"
#include "../Core/Utils.mqh"
#include "../Core/Logger.mqh"
#include "DrawObjects.mqh"

//+------------------------------------------------------------------+
class CChartOverlay
  {
private:
   CLogger      *m_log;
   CDrawObjects *m_draw;
   string        m_prefix;
   bool          m_built;
   bool          m_enabled;

public:
                 CChartOverlay(void)
                   : m_log(NULL), m_draw(NULL), m_prefix("GMD_Ov_"),
                     m_built(false), m_enabled(false) {}
                ~CChartOverlay(void) {}

   bool          Init(CLogger *logger, CDrawObjects *draw,
                      const string prefix = "GMD_Ov_")
     {
      m_log    = logger;
      m_draw   = draw;
      m_prefix = prefix;
      return(true);
     }

   void          SetEnabled(const bool on) { m_enabled = on; }
   bool          IsEnabled(void) const     { return(m_enabled); }

   bool          Build(void)
     {
      m_built = true;
      return(true);
     }

   bool          Update(void)
     {
      if(!m_built || !m_enabled) return(false);
      // [2.30+] チャート要素の差分更新
      return(true);
     }

   void          Destroy(void)
     {
      m_built   = false;
      m_enabled = false;
     }

   string        GetName(void) { return("ChartOverlay"); }
  };

#endif // __GMD_CHART_OVERLAY_MQH__
//+------------------------------------------------------------------+
