//+------------------------------------------------------------------+
//|                                             CurrencyStrength.mqh |
//|                        Global Market Dashboard Ultimate (GMD)     |
//|                                                                   |
//|  役割 : 主要8通貨の相対的な強弱をスコア化する                     |
//|  依存 : Types.mqh, Logger.mqh, AssetDetection.mqh                 |
//|  仕様 : Project Specification v1.6 第5章（Currency Strength v2）  |
//|                                                                   |
//|  方式 : 直近N本の重み付き集計（既定 3本 / 重み 1:2:3）            |
//|         上昇した足は基軸通貨へ、下降した足は決済通貨へ加点        |
//+------------------------------------------------------------------+
#property strict

#ifndef __GMD_CURRENCYSTRENGTH_MQH__
#define __GMD_CURRENCYSTRENGTH_MQH__

#include "../Core/Types.mqh"
#include "../Core/Logger.mqh"
#include "../Core/AssetDetection.mqh"

//+------------------------------------------------------------------+
//| CCurrencyStrength                                                 |
//+------------------------------------------------------------------+
class CCurrencyStrength : public IEngine
  {
private:
   CAssetDetection  *m_assets;
   CLogger          *m_log;

   //--- 設定
   ENUM_TIMEFRAMES   m_tf;
   int               m_bars;              // 判定本数
   bool              m_useWeight;
   int               m_minPairs;

   //--- 計算結果
   int               m_scoreRaw[CUR_COUNT];
   double            m_score[CUR_COUNT];      // 0-100（50が中立）
   int               m_momentum[CUR_COUNT];   // -7 〜 +7
   int               m_rank[CUR_COUNT];       // 1〜8
   ENUM_CURRENCY     m_byRank[CUR_COUNT];     // 順位(0始まり) → 通貨

   int               m_pairsUsed;
   int               m_maxScore;              // 7 × 重み合計
   bool              m_ready;

   void              ClearResults(void);
   int               WeightOf(const int shift) const;
   int               TotalWeight(void) const;
   void              BuildRanking(void);

public:
                     CCurrencyStrength(void);
                    ~CCurrencyStrength(void);

   bool              Init(CAssetDetection *assets,
                          CLogger *logger,
                          const ENUM_TIMEFRAMES tf = PERIOD_M1,
                          const int  bars      = 3,
                          const bool useWeight = true,
                          const int  minPairs  = 20);

   //--- IEngine
   bool              Calculate(void);
   bool              IsReady(void)   { return(m_ready); }
   string            GetName(void)   { return("CurrencyStrength"); }

   //--- 参照
   double            GetScore(const ENUM_CURRENCY c);
   int               GetRawScore(const ENUM_CURRENCY c);
   int               GetMomentum(const ENUM_CURRENCY c);
   string            GetArrow(const ENUM_CURRENCY c);
   int               GetRank(const ENUM_CURRENCY c);
   ENUM_CURRENCY     GetByRank(const int rank);          // 1〜8
   ENUM_CURRENCY     GetStrongest(void) { return(GetByRank(1)); }
   ENUM_CURRENCY     GetWeakest(void)   { return(GetByRank(CUR_COUNT)); }
   double            GetSpread(void);
   int               GetPairsUsed(void) { return(m_pairsUsed); }
   color             GetColor(const ENUM_CURRENCY c);
   ENUM_TIMEFRAMES   GetTimeframe(void) { return(m_tf);   }
   int               GetBars(void)      { return(m_bars); }

   string            BuildRankingText(void);
  };

//+------------------------------------------------------------------+
CCurrencyStrength::CCurrencyStrength(void) : m_assets(NULL),
                                             m_log(NULL),
                                             m_tf(PERIOD_M1),
                                             m_bars(3),
                                             m_useWeight(true),
                                             m_minPairs(20),
                                             m_pairsUsed(0),
                                             m_maxScore(0),
                                             m_ready(false)
  {
   ClearResults();
  }

//+------------------------------------------------------------------+
CCurrencyStrength::~CCurrencyStrength(void)
  {
  }

//+------------------------------------------------------------------+
void CCurrencyStrength::ClearResults(void)
  {
   for(int i = 0; i < CUR_COUNT; i++)
     {
      m_scoreRaw[i] = 0;
      m_score[i]    = 50.0;
      m_momentum[i] = 0;
      m_rank[i]     = i + 1;
      m_byRank[i]   = (ENUM_CURRENCY)i;
     }
   m_pairsUsed = 0;
  }

//+------------------------------------------------------------------+
//| シフト s の重み。s=1（最新の確定足）が最大になる                  |
//+------------------------------------------------------------------+
int CCurrencyStrength::WeightOf(const int shift) const
  {
   if(!m_useWeight)
      return(1);
   return(m_bars - shift + 1);
  }

