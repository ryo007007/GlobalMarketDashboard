//+------------------------------------------------------------------+
//| CCompression_ValidationScanner.mq5                               |
//| Place under MQL5/Indicators/GlobalMarketDashboard/tests/          |
//| Multi-symbol / multi-timeframe Compression validation scanner     |
//+------------------------------------------------------------------+
#property strict
#property version "1.00"
#property description "Compression validation scanner using class-based CCompression"
#property indicator_chart_window
#property indicator_plots 0

#include "../src/Modules/Engines/CCompression.mqh"

input string InpSymbols="USDJPY,EURUSD,GBPUSD,AUDUSD,NZDUSD,USDCAD,USDCHF,EURJPY,GBPJPY,AUDJPY,NZDJPY,CADJPY,CHFJPY,EURGBP,GBPCHF,EURCAD,EURCHF,AUDNZD,CADCHF,AUDCHF,GBPCAD,AUDCAD,EURAUD,GBPAUD,EURNZD,XAUUSD,BTCUSD,US30";
input group "=== 監視時間足 ==="
input bool ScanM1=false;
input bool ScanM5=true;
input bool ScanM15=true;
input bool ScanM30=true;
input bool ScanH1=true;
input bool ScanH4=true;
input bool ScanD1=true;
input group "=== 表示設定 ==="
input int PanelX=12;
input int PanelY=18;
input int MaxRows=32;
input int RefreshSeconds=1;
input int RowHeight=17;
input int FontSize=9;
input bool ShowNormalStates=true;
input bool OpenInNewChart=false;

struct SScanRow
  {
   string symbol;
   ENUM_TIMEFRAMES tf;
   int engine;
   int score;
   ENUM_COMPRESSION_STATE state;
   int delta;
   int age;
   bool available;
  };

string g_symbols[];
ENUM_TIMEFRAMES g_tfs[];
CCompression *g_engines[];
datetime g_lastBar[];
SScanRow g_rows[];
string g_rowSymbols[];
ENUM_TIMEFRAMES g_rowTFs[];
int g_rowEngines[];
int g_symbolCount=0,g_tfCount=0,g_total=0,g_selectedEngine=-1;
string PFX="CCVS_";

int ParseSymbols(const string src,string &out[])
  {
   string parts[]; int n=StringSplit(src,',',parts),k=0;
   ArrayResize(out,n);
   for(int i=0;i<n;i++)
     { string s=parts[i]; StringTrimLeft(s); StringTrimRight(s); if(s!="") out[k++]=s; }
   ArrayResize(out,k); return k;
  }

int BuildTFs(ENUM_TIMEFRAMES &out[])
  {
   ArrayResize(out,7); int n=0;
   if(ScanM1) out[n++]=PERIOD_M1;
   if(ScanM5) out[n++]=PERIOD_M5;
   if(ScanM15) out[n++]=PERIOD_M15;
   if(ScanM30) out[n++]=PERIOD_M30;
   if(ScanH1) out[n++]=PERIOD_H1;
   if(ScanH4) out[n++]=PERIOD_H4;
   if(ScanD1) out[n++]=PERIOD_D1;
   ArrayResize(out,n); return n;
  }

string TFText(const ENUM_TIMEFRAMES tf)
  { string s=EnumToString(tf); StringReplace(s,"PERIOD_",""); return s; }
int TFSeconds(const ENUM_TIMEFRAMES tf)
  { int n=PeriodSeconds(tf); return n>0?n:2147483647; }

string StateText(const ENUM_COMPRESSION_STATE s)
  {
   switch(s)
     {
      case COMPRESSION_NORMAL: return "NORMAL";
      case COMPRESSION: return "COMPRESSION";
      case COMPRESSION_STRONG: return "STRONG COMPRESSION";
      case COMPRESSION_TIGHT: return "TIGHT COMPRESSION";
      case COMPRESSION_TRANSITION: return "TRANSITION";
      default: return "UNAVAILABLE";
     }
  }
