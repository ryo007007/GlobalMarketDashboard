//+------------------------------------------------------------------+
//|                                                 SessionClock.mqh |
//|                        Global Market Dashboard Ultimate (GMD)     |
//|                                                                   |
//|  役割 : 「いま世界のどの市場が開いているか」だけを答える          |
//|  依存 : Types.mqh, Logger.mqh                                     |
//|  仕様 : Project Specification v1.5 第36章                         |
//|                                                                   |
//|  なぜ Core に置くのか                                             |
//|    時刻の変換はエンジンではない。判断を含まない事実の計算である。 |
//|    AdaptiveUpdate も Anomaly も Dashboard もこれを参照するため、  |
//|    どのエンジンにも属さない Core に置く。                         |
//|                                                                   |
//|  設計上いちばん重要な点                                           |
//|    セッションは「日本時間で15:45」ではなく                        |
//|    「ロンドン現地の8:00」で定義する。                             |
//|    現地時刻で定義しておけば、夏時間の切り替えは自動で追従する。   |
//|    日本時間で書くと、年2回×3地域=6回、手で直すことになる。        |
//+------------------------------------------------------------------+
#property strict

#ifndef __GMD_SESSIONCLOCK_MQH__
#define __GMD_SESSIONCLOCK_MQH__

#include "Types.mqh"
#include "Logger.mqh"

//+------------------------------------------------------------------+
//| 夏時間の地域。地域ごとに切替日が違うので個別に持つ                |
//|                                                                   |
//|  よくある誤り : 「夏時間フラグ」を1つだけ持つ実装。               |
//|  欧州は3月最終日曜〜10月最終日曜、米国は3月第2日曜〜11月第1日曜。 |
//|  3月の約2週間と10〜11月の約1週間、両者はずれる。この期間だけ      |
//|  ロンドン〜NYの時差が普段の5時間ではなく4時間になる。             |
//|  フラグ1つで組むと、年に3週間だけ静かに1時間ずれる。              |
//+------------------------------------------------------------------+
enum ENUM_DST_REGION
  {
   DST_NONE = 0,      // 日本など
   DST_EU,            // 欧州
   DST_US,            // 米国
   DST_AU             // 豪州（南半球なので夏冬が逆）
  };

//+------------------------------------------------------------------+
//| セッション定義。すべて「現地時刻」で書く                          |
//+------------------------------------------------------------------+
struct SSessionDef
  {
   string            label;
   int               stdGmtOffset;   // 冬時間における 現地 = GMT + これ
   ENUM_DST_REGION   dstRegion;
   int               openLocalMin;   // 現地0時からの分
   int               closeLocalMin;
   int               keyLocalMin;    // 追加の注目時刻。-1 でなし
   string            keyLabel;
  };

//+------------------------------------------------------------------+
class CSessionClock
  {
private:
   CLogger          *m_log;

   //--- ブローカー時刻 → GMT
   int               m_serverStdOffset;   // 冬時間のGMT差（多くの業者で +2）
   bool              m_serverFollowsEuDst;

   SSessionDef       m_def[GMD_SESSION_MAX];

   //--- 計算結果
   datetime          m_gmt;
   ENUM_SESSION_PHASE m_phase[GMD_SESSION_MAX];
   int               m_minToOpen[GMD_SESSION_MAX];
   bool              m_dstEU;
   bool              m_dstUS;
   bool              m_dstAU;

   int               m_preMinutes;    // 開始前の警戒帯
   int               m_openMinutes;   // 開始後の急変帯

   bool              m_ready;

   //--- 内部
   void              BuildDefs(void);
   int               NthWeekdayDay(const int year, const int month,
                                   const int weekday, const int nth);
   int               LastWeekdayDay(const int year, const int month,
                                    const int weekday);
   bool              CalcDstEU(const MqlDateTime &g);
   bool              CalcDstUS(const MqlDateTime &g);
   bool              CalcDstAU(const MqlDateTime &g);
   int               LocalOffsetOf(const ENUM_SESSION s);
   int               LocalMinutesOf(const ENUM_SESSION s);

public:
                     CSessionClock(void);
                    ~CSessionClock(void);

   bool              Init(CLogger *logger,
                          const int serverStdGmtOffset = 2,
                          const bool serverFollowsEuDst = true,
                          const int preMinutes = 15,
                          const int openMinutes = 30);

   bool              Refresh(void);
   bool              IsReady(void) { return(m_ready); }

   //--- 時刻
   datetime          GmtNow(void)   { return(m_gmt); }
   datetime          LocalNow(const ENUM_SESSION s);
   datetime          TokyoNow(void) { return(LocalNow(SESSION_TOKYO)); }

   //--- 状態
   ENUM_SESSION_PHASE GetPhase(const ENUM_SESSION s);
   int               GetMinutesToOpen(const ENUM_SESSION s);
   bool              IsOpen(const ENUM_SESSION s);
   int               GetOpenCount(void);

   //--- 「いま警戒すべきセッションがあるか」= AdaptiveUpdate の入力
   bool              IsAnyPreOrOpen(void);
   ENUM_SESSION      GetHottestSession(void);

   //--- 夏時間
   bool              IsDstEurope(void) { return(m_dstEU); }
   bool              IsDstUS(void)     { return(m_dstUS); }

   //--- 任意の GMT 日時での夏時間判定（検証用に公開している）。
   //    夏時間の境界は年に4回しか来ないので、実運用だけでは
   //    正しさを確認できない。テストから直接叩けるようにしておく
   bool              DstEuropeAt(const datetime gmt);
   bool              DstUsAt(const datetime gmt);

   //--- 表示
   string            GetDisplayText(void);
   string            BuildDetailText(void);
  };

