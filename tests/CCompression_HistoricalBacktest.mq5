//+------------------------------------------------------------------+
//|                  CCompression_HistoricalBacktest.mq5             |
//| CCompression Scanner historical replay / CSV exporter             |
//| 既存検出ルールを独立スクリプト内で再現し、確定足を古い順に検証する |
//| 判定時点の計算には未来足を使用しない。未来値は評価列だけに記録。   |
//+------------------------------------------------------------------+
#property strict
#property script_show_inputs
#property version   "1.00"
#property description "CCompression historical replay. Writes CSV to MQL5/Files."

input string          InpSymbol             = "";             // 空欄=現在のチャート銘柄
input ENUM_TIMEFRAMES InpTimeframe          = PERIOD_M15;      // 検証時間足
input int             InpBarsToTest         = 17500;           // 検証対象の確定足数（M15で約6か月相当）
input int             InpLookback            = 125;             // 現行ロジック: パーセンタイル参照本数
input int             InpRangePeriod         = 20;              // 現行ロジック: Range期間
input int             InpATRPeriod           = 14;
input int             InpBBPeriod            = 20;
input double          InpBBDeviation         = 2.0;
input int             InpADXPeriod           = 14;
input bool            InpIncludeEveryBar     = true;            // true=全確定足、false=圧縮/TRANSITIONのみ
input string          InpOutputPrefix        = "CCompression_History";

struct SMetric
  {
   double atrPct;
   double bbPct;
   double rangePct;
   double adx;
   double atrPctile;
   double bbPctile;
   double rangePctile;
   int atrScore;
   int bbScore;
   int rangeScore;
   int adxScore;
   int score;
   int state;
   int delta;
   int age;
  };

string StateText(const int state)
  {
   if(state==0) return "NORMAL";
   if(state==1) return "COMPRESSION";
   if(state==2) return "STRONG COMPRESSION";
   if(state==3) return "TIGHT COMPRESSION";
   if(state==4) return "TRANSITION";
   return "?";
  }

int ScoreATR(const double p)   { if(p<=20.0) return 2; if(p<=35.0) return 1; return 0; }
int ScoreBB(const double p)    { if(p<=10.0) return 2; if(p<=20.0) return 1; return 0; }
int ScoreRange(const double p) { if(p<=20.0) return 2; if(p<=40.0) return 1; return 0; }
int ScoreADX(const double a)   { if(a<15.0) return 2; if(a<20.0) return 1; return 0; }

int StateFromScore(const int score)
  {
   if(score<=2) return 0;
   if(score<=4) return 1;
   if(score<=6) return 2;
   return 3;
  }

double PercentileLE(const double &values[],const int shift,const int lookback,const double current)
  {
   int count=0;
   for(int k=1;k<=lookback;k++) if(values[shift+k]<=current) count++;
   return (double)count/(double)lookback*100.0;
  }

// 1 signal bar (at shift s) and its older history only; no future candles.
bool CalculateMetric(const int s,const int lookback,const int rangePeriod,
                     const MqlRates &rates[],const double &atr[],
                     const double &bbUp[],const double &bbLo[],const double &bbMid[],
                     const double &adx[],const double &atrPctSeries[],
                     const double &bbPctSeries[],const double &rangePctSeries[],
                     SMetric &m)
  {
   if(rates[s].close==0.0 || bbMid[s]==0.0) return false;
   m.atrPct=atrPctSeries[s];
   m.bbPct=bbPctSeries[s];
   m.rangePct=rangePctSeries[s];
   m.adx=adx[s];
   m.atrPctile=PercentileLE(atrPctSeries,s,lookback,m.atrPct);
   m.bbPctile=PercentileLE(bbPctSeries,s,lookback,m.bbPct);
   m.rangePctile=PercentileLE(rangePctSeries,s,lookback,m.rangePct);
   m.atrScore=ScoreATR(m.atrPctile);
   m.bbScore=ScoreBB(m.bbPctile);
   m.rangeScore=ScoreRange(m.rangePctile);
   m.adxScore=ScoreADX(m.adx);
   m.score=m.atrScore+m.bbScore+m.rangeScore+m.adxScore;
   m.state=StateFromScore(m.score);
   return true;
  }

// Evaluate post-signal movement only; shifts s-1...s-horizon are later bars.
void FutureOutcome(const int s,const int horizon,const MqlRates &rates[],
                   const int total,double &upPct,double &downPct)
  {
   upPct=EMPTY_VALUE;
   downPct=EMPTY_VALUE;
   if(s-horizon<1 || rates[s].close<=0.0) return;
   double hi=rates[s-1].high;
   double lo=rates[s-1].low;
   for(int k=2;k<=horizon;k++)
     {
      if(rates[s-k].high>hi) hi=rates[s-k].high;
      if(rates[s-k].low<lo) lo=rates[s-k].low;
     }
   upPct=(hi-rates[s].close)/rates[s].close*100.0;
   downPct=(lo-rates[s].close)/rates[s].close*100.0;
  }

