//+------------------------------------------------------------------+
//|                                                 SummaryPanel.mqh |
//|                        Global Market Dashboard Ultimate (GMD)     |
//|                                                                   |
//|  役割 : Market Summary 行（Best Pair / Confidence / Regime 等）  |
//|         を描画する。Dashboard から呼び出される下請けパネル。       |
//|  依存 : DrawObjects / Types / Utils                               |
//|  仕様 : Project Specification 第14章・Display 分割方針            |
//|                                                                   |
//|  Ver2.11 では骨格のみ。実際の描画ロジックは Dashboard 内に残し、 |
//|  段階的にここに切り出す。                                         |
//+------------------------------------------------------------------+
#property strict

#ifndef __GMD_SUMMARY_PANEL_MQH__
#define __GMD_SUMMARY_PANEL_MQH__

#include "../Core/Types.mqh"
#include "../Core/Utils.mqh"
#include "../Core/Logger.mqh"
#include "DrawObjects.mqh"

//+------------------------------------------------------------------+
class CSummaryPanel
  {
private:
   CLogger          *m_log;
   CDrawObjects     *m_draw;
   string            m_prefix;      // オブジェクト名プレフィックス
   int               m_x;
   int               m_y;
   int               m_rowHeight;
   bool              m_built;

public:
                     CSummaryPanel(void)
                       : m_log(NULL), m_draw(NULL), m_prefix("GMD_Sum_"),
                         m_x(0), m_y(0), m_rowHeight(16), m_built(false) {}
                    ~CSummaryPanel(void) {}

   bool              Init(CLogger *logger, CDrawObjects *draw,
                          const int x, const int y, const int rowH,
                          const string prefix = "GMD_Sum_")
     {
      m_log        = logger;
      m_draw       = draw;
      m_x          = x;
      m_y          = y;
      m_rowHeight  = rowH;
      m_prefix     = prefix;
      return(true);
     }

   //--- 初回構築（オブジェクト生成）
   bool              Build(void)
     {
      // Ver2.11: Dashboard 側が統括描画中のため、ここではプレースホルダ
      m_built = true;
      return(true);
     }

   //--- 値のみ更新
   bool              Update(const string bestPairText,
                            const string confidenceText,
                            const string regimeText = "--")
     {
      if(!m_built || m_draw == NULL)
         return(false);
      // 段階的に ObjectSetString 等をここに移す
      return(true);
     }

   void              Destroy(void)
     {
      m_built = false;
     }

   string            GetName(void) { return("SummaryPanel"); }
  };

#endif // __GMD_SUMMARY_PANEL_MQH__
//+------------------------------------------------------------------+