//+------------------------------------------------------------------+
CSessionClock::CSessionClock(void) : m_log(NULL),
                                     m_serverStdOffset(2),
                                     m_serverFollowsEuDst(true),
                                     m_gmt(0),
                                     m_dstEU(false),
                                     m_dstUS(false),
                                     m_dstAU(false),
                                     m_preMinutes(15),
                                     m_openMinutes(30),
                                     m_ready(false)
  {
   ArrayInitialize(m_minToOpen, 0);
   for(int i = 0; i < GMD_SESSION_MAX; i++)
      m_phase[i] = PHASE_OFF;
  }

CSessionClock::~CSessionClock(void) {}

//+------------------------------------------------------------------+
//| セッション定義。現地時刻で書く                                    |
//+------------------------------------------------------------------+
void CSessionClock::BuildDefs(void)
  {
   //--- シドニー 現地7:00-16:00（AEST=GMT+10）
   m_def[SESSION_SYDNEY].label        = "Sydney";
   m_def[SESSION_SYDNEY].stdGmtOffset = 10;
   m_def[SESSION_SYDNEY].dstRegion    = DST_AU;
   m_def[SESSION_SYDNEY].openLocalMin =  7 * 60;
   m_def[SESSION_SYDNEY].closeLocalMin= 16 * 60;
   m_def[SESSION_SYDNEY].keyLocalMin  = -1;
   m_def[SESSION_SYDNEY].keyLabel     = "";

   //--- 東京 現地9:00-15:00。日本に夏時間は無い
   //    注目は 9:55 の仲値。ここが五十日の効く瞬間である
   m_def[SESSION_TOKYO].label         = "Tokyo";
   m_def[SESSION_TOKYO].stdGmtOffset  = 9;
   m_def[SESSION_TOKYO].dstRegion     = DST_NONE;
   m_def[SESSION_TOKYO].openLocalMin  =  9 * 60;
   m_def[SESSION_TOKYO].closeLocalMin = 15 * 60;
   m_def[SESSION_TOKYO].keyLocalMin   =  9 * 60 + 55;
   m_def[SESSION_TOKYO].keyLabel      = "Fixing";

   //--- ロンドン 現地8:00-16:30
   m_def[SESSION_LONDON].label        = "London";
   m_def[SESSION_LONDON].stdGmtOffset = 0;
   m_def[SESSION_LONDON].dstRegion    = DST_EU;
   m_def[SESSION_LONDON].openLocalMin =  8 * 60;
   m_def[SESSION_LONDON].closeLocalMin= 16 * 60 + 30;
   m_def[SESSION_LONDON].keyLocalMin  = -1;
   m_def[SESSION_LONDON].keyLabel     = "";

   //--- ニューヨーク
   //    株式は9:30開始だが、為替が動くのは 8:30 の指標発表である。
   //    CPI・雇用統計・小売売上はすべて 8:30 ET に出る。
   //    したがって open は 8:30、key に 9:30 を置く
   m_def[SESSION_NEWYORK].label        = "NewYork";
   m_def[SESSION_NEWYORK].stdGmtOffset = -5;
   m_def[SESSION_NEWYORK].dstRegion    = DST_US;
   m_def[SESSION_NEWYORK].openLocalMin =  8 * 60 + 30;
   m_def[SESSION_NEWYORK].closeLocalMin= 17 * 60;
   m_def[SESSION_NEWYORK].keyLocalMin  =  9 * 60 + 30;
   m_def[SESSION_NEWYORK].keyLabel     = "Equity";
  }

