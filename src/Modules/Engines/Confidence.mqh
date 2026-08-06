//+------------------------------------------------------------------+
//|                                                   Confidence.mqh |
//|                        Global Market Dashboard Ultimate (GMD)     |
//|                                                                   |
//|  役割 : 表示している判断をどれだけ信じてよいかを0〜100%で示す     |
//|  依存 : Types.mqh, CurrencyStrength.mqh                           |
//|  仕様 : Project Specification v1.6 第8章（8.3.1 Ver2.11暫定式）   |
//|                                                                   |
//|  [2.11] Confidence = (50 + Spread/2) × (PairsUsed / 28)           |
//|  [2.20] MoneyFlow / MarketRegime を加えた加重平均へ移行する       |
//+------------------------------------------------------------------+
#property strict

#ifndef __GMD_CONFIDENCE_MQH__
#define __GMD_CONFIDENCE_MQH__

#include "../Core/Types.mqh"
#include "../Core/Logger.mqh"
#include "../Core/Utils.mqh"
#include "CurrencyStrength.mqh"
#include "AnomalyEngine.mqh"

//+------------------------------------------------------------------+
class CConfidence : public IEngine
  {
private:
   CCurrencyStrength *m_cs;
   CAnomalyEngine    *m_anomaly;        // 任意。NULLでも動く
   CLogger           *m_log;

   double            m_base;            // データ品質だけの信頼度
   double            m_confidence;      // 0〜100（調整後）
   double            m_spreadPart;      // 内訳：強弱の明確さ
   double            m_dataPart;        // 内訳：データ充足率
   int               m_anomalyAdj;      // 内訳：アノマリー調整
   bool              m_useAnomaly;      // アノマリーを信頼度に反映するか
   ENUM_ANOMALY_SCOPE m_scope;          // どの範囲のアノマリーを使うか
   bool              m_available;       // 算出できたか
   bool              m_ready;

public:
                     CConfidence(void);
                    ~CConfidence(void);

   bool              Init(CCurrencyStrength *cs, CLogger *logger);

   //--- アノマリーの接続（任意）
   //    useAnomaly=false なら、参照だけして信頼度の値は変えない
   void              SetAnomaly(CAnomalyEngine *anomaly,
                                const bool useAnomaly = false,
                                const ENUM_ANOMALY_SCOPE scope = SCOPE_FX);

   //--- IEngine
   bool              Calculate(void);
   bool              IsReady(void) { return(m_ready); }
   string            GetName(void) { return("Confidence"); }

   //--- 参照
   double                GetConfidence(void)     { return(m_confidence); }
   double                GetBaseConfidence(void) { return(m_base);       }
   int                   GetAnomalyAdj(void)     { return(m_anomalyAdj); }
   bool                  IsAvailable(void)       { return(m_available);  }
   ENUM_CONFIDENCE_LEVEL GetLevel(void);
   string                GetLevelText(void);
   string                GetDisplayText(void);
   string                GetBreakdownText(void);
   color                 GetColor(void);
  };

//+------------------------------------------------------------------+
CConfidence::CConfidence(void) : m_cs(NULL),
                                 m_anomaly(NULL),
                                 m_log(NULL),
                                 m_base(0.0),
                                 m_confidence(0.0),
                                 m_spreadPart(0.0),
                                 m_dataPart(0.0),
                                 m_anomalyAdj(0),
                                 m_useAnomaly(false),
                                 m_scope(SCOPE_FX),
                                 m_available(false),
                                 m_ready(false)
  {
  }

//+------------------------------------------------------------------+
void CConfidence::SetAnomaly(CAnomalyEngine *anomaly,
                             const bool useAnomaly,
                             const ENUM_ANOMALY_SCOPE scope)
  {
   m_anomaly    = anomaly;
   m_useAnomaly = useAnomaly;
   m_scope      = scope;
  }

//+------------------------------------------------------------------+
CConfidence::~CConfidence(void)
  {
  }

//+------------------------------------------------------------------+
bool CConfidence::Init(CCurrencyStrength *cs, CLogger *logger)
  {
   m_cs    = cs;
   m_log   = logger;
   m_ready = false;

   if(m_cs == NULL)
     {
      if(m_log != NULL)
         m_log.Error("CF-402", "Confidence: CurrencyStrength is NULL");
      return(false);
     }
   return(true);
  }