//+------------------------------------------------------------------+
//| 重みの合計。N=3・重みありなら 1+2+3 = 6                           |
//+------------------------------------------------------------------+
int CCurrencyStrength::TotalWeight(void) const
  {
   if(!m_useWeight)
      return(m_bars);
   return(m_bars * (m_bars + 1) / 2);
  }

//+------------------------------------------------------------------+
bool CCurrencyStrength::Init(CAssetDetection *assets,
                             CLogger *logger,
                             const ENUM_TIMEFRAMES tf,
                             const int bars,
                             const bool useWeight,
                             const int minPairs)
  {
   m_assets    = assets;
   m_log       = logger;
   m_tf        = tf;
   m_bars      = (bars < 1 ? 1 : (bars > 10 ? 10 : bars));
   m_useWeight = useWeight;
   m_minPairs  = minPairs;
   m_ready     = false;

   m_maxScore  = (CUR_COUNT - 1) * TotalWeight();   // 7 × 重み合計

   ClearResults();

   if(m_assets == NULL)
     {
      if(m_log != NULL)
         m_log.Error("CS-103", "CurrencyStrength: AssetDetection is NULL");
      return(false);
     }

   if(m_log != NULL)
      m_log.Info(StringFormat("CurrencyStrength v2 init: tf=%s bars=%d weight=%s maxScore=%d",
                              EnumToString(m_tf), m_bars,
                              (m_useWeight ? "on" : "off"), m_maxScore));
   return(true);
  }

//+------------------------------------------------------------------+
//| 計算本体                                                          |
//+------------------------------------------------------------------+
bool CCurrencyStrength::Calculate(void)
  {
   m_ready = false;

   if(m_assets == NULL)
      return(false);

   for(int i = 0; i < CUR_COUNT; i++)
     {
      m_scoreRaw[i] = 0;
      m_momentum[i] = 0;
     }

   int pairsUsed = 0;

   //--- 28ペアを走査
   for(int b = 0; b < CUR_COUNT; b++)
     {
      for(int q = b + 1; q < CUR_COUNT; q++)
        {
         const ENUM_CURRENCY curBase  = (ENUM_CURRENCY)b;
         const ENUM_CURRENCY curQuote = (ENUM_CURRENCY)q;

         bool inverted = false;
         const string sym = m_assets.GetFxSymbol(curBase, curQuote, inverted);
         if(sym == "")
            continue;

         //--- 必要バー数を満たしているか
         if(Bars(sym, m_tf) < m_bars + 1)
            continue;

         //--- 銘柄上の base/quote（inverted のときは入れ替わる）
         const ENUM_CURRENCY symBase  = (inverted ? curQuote : curBase);
         const ENUM_CURRENCY symQuote = (inverted ? curBase  : curQuote);

         bool usedAnyBar = false;

         for(int shift = m_bars; shift >= 1; shift--)
           {
            const double o = iOpen(sym, m_tf, shift);
            const double c = iClose(sym, m_tf, shift);

            //--- データ未取得のバーはスキップする（0で計算しない）
            if(o <= 0.0 || c <= 0.0)
               continue;

            const int w = WeightOf(shift);

            if(c > o)                      // 陽線 = 銘柄の基軸通貨が強い
              {
               m_scoreRaw[symBase] += w;
               if(shift == 1)
                 {
                  m_momentum[symBase]++;
                  m_momentum[symQuote]--;
                 }
              }
            else
               if(c < o)                   // 陰線 = 銘柄の決済通貨が強い
                 {
                  m_scoreRaw[symQuote] += w;
                  if(shift == 1)
                    {
                     m_momentum[symQuote]++;
                     m_momentum[symBase]--;
                    }
                 }
            //--- 同値は加点しない

            usedAnyBar = true;
           }

         if(usedAnyBar)
            pairsUsed++;
        }
     }

   m_pairsUsed = pairsUsed;

   //--- 最低ペア数に満たなければ計算結果を採用しない
   if(m_pairsUsed < m_minPairs)
     {
      ClearResults();
      m_pairsUsed = pairsUsed;
      if(m_log != NULL)
         m_log.Warn("CS-101", StringFormat("FX pairs available: %d/28 (need %d). Ranking disabled.",
                                           m_pairsUsed, m_minPairs));
      return(false);
     }

   //--- 正規化（0〜100。50が中立）
   if(m_maxScore <= 0)
     {
      for(int i = 0; i < CUR_COUNT; i++)
         m_score[i] = 50.0;
     }
   else
     {
      for(int i = 0; i < CUR_COUNT; i++)
         m_score[i] = (double)m_scoreRaw[i] / (double)m_maxScore * 100.0;
     }

   //--- 全通貨同点（週末など）
   bool allSame = true;
   for(int i = 1; i < CUR_COUNT && allSame; i++)
      if(m_scoreRaw[i] != m_scoreRaw[0])
         allSame = false;

   if(allSame)
     {
      for(int i = 0; i < CUR_COUNT; i++)
         m_score[i] = 50.0;
      if(m_log != NULL)
         m_log.Warn("CS-102", "All currencies scored equally (flat market).");
     }

   BuildRanking();

   m_ready = true;
   return(true);
  }

