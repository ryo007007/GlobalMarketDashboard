//+------------------------------------------------------------------+
//| Test_Compression.mq5                                             |
//| Global Market Dashboard Ultimate                                 |
//| CCompression 単体テスト用インジケーター                         |
//+------------------------------------------------------------------+
#property copyright "Global Market Dashboard Ultimate"
#property version   "0.100"
#property description "CCompression Engine standalone test indicator"
#property indicator_chart_window
#property indicator_plots 0

#include "Modules/Engines/CCompression.mqh"

CCompression g_compression;
datetime g_last_d1_bar = 0;

int OnInit()
  {
   if(!g_compression.Init())
     {
      Print("Test_Compression: CCompression.Init() failed. Error=",GetLastError());
      return(INIT_FAILED);
     }

   g_last_d1_bar=0;
   Comment("Compression Test: initializing...");
   return(INIT_SUCCEEDED);
  }

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
   MqlRates d1[];
   ArraySetAsSeries(d1,true);

   if(CopyRates(_Symbol,PERIOD_D1,0,1,d1)<1)
     {
      Comment("Compression Test\n",
              "Symbol: ",_Symbol,"\n",
              "D1 data: waiting...");
      return(rates_total);
     }

   const datetime current_d1_bar=d1[0].time;

   if(g_last_d1_bar==0 || current_d1_bar!=g_last_d1_bar)
     {
      g_last_d1_bar=current_d1_bar;

      if(!g_compression.Calculate())
        {
         Comment("Compression Test\n",
                 "Symbol: ",_Symbol,"\n",
                 "Calculate: FAILED");
         return(rates_total);
        }

      if(g_compression.IsAvailable())
        {
         PrintFormat("Compression Test | %s | %s | Score=%d/8 | ATR=%.3f%% (Pctl %.1f) | BB=%.3f%% (Pctl %.1f) | Range20=%.3f%% (Pctl %.1f) | ADX=%.2f",
                     _Symbol,
                     g_compression.GetStateText(),
                     g_compression.GetScore(),
                     g_compression.GetATRPercent(),
                     g_compression.GetATRPercentile(),
                     g_compression.GetBBWidth(),
                     g_compression.GetBBWidthPercentile(),
                     g_compression.GetRange20Percent(),
                     g_compression.GetRange20Percentile(),
                     g_compression.GetADX());
        }
      else
        {
         Print("Compression Test | ",_Symbol," | UNAVAILABLE");
        }
     }

   string status="UNAVAILABLE";
   if(g_compression.IsAvailable())
      status=g_compression.GetStateText();

   string delta="--";
   if(g_compression.GetPreviousScore()>=0)
      delta=StringFormat("%+d",g_compression.GetScoreDelta());

   string age=StringFormat("%d",g_compression.GetStateAge());

   Comment(
      "=== CCompression TEST ===\n",
      "Symbol: ",_Symbol,"   Timeframe: D1\n",
      "\n",
      "STATE: ",status,
      "   SCORE: ",g_compression.GetScore(),"/8",
      "   Delta: ",delta,
      "   Age: ",age,"\n",
      "\n",
      g_compression.GetBreakdownText(),"\n",
      "\n",
      StringFormat("ATR%%       : %.3f%%   Percentile: %.1f   Score: %d/2",
                   g_compression.GetATRPercent(),
                   g_compression.GetATRPercentile(),
                   g_compression.GetATRScore()),"\n",
      StringFormat("BB Width%%  : %.3f%%   Percentile: %.1f   Score: %d/2",
                   g_compression.GetBBWidth(),
                   g_compression.GetBBWidthPercentile(),
                   g_compression.GetBBScore()),"\n",
      StringFormat("Range20%%   : %.3f%%   Percentile: %.1f   Score: %d/2",
                   g_compression.GetRange20Percent(),
                   g_compression.GetRange20Percentile(),
                   g_compression.GetRangeScore()),"\n",
      StringFormat("ADX(14)     : %.2f             Score: %d/2",
                   g_compression.GetADX(),
                   g_compression.GetADXScore()),"\n",
      "\n",
      "Note: closed D1 bar is used. Recalculation occurs once per new D1 bar."
      );

   return(rates_total);
  }

void OnDeinit(const int reason)
  {
   g_compression.Release();
   Comment("");
  }
//+------------------------------------------------------------------+
