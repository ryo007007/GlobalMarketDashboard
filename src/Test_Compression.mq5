//+------------------------------------------------------------------+
//| Test_Compression.mq5                                             |
//| Global Market Dashboard Ultimate                                 |
//| CCompression 単体テスト用インジケーター                         |
//+------------------------------------------------------------------+
#property copyright "Global Market Dashboard Ultimate"
#property version   "1.00"
#property description "CCompression Engine standalone test indicator"
#property indicator_chart_window
#property indicator_plots 0

// Test_Compression.mq5 は src 直下
// CCompression.mqh は src/Modules/Engines/ にある
#include "Modules/Engines/CCompression.mqh"


//+------------------------------------------------------------------+
//| Test settings                                                    |
//+------------------------------------------------------------------+
input ENUM_TIMEFRAMES InpTimeframe = PERIOD_D1;


//+------------------------------------------------------------------+
//| Compression engines                                              |
//| D1用とH4用を用意し、入力値に応じて使用する                      |
//+------------------------------------------------------------------+
CCompression g_compressionD1(NULL,PERIOD_D1);
CCompression g_compressionH4(NULL,PERIOD_H4);

CCompression *g_compression=NULL;

datetime g_last_tf_bar=0;


//+------------------------------------------------------------------+
//| Timeframe text                                                   |
//+------------------------------------------------------------------+
string GetTimeframeText()
  {
   switch(InpTimeframe)
     {
      case PERIOD_H4:
         return("H4");

      case PERIOD_D1:
         return("D1");

      default:
         return(EnumToString(InpTimeframe));
     }
  }


//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
   // ---------------------------------------------------------------
   // H4 / D1 を選択
   // ---------------------------------------------------------------
   if(InpTimeframe==PERIOD_H4)
      g_compression=&g_compressionH4;
   else
      g_compression=&g_compressionD1;


   // ---------------------------------------------------------------
   // CCompression 初期化
   // ---------------------------------------------------------------
   if(!g_compression.Init())
     {
      Print(
         "Test_Compression: CCompression.Init() failed. Error=",
         GetLastError()
         );

      g_compression=NULL;

      return(INIT_FAILED);
     }


   g_last_tf_bar=0;

   Comment(
      "Compression Test: initializing...\n",
      "Symbol: ",_Symbol,"\n",
      "Timeframe: ",GetTimeframeText()
      );

   return(INIT_SUCCEEDED);
  }


//+------------------------------------------------------------------+
//| OnCalculate                                                      |
//+------------------------------------------------------------------+
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
   // ---------------------------------------------------------------
   // Safety check
   // ---------------------------------------------------------------
   if(g_compression==NULL)
      return(rates_total);


   // ---------------------------------------------------------------
   // 選択された時間足の現在バーを取得
   // ---------------------------------------------------------------
   MqlRates tf_rates[];
   ArraySetAsSeries(tf_rates,true);

   if(CopyRates(
         _Symbol,
         InpTimeframe,
         0,
         1,
         tf_rates)<1)
     {
      Comment(
         "Compression Test\n",
         "Symbol: ",_Symbol,"\n",
         "Timeframe: ",GetTimeframeText(),"\n",
         "Data: waiting..."
         );

      return(rates_total);
     }


   const datetime current_tf_bar=tf_rates[0].time;


   // ---------------------------------------------------------------
   // Calculate
   //
   // 初回
   // 新しいH4/D1バー
   // データ未取得
   //
   // の場合に再計算
   // ---------------------------------------------------------------
   if(g_last_tf_bar==0 ||
      current_tf_bar!=g_last_tf_bar ||
      !g_compression.IsAvailable())
     {
      g_last_tf_bar=current_tf_bar;


      // ------------------------------------------------------------
      // Compression calculation
      // ------------------------------------------------------------
      if(!g_compression.Calculate())
        {
         Comment(
            "Compression Test\n",
            "Symbol: ",_Symbol,"\n",
            "Timeframe: ",GetTimeframeText(),"\n",
            "Calculate: FAILED"
            );

         return(rates_total);
        }


      // ------------------------------------------------------------
      // Journal output
      // ------------------------------------------------------------
      if(g_compression.IsAvailable())
        {
         PrintFormat(
            "Compression Test | %s | %s | TF=%s | "
            "Score=%d/8 | "
            "ATR=%.3f%% (Pctl %.1f) | "
            "BB=%.3f%% (Pctl %.1f) | "
            "Range20=%.3f%% (Pctl %.1f) | "
            "ADX=%.2f",

            _Symbol,

            g_compression.GetStateText(),

            GetTimeframeText(),

            g_compression.GetScore(),

            g_compression.GetATRPercent(),
            g_compression.GetATRPercentile(),

            g_compression.GetBBWidth(),
            g_compression.GetBBWidthPercentile(),

            g_compression.GetRange20Percent(),
            g_compression.GetRange20Percentile(),

            g_compression.GetADX()
            );
        }
      else
        {
         Print(
            "Compression Test | ",
            _Symbol,
            " | TF=",
            GetTimeframeText(),
            " | UNAVAILABLE"
            );
        }
     }


   // ---------------------------------------------------------------
   // State
   // ---------------------------------------------------------------
   string status="UNAVAILABLE";

   if(g_compression.IsAvailable())
      status=g_compression.GetStateText();


   // ---------------------------------------------------------------
   // Score delta
   // ---------------------------------------------------------------
   string delta="--";

   if(g_compression.GetPreviousScore()>=0)
      delta=StringFormat(
         "%+d",
         g_compression.GetScoreDelta()
         );


   // ---------------------------------------------------------------
   // State age
   // ---------------------------------------------------------------
   string age=StringFormat(
      "%d",
      g_compression.GetStateAge()
      );


   // ---------------------------------------------------------------
   // Chart display
   // ---------------------------------------------------------------
   Comment(

      "=== CCompression TEST ===\n",

      "Symbol: ",_Symbol,
      "   Timeframe: ",GetTimeframeText(),"\n",

      "\n",

      "STATE: ",status,
      "   SCORE: ",g_compression.GetScore(),"/8",
      "   Delta: ",delta,
      "   Age: ",age,"\n",

      "\n",

      g_compression.GetBreakdownText(),"\n",

      "\n",

      StringFormat(
         "ATR         : %.3f%%   Percentile: %.1f   Score: %d/2",

         g_compression.GetATRPercent(),

         g_compression.GetATRPercentile(),

         g_compression.GetATRScore()
         ),

      "\n",

      StringFormat(
         "BB Width    : %.3f%%   Percentile: %.1f   Score: %d/2",

         g_compression.GetBBWidth(),

         g_compression.GetBBWidthPercentile(),

         g_compression.GetBBScore()
         ),

      "\n",

      StringFormat(
         "Range20     : %.3f%%   Percentile: %.1f   Score: %d/2",

         g_compression.GetRange20Percent(),

         g_compression.GetRange20Percentile(),

         g_compression.GetRangeScore()
         ),

      "\n",

      StringFormat(
         "ADX(14)     : %.2f             Score: %d/2",

         g_compression.GetADX(),

         g_compression.GetADXScore()
         ),

      "\n",

      "\n",

      "Note: closed ",
      GetTimeframeText(),
      " bar is used.\n",

      "Recalculation occurs once per new ",
      GetTimeframeText(),
      " bar."

      );


   return(rates_total);
  }


//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(g_compression!=NULL)
     {
      g_compression.Release();
      g_compression=NULL;
     }

   Comment("");
  }

//+------------------------------------------------------------------+