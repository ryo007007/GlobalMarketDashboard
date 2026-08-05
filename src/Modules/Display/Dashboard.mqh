//+------------------------------------------------------------------+
//|                                                    Dashboard.mqh |
//|                        Global Market Dashboard Ultimate (GMD)     |
//|                                                                   |
//|  役割 : エンジンの結果を1枚のパネルにまとめて表示する            |
//|  依存 : Types / Utils / DrawObjects / CurrencyStrength /          |
//|         BestPair / Confidence                                     |
//|  仕様 : Project Specification v1.3 第15章                         |
//|                                                                   |
//|  レイアウト（Ver2.11）                                            |
//|    ┌────────────────────────────┐                                 |
//|    │ GLOBAL MARKET DASHBOARD  M1 │  ← タイトル                    |
//|    ├────────────────────────────┤                                 |
//|    │ ① USD   72  ↑↑↑            │  ← 1位だけ赤                   |
//|    │ ② EUR   61  ↑↑             │                                 |
//|    │  …                          │  ← 2〜7位は白                  |
//|    │ ⑧ JPY   28  ↓↓↓            │  ← 8位だけ青                   |
//|    ├────────────────────────────┤                                 |
//|    │ Best   USDJPY  BUY          │                                 |
//|    │ Confidence 78%  (FX only)   │                                 |
//|    │ Regime  --  (Ver2.20)       │                                 |
//|    │ 28/28 pairs   12:34:56      │  ← フッター                    |
//|    └────────────────────────────┘                                 |
//|                                                                   |
//|  色は赤・白・青の3つだけ。増やさない（15.1）。                    |
//+------------------------------------------------------------------+
#property strict

#ifndef __GMD_DASHBOARD_MQH__
#define __GMD_DASHBOARD_MQH__

#include "../Core/Types.mqh"
#include "../Core/Utils.mqh"
#include "../Core/Logger.mqh"
#include "DrawObjects.mqh"
#include "../Engines/CurrencyStrength.mqh"
#include "../Engines/BestPair.mqh"
#include "../Engines/Confidence.mqh"

//+------------------------------------------------------------------+
class CDashboard
  {
private:
   CCurrencyStrength *m_cs;
   CBestPair         *m_bestPair;
   CConfidence       *m_confidence;
   CLogger           *m_log;

   //--- レイアウト
   int               m_x;
   int               m_y;
   int               m_fontSize;
   int               m_rowHeight;
   int               m_panelWidth;
   string            m_font;
   ENUM_BASE_CORNER  m_corner;

   //--- 配色
   color             m_bgColor;
   color             m_borderColor;
   color             m_titleColor;
   color             m_subColor;

   bool              m_built;
   int               m_lastRedrawCount;

   //--- 内部
   int               RowY(const int row) { return(m_y + 8 + row * m_rowHeight); }
   string            BuildRankRow(const int rank);
   string            BuildTitleText(void);
   string            BuildFooterText(void);

public:
                     CDashboard(void);
                    ~CDashboard(void);

   bool              Init(CCurrencyStrength *cs,
                          CBestPair *bestPair,
                          CConfidence *confidence,
                          CLogger *logger);

   void              SetLayout(const int x, const int y,
                               const int fontSize = 9,
                               const ENUM_BASE_CORNER corner = CORNER_LEFT_UPPER);
   void              SetColors(const color bg, const color border);

   bool              Build(void);       // オブジェクトを1度だけ作る
   bool              Update(void);      // 値だけ差し替える
   void              Destroy(void);     // 全消し

   int               GetLastRedrawCount(void) const { return(m_lastRedrawCount); }
  };

//+------------------------------------------------------------------+
CDashboard::CDashboard(void) : m_cs(NULL),
                               m_bestPair(NULL),
                               m_confidence(NULL),
                               m_log(NULL),
                               m_x(20),
                               m_y(30),
                               m_fontSize(9),
                               m_rowHeight(16),
                               m_panelWidth(230),
                               m_font("Consolas"),
                               m_corner(CORNER_LEFT_UPPER),
                               m_bgColor(C'20,20,24'),
                               m_borderColor(C'70,70,78'),
                               m_titleColor(clrWhite),
                               m_subColor(clrSilver),
                               m_built(false),
                               m_lastRedrawCount(0)
  {
  }

//+------------------------------------------------------------------+
CDashboard::~CDashboard(void)
  {
  }

//+------------------------------------------------------------------+
bool CDashboard::Init(CCurrencyStrength *cs,
                      CBestPair *bestPair,
                      CConfidence *confidence,
                      CLogger *logger)
  {
   m_cs         = cs;
   m_bestPair   = bestPair;
   m_confidence = confidence;
   m_log        = logger;
   m_built      = false;

   if(m_cs == NULL)
     {
      if(m_log != NULL)
         m_log.Error("DP-603", "Dashboard: CurrencyStrength is NULL");
      return(false);
     }
   return(true);
  }

//+------------------------------------------------------------------+
void CDashboard::SetLayout(const int x, const int y,
                           const int fontSize,
                           const ENUM_BASE_CORNER corner)
  {
   m_x        = x;
   m_y        = y;
   m_fontSize = fontSize;
   m_corner   = corner;

   //--- 文字サイズに合わせて行間とパネル幅を決める
   m_rowHeight  = fontSize + 7;
   m_panelWidth = fontSize * 25;
  }

//+------------------------------------------------------------------+
void CDashboard::SetColors(const color bg, const color border)
  {
   m_bgColor     = bg;
   m_borderColor = border;
  }

