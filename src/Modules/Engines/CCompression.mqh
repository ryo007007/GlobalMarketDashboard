//+------------------------------------------------------------------+
//| CCompression.mqh                                                 |
//| Global Market Dashboard Ultimate                                 |
//| Compression / Sideways Detection Engine - Ver 0.1               |
//+------------------------------------------------------------------+
#ifndef __GMD_COMPRESSION_MQH__
#define __GMD_COMPRESSION_MQH__

#include "../Core/Types.mqh"

enum ENUM_COMPRESSION_STATE
  {
   COMPRESSION_UNAVAILABLE=0,
   COMPRESSION_NORMAL,
   COMPRESSION,
   COMPRESSION_STRONG,
   COMPRESSION_TIGHT,
   COMPRESSION_TRANSITION
  };

class CCompression : public IEngine
  {
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_tf;
   int               m_atrPeriod;
   int               m_bbPeriod;
   double            m_bbDeviation;
   int               m_rangePeriod;
   int               m_adxPeriod;
   int               m_percentilePeriod;

   int               m_atrHandle;
   int               m_bbHandle;
   int               m_adxHandle;

   bool              m_ready;
   bool              m_available;

   double            m_atrPercent;
   double            m_atrPercentile;
   double            m_bbWidth;
   double            m_bbPercentile;
   double            m_range20Percent;
   double            m_rangePercentile;
   double            m_adx;

   int               m_atrScore;
   int               m_bbScore;
   int               m_rangeScore;
   int               m_adxScore;
   int               m_compressionScore;
   int               m_previousScore;
   int               m_scoreDelta;
   int               m_stateAge;

   ENUM_COMPRESSION_STATE m_state;
   ENUM_COMPRESSION_STATE m_previousState;

   double            m_prevAtrPercent;
   double            m_prevBbWidth;

private:
   double PercentileRank(const double &values[],const int count,const double value) const
     {
      if(count<=0) return(-1.0);
      int lessOrEqual=0;
      for(int i=0;i<count;i++)
         if(values[i]<=value) lessOrEqual++;
      return(100.0*(double)lessOrEqual/(double)count);
     }

   int AtrScoreFromPercentile(const double p) const
     {
      if(p<0.0) return(-1);
      if(p<=20.0) return(2);
      if(p<=35.0) return(1);
      return(0);
     }

   int BbScoreFromPercentile(const double p) const
     {
      if(p<0.0) return(-1);
      if(p<=10.0) return(2);
      if(p<=20.0) return(1);
      return(0);
     }

   int RangeScoreFromPercentile(const double p) const
     {
      if(p<0.0) return(-1);
      if(p<=20.0) return(2);
      if(p<=40.0) return(1);
      return(0);
     }

   int AdxScore(const double adx) const
     {
      if(adx<0.0) return(-1);
      if(adx<15.0) return(2);
      if(adx<20.0) return(1);
      return(0);
     }

   ENUM_COMPRESSION_STATE BaseStateFromScore(const int score) const
     {
      if(score<=2) return(COMPRESSION_NORMAL);
      if(score<=4) return(COMPRESSION);
      if(score<=6) return(COMPRESSION_STRONG);
      return(COMPRESSION_TIGHT);
     }

   bool HasTransition(const ENUM_COMPRESSION_STATE previousState,
                      const int previousScore,
                      const int currentScore,
                      const double currentAtr,
                      const double currentBb) const
     {
      if(previousState!=COMPRESSION_STRONG && previousState!=COMPRESSION_TIGHT)
         return(false);
      if(currentScore>=previousScore)
         return(false);
      if(m_prevAtrPercent<=0.0 && m_prevBbWidth<=0.0)
         return(false);
      return(currentAtr>m_prevAtrPercent || currentBb>m_prevBbWidth);
     }

public:
   CCompression(const string symbol=NULL,const ENUM_TIMEFRAMES timeframe=PERIOD_D1)
     {
      m_symbol=(symbol==NULL || symbol=="") ? _Symbol : symbol;
      m_tf=timeframe;
      m_atrPeriod=14;
      m_bbPeriod=20;
      m_bbDeviation=2.0;
      m_rangePeriod=20;
      m_adxPeriod=14;
      m_percentilePeriod=125;
      m_atrHandle=INVALID_HANDLE;
      m_bbHandle=INVALID_HANDLE;
      m_adxHandle=INVALID_HANDLE;
      m_ready=false;
      m_available=false;
      m_atrPercent=0.0;
      m_atrPercentile=-1.0;
      m_bbWidth=0.0;
      m_bbPercentile=-1.0;
      m_range20Percent=0.0;
      m_rangePercentile=-1.0;
      m_adx=-1.0;
      m_atrScore=-1;
      m_bbScore=-1;
      m_rangeScore=-1;
      m_adxScore=-1;
      m_compressionScore=-1;
      m_previousScore=-1;
      m_scoreDelta=0;
      m_stateAge=0;
      m_state=COMPRESSION_UNAVAILABLE;
      m_previousState=COMPRESSION_UNAVAILABLE;
      m_prevAtrPercent=0.0;
      m_prevBbWidth=0.0;
     }

   ~CCompression() { Release(); }

   bool Init()
     {
      Release();
      m_atrHandle=iATR(m_symbol,m_tf,m_atrPeriod);
      if(m_atrHandle==INVALID_HANDLE) return(false);
      m_bbHandle=iBands(m_symbol,m_tf,m_bbPeriod,0,m_bbDeviation,PRICE_CLOSE);
      if(m_bbHandle==INVALID_HANDLE) { Release(); return(false); }
      m_adxHandle=iADX(m_symbol,m_tf,m_adxPeriod);
      if(m_adxHandle==INVALID_HANDLE) { Release(); return(false); }
      m_ready=true;
      return(true);
     }

   void Release()
     {
      if(m_atrHandle!=INVALID_HANDLE) { IndicatorRelease(m_atrHandle); m_atrHandle=INVALID_HANDLE; }
      if(m_bbHandle!=INVALID_HANDLE)  { IndicatorRelease(m_bbHandle);  m_bbHandle=INVALID_HANDLE; }
      if(m_adxHandle!=INVALID_HANDLE) { IndicatorRelease(m_adxHandle); m_adxHandle=INVALID_HANDLE; }
      m_ready=false;
     }

   bool Calculate()
     {
      if(!m_ready && !Init()) return(false);

      // Need 125 closed observations plus 20 bars for each Range calculation.
      const int requiredBars=m_percentilePeriod+m_rangePeriod+2;
      const int copyCount=m_percentilePeriod+1;

      MqlRates rates[];
      ArraySetAsSeries(rates,true);
      int copiedRates=CopyRates(m_symbol,m_tf,0,requiredBars,rates);
      if(copiedRates<requiredBars)
        {
         m_available=false;
         m_state=COMPRESSION_UNAVAILABLE;
         return(true);
        }

      double atrValues[],adxValues[],middleValues[],upperValues[],lowerValues[];
      ArraySetAsSeries(atrValues,true);
      ArraySetAsSeries(adxValues,true);
      ArraySetAsSeries(middleValues,true);
      ArraySetAsSeries(upperValues,true);
      ArraySetAsSeries(lowerValues,true);

      if(CopyBuffer(m_atrHandle,0,1,copyCount,atrValues)<copyCount ||
         CopyBuffer(m_bbHandle,0,1,copyCount,middleValues)<copyCount ||
         CopyBuffer(m_bbHandle,1,1,copyCount,upperValues)<copyCount ||
         CopyBuffer(m_bbHandle,2,1,copyCount,lowerValues)<copyCount ||
         CopyBuffer(m_adxHandle,0,1,1,adxValues)<1)
        {
         m_available=false;
         m_state=COMPRESSION_UNAVAILABLE;
         return(true);
        }

      const double close1=rates[1].close;
      if(close1<=0.0 || middleValues[0]<=0.0)
        {
         m_available=false;
         m_state=COMPRESSION_UNAVAILABLE;
         return(true);
        }

      m_atrPercent=(atrValues[0]/close1)*100.0;
      m_bbWidth=((upperValues[0]-lowerValues[0])/middleValues[0])*100.0;
      m_adx=adxValues[0];

      double highest=-DBL_MAX,lowest=DBL_MAX;
      for(int i=1;i<=m_rangePeriod;i++)
        {
         if(rates[i].high>highest) highest=rates[i].high;
         if(rates[i].low<lowest)  lowest=rates[i].low;
        }
      if(highest<=-DBL_MAX/2.0 || lowest>=DBL_MAX/2.0)
        {
         m_available=false;
         m_state=COMPRESSION_UNAVAILABLE;
         return(true);
        }
      m_range20Percent=((highest-lowest)/close1)*100.0;

      double atrPctHistory[],bbWidthHistory[],rangeHistory[];
      ArrayResize(atrPctHistory,m_percentilePeriod);
      ArrayResize(bbWidthHistory,m_percentilePeriod);
      ArrayResize(rangeHistory,m_percentilePeriod);

      for(int h=0;h<m_percentilePeriod;h++)
        {
         const int shift=h+1;
         if(rates[shift].close<=0.0 || middleValues[h]<=0.0)
           {
            m_available=false;
            m_state=COMPRESSION_UNAVAILABLE;
            return(true);
           }

         atrPctHistory[h]=(atrValues[h]/rates[shift].close)*100.0;
         bbWidthHistory[h]=((upperValues[h]-lowerValues[h])/middleValues[h])*100.0;

         double hHigh=-DBL_MAX,hLow=DBL_MAX;
         for(int j=0;j<m_rangePeriod;j++)
           {
            const int s=shift+j;
            if(s>=copiedRates)
              {
               m_available=false;
               m_state=COMPRESSION_UNAVAILABLE;
               return(true);
              }
            if(rates[s].high>hHigh) hHigh=rates[s].high;
            if(rates[s].low<hLow)   hLow=rates[s].low;
           }
         if(hHigh<=-DBL_MAX/2.0 || hLow>=DBL_MAX/2.0)
           {
            m_available=false;
            m_state=COMPRESSION_UNAVAILABLE;
            return(true);
           }
         rangeHistory[h]=((hHigh-hLow)/rates[shift].close)*100.0;
        }

      m_atrPercentile=PercentileRank(atrPctHistory,m_percentilePeriod,m_atrPercent);
      m_bbPercentile=PercentileRank(bbWidthHistory,m_percentilePeriod,m_bbWidth);
      m_rangePercentile=PercentileRank(rangeHistory,m_percentilePeriod,m_range20Percent);

      m_atrScore=AtrScoreFromPercentile(m_atrPercentile);
      m_bbScore=BbScoreFromPercentile(m_bbPercentile);
      m_rangeScore=RangeScoreFromPercentile(m_rangePercentile);
      m_adxScore=AdxScore(m_adx);

      if(m_atrScore<0 || m_bbScore<0 || m_rangeScore<0 || m_adxScore<0)
        {
         m_available=false;
         m_state=COMPRESSION_UNAVAILABLE;
         return(true);
        }

      const int newScore=m_atrScore+m_bbScore+m_rangeScore+m_adxScore;
      m_previousState=m_state;
      m_previousScore=m_compressionScore;
      m_scoreDelta=(m_previousScore>=0) ? newScore-m_previousScore : 0;

      ENUM_COMPRESSION_STATE baseState=BaseStateFromScore(newScore);
      bool transition=false;
      if(m_previousScore>=0)
         transition=HasTransition(m_previousState,m_previousScore,newScore,m_atrPercent,m_bbWidth);

      m_compressionScore=newScore;
      m_state=transition ? COMPRESSION_TRANSITION : baseState;
      m_stateAge=(m_previousState==m_state) ? m_stateAge+1 : 1;

      m_prevAtrPercent=m_atrPercent;
      m_prevBbWidth=m_bbWidth;
      m_available=true;
      m_ready=true;
      return(true);
     }

   bool IsReady() { return(m_ready && m_available); }
   string GetName()  { return("Compression"); }
   bool IsAvailable() const { return(m_available); }

   ENUM_COMPRESSION_STATE GetState() const { return(m_state); }
   ENUM_COMPRESSION_STATE GetPreviousState() const { return(m_previousState); }
   int GetScore() const { return(m_compressionScore); }
   int GetPreviousScore() const { return(m_previousScore); }
   int GetScoreDelta() const { return(m_scoreDelta); }
   int GetStateAge() const { return(m_stateAge); }

   double GetATRPercent() const { return(m_atrPercent); }
   double GetATRPercentile() const { return(m_atrPercentile); }
   double GetBBWidth() const { return(m_bbWidth); }
   double GetBBWidthPercentile() const { return(m_bbPercentile); }
   double GetRange20Percent() const { return(m_range20Percent); }
   double GetRange20Percentile() const { return(m_rangePercentile); }
   double GetADX() const { return(m_adx); }

   int GetATRScore() const { return(m_atrScore); }
   int GetBBScore() const { return(m_bbScore); }
   int GetRangeScore() const { return(m_rangeScore); }
   int GetADXScore() const { return(m_adxScore); }

   string StateToString(const ENUM_COMPRESSION_STATE state) const
     {
      switch(state)
        {
         case COMPRESSION_NORMAL:     return("NORMAL");
         case COMPRESSION:            return("COMPRESSION");
         case COMPRESSION_STRONG:     return("STRONG COMPRESSION");
         case COMPRESSION_TIGHT:      return("TIGHT COMPRESSION");
         case COMPRESSION_TRANSITION: return("TRANSITION");
         default:                     return("UNAVAILABLE");
        }
     }

   string GetStateText() const { return(StateToString(m_state)); }

   string GetDisplayText() const
     {
      if(!m_available) return("Compression: --");
      return(StringFormat("Compression: %s (%d/8)",StateToString(m_state),m_compressionScore));
     }

   string GetBreakdownText() const
     {
      if(!m_available) return("Compression: UNAVAILABLE");
      return(StringFormat("ATR %d/2 | BB %d/2 | Range20 %d/2 | ADX %d/2",
                          m_atrScore,m_bbScore,m_rangeScore,m_adxScore));
     }
  };

#endif // __GMD_COMPRESSION_MQH__
