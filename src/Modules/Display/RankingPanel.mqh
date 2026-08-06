//+------------------------------------------------------------------+
//|                                                 RankingPanel.mqh |
//|                        Global Market Dashboard Ultimate (GMD)     |
//|                                                                   |
//|  役割 : 通貨強弱ランキング 8 行の描画を担当する。                 |
//|  依存 : DrawObjects / Types / CurrencyStrength                    |
//|  仕様 : Project Specification 第5章・第14章                       |
//|                                                                   |
//|  Ver2.11 では骨格のみ。Dashboard から段階的に切り出す。           |
//+------------------------------------------------------------------+
#property strict

#ifndef __GMD_RANKING_PANEL_MQH__
#define __GMD_RANKING_PANEL_MQH__

#include "../Core/Types.mqh"
#include "../Core/Utils.mqh"
#include "../Core/Logger.mqh"
#include "DrawObjects.mqh"
#include "../Engines/CurrencyStrength.mqh"

//+------------------------------------------------------------------+
class CRankingPanel
  {
private:
   CLogger             *m_log;
   CDrawObjects        *m_draw;
   CCurrencyStrength   *m_cs;
   string               m_prefix;
   int                  m_x;
   int                  m_y;
   int                  m_rowHeight;
   bool                 m_built;

public:
                        CRankingPanel(void)
                          : m_log(NULL), m_draw(NULL), m_cs(NULL),
                            m_prefix("GMD_Rank_"), m_x(0), m_y(0),
                            m_rowHeight(16), m_built(false) {}
                       ~CRankingPanel(void) {}

   bool                 Init(CLogger *logger, CDrawObjects *draw,
                             CCurrencyStrength *cs,
                             const int x, const int y, const int rowH,
                             const string prefix = "GMD_Rank_")
     {
      m_log       = logger;
      m_draw      = draw;
      m_cs        = cs;
      m_x         = x;
      m_y         = y;
      m_rowHeight = rowH;
      m_prefix    = prefix;
      return(true);
     }

   bool                 Build(void)
     {
      m_built = true;
      return(true);
     }

   bool                 Update(void)
     {
      if(!m_built || m_cs == NULL || m_draw == NULL)
         return(false);
      // 段階的にランキング行の差分更新をここに移す
      return(true);
     }

   void                 Destroy(void) { m_built = false; }
   string               GetName(void) { return("RankingPanel"); }
  };

#endif // __GMD_RANKING_PANEL_MQH__
//+------------------------------------------------------------------+