color StateColor(const ENUM_COMPRESSION_STATE s)
  {
   switch(s)
     {
      case COMPRESSION: return clrYellow;
      case COMPRESSION_STRONG: return clrOrange;
      case COMPRESSION_TIGHT: return clrTomato;
      case COMPRESSION_TRANSITION: return clrAqua;
      case COMPRESSION_NORMAL: return clrSilver;
      default: return clrGray;
     }
  }
string ExplainATR(const int s) { if(s>=2)return "1本の値動き：かなり小さい"; if(s==1)return "1本の値動き：やや小さい"; return "1本の値動き：通常～大きめ"; }
string ExplainBB(const int s) { if(s>=2)return "価格の広がり：かなり狭い"; if(s==1)return "価格の広がり：やや狭い"; return "価格の広がり：通常～大きい"; }
string ExplainRange(const int s) { if(s>=2)return "20期間の活動範囲：かなり狭い"; if(s==1)return "20期間の活動範囲：やや狭い"; return "20期間の活動範囲：通常～大きい"; }
string ExplainADX(const int s) { if(s>=2)return "トレンド強度：弱い"; if(s==1)return "トレンド強度：やや弱い"; return "トレンド強度：強め"; }

void PutLabel(const string name,const int x,const int y,const string txt,const color clr,const bool selectable=false,const int size=-1)
  {
   if(ObjectFind(0,name)<0)
     {
      ObjectCreate(0,name,OBJ_LABEL,0,0,0);
      ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ObjectSetInteger(0,name,OBJPROP_ANCHOR,ANCHOR_LEFT_UPPER);
      ObjectSetInteger(0,name,OBJPROP_BACK,false);
      ObjectSetString(0,name,OBJPROP_FONT,"Consolas");
     }
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,size>0?size:FontSize);
   ObjectSetString(0,name,OBJPROP_TEXT,txt);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,selectable);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,false);
  }

void UpdateEngines()
  {
   for(int i=0;i<g_total;i++)
     {
      if(g_engines[i]==NULL) continue;
      string sym=g_symbols[i/g_tfCount];
      ENUM_TIMEFRAMES tf=g_tfs[i%g_tfCount];
      MqlRates r[]; ArraySetAsSeries(r,true);
      if(CopyRates(sym,tf,0,1,r)<1) continue;
      // Only calculate once per new bar. If data is unavailable, retry next timer tick.
      if(g_lastBar[i]==0 || r[0].time!=g_lastBar[i] || !g_engines[i].IsAvailable())
         if(g_engines[i].Calculate()) g_lastBar[i]=r[0].time;
     }
  }

void SortRows(SScanRow &a[])
  {
   int n=ArraySize(a);
   for(int i=0;i<n-1;i++)
     {
      int best=i;
      for(int j=i+1;j<n;j++)
        {
         bool take=false;
         if(a[j].available!=a[best].available) take=a[j].available;
         else if(a[j].available && a[best].available)
           {
            if(a[j].score>a[best].score) take=true;
            else if(a[j].score==a[best].score)
              {
               if(TFSeconds(a[j].tf)<TFSeconds(a[best].tf)) take=true;
               else if(TFSeconds(a[j].tf)==TFSeconds(a[best].tf) && a[j].symbol<a[best].symbol) take=true;
              }
           }
         else if(a[j].symbol<a[best].symbol) take=true;
         if(take) best=j;
        }
      if(best!=i) { SScanRow tmp=a[i]; a[i]=a[best]; a[best]=tmp; }
     }
  }

void BuildRows()
  {
   ArrayResize(g_rows,g_total); int n=0;
   for(int i=0;i<g_total;i++)
     {
      if(g_engines[i]==NULL) continue;
      bool ok=g_engines[i].IsAvailable();
      ENUM_COMPRESSION_STATE st=ok?g_engines[i].GetState():COMPRESSION_UNAVAILABLE;
      if(ok && !ShowNormalStates && st==COMPRESSION_NORMAL) continue;
      g_rows[n].symbol=g_symbols[i/g_tfCount];
      g_rows[n].tf=g_tfs[i%g_tfCount];
      g_rows[n].engine=i;
      g_rows[n].available=ok;
      g_rows[n].state=st;
      g_rows[n].score=ok?g_engines[i].GetScore():-1;
      g_rows[n].delta=ok?g_engines[i].GetScoreDelta():0;
      g_rows[n].age=ok?g_engines[i].GetStateAge():0;
      n++;
     }
   ArrayResize(g_rows,n); SortRows(g_rows);
  }