//+------------------------------------------------------------------+
//| スコア降順で順位を決める（単純な選択ソート。8要素なので十分）     |
//+------------------------------------------------------------------+
void CCurrencyStrength::BuildRanking(void)
  {
   int idx[CUR_COUNT];
   for(int i = 0; i < CUR_COUNT; i++)
      idx[i] = i;

   for(int i = 0; i < CUR_COUNT - 1; i++)
     {
      int best = i;
      for(int j = i + 1; j < CUR_COUNT; j++)
        {
         if(m_score[idx[j]] > m_score[idx[best]])
            best = j;
         else
            if(m_score[idx[j]] == m_score[idx[best]] && idx[j] < idx[best])
               best = j;              // 同点は enum 順で安定させる
        }
      if(best != i)
        {
         const int tmp = idx[i];
         idx[i]        = idx[best];
         idx[best]     = tmp;
        }
     }

   for(int r = 0; r < CUR_COUNT; r++)
     {
      m_byRank[r]        = (ENUM_CURRENCY)idx[r];
      m_rank[idx[r]]     = r + 1;
     }
  }

//+------------------------------------------------------------------+
//| 参照系                                                            |
//+------------------------------------------------------------------+
double CCurrencyStrength::GetScore(const ENUM_CURRENCY c)
  {
   if(c < 0 || c >= CUR_COUNT)
      return(50.0);
   return(m_score[c]);
  }

//+------------------------------------------------------------------+
int CCurrencyStrength::GetRawScore(const ENUM_CURRENCY c)
  {
   if(c < 0 || c >= CUR_COUNT)
      return(0);
   return(m_scoreRaw[c]);
  }

//+------------------------------------------------------------------+
int CCurrencyStrength::GetMomentum(const ENUM_CURRENCY c)
  {
   if(c < 0 || c >= CUR_COUNT)
      return(0);
   return(m_momentum[c]);
  }

//+------------------------------------------------------------------+
//| 勢いを7段階の矢印に変換する（仕様書 5.3.5）                       |
//+------------------------------------------------------------------+
string CCurrencyStrength::GetArrow(const ENUM_CURRENCY c)
  {
   const int m = GetMomentum(c);

   if(m >=  6) return("↑↑↑");
   if(m >=  3) return("↑↑");
   if(m >=  1) return("↑");
   if(m == 0)  return("→");
   if(m >= -2) return("↓");
   if(m >= -5) return("↓↓");
   return("↓↓↓");
  }

//+------------------------------------------------------------------+
int CCurrencyStrength::GetRank(const ENUM_CURRENCY c)
  {
   if(c < 0 || c >= CUR_COUNT)
      return(0);
   return(m_rank[c]);
  }

//+------------------------------------------------------------------+
ENUM_CURRENCY CCurrencyStrength::GetByRank(const int rank)
  {
   if(rank < 1 || rank > CUR_COUNT)
      return(CUR_USD);
   return(m_byRank[rank - 1]);
  }

//+------------------------------------------------------------------+
//| 1位と8位の点差（0〜100）                                          |
//+------------------------------------------------------------------+
double CCurrencyStrength::GetSpread(void)
  {
   if(!m_ready)
      return(0.0);
   return(m_score[GetByRank(1)] - m_score[GetByRank(CUR_COUNT)]);
  }

//+------------------------------------------------------------------+
//| 配色：最強のみ赤、最弱のみ青、その他は白（仕様書 15.2）           |
//+------------------------------------------------------------------+
color CCurrencyStrength::GetColor(const ENUM_CURRENCY c)
  {
   if(!m_ready)
      return(clrGray);

   const int r = GetRank(c);
   if(r == 1)
      return(clrRed);
   if(r == CUR_COUNT)
      return(clrDodgerBlue);
   return(clrWhite);
  }

//+------------------------------------------------------------------+
//| ランキングをテキスト化（ログ・デバッグ用）                        |
//+------------------------------------------------------------------+
string CCurrencyStrength::BuildRankingText(void)
  {
   string out = "";

   for(int r = 1; r <= CUR_COUNT; r++)
     {
      const ENUM_CURRENCY c = GetByRank(r);
      out += StringFormat("%d.%s %d %s  ",
                          r,
                          CurrencyToString(c),
                          (int)MathRound(GetScore(c)),
                          GetArrow(c));
     }
   return(out);
  }

#endif // __GMD_CURRENCYSTRENGTH_MQH__
//+------------------------------------------------------------------+
