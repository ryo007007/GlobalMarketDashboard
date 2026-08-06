//+------------------------------------------------------------------+
//|                                                     BestPair.mqh |
//|                        Global Market Dashboard Ultimate (GMD)     |
//|                                                                   |
//|  役割 : 最強通貨 × 最弱通貨 から推奨ペアと方向を1つ提案する      |
//|  依存 : Types.mqh, AssetDetection.mqh, CurrencyStrength.mqh       |
//|  仕様 : Project Specification v1.6 第9章                          |
//|                                                                   |
//|  重要 : "JPYUSD" のような存在しない表記は絶対に画面へ出さない。   |
//|         銘柄は実在するものを使い、方向のほうを反転させる。        |
//+------------------------------------------------------------------+
#property strict

#ifndef __GMD_BESTPAIR_MQH__
#define __GMD_BESTPAIR_MQH__

#include "../Core/Types.mqh"
#include "../Core/Logger.mqh"
#include "../Core/AssetDetection.mqh"
#include "CurrencyStrength.mqh"

//+------------------------------------------------------------------+
class CBestPair : public IEngine
  {
private:
   CCurrencyStrength *m_cs;
   CAssetDetection   *m_assets;
   CLogger           *m_log;

   double               m_minSpread;       // 点差がこれ未満なら方向を出さない

   string               m_symbol;
   bool                 m_inverted;
   ENUM_TRADE_DIRECTION m_direction;
   ENUM_CURRENCY        m_strongest;
   ENUM_CURRENCY        m_weakest;
   double               m_spread;
   bool                 m_ready;

public:
                     CBestPair(void);
                    ~CBestPair(void);

   bool              Init(CCurrencyStrength *cs, CAssetDetection *assets,
                          CLogger *logger, const double minSpread = 20.0);

   //--- IEngine
   bool              Calculate(void);
   bool              IsReady(void) { return(m_ready); }
   string            GetName(void) { return("BestPair"); }

   //--- 参照
   string            GetSymbol(void)     { return(m_symbol);    }
   bool              IsInverted(void)    { return(m_inverted);  }
   ENUM_TRADE_DIRECTION GetDirection(void) { return(m_direction); }
   double            GetSpread(void)     { return(m_spread);    }
   string            GetDirectionText(void);
   string            GetDisplayText(void);
   color             GetColor(void);
  };

//+------------------------------------------------------------------+
CBestPair::CBestPair(void) : m_cs(NULL),
                             m_assets(NULL),
                             m_log(NULL),
                             m_minSpread(20.0),
                             m_symbol(""),
                             m_inverted(false),
                             m_direction(DIR_NONE),
                             m_strongest(CUR_USD),
                             m_weakest(CUR_USD),
                             m_spread(0.0),
                             m_ready(false)
  {
  }

//+------------------------------------------------------------------+
CBestPair::~CBestPair(void)
  {
  }

//+------------------------------------------------------------------+
bool CBestPair::Init(CCurrencyStrength *cs, CAssetDetection *assets,
                     CLogger *logger, const double minSpread)
  {
   m_cs        = cs;
   m_assets    = assets;
   m_log       = logger;
   m_minSpread = minSpread;
   m_ready     = false;

   if(m_cs == NULL || m_assets == NULL)
     {
      if(m_log != NULL)
         m_log.Error("BP-503", "BestPair: dependency is NULL");
      return(false);
     }
   return(true);
  }

//+------------------------------------------------------------------+
//| 計算：強弱の両端からペアを解決する                                |
//+------------------------------------------------------------------+
bool CBestPair::Calculate(void)
  {
   m_ready     = false;
   m_symbol    = "";
   m_inverted  = false;
   m_direction = DIR_NONE;
   m_spread    = 0.0;

   if(m_cs == NULL || m_assets == NULL)
      return(false);

   if(!m_cs.IsReady())
      return(false);

   m_strongest = m_cs.GetStrongest();
   m_weakest   = m_cs.GetWeakest();
   m_spread    = m_cs.GetSpread();

   if(m_strongest == m_weakest)
      return(false);

   //--- レジストリから実在する銘柄を引く（探索を再実装しない）
   bool inverted = false;
   const string sym = m_assets.GetFxSymbol(m_strongest, m_weakest, inverted);

   if(sym == "")
     {
      if(m_log != NULL)
         m_log.Warn("BP-501", StringFormat("No symbol for %s/%s",
                                           CurrencyToString(m_strongest),
                                           CurrencyToString(m_weakest)));
      m_ready = true;              // 「該当なし」も正常な結果
      return(true);
     }

   m_symbol   = sym;
   m_inverted = inverted;

   //--- 点差不足なら方向を出さない
   if(m_spread < m_minSpread)
     {
      m_direction = DIR_NONE;
      if(m_log != NULL)
         m_log.Info(StringFormat("BestPair: spread %.1f < %.1f. Direction withheld.",
                                 m_spread, m_minSpread));
      m_ready = true;
      return(true);
     }

   //--- 方向の決定
   //    inverted = false : 強い通貨が基軸  → BUY
   //    inverted = true  : 強い通貨が決済  → SELL
   m_direction = (inverted ? DIR_SELL : DIR_BUY);

   m_ready = true;
   return(true);
  }

//+------------------------------------------------------------------+
string CBestPair::GetDirectionText(void)
  {
   switch(m_direction)
     {
      case DIR_BUY:  return("BUY");
      case DIR_SELL: return("SELL");
      default:       return("--");
     }
  }

//+------------------------------------------------------------------+
//| 表示用テキスト                                                    |
//|   例: "USDJPY BUY"  /  "USDJPY SELL"  /  "N/A"                   |
//+------------------------------------------------------------------+
string CBestPair::GetDisplayText(void)
  {
   if(!m_ready || m_symbol == "")
      return("N/A");

   if(m_direction == DIR_NONE)
      return(m_symbol + "  (low spread)");

   return(m_symbol + "  " + GetDirectionText());
  }

//+------------------------------------------------------------------+
color CBestPair::GetColor(void)
  {
   switch(m_direction)
     {
      case DIR_BUY:  return(clrRed);
      case DIR_SELL: return(clrDodgerBlue);
      default:       return(clrGray);
     }
  }

#endif // __GMD_BESTPAIR_MQH__
//+------------------------------------------------------------------+
