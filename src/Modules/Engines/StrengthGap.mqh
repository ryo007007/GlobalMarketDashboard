//+------------------------------------------------------------------+
//|                                               StrengthGap.mqh     |
//|             Global Market Dashboard Ultimate (GMD)               |
//|                                                                  |
//|  Role    : Strength Gap Engine                                   |
//|  Depends : Types.mqh, CurrencyStrength.mqh                       |
//|  Spec    : Currency Strength -> Strongest/Weakest score gap      |
//|                                                                  |
//|  Formula :                                                        |
//|      StrengthGap = Strongest Score - Weakest Score                |
//|                                                                  |
//|  Range   : 0.0 .. 100.0                                           |
//|  Meaning :                                                        |
//|      0   = strongest and weakest are equal                        |
//|      50  = moderate separation                                    |
//|      100 = maximum separation                                     |
//|                                                                  |
//|  Important:                                                       |
//|      This engine does NOT modify CurrencyStrength calculations.   |
//|      It only reads the already calculated ranking/score.           |
//+------------------------------------------------------------------+
#property strict

#ifndef __GMD_STRENGTHGAP_MQH__
#define __GMD_STRENGTHGAP_MQH__

#include "../Core/Types.mqh"
#include "CurrencyStrength.mqh"

//+------------------------------------------------------------------+
//| CStrengthGap                                                     |
//+------------------------------------------------------------------+
class CStrengthGap : public IEngine
  {
private:
   CCurrencyStrength *m_strength;
   double             m_gap;
   bool               m_ready;

public:
                     CStrengthGap(void);
                    ~CStrengthGap(void);

   bool              Init(CCurrencyStrength *strength);

   //--- IEngine
   bool              Calculate(void);
   bool              IsReady(void) { return(m_ready); }
   string            GetName(void) { return("StrengthGap"); }

   //--- Results
   double            GetGap(void) const { return(m_gap); }

   //--- Convenience references
   ENUM_CURRENCY     GetStrongest(void);
   ENUM_CURRENCY     GetWeakest(void);
   double            GetStrongestScore(void);
   double            GetWeakestScore(void);

   //--- Debug / display
   string            BuildText(void);
  };

//+------------------------------------------------------------------+
CStrengthGap::CStrengthGap(void)
   : m_strength(NULL),
     m_gap(0.0),
     m_ready(false)
  {
  }

//+------------------------------------------------------------------+
CStrengthGap::~CStrengthGap(void)
  {
  }

//+------------------------------------------------------------------+
//| Initialize                                                        |
//+------------------------------------------------------------------+
bool CStrengthGap::Init(CCurrencyStrength *strength)
  {
   m_strength = strength;
   m_gap      = 0.0;
   m_ready    = false;

   if(m_strength == NULL)
      return(false);

   return(true);
  }

//+------------------------------------------------------------------+
//| Calculate                                                         |
//+------------------------------------------------------------------+
bool CStrengthGap::Calculate(void)
  {
   m_ready = false;
   m_gap   = 0.0;

   if(m_strength == NULL)
      return(false);

   // CurrencyStrength がまだランキングを確定していない場合は待つ
   if(!m_strength.IsReady())
      return(false);

   const double strongest = m_strength.GetScore(m_strength.GetStrongest());
   const double weakest   = m_strength.GetScore(m_strength.GetWeakest());

   double gap = strongest - weakest;

   // 浮動小数誤差・異常値を防ぐ
   if(gap < 0.0)
      gap = 0.0;
   if(gap > 100.0)
      gap = 100.0;

   m_gap   = gap;
   m_ready = true;

   return(true);
  }

//+------------------------------------------------------------------+
//| Strongest currency                                                |
//+------------------------------------------------------------------+
ENUM_CURRENCY CStrengthGap::GetStrongest(void)
  {
   if(m_strength == NULL || !m_strength.IsReady())
      return(CUR_USD);

   return(m_strength.GetStrongest());
  }

//+------------------------------------------------------------------+
//| Weakest currency                                                  |
//+------------------------------------------------------------------+
ENUM_CURRENCY CStrengthGap::GetWeakest(void)
  {
   if(m_strength == NULL || !m_strength.IsReady())
      return(CUR_USD);

   return(m_strength.GetWeakest());
  }

//+------------------------------------------------------------------+
//| Strongest score                                                   |
//+------------------------------------------------------------------+
double CStrengthGap::GetStrongestScore(void)
  {
   if(m_strength == NULL || !m_strength.IsReady())
      return(50.0);

   return(m_strength.GetScore(m_strength.GetStrongest()));
  }

//+------------------------------------------------------------------+
//| Weakest score                                                     |
//+------------------------------------------------------------------+
double CStrengthGap::GetWeakestScore(void)
  {
   if(m_strength == NULL || !m_strength.IsReady())
      return(50.0);

   return(m_strength.GetScore(m_strength.GetWeakest()));
  }

//+------------------------------------------------------------------+
//| Display / debug text                                             |
//+------------------------------------------------------------------+
string CStrengthGap::BuildText(void)
  {
   if(!m_ready)
      return("Strength Gap: --");

   return(StringFormat("Strength Gap: %.0f (%s %.0f - %s %.0f)",
                       m_gap,
                       CurrencyToString(GetStrongest()),
                       GetStrongestScore(),
                       CurrencyToString(GetWeakest()),
                       GetWeakestScore()));
  }

#endif // __GMD_STRENGTHGAP_MQH__
//+------------------------------------------------------------------+