//+------------------------------------------------------------------+
bool CSessionClock::Init(CLogger *logger,
                         const int serverStdGmtOffset,
                         const bool serverFollowsEuDst,
                         const int preMinutes,
                         const int openMinutes)
  {
   m_log                = logger;
   m_serverStdOffset    = serverStdGmtOffset;
   m_serverFollowsEuDst = serverFollowsEuDst;
   m_preMinutes         = (preMinutes  > 0 ? preMinutes  : 15);
   m_openMinutes        = (openMinutes > 0 ? openMinutes : 30);

   BuildDefs();

   m_ready = false;
   Refresh();

   if(m_log != NULL)
      m_log.Info(StringFormat("SessionClock init: serverStdGmt=%+d euDst=%s",
                              m_serverStdOffset,
                              (m_serverFollowsEuDst ? "yes" : "no")));
   return(true);
  }

//+------------------------------------------------------------------+
//| 指定年月の 第n weekday の日付を返す（weekday: 0=日曜）            |
//+------------------------------------------------------------------+
int CSessionClock::NthWeekdayDay(const int year, const int month,
                                 const int weekday, const int nth)
  {
   MqlDateTime t;
   t.year = year; t.mon = month; t.day = 1;
   t.hour = 0;    t.min = 0;     t.sec = 0;

   const datetime first = StructToTime(t);
   MqlDateTime f;
   TimeToStruct(first, f);

   int delta = weekday - f.day_of_week;
   if(delta < 0)
      delta += 7;

   return(1 + delta + (nth - 1) * 7);
  }

//+------------------------------------------------------------------+
//| 指定年月の 最終 weekday の日付を返す                              |
//+------------------------------------------------------------------+
int CSessionClock::LastWeekdayDay(const int year, const int month,
                                  const int weekday)
  {
   //--- 月の日数
   int dim[13] = {0,31,28,31,30,31,30,31,31,30,31,30,31};
   int last = dim[month];

   if(month == 2)
     {
      const bool leap = ((year % 4 == 0 && year % 100 != 0) || year % 400 == 0);
      if(leap)
         last = 29;
     }

   MqlDateTime t;
   t.year = year; t.mon = month; t.day = last;
   t.hour = 0;    t.min = 0;     t.sec = 0;

   MqlDateTime l;
   TimeToStruct(StructToTime(t), l);

   int delta = l.day_of_week - weekday;
   if(delta < 0)
      delta += 7;

   return(last - delta);
  }

//+------------------------------------------------------------------+
//| 欧州夏時間 : 3月最終日曜 01:00 UTC 〜 10月最終日曜 01:00 UTC      |
//+------------------------------------------------------------------+
bool CSessionClock::CalcDstEU(const MqlDateTime &g)
  {
   if(g.mon < 3 || g.mon > 10)
      return(false);
   if(g.mon > 3 && g.mon < 10)
      return(true);

   const int sw = LastWeekdayDay(g.year, g.mon, 0);   // 日曜

   if(g.mon == 3)
     {
      if(g.day > sw)  return(true);
      if(g.day < sw)  return(false);
      return(g.hour >= 1);
     }

   //--- 10月
   if(g.day > sw)  return(false);
   if(g.day < sw)  return(true);
   return(g.hour < 1);
  }

//+------------------------------------------------------------------+
//| 米国夏時間 : 3月第2日曜 07:00 UTC 〜 11月第1日曜 06:00 UTC        |
//+------------------------------------------------------------------+
bool CSessionClock::CalcDstUS(const MqlDateTime &g)
  {
   if(g.mon < 3 || g.mon > 11)
      return(false);
   if(g.mon > 3 && g.mon < 11)
      return(true);

   if(g.mon == 3)
     {
      const int sw = NthWeekdayDay(g.year, 3, 0, 2);
      if(g.day > sw)  return(true);
      if(g.day < sw)  return(false);
      return(g.hour >= 7);
     }

   //--- 11月
   const int sw = NthWeekdayDay(g.year, 11, 0, 1);
   if(g.day > sw)  return(false);
   if(g.day < sw)  return(true);
   return(g.hour < 6);
  }

