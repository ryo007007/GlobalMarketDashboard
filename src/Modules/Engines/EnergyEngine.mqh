//+------------------------------------------------------------------+
//|                                                 EnergyEngine.mqh |
//|                        Global Market Dashboard Ultimate (GMD)     |
//|                                                                   |
//|  役割 : 「動く準備ができているか」だけを 0〜100 で示す            |
//|  依存 : Types.mqh, Logger.mqh, Utils.mqh                          |
//|  仕様 : Project Specification v1.5 第37章                         |
//|                                                                   |
//|  ============ このエンジンが言わないこと ============             |
//|                                                                   |
//|  ・どちらへ動くか   → 言わない。上か下かは分からない              |
//|  ・いつ動くか       → 言わない。圧縮は数日続くことがある          |
//|  ・当たる確率       → 言わない。0〜100は確率ではない              |
//|                                                                   |
//|  言うのは1つだけ。「いまの値動きの狭さが、過去100本の中で         |
//|  どのくらい珍しいか」である。                                     |
//|                                                                   |
//|  ============ 設計上の分岐点 ============                         |
//|                                                                   |
//|  A. 絶対値ではなくパーセンタイルで持つ                            |
//|     「ATRが小さい」は基準が無いと意味を持たない。USDJPYの0.05と   |
//|     XAUUSDの0.05とBTCの0.05は全く別物である。                     |
//|     そこで「過去100本の中で下から何%か」に変換する。              |
//|     この形なら、どの銘柄でも どの時間足でも同じ物差しになる。     |
//|                                                                   |
//|  B. 単純な足し算にしない                                          |
//|     ATR・BB幅・レンジ継続は、どれも「値幅が無い」ことを           |
//|     別の角度から測っているだけで、独立していない。                |
//|     4つ全部に配点して足すと、静かなときは全部満点、動くときは     |
//|     全部0点になり、0か100しか出ない指標になる。                   |
//|     そこで軸を3つに畳み、同じものを二重に数えない。               |
//|                                                                   |
//|       軸1 圧縮   : ATR比 と BB幅 の 低いほう（互いの確認に使う）  |
//|       軸2 無方向 : ADX                                            |
//|       軸3 参加   : ティック数                                     |
//|                                                                   |
//|  C. 水準ではなく「解けた瞬間」を事象とする                        |
//|     Energy=95 は3日続くことがある。3日間ずっと警報を出すのは      |
//|     警報ではない。値打ちがあるのは LOADED から抜けた瞬間で、      |
//|     それを ENERGY_RELEASED として1回だけ立てる。                  |
//+------------------------------------------------------------------+
#property strict

#ifndef __GMD_ENERGYENGINE_MQH__
#define __GMD_ENERGYENGINE_MQH__

#include "../Core/Types.mqh"
#include "../Core/Logger.mqh"
#include "../Core/Utils.mqh"

