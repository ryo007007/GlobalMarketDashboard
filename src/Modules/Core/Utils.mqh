//+------------------------------------------------------------------+
//|                                                        Utils.mqh |
//|                        Global Market Dashboard Ultimate (GMD)     |
//|                                                                   |
//|  役割 : どの層からも使える小さな汎用関数だけを置く                |
//|  依存 : Types.mqh のみ                                            |
//|  仕様 : Project Specification v1.3 第18章                         |
//|                                                                   |
//|  方針 : ここに「相場の判断」と「描画」を書かない。                |
//|         描画は Display/DrawObjects.mqh、判断は Engines/ に置く。  |
//|         Utils が太ると依存関係が絡まり、後から分解できなくなる。  |
//+------------------------------------------------------------------+
#property strict

#ifndef __GMD_UTILS_MQH__
#define __GMD_UTILS_MQH__

#include "Types.mqh"

//+------------------------------------------------------------------+
//| 文字列を指定幅に右詰めする（等幅フォント前提の桁揃え）            |
//+------------------------------------------------------------------+
string PadLeft(const string src, const int width)
  {
   string out = src;
   while(StringLen(out) < width)
      out = " " + out;
   return(out);
  }

//+------------------------------------------------------------------+
//| 文字列を指定幅に左詰めする                                        |
//+------------------------------------------------------------------+
string PadRight(const string src, const int width)
  {
   string out = src;
   while(StringLen(out) < width)
      out = out + " ";
   return(out);
  }

//+------------------------------------------------------------------+
//| 順位を丸数字に変換する（1〜8以外は素の数字）                      |
//+------------------------------------------------------------------+
string CalcRankMark(const int rank)
  {
   switch(rank)
     {
      case 1: return("①");
      case 2: return("②");
      case 3: return("③");
      case 4: return("④");
      case 5: return("⑤");
      case 6: return("⑥");
      case 7: return("⑦");
      case 8: return("⑧");
     }
   return(IntegerToString(rank));
  }

//+------------------------------------------------------------------+
//| 時間足を短い表記にする（PERIOD_M1 → "M1"）                        |
//+------------------------------------------------------------------+
string CalcTimeframeText(const ENUM_TIMEFRAMES tf)
  {
   const string s = EnumToString(tf);          // "PERIOD_M1"
   const int    p = StringFind(s, "_");

   if(p < 0)
      return(s);

   return(StringSubstr(s, p + 1));
  }

//+------------------------------------------------------------------+
//| 秒を mm:ss（1時間以上は h:mm:ss）にする                           |
//+------------------------------------------------------------------+
string CalcDurationText(const int seconds)
  {
   if(seconds < 0)
      return("--:--");

   const int h = seconds / 3600;
   const int m = (seconds % 3600) / 60;
   const int s = seconds % 60;

   if(h > 0)
      return(StringFormat("%d:%02d:%02d", h, m, s));

   return(StringFormat("%02d:%02d", m, s));
  }

//+------------------------------------------------------------------+
//| 指定間隔が経過したか判定する                                      |
//|  毎ティック再計算しないための門番。lastTick は呼び出し側が持つ    |
//|  経過していれば lastTick を更新して true を返す                   |
//+------------------------------------------------------------------+
bool DetectIntervalElapsed(uint &lastTick, const uint intervalMs)
  {
   const uint now = GetTickCount();

   if(lastTick != 0 && (now - lastTick) < intervalMs)
      return(false);

   lastTick = now;
   return(true);
  }

//+------------------------------------------------------------------+
//| 新しい足が確定したか判定する                                      |
//|  lastBarTime は呼び出し側が保持する                               |
//+------------------------------------------------------------------+
bool DetectNewBar(const string symbol, const ENUM_TIMEFRAMES tf, datetime &lastBarTime)
  {
   const datetime t = (datetime)SeriesInfoInteger(symbol, tf, SERIES_LASTBAR_DATE);

   if(t == 0 || t == lastBarTime)
      return(false);

   lastBarTime = t;
   return(true);
  }

//+------------------------------------------------------------------+
//| 値を範囲内に収める                                                |
//+------------------------------------------------------------------+
int CalcClampInt(const int value, const int lo, const int hi)
  {
   if(value < lo) return(lo);
   if(value > hi) return(hi);
   return(value);
  }

//+------------------------------------------------------------------+
double CalcClamp(const double value, const double lo, const double hi)
  {
   if(value < lo)
      return(lo);
   if(value > hi)
      return(hi);
   return(value);
  }

//+------------------------------------------------------------------+
//| 数値を符号付きで表示する（+3 / -2 / 0）                           |
//+------------------------------------------------------------------+
string CalcSignedText(const int value)
  {
   if(value > 0)
      return("+" + IntegerToString(value));
   return(IntegerToString(value));
  }

#endif // __GMD_UTILS_MQH__
//+------------------------------------------------------------------+