//+------------------------------------------------------------------+
//| 豪州夏時間 : 10月第1日曜 〜 4月第1日曜（南半球なので冬に無い）    |
//+------------------------------------------------------------------+
bool CSessionClock::CalcDstAU(const MqlDateTime &g)
  {
   if(g.mon > 4 && g.mon < 10)
      return(false);
   if(g.mon < 4 || g.mon > 10)
      return(true);

   if(g.mon == 4)
     {
      const int sw = NthWeekdayDay(g.year, 4, 0, 1);
      return(g.day < sw);
     }

   const int sw = NthWeekdayDay(g.year, 10, 0, 1);
   return(g.day >= sw);
  }

//+------------------------------------------------------------------+
int CSessionClock::LocalOffsetOf(const ENUM_SESSION s)
  {
   const int i = (int)s;
   int off = m_def[i].stdGmtOffset;

   switch(m_def[i].dstRegion)
     {
      case DST_EU: if(m_dstEU) off += 1; break;
      case DST_US: if(m_dstUS) off += 1; break;
      case DST_AU: if(m_dstAU) off += 1; break;
      default: break;
     }
   return(off);
  }

//+------------------------------------------------------------------+
//| そのセッションの現地時刻における「0時からの分」                   |
//+------------------------------------------------------------------+
int CSessionClock::LocalMinutesOf(const ENUM_SESSION s)
  {
   const datetime local = m_gmt + LocalOffsetOf(s) * 3600;

   MqlDateTime t;
   TimeToStruct(local, t);
   return(t.hour * 60 + t.min);
  }

//+------------------------------------------------------------------+
datetime CSessionClock::LocalNow(const ENUM_SESSION s)
  {
   return(m_gmt + LocalOffsetOf(s) * 3600);
  }

//+------------------------------------------------------------------+
bool CSessionClock::Refresh(void)
  {
   //--- サーバ時刻 → GMT
   //    TimeGMT() を使わない理由は Anomaly と同じ。
   //    ストラテジーテスター内では実時間が返り、過去検証が崩れる
   int serverOff = m_serverStdOffset;

   //--- 一度 冬時間の仮定でGMTを作り、そこで欧州夏時間を判定してから補正する
   datetime provisional = TimeCurrent() - serverOff * 3600;
   MqlDateTime pg;
   TimeToStruct(provisional, pg);

   if(m_serverFollowsEuDst && CalcDstEU(pg))
      serverOff += 1;

   m_gmt = TimeCurrent() - serverOff * 3600;

   MqlDateTime g;
   TimeToStruct(m_gmt, g);

   m_dstEU = CalcDstEU(g);
   m_dstUS = CalcDstUS(g);
   m_dstAU = CalcDstAU(g);

   //--- 週末は全セッション閉場として扱う
   const bool weekend = (g.day_of_week == 0 || g.day_of_week == 6);

   for(int i = 0; i < GMD_SESSION_MAX; i++)
     {
      const ENUM_SESSION s = (ENUM_SESSION)i;

      if(weekend)
        {
         m_phase[i]     = PHASE_OFF;
         m_minToOpen[i] = -1;
         continue;
        }

      const int now   = LocalMinutesOf(s);
      const int open  = m_def[i].openLocalMin;
      const int close = m_def[i].closeLocalMin;

      int toOpen = open - now;
      if(toOpen < 0)
         toOpen += 24 * 60;
      m_minToOpen[i] = toOpen;

      if(now >= open && now <= close)
        {
         m_phase[i] = (now < open + m_openMinutes ? PHASE_OPEN : PHASE_CORE);
        }
      else
         if(toOpen > 0 && toOpen <= m_preMinutes)
            m_phase[i] = PHASE_PRE;
         else
            m_phase[i] = PHASE_OFF;

      //--- 注目時刻（仲値・NY株式開始）の前後も PHASE_OPEN に引き上げる
      if(m_def[i].keyLocalMin >= 0)
        {
         const int d = now - m_def[i].keyLocalMin;
         if(d >= -m_preMinutes && d <= m_openMinutes)
            m_phase[i] = PHASE_OPEN;
        }
     }

   m_ready = true;
   return(true);
  }

//+------------------------------------------------------------------+
ENUM_SESSION_PHASE CSessionClock::GetPhase(const ENUM_SESSION s)
  {
   const int i = (int)s;
   if(i < 0 || i >= GMD_SESSION_MAX)
      return(PHASE_OFF);
   return(m_phase[i]);
  }