//+------------------------------------------------------------------+
class CEnergyEngine : public IEngine
  {
private:
   CLogger          *m_log;

   string            m_symbol;
   ENUM_TIMEFRAMES   m_tf;

   //--- 指標ハンドル
   int               m_hAtr;
   int               m_hBands;
   int               m_hAdx;

   int               m_atrPeriod;
   int               m_bbPeriod;
   int               m_adxPeriod;
   int               m_lookback;      // パーセンタイルの母数

   //--- 計算結果
   int               m_energy;        // 0〜100。確率ではない
   int               m_axisSqueeze;   // 0〜100
   int               m_axisNoTrend;   // 0〜100
   int               m_axisVolume;    // 0〜100

   double            m_atrRatio;      // 現在ATR / 過去平均ATR
   double            m_bbWidthPct;    // BB幅の百分位
   double            m_adx;

   ENUM_ENERGY_STATE m_state;
   ENUM_ENERGY_STATE m_prevState;
   int               m_loadedBars;    // LOADED が何本続いたか
   datetime          m_lastBarTime;

   //--- 閾値
   int               m_thBuilding;    // 既定 60
   int               m_thLoaded;      // 既定 80

   bool              m_ready;

   //--- 内部
   int               PercentileRank(const double &buf[], const int count,
                                    const double value);
   int               InvertPct(const int pct) { return(100 - pct); }
   bool              LoadBuffers(void);

public:
                     CEnergyEngine(void);
                    ~CEnergyEngine(void);

   bool              Init(CLogger *logger,
                          const string symbol = NULL,
                          const ENUM_TIMEFRAMES tf = PERIOD_CURRENT,
                          const int atrPeriod = 14,
                          const int bbPeriod  = 20,
                          const int adxPeriod = 14,
                          const int lookback  = GMD_ENERGY_LOOKBACK);
   void              Deinit(void);

   void              SetThresholds(const int building, const int loaded);

   bool              Calculate(void);
   bool              IsReady(void) { return(m_ready); }
   string            GetName(void) { return("Energy"); }

   //--- 出力
   int               GetEnergy(void)      { return(m_energy); }
   ENUM_ENERGY_STATE GetState(void)       { return(m_state); }
   bool              IsReleasedNow(void);
   int               GetLoadedBars(void)  { return(m_loadedBars); }

   int               GetAxisSqueeze(void) { return(m_axisSqueeze); }
   int               GetAxisNoTrend(void) { return(m_axisNoTrend); }
   int               GetAxisVolume(void)  { return(m_axisVolume); }
   double            GetAdx(void)         { return(m_adx); }

   //--- 表示
   string            GetBarText(void);
   string            GetDisplayText(void);
   string            BuildDetailText(void);
   color             GetColor(void);
  };

//+------------------------------------------------------------------+
CEnergyEngine::CEnergyEngine(void) : m_log(NULL),
                                     m_symbol(""),
                                     m_tf(PERIOD_CURRENT),
                                     m_hAtr(INVALID_HANDLE),
                                     m_hBands(INVALID_HANDLE),
                                     m_hAdx(INVALID_HANDLE),
                                     m_atrPeriod(14),
                                     m_bbPeriod(20),
                                     m_adxPeriod(14),
                                     m_lookback(GMD_ENERGY_LOOKBACK),
                                     m_energy(0),
                                     m_axisSqueeze(0),
                                     m_axisNoTrend(0),
                                     m_axisVolume(0),
                                     m_atrRatio(0.0),
                                     m_bbWidthPct(0.0),
                                     m_adx(0.0),
                                     m_state(ENERGY_UNAVAILABLE),
                                     m_prevState(ENERGY_UNAVAILABLE),
                                     m_loadedBars(0),
                                     m_lastBarTime(0),
                                     m_thBuilding(60),
                                     m_thLoaded(80),
                                     m_ready(false)
  {
  }

CEnergyEngine::~CEnergyEngine(void) { Deinit(); }

//+------------------------------------------------------------------+
bool CEnergyEngine::Init(CLogger *logger,
                         const string symbol,
                         const ENUM_TIMEFRAMES tf,
                         const int atrPeriod,
                         const int bbPeriod,
                         const int adxPeriod,
                         const int lookback)
  {
   m_log    = logger;
   m_symbol = (symbol == NULL || symbol == "" ? _Symbol : symbol);
   m_tf     = (tf == PERIOD_CURRENT ? (ENUM_TIMEFRAMES)_Period : tf);

   m_atrPeriod = (atrPeriod < 2 ? 14 : atrPeriod);
   m_bbPeriod  = (bbPeriod  < 2 ? 20 : bbPeriod);
   m_adxPeriod = (adxPeriod < 2 ? 14 : adxPeriod);
   m_lookback  = (lookback  < 20 ? 20 : lookback);

   m_hAtr   = iATR(m_symbol, m_tf, m_atrPeriod);
   m_hBands = iBands(m_symbol, m_tf, m_bbPeriod, 0, 2.0, PRICE_CLOSE);
   m_hAdx   = iADX(m_symbol, m_tf, m_adxPeriod);

   //--- ハンドルが取れなくても Init は成功させる。
   //    インジケーターを止める理由にはならない（仕様書31.2）
   if(m_hAtr == INVALID_HANDLE || m_hBands == INVALID_HANDLE ||
      m_hAdx == INVALID_HANDLE)
     {
      if(m_log != NULL)
         m_log.Warn("EN-801", StringFormat("indicator handle failed on %s", m_symbol));
      m_state = ENERGY_UNAVAILABLE;
      return(true);
     }

   if(m_log != NULL)
      m_log.Info(StringFormat("Energy init: %s %s atr=%d bb=%d adx=%d lookback=%d",
                              m_symbol, CalcTimeframeText(m_tf),
                              m_atrPeriod, m_bbPeriod, m_adxPeriod, m_lookback));
   return(true);
  }