void DrawDetail(const int y)
  {
   if(g_selectedEngine<0 || g_selectedEngine>=g_total || g_engines[g_selectedEngine]==NULL || !g_engines[g_selectedEngine].IsAvailable())
     {
      PutLabel(PFX+"D0",PanelX,y,"詳細：一覧の行をクリックしてください",clrWhite);
      PutLabel(PFX+"D1",PanelX,y+RowHeight,"ATR：1本の値動きの大きさ",clrSilver);
      PutLabel(PFX+"D2",PanelX,y+RowHeight*2,"BB Width：価格の広がり",clrSilver);
      PutLabel(PFX+"D3",PanelX,y+RowHeight*3,"Range20：直近20期間の活動範囲",clrSilver);
      PutLabel(PFX+"D4",PanelX,y+RowHeight*4,"ADX：トレンドの強さ（方向ではありません）",clrSilver);
      PutLabel(PFX+"D5",PanelX,y+RowHeight*5,"TRANSITIONは方向予測ではありません。だましも記録してください。",clrAqua);
      return;
     }
   CCompression *e=g_engines[g_selectedEngine];
   string sym=g_symbols[g_selectedEngine/g_tfCount];
   string tf=TFText(g_tfs[g_selectedEngine%g_tfCount]);
   PutLabel(PFX+"D0",PanelX,y,StringFormat("詳細：%s / %s | %s | Score %d/8 | Delta %+d | Age %d",sym,tf,e.GetStateText(),e.GetScore(),e.GetScoreDelta(),e.GetStateAge()),clrWhite);
   PutLabel(PFX+"D1",PanelX,y+RowHeight,StringFormat("ATR %.3f%% | Percentile %.1f | Score %d/2 | %s",e.GetATRPercent(),e.GetATRPercentile(),e.GetATRScore(),ExplainATR(e.GetATRScore())),clrSilver);
   PutLabel(PFX+"D2",PanelX,y+RowHeight*2,StringFormat("BB Width %.3f%% | Percentile %.1f | Score %d/2 | %s",e.GetBBWidth(),e.GetBBWidthPercentile(),e.GetBBScore(),ExplainBB(e.GetBBScore())),clrSilver);
   PutLabel(PFX+"D3",PanelX,y+RowHeight*3,StringFormat("Range20 %.3f%% | Percentile %.1f | Score %d/2 | %s",e.GetRange20Percent(),e.GetRange20Percentile(),e.GetRangeScore(),ExplainRange(e.GetRangeScore())),clrSilver);
   PutLabel(PFX+"D4",PanelX,y+RowHeight*4,StringFormat("ADX(14) %.2f | Score %d/2 | %s",e.GetADX(),e.GetADXScore(),ExplainADX(e.GetADXScore())),clrSilver);
   PutLabel(PFX+"D5",PanelX,y+RowHeight*5,"TRANSITIONは方向予測ではありません。だましも記録してください。",clrAqua);
  }