void WriteOutcome(const int fh,const int s,const int horizon,const MqlRates &rates[],const int total)
  {
   double up,down;
   FutureOutcome(s,horizon,rates,total,up,down);
   if(up==EMPTY_VALUE || down==EMPTY_VALUE)
     {
      FileWrite(fh,""); // helper not used for actual output
      return;
     }
  }

void OnStart()
  {
   string symbol=(StringLen(InpSymbol)>0 ? InpSymbol : _Symbol);
   ENUM_TIMEFRAMES tf=InpTimeframe;
   int lb=MathMax(10,InpLookback);
   int rp=MathMax(2,InpRangePeriod);
   int barsWanted=MathMax(100,InpBarsToTest);
   int symbolDigits=(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS);

   if(!SymbolSelect(symbol,true))
     {
      Print("CCompression Backtest: 銘柄を選択できません: ",symbol);
      return;
     }

   // Additional room for percentile history, Range lookback and indicator warm-up.
   int requestCount=barsWanted+lb+rp+MathMax(InpATRPeriod,MathMax(InpBBPeriod,InpADXPeriod))+20;
   MqlRates rates[];
   double atr[],bbUp[],bbLo[],bbMid[],adx[];
   ArraySetAsSeries(rates,true);
   ArraySetAsSeries(atr,true);
   ArraySetAsSeries(bbUp,true);
   ArraySetAsSeries(bbLo,true);
   ArraySetAsSeries(bbMid,true);
   ArraySetAsSeries(adx,true);

   int copied=CopyRates(symbol,tf,0,requestCount,rates);
   if(copied<=lb+rp+50)
     {
      PrintFormat("CCompression Backtest: ヒストリー不足。取得=%d本。MT5で対象銘柄/時間足の過去データを読み込んでください。",copied);
      return;
     }

   int hATR=iATR(symbol,tf,InpATRPeriod);
   int hBB=iBands(symbol,tf,InpBBPeriod,0,InpBBDeviation,PRICE_CLOSE);
   int hADX=iADX(symbol,tf,InpADXPeriod);
   if(hATR==INVALID_HANDLE || hBB==INVALID_HANDLE || hADX==INVALID_HANDLE)
     {
      Print("CCompression Backtest: インジケーターハンドル作成に失敗しました。");
      if(hATR!=INVALID_HANDLE) IndicatorRelease(hATR);
      if(hBB!=INVALID_HANDLE) IndicatorRelease(hBB);
      if(hADX!=INVALID_HANDLE) IndicatorRelease(hADX);
      return;
     }

   int nATR=CopyBuffer(hATR,0,0,copied,atr);
   int nUp=CopyBuffer(hBB,UPPER_BAND,0,copied,bbUp);
   int nLo=CopyBuffer(hBB,LOWER_BAND,0,copied,bbLo);
   int nMid=CopyBuffer(hBB,BASE_LINE,0,copied,bbMid);
   int nADX=CopyBuffer(hADX,0,0,copied,adx);
   if(nATR<copied || nUp<copied || nLo<copied || nMid<copied || nADX<copied)
     {
      PrintFormat("CCompression Backtest: 指標データが不足。Rates=%d ATR=%d BBup=%d BBlow=%d BBmid=%d ADX=%d",copied,nATR,nUp,nLo,nMid,nADX);
      IndicatorRelease(hATR); IndicatorRelease(hBB); IndicatorRelease(hADX);
      return;
     }

   double atrPct[],bbPct[],rangePct[];
   ArrayResize(atrPct,copied); ArrayResize(bbPct,copied); ArrayResize(rangePct,copied);
   ArraySetAsSeries(atrPct,true); ArraySetAsSeries(bbPct,true); ArraySetAsSeries(rangePct,true);
   for(int s=0;s<copied;s++)
     {
      atrPct[s]=(rates[s].close!=0.0 ? atr[s]/rates[s].close*100.0 : 0.0);
      bbPct[s]=(bbMid[s]!=0.0 ? (bbUp[s]-bbLo[s])/bbMid[s]*100.0 : 0.0);
     }
   for(int s=0;s<copied;s++)
     {
      if(s+rp-1>=copied) { rangePct[s]=0.0; continue; }
      double hi=rates[s].high,lo=rates[s].low;
      for(int k=1;k<rp;k++)
        {
         if(rates[s+k].high>hi) hi=rates[s+k].high;
         if(rates[s+k].low<lo) lo=rates[s+k].low;
        }
      rangePct[s]=(rates[s].close!=0.0 ? (hi-lo)/rates[s].close*100.0 : 0.0);
     }

   // Valid oldest signal shift must have enough older bars for lookback + range.
   int oldest=MathMin(barsWanted,copied-lb-rp-2);
   if(oldest<2)
     {
      Print("CCompression Backtest: 検証できる確定足がありません。");
      IndicatorRelease(hATR); IndicatorRelease(hBB); IndicatorRelease(hADX);
      return;
     }

   string stamp=TimeToString(TimeLocal(),TIME_DATE|TIME_MINUTES|TIME_SECONDS);
   StringReplace(stamp,".",""); StringReplace(stamp,":",""); StringReplace(stamp," ","_");
   string filename=InpOutputPrefix+"_"+symbol+"_"+EnumToString(tf)+"_"+stamp+".csv";
   StringReplace(filename,"/","_"); StringReplace(filename,"\\","_");
   int fh=FileOpen(filename,FILE_WRITE|FILE_CSV|FILE_ANSI,',');
   if(fh==INVALID_HANDLE)
     {
      PrintFormat("CCompression Backtest: CSVを作成できません。エラー=%d",GetLastError());
      IndicatorRelease(hATR); IndicatorRelease(hBB); IndicatorRelease(hADX);
      return;
     }

   FileWrite(fh,"Symbol","Timeframe","BarTime","Open","High","Low","Close",
             "ATR_Pct","ATR_Percentile","ATR_Score","BBWidth_Pct","BB_Percentile","BB_Score",
             "Range20_Pct","Range_Percentile","Range_Score","ADX","ADX_Score","Score","State","Delta","Age",
             "MaxUp_4bars_Pct","MaxDown_4bars_Pct","MaxUp_8bars_Pct","MaxDown_8bars_Pct",
             "MaxUp_12bars_Pct","MaxDown_12bars_Pct");

   // Process chronologically: oldest confirmed candle -> newest confirmed candle.
   int prevScore=0,prevState=0,age=1;
   double prevATR=0.0,prevBB=0.0;
   int rows=0,transitionCount=0,compressionCount=0;
   for(int s=oldest;s>=1;s--)
     {
      SMetric m;
      if(!CalculateMetric(s,lb,rp,rates,atr,bbUp,bbLo,bbMid,adx,atrPct,bbPct,rangePct,m)) continue;
      bool wasCompression=(prevState==2 || prevState==3);
      bool scoreFell=(m.score<prevScore);
      bool rangeExpanded=(m.atrPct>prevATR || m.bbPct>prevBB);
      if(wasCompression && scoreFell && rangeExpanded) m.state=4;
      m.delta=m.score-prevScore;
      age=(m.state==prevState ? age+1 : 1);
      m.age=age;

      if(InpIncludeEveryBar || m.state!=0)
        {
         double up4,down4,up8,down8,up12,down12;
         FutureOutcome(s,4,rates,copied,up4,down4);
         FutureOutcome(s,8,rates,copied,up8,down8);
         FutureOutcome(s,12,rates,copied,up12,down12);
         string t4=(up4==EMPTY_VALUE ? "" : DoubleToString(up4,5));
         string d4=(down4==EMPTY_VALUE ? "" : DoubleToString(down4,5));
         string t8=(up8==EMPTY_VALUE ? "" : DoubleToString(up8,5));
         string d8=(down8==EMPTY_VALUE ? "" : DoubleToString(down8,5));
         string t12=(up12==EMPTY_VALUE ? "" : DoubleToString(up12,5));
         string d12=(down12==EMPTY_VALUE ? "" : DoubleToString(down12,5));
         FileWrite(fh,symbol,EnumToString(tf),TimeToString(rates[s].time,TIME_DATE|TIME_MINUTES),
                   DoubleToString(rates[s].open,symbolDigits),DoubleToString(rates[s].high,symbolDigits),
                   DoubleToString(rates[s].low,symbolDigits),DoubleToString(rates[s].close,symbolDigits),
                   DoubleToString(m.atrPct,6),DoubleToString(m.atrPctile,2),m.atrScore,
                   DoubleToString(m.bbPct,6),DoubleToString(m.bbPctile,2),m.bbScore,
                   DoubleToString(m.rangePct,6),DoubleToString(m.rangePctile,2),m.rangeScore,
                   DoubleToString(m.adx,3),m.adxScore,m.score,StateText(m.state),m.delta,m.age,
                   t4,d4,t8,d8,t12,d12);
         rows++;
        }
      if(m.state==4) transitionCount++;
      if(m.state>=1) compressionCount++;

      // Mirror the live engine's state memory for the next newer bar.
      prevScore=m.score;
      prevATR=m.atrPct;
      prevBB=m.bbPct;
      prevState=m.state;
     }

   FileClose(fh);
   IndicatorRelease(hATR); IndicatorRelease(hBB); IndicatorRelease(hADX);
   Print("============================================================");
   Print("CCompression Backtest 完了");
   Print("銘柄: ",symbol," / 時間足: ",EnumToString(tf));
   PrintFormat("対象確定足: %d / CSV出力行: %d",oldest,rows);
   PrintFormat("圧縮系状態（圧縮/強/タイト/TRANSITION）: %d / TRANSITION: %d",compressionCount,transitionCount);
   Print("保存先: MQL5/Files/",filename);
   Print("注意: 未来値列はシグナル後の評価専用で、シグナル判定には使用していません。");
   Print("注意: 本スクリプトは既存ソースを変更しません。MetaEditorでコンパイル確認後に実行してください。");
   Print("============================================================");
   Alert("CCompression過去検証が完了しました。CSV: ",filename);
  }
//+------------------------------------------------------------------+