//+------------------------------------------------------------------+
void CEnergyEngine::Deinit(void)
  {
   if(m_hAtr   != INVALID_HANDLE) { IndicatorRelease(m_hAtr);   m_hAtr   = INVALID_HANDLE; }
   if(m_hBands != INVALID_HANDLE) { IndicatorRelease(m_hBands); m_hBands = INVALID_HANDLE; }
   if(m_hAdx   != INVALID_HANDLE) { IndicatorRelease(m_hAdx);   m_hAdx   = INVALID_HANDLE; }
  }

//+------------------------------------------------------------------+
void CEnergyEngine::SetThresholds(const int building, const int loaded)
  {
   m_thBuilding = CalcClampInt(building, 1, 99);
   m_thLoaded   = CalcClampInt(loaded,   1, 99);

   if(m_thLoaded <= m_thBuilding)
      m_thLoaded = CalcClampInt(m_thBuilding + 10, 1, 99);
  }

//+------------------------------------------------------------------+
//| value が buf[0..count-1] の中で下から何パーセントの位置か         |
//|  0   = 過去100本の中でいちばん狭い                                |
//|  100 = いちばん広い                                               |
//+------------------------------------------------------------------+
int CEnergyEngine::PercentileRank(const double &buf[], const int count,
                                  const double value)
  {
   if(count <= 1)
      return(50);

   int below = 0;
   for(int i = 0; i < count; i++)
      if(buf[i] < value)
         below++;

   return((int)MathRound(100.0 * below / count));
  }