//+------------------------------------------------------------------+
//| 1度だけ作る。以降は Update() で中身だけ差し替える                 |
//+------------------------------------------------------------------+
bool CDashboard::Build(void)
  {
   //--- 行構成
   //   0        : タイトル
   //   1        : 区切り
   //   2  〜 9  : ランキング8行
   //   10       : 区切り
   //   11       : Best Pair
   //   12       : Confidence
   //   13       : Regime（Ver2.20の枠）
   //   14       : フッター
   const int totalRows   = 15;
   const int panelHeight = 16 + totalRows * m_rowHeight;

   DrawPanel(CalcObjectName("Panel"), m_x, m_y,
             m_panelWidth, panelHeight,
             m_bgColor, m_borderColor, m_corner);

   const int tx = m_x + 10;

   DrawLabel(CalcObjectName("Title"), tx, RowY(0),
             BuildTitleText(), m_titleColor, m_fontSize + 1, m_font, m_corner);

   DrawSeparator(CalcObjectName("Sep1"), m_x + 8, RowY(1) + 6,
                 m_panelWidth - 16, m_borderColor, m_corner);

   for(int r = 1; r <= CUR_COUNT; r++)
      DrawLabel(CalcObjectName("Rank", r), tx, RowY(1 + r),
                BuildRankRow(r), clrWhite, m_fontSize, m_font, m_corner);

   DrawSeparator(CalcObjectName("Sep2"), m_x + 8, RowY(10) + 6,
                 m_panelWidth - 16, m_borderColor, m_corner);

   DrawLabel(CalcObjectName("BestPair"), tx, RowY(11),
             "Best  --", clrGray, m_fontSize, m_font, m_corner);

   DrawLabel(CalcObjectName("Confidence"), tx, RowY(12),
             "Confidence  --", clrGray, m_fontSize, m_font, m_corner);

   DrawLabel(CalcObjectName("Regime"), tx, RowY(13),
             "Regime  --  [2.20]", m_subColor, m_fontSize, m_font, m_corner);

   DrawLabel(CalcObjectName("Footer"), tx, RowY(14),
             BuildFooterText(), m_subColor, m_fontSize - 1, m_font, m_corner);

   m_built = true;
   ChartRedraw(0);
   return(true);
  }

//+------------------------------------------------------------------+
//| 値だけ差し替える。変化がなければ再描画も呼ばない                  |
//+------------------------------------------------------------------+
bool CDashboard::Update(void)
  {
   if(!m_built)
      return(false);

   int changed = 0;

   //--- タイトル
   if(UpdateLabel(CalcObjectName("Title"), BuildTitleText(), m_titleColor))
      changed++;

   //--- ランキング
   for(int r = 1; r <= CUR_COUNT; r++)
     {
      color clr = clrGray;

      if(m_cs != NULL && m_cs.IsReady())
         clr = m_cs.GetColor(m_cs.GetByRank(r));

      if(UpdateLabel(CalcObjectName("Rank", r), BuildRankRow(r), clr))
         changed++;
     }

   //--- Best Pair
   if(m_bestPair != NULL)
     {
      const string txt = "Best  " + m_bestPair.GetDisplayText();

      if(UpdateLabel(CalcObjectName("BestPair"), txt, m_bestPair.GetColor()))
         changed++;
     }

   //--- Confidence
   if(m_confidence != NULL)
     {
      if(UpdateLabel(CalcObjectName("Confidence"),
                     m_confidence.GetDisplayText(),
                     m_confidence.GetColor()))
         changed++;
     }

   //--- フッター
   if(UpdateLabel(CalcObjectName("Footer"), BuildFooterText(), m_subColor))
      changed++;

   m_lastRedrawCount = changed;

   if(changed > 0)
      ChartRedraw(0);

   return(true);
  }

//+------------------------------------------------------------------+
void CDashboard::Destroy(void)
  {
   DeleteAllObjects();
   m_built = false;
  }

//+------------------------------------------------------------------+
//| "GLOBAL MARKET DASHBOARD   M1"                                    |
//+------------------------------------------------------------------+
string CDashboard::BuildTitleText(void)
  {
   if(m_cs == NULL)
      return("GLOBAL MARKET DASHBOARD");

   return(StringFormat("GLOBAL MARKET DASHBOARD  %s",
                       CalcTimeframeText(m_cs.GetTimeframe())));
  }

//+------------------------------------------------------------------+
//| "① USD   72  ↑↑↑"                                                |
//+------------------------------------------------------------------+
string CDashboard::BuildRankRow(const int rank)
  {
   if(m_cs == NULL || !m_cs.IsReady())
      return(CalcRankMark(rank) + " ---   --");

   const ENUM_CURRENCY c = m_cs.GetByRank(rank);

   return(StringFormat("%s %s %s  %s",
                       CalcRankMark(rank),
                       PadRight(CurrencyToString(c), 4),
                       PadLeft(IntegerToString((int)MathRound(m_cs.GetScore(c))), 3),
                       m_cs.GetArrow(c)));
  }

//+------------------------------------------------------------------+
//| "24/28 pairs        21:05:30"                                     |
//+------------------------------------------------------------------+
string CDashboard::BuildFooterText(void)
  {
   const int used = (m_cs != NULL ? m_cs.GetPairsUsed() : 0);

   return(StringFormat("%d/%d pairs   %s",
                       used,
                       GMD_FX_PAIR_MAX,
                       TimeToString(TimeCurrent(), TIME_SECONDS)));
  }

#endif // __GMD_DASHBOARD_MQH__
//+------------------------------------------------------------------+