void DrawScanner()
  {
   BuildRows();
   int n=ArraySize(g_rows),limit=MathMax(1,MaxRows),shown=MathMin(n,limit);
   ArrayResize(g_rowSymbols,shown); ArrayResize(g_rowTFs,shown); ArrayResize(g_rowEngines,shown);
   int ready=0,trans=0;
   for(int i=0;i<g_total;i++) if(g_engines[i]!=NULL && g_engines[i].IsAvailable()) { ready++; if(g_engines[i].GetState()==COMPRESSION_TRANSITION) trans++; }
   PutLabel(PFX+"Title",PanelX,PanelY,StringFormat("CCompression Validation Scanner | Ready %d/%d | TRANSITION %d | Rows %d/%d",ready,g_total,trans,shown,n),clrWhite,false,10);
   PutLabel(PFX+"Header",PanelX,PanelY+18,"SYMBOL     TF    STATE                    SCORE DELTA AGE",clrSilver);
   ObjectsDeleteAll(0,PFX+"R_");
   for(int r=0;r<shown;r++)
     {
      SScanRow row=g_rows[r];
      string txt;
      color c;
      if(!row.available) { txt=StringFormat("%-10s %-5s %-24s --",row.symbol,TFText(row.tf),"WAITING"); c=clrGray; }
      else { txt=StringFormat("%-10s %-5s %-24s %2d/8  %+3d %3d",row.symbol,TFText(row.tf),StateText(row.state),row.score,row.delta,row.age); c=StateColor(row.state); }
      PutLabel(PFX+"R_"+IntegerToString(r),PanelX,PanelY+36+r*RowHeight,txt,c,true);
      g_rowSymbols[r]=row.symbol; g_rowTFs[r]=row.tf; g_rowEngines[r]=row.engine;
     }
   int detailY=PanelY+36+shown*RowHeight+8;
   if(n>shown) PutLabel(PFX+"More",PanelX,detailY,StringFormat("... %d rows hidden; increase MaxRows to see more",n-shown),clrGray);
   else ObjectDelete(0,PFX+"More");
   DrawDetail(detailY+RowHeight);
   ChartRedraw(0);
  }

int OnInit()
  {
   g_symbolCount=ParseSymbols(InpSymbols,g_symbols);
   g_tfCount=BuildTFs(g_tfs);
   if(g_symbolCount<=0 || g_tfCount<=0) return INIT_FAILED;
   g_total=g_symbolCount*g_tfCount;
   ArrayResize(g_engines,g_total); ArrayResize(g_lastBar,g_total);
   for(int i=0;i<g_total;i++)
     {
      g_engines[i]=NULL; g_lastBar[i]=0;
      string sym=g_symbols[i/g_tfCount]; ENUM_TIMEFRAMES tf=g_tfs[i%g_tfCount];
      if(!SymbolSelect(sym,true)) PrintFormat("SymbolSelect failed: %s (broker suffix/name may differ)",sym);
      g_engines[i]=new CCompression(sym,tf);
      if(g_engines[i]==NULL) PrintFormat("Allocation failed: %s %s",sym,TFText(tf));
      else if(!g_engines[i].Init()) PrintFormat("Init failed: %s %s error=%d",sym,TFText(tf),GetLastError());
     }
   EventSetTimer(MathMax(1,RefreshSeconds));
   UpdateEngines(); DrawScanner();
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   for(int i=0;i<ArraySize(g_engines);i++) if(g_engines[i]!=NULL) { g_engines[i].Release(); delete g_engines[i]; g_engines[i]=NULL; }
   ObjectsDeleteAll(0,PFX); ChartRedraw(0);
  }

int OnCalculate(const int rates_total,const int prev_calculated,const datetime &time[],const double &open[],const double &high[],const double &low[],const double &close[],const long &tick_volume[],const long &volume[],const int &spread[])
  { UpdateEngines(); DrawScanner(); return rates_total; }

void OnTimer()
  { UpdateEngines(); DrawScanner(); }

void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
  {
   if(id!=CHARTEVENT_OBJECT_CLICK || StringFind(sparam,PFX+"R_")!=0) return;
   int r=(int)StringToInteger(StringSubstr(sparam,StringLen(PFX+"R_")));
   if(r<0 || r>=ArraySize(g_rowSymbols)) return;
   g_selectedEngine=g_rowEngines[r];
   string sym=g_rowSymbols[r]; ENUM_TIMEFRAMES tf=g_rowTFs[r];
   DrawScanner();
   if(OpenInNewChart) { if(ChartOpen(sym,tf)==0) PrintFormat("ChartOpen failed: %s %s",sym,TFText(tf)); }
   else if(!ChartSetSymbolPeriod(0,sym,tf)) PrintFormat("Chart switch failed: %s %s",sym,TFText(tf));
  }
//+------------------------------------------------------------------+