//+------------------------------------------------------------------+
bool CEnergyEngine::Calculate(void)
  {
   m_prevState = m_state;

   if(m_hAtr == INVALID_HANDLE || m_hBands == INVALID_HANDLE ||
      m_hAdx == INVALID_HANDLE)
     {
      m_state = ENERGY_UNAVAILABLE;
      m_ready = true;
      return(false);
     }

   const int need = m_lookback + 2;

   //--- 履歴が足りないうちは黙って降りる。0 と表示してはいけない。
   //    0 は「圧縮していない」の意味であり、「分からない」ではない
   if(Bars(m_symbol, m_tf) < GMD_ENERGY_MIN_BARS)
     {
      if(m_log != NULL)
         m_log.Info(StringFormat("[EN-802] not enough bars on %s (%d)",
                                 m_symbol, Bars(m_symbol, m_tf)));
      m_state = ENERGY_UNAVAILABLE;
      m_ready = true;
      return(false);
     }

   double atr[], up[], lo[], mid[], adx[];
   long   vol[];

   ArraySetAsSeries(atr, true);
   ArraySetAsSeries(up,  true);
   ArraySetAsSeries(lo,  true);
   ArraySetAsSeries(mid, true);
   ArraySetAsSeries(adx, true);
   ArraySetAsSeries(vol, true);

   if(CopyBuffer(m_hAtr,   0, 0, need, atr) < need ||
      CopyBuffer(m_hBands, 1, 0, need, up)  < need ||
      CopyBuffer(m_hBands, 2, 0, need, lo)  < need ||
      CopyBuffer(m_hBands, 0, 0, need, mid) < need ||
      CopyBuffer(m_hAdx,   0, 0, 2,    adx) < 2    ||
      CopyTickVolume(m_symbol, m_tf, 0, need, vol) < need)
     {
      if(m_log != NULL)
         m_log.Warn("EN-803", StringFormat("buffer copy failed on %s", m_symbol));
      m_state = ENERGY_UNAVAILABLE;
      m_ready = true;
      return(false);
     }

   //================================================================
   // 軸1 : 圧縮
   //   ATR比 と BB幅 の 2つで測る。ただし足さない。
   //   両方が同じ「値幅の狭さ」を見ているため、足すと二重計上になる。
   //   低いほう（＝より控えめな評価）を採る。
   //   片方だけが極端な値になったときに騙されないための保険である。
   //================================================================

   //--- ATR比。過去平均に対する現在の比率をパーセンタイル化
   double atrHist[];
   ArrayResize(atrHist, m_lookback);
   for(int i = 0; i < m_lookback; i++)
      atrHist[i] = atr[i + 1];

   const int atrPct = PercentileRank(atrHist, m_lookback, atr[0]);

   double atrAvg = 0.0;
   for(int i = 0; i < m_lookback; i++)
      atrAvg += atrHist[i];
   atrAvg /= m_lookback;
   m_atrRatio = (atrAvg > 0.0 ? atr[0] / atrAvg : 0.0);

   //--- BB幅。中心線で割って正規化してからパーセンタイル化
   double bbwHist[];
   ArrayResize(bbwHist, m_lookback);
   for(int i = 0; i < m_lookback; i++)
      bbwHist[i] = (mid[i + 1] != 0.0 ? (up[i + 1] - lo[i + 1]) / mid[i + 1] : 0.0);

   const double bbwNow = (mid[0] != 0.0 ? (up[0] - lo[0]) / mid[0] : 0.0);
   const int    bbwPct = PercentileRank(bbwHist, m_lookback, bbwNow);
   m_bbWidthPct = bbwPct;

   //--- パーセンタイルが低いほど圧縮している。反転して点にする
   const int sqAtr = InvertPct(atrPct);
   const int sqBbw = InvertPct(bbwPct);

   m_axisSqueeze = MathMin(sqAtr, sqBbw);

   //================================================================
   // 軸2 : 無方向
   //   ADX が低いほど「行き先が決まっていない」。
   //   20 を境に、10以下で満点、30以上で0点とする
   //================================================================
   m_adx = adx[0];

   if(m_adx <= 10.0)
      m_axisNoTrend = 100;
   else
      if(m_adx >= 30.0)
         m_axisNoTrend = 0;
      else
         m_axisNoTrend = (int)MathRound((30.0 - m_adx) / 20.0 * 100.0);

   //================================================================
   // 軸3 : 参加
   //   FXに出来高は無いのでティック数で代用する。
   //   これは「値幅」とは別物を測っているので、独立軸として持てる
   //================================================================
   double volHist[];
   ArrayResize(volHist, m_lookback);
   for(int i = 0; i < m_lookback; i++)
      volHist[i] = (double)vol[i + 1];

   const int volPct = PercentileRank(volHist, m_lookback, (double)vol[0]);
   m_axisVolume = InvertPct(volPct);

   //================================================================
   // 合成
   //   圧縮を主、無方向を従、参加を補助とする。
   //   配点が 50/30/20 なのは「圧縮こそが本体」だからで、
   //   4項目に均等配分すると、無方向だけで高得点が出てしまう
   //================================================================
   const double raw = m_axisSqueeze * 0.50
                    + m_axisNoTrend * 0.30
                    + m_axisVolume  * 0.20;

   m_energy = CalcClampInt((int)MathRound(raw), 0, 100);

   //================================================================
   // 状態遷移
   //   水準そのものより「LOADED から抜けた瞬間」が事象である
   //================================================================
   const datetime barTime = iTime(m_symbol, m_tf, 0);
   const bool     newBar  = (barTime != m_lastBarTime);

   ENUM_ENERGY_STATE next;

   if(m_energy >= m_thLoaded)
      next = ENERGY_LOADED;
   else
      if(m_energy >= m_thBuilding)
         next = ENERGY_BUILDING;
      else
         next = ENERGY_NORMAL;

   //--- LOADED から落ちたら RELEASED を1回だけ立てる
   if((m_prevState == ENERGY_LOADED || m_prevState == ENERGY_RELEASED) &&
      next != ENERGY_LOADED && m_loadedBars >= 2)
     {
      if(m_prevState == ENERGY_LOADED)
         next = ENERGY_RELEASED;
     }

   if(next == ENERGY_LOADED)
     {
      if(newBar)
         m_loadedBars++;
     }
   else
      if(next != ENERGY_RELEASED)
         m_loadedBars = 0;

   m_state = next;

   if(newBar)
      m_lastBarTime = barTime;

   if(m_state == ENERGY_RELEASED && m_log != NULL)
      m_log.Info(StringFormat("[EN-804] energy released on %s after %d bars loaded",
                              m_symbol, m_loadedBars));

   m_ready = true;
   return(true);
  }

