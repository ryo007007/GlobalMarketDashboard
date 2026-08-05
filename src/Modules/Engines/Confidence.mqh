//+------------------------------------------------------------------+
//|                                                   Confidence.mqh |
//|                        Global Market Dashboard Ultimate (GMD)     |
//|                                                                   |
//|  役割 : 表示している判断をどれだけ信じてよいかを0〜100%で示す     |
//|  依存 : Types.mqh, CurrencyStrength.mqh                           |
//|  仕様 : Project Specification v1.3 第8章（8.3.1 Ver2.11暫定式）   |
//|                                                                   |
//|  [2.11] Confidence = (50 + Spread/2) × (PairsUsed / 28)           |
//|  [2.20] MoneyFlow / MarketRegime を加えた加重平均へ移行する       |
//+------------------------------------------------------------------+
#property strict

#ifndef __GMD_CONFIDENCE_MQH__
#define __GMD_CONFIDENCE_MQH__

#include "../Core/Types.mqh"
#include "../Core/Logger.mqh"
#include "CurrencyStrength.mqh"

//+------------------------------------------------------------------+
class CConfidence : public IEngine
  {
private:
   CCurrencyStrength *m_cs;
   CLogger           *m_log;

   double            m_confidence;      // 0〜100
   double            m_spreadPart;      // 内訳：強弱の明確さ
   double            m_dataPart;        // 内訳：データ充足率
   bool              m_available;       // 算出できたか
   bool              m_ready;

public:
                     CConfidence(void);
                    ~CConfidence(void);

   bool              Init(CCurrencyStrength *cs, CLogger *logger);

   //--- IEngine
   bool              Calculate(void);
   bool              IsReady(void) { return(m_ready); }
   string            GetName(void) { return("Confidence"); }

   //--- 参照
   double                GetConfidence(void) { return(m_confidence); }
   bool                  IsAvailable(void)   { return(m_available);  }
   ENUM_CONFIDENCE_LEVEL GetLevel(void);
   string                GetLevelText(void);
   string                GetDisplayText(void);
   string                GetBreakdownText(void);
   color                 GetColor(void);
  };

//+------------------------------------------------------------------+
CConfidence::CConfidence(void) : m_cs(NULL),
                                 m_log(NULL),
                                 m_confidence(0.0),
                                 m_spreadPart(0.0),
                                 m_dataPart(0.0),
                                 m_available(false),
                                 m_ready(false)
  {
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

   m_confidence = m_spreadPart * (m_dataPart / 100.0);

   //--- 0〜100 にクリップ
   if(m_confidence < 0.0)
      m_confidence = 0.0;
   if(m_confidence > 100.0)
      m_confidence = 100.0;

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

   return(StringFormat("Confidence  %d%%  (FX only)", (int)MathRound(m_confidence)));
  }

//+------------------------------------------------------------------+
string CConfidence::GetBreakdownText(void)
  {
   if(!m_available)
      return("no input available");

   return(StringFormat("spread part %.1f / data part %.1f%%",
                       m_spreadPart, m_dataPart));
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