//+------------------------------------------------------------------+
//| 計算（Ver2.11 暫定式）                                            |
//|   base  = 50 + Spread / 2        … 強弱がどれだけ開いているか    |
//|   ratio = PairsUsed / 28         … データがどれだけ揃っているか  |
//|   Confidence = base × ratio                                       |
//+------------------------------------------------------------------+
bool CConfidence::Calculate(void)
  {
   m_ready      = false;
   m_available  = false;
   m_confidence = 0.0;
   m_base       = 0.0;
   m_anomalyAdj = 0;

   if(m_cs == NULL)
      return(false);

   //--- 強弱が計算できていなければ「算出不可」。0%にはしない
   if(!m_cs.IsReady())
     {
      if(m_log != NULL)
         m_log.Warn("CF-401", "Confidence unavailable: no engine produced a result.");
      m_ready = true;
      return(true);
     }

   const double spread    = m_cs.GetSpread();                  // 0〜100
   const int    pairsUsed = m_cs.GetPairsUsed();               // 0〜28

   m_spreadPart = 50.0 + spread / 2.0;
   m_dataPart   = (double)pairsUsed / 28.0 * 100.0;

   if(m_dataPart > 100.0)
      m_dataPart = 100.0;

   m_base       = m_spreadPart * (m_dataPart / 100.0);
   m_confidence = m_base;

   //--- アノマリー調整
   //    参照は常にするが、値を動かすのは m_useAnomaly が true のときだけ。
   //    既定で切ってある理由は 8.4 に書いたとおり、
   //    「この表示を信じてよいか」と「今日は上がりやすいか」は
   //    別の問いだから。混ぜると、低い数値の原因が分からなくなる。
   if(m_anomaly != NULL && m_anomaly.IsReady())
     {
      m_anomalyAdj = m_anomaly.GetScore(m_scope);

      if(m_useAnomaly)
         m_confidence += (double)m_anomalyAdj;
     }

   //--- 0〜100 にクリップ
   m_base       = CalcClamp(m_base,       0.0, 100.0);
   m_confidence = CalcClamp(m_confidence, 0.0, 100.0);

   m_available = true;
   m_ready     = true;
   return(true);
  }

//+------------------------------------------------------------------+
ENUM_CONFIDENCE_LEVEL CConfidence::GetLevel(void)
  {
   if(m_confidence >= 80.0)
      return(CONF_HIGH);
   if(m_confidence >= 50.0)
      return(CONF_MEDIUM);
   return(CONF_LOW);
  }

//+------------------------------------------------------------------+
string CConfidence::GetLevelText(void)
  {
   switch(GetLevel())
     {
      case CONF_HIGH:   return("High");
      case CONF_MEDIUM: return("Medium");
      default:          return("Low");
     }
  }

//+------------------------------------------------------------------+
//| 表示用。Ver2.11 は FX の情報しか見ていないことを明示する          |
//+------------------------------------------------------------------+
string CConfidence::GetDisplayText(void)
  {
   if(!m_available)
      return("Confidence  --");

   //--- アノマリーを反映しているときは、内訳を必ず見せる。
   //    94% とだけ出すと、なぜ94なのか後から説明できない
   if(m_useAnomaly && m_anomalyAdj != 0)
      return(StringFormat("Confidence  %d%%  (%d %s)",
                          (int)MathRound(m_confidence),
                          (int)MathRound(m_base),
                          CalcSignedText(m_anomalyAdj)));

   return(StringFormat("Confidence  %d%%  (FX only)", (int)MathRound(m_confidence)));
  }

//+------------------------------------------------------------------+
string CConfidence::GetBreakdownText(void)
  {
   if(!m_available)
      return("no input available");

   return(StringFormat("spread part %.1f / data part %.1f%% / base %.1f / anomaly %s%s",
                       m_spreadPart, m_dataPart, m_base,
                       CalcSignedText(m_anomalyAdj),
                       (m_useAnomaly ? "" : " (not applied)")));
  }

//+------------------------------------------------------------------+
//| 信頼度に方向色（赤・青）は使わない（仕様書 15.3）                 |
//+------------------------------------------------------------------+
color CConfidence::GetColor(void)
  {
   if(!m_available)
      return(clrGray);

   return(GetLevel() == CONF_LOW ? clrGray : clrWhite);
  }

#endif // __GMD_CONFIDENCE_MQH__
//+------------------------------------------------------------------+
