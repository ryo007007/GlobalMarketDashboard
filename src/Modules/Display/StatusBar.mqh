//+------------------------------------------------------------------+
//|                                                    StatusBar.mqh |
//|                        Global Market Dashboard Ultimate (GMD)     |
//|                                                                   |
//|  役割 : フッター（更新間隔 / 段 / ペア数 / 時刻）の描画。         |
//|  依存 : DrawObjects / AdaptiveUpdate / SessionClock               |
//|  仕様 : 可変更新間隔を隠さない（性能切り分けのため常時表示）     |
//+------------------------------------------------------------------+
#property strict

#ifndef __GMD_STATUS_BAR_MQH__
#define __GMD_STATUS_BAR_MQH__

#include "../Core/Types.mqh"
#include "../Core/Utils.mqh"
#include "../Core/Logger.mqh"
#include "DrawObjects.mqh"

//+------------------------------------------------------------------+
class CStatusBar
  {
private:
   CLogger      *m_log;
   CDrawObjects *m_draw;
   string        m_prefix;
   int           m_x;
   int           m_y;
   bool          m_built;

public:
                 CStatusBar(void)
                   : m_log(NULL), m_draw(NULL), m_prefix("GMD_Status_"),
                     m_x(0), m_y(0), m_built(false) {}
                ~CStatusBar(void) {}

   bool          Init(CLogger *logger, CDrawObjects *draw,
                      const int x, const int y,
                      const string prefix = "GMD_Status_")
     {
      m_log    = logger;
      m_draw   = draw;
      m_x      = x;
      m_y      = y;
      m_prefix = prefix;
      return(true);
     }

   bool          Build(void)
     {
      m_built = true;
      return(true);
     }

   // text 例: "28/28 pairs   1000ms Normal   12:34:56"
   bool          Update(const string text)
     {
      if(!m_built || m_draw == NULL)
         return(false);
      // 段階的に差分更新をここに移す
      return(true);
     }

   void          Destroy(void) { m_built = false; }
   string        GetName(void) { return("StatusBar"); }
  };

#endif // __GMD_STATUS_BAR_MQH__
//+------------------------------------------------------------------+