//+------------------------------------------------------------------+
int CSessionClock::GetMinutesToOpen(const ENUM_SESSION s)
  {
   const int i = (int)s;
   if(i < 0 || i >= GMD_SESSION_MAX)
      return(-1);
   return(m_minToOpen[i]);
  }

//+------------------------------------------------------------------+
bool CSessionClock::IsOpen(const ENUM_SESSION s)
  {
   const ENUM_SESSION_PHASE p = GetPhase(s);
   return(p == PHASE_OPEN || p == PHASE_CORE);
  }

//+------------------------------------------------------------------+
int CSessionClock::GetOpenCount(void)
  {
   int n = 0;
   for(int i = 0; i < GMD_SESSION_MAX; i++)
      if(IsOpen((ENUM_SESSION)i))
         n++;
   return(n);
  }

//+------------------------------------------------------------------+
bool CSessionClock::IsAnyPreOrOpen(void)
  {
   for(int i = 0; i < GMD_SESSION_MAX; i++)
      if(m_phase[i] == PHASE_PRE || m_phase[i] == PHASE_OPEN)
         return(true);
   return(false);
  }

//+------------------------------------------------------------------+
//| いま最も注意すべきセッション。OPEN > PRE > CORE の順              |
//+------------------------------------------------------------------+
ENUM_SESSION CSessionClock::GetHottestSession(void)
  {
   for(int i = 0; i < GMD_SESSION_MAX; i++)
      if(m_phase[i] == PHASE_OPEN)
         return((ENUM_SESSION)i);
   for(int i = 0; i < GMD_SESSION_MAX; i++)
      if(m_phase[i] == PHASE_PRE)
         return((ENUM_SESSION)i);
   for(int i = 0; i < GMD_SESSION_MAX; i++)
      if(m_phase[i] == PHASE_CORE)
         return((ENUM_SESSION)i);
   return(SESSION_TOKYO);
  }

//+------------------------------------------------------------------+
//| 「Session  London Open / NY in 12m」                              |
//+------------------------------------------------------------------+
bool CSessionClock::DstEuropeAt(const datetime gmt)
  {
   MqlDateTime g;
   TimeToStruct(gmt, g);
   return(CalcDstEU(g));
  }

//+------------------------------------------------------------------+
bool CSessionClock::DstUsAt(const datetime gmt)
  {
   MqlDateTime g;
   TimeToStruct(gmt, g);
   return(CalcDstUS(g));
  }

//+------------------------------------------------------------------+
string CSessionClock::GetDisplayText(void)
  {
   if(!m_ready)
      return("Session  --");

   string open = "";
   for(int i = 0; i < GMD_SESSION_MAX; i++)
     {
      if(!IsOpen((ENUM_SESSION)i))
         continue;
      if(StringLen(open) > 0)
         open += "+";
      open += m_def[i].label;
     }

   if(StringLen(open) == 0)
      open = "Closed";

   //--- 次に開く市場を1つだけ添える
   int    best = -1;
   int    bestMin = 99999;
   for(int i = 0; i < GMD_SESSION_MAX; i++)
     {
      if(IsOpen((ENUM_SESSION)i) || m_minToOpen[i] < 0)
         continue;
      if(m_minToOpen[i] < bestMin)
        {
         bestMin = m_minToOpen[i];
         best    = i;
        }
     }

   if(best < 0)
      return(StringFormat("Session  %s", open));

   return(StringFormat("Session  %s / %s in %dm",
                       open, m_def[best].label, bestMin));
  }

//+------------------------------------------------------------------+
string CSessionClock::BuildDetailText(void)
  {
   string out = StringFormat("GMT=%s  dstEU=%s dstUS=%s dstAU=%s",
                             TimeToString(m_gmt, TIME_DATE | TIME_MINUTES),
                             (m_dstEU ? "1" : "0"),
                             (m_dstUS ? "1" : "0"),
                             (m_dstAU ? "1" : "0"));

   for(int i = 0; i < GMD_SESSION_MAX; i++)
      out += StringFormat("\n  %-8s %-5s  local=%02d:%02d  toOpen=%dm",
                          m_def[i].label,
                          SessionPhaseToString(m_phase[i]),
                          LocalMinutesOf((ENUM_SESSION)i) / 60,
                          LocalMinutesOf((ENUM_SESSION)i) % 60,
                          m_minToOpen[i]);
   return(out);
  }

#endif // __GMD_SESSIONCLOCK_MQH__
//+------------------------------------------------------------------+