//+------------------------------------------------------------------+
//| 「解けた瞬間」か。ここだけが通知に値する                          |
//+------------------------------------------------------------------+
bool CEnergyEngine::IsReleasedNow(void)
  {
   return(m_state == ENERGY_RELEASED && m_prevState == ENERGY_LOADED);
  }

//+------------------------------------------------------------------+
//| ■■■■□□□□ 形式のバー。8マスで表す                            |
//+------------------------------------------------------------------+
string CEnergyEngine::GetBarText(void)
  {
   if(m_state == ENERGY_UNAVAILABLE)
      return("--------");

   const int filled = CalcClampInt((int)MathRound(m_energy / 12.5), 0, 8);

   string out = "";
   for(int i = 0; i < 8; i++)
      out += (i < filled ? "■" : "□");
   return(out);
  }

//+------------------------------------------------------------------+
//| 「Energy  ■■■■■■□□  78  Loaded」                             |
//|                                                                   |
//|  % を付けない。付けると確率だと読まれる。                         |
//+------------------------------------------------------------------+
string CEnergyEngine::GetDisplayText(void)
  {
   if(m_state == ENERGY_UNAVAILABLE)
      return("Energy  --------  --");

   return(StringFormat("Energy  %s  %d  %s",
                       GetBarText(), m_energy,
                       EnergyStateToString(m_state)));
  }

//+------------------------------------------------------------------+
string CEnergyEngine::BuildDetailText(void)
  {
   if(m_state == ENERGY_UNAVAILABLE)
      return("Energy: unavailable (not enough bars or handle failed)");

   return(StringFormat("Energy=%d  squeeze=%d notrend=%d volume=%d"
                       "  atrRatio=%.2f bbwPct=%.0f adx=%.1f  loadedBars=%d",
                       m_energy, m_axisSqueeze, m_axisNoTrend, m_axisVolume,
                       m_atrRatio, m_bbWidthPct, m_adx, m_loadedBars));
  }

//+------------------------------------------------------------------+
//| 色は3色のみ（仕様書15.1）                                         |
//|  RELEASED だけを赤にする。LOADED を赤にすると、圧縮が続く         |
//|  数日間ずっと赤くなり、赤が意味を失う                             |
//+------------------------------------------------------------------+
color CEnergyEngine::GetColor(void)
  {
   switch(m_state)
     {
      case ENERGY_RELEASED: return(clrRed);
      case ENERGY_LOADED:   return(clrWhite);
      case ENERGY_BUILDING: return(clrWhite);
      case ENERGY_NORMAL:   return(clrDodgerBlue);
      default:              return(clrGray);
     }
  }

#endif // __GMD_ENERGYENGINE_MQH__
//+------------------------------------------------------------------+
