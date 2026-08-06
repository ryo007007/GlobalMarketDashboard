//+------------------------------------------------------------------+
//|                                               AdaptiveUpdate.mqh |
//|                        Global Market Dashboard Ultimate (GMD)     |
//|                                                                   |
//|  役割 : いま何ミリ秒ごとに再計算すべきかを1つの整数で答える       |
//|  依存 : Types.mqh, Logger.mqh, SessionClock.mqh                   |
//|  仕様 : Project Specification v1.5 第36章                         |
//|                                                                   |
//|  設計方針                                                         |
//|                                                                   |
//|  1. 主目的は「速くすること」ではなく「無駄をやめること」          |
//|     1日24時間のうち、値が動く時間は限られている。深夜に1秒ごと    |
//|     28ペア分のCopyCloseを回しても、返る数字はほぼ同じである。     |
//|     よって既定は 通常1秒 / 静穏2秒 / 警戒300ms とし、             |
//|     「速い段」より「遅い段」を先に用意した。                      |
//|                                                                   |
//|  2. 段は3つしか作らない                                           |
//|     1000 / 750 / 500 / 300 / 250 と刻むと、いま何msで動いて       |
//|     いるのか誰も追えなくなり、性能問題の切り分けが不能になる。    |
//|                                                                   |
//|  3. 必ず滞留時間（hysteresis）を置く                              |
//|     セッション境界の1分間に、段が何度も上下すると                 |
//|     EventKillTimer / EventSetMillisecondTimer が連打される。      |
//|     一度変えたら最低 m_dwellSec は動かさない。                    |
//+------------------------------------------------------------------+
#property strict

#ifndef __GMD_ADAPTIVEUPDATE_MQH__
#define __GMD_ADAPTIVEUPDATE_MQH__

#include "../Core/Types.mqh"
#include "../Core/Logger.mqh"
#include "../Core/SessionClock.mqh"

//+------------------------------------------------------------------+
class CAdaptiveUpdate
  {
private:
   CLogger         *m_log;
   CSessionClock   *m_clock;

   //--- 段ごとの間隔（ms）
   int              m_msIdle;
   int              m_msNormal;
   int              m_msAlert;

   //--- 状態
   ENUM_UPDATE_TIER m_tier;
   int              m_currentMs;
   datetime         m_lastChange;
   int              m_dwellSec;        // 段を変えた後、最低これだけ動かさない
   int              m_changeCount;

   //--- 外部からの引き上げ要求（Energy など）
   bool             m_externalAlert;

   bool             m_enabled;
   bool             m_ready;

   ENUM_UPDATE_TIER DecideTier(void);
   int              MsOf(const ENUM_UPDATE_TIER t);

public:
                    CAdaptiveUpdate(void);
                   ~CAdaptiveUpdate(void);

   bool             Init(CLogger *logger,
                         CSessionClock *clock,
                         const int msNormal = 1000,
                         const int msAlert  = 300,
                         const int msIdle   = 2000,
                         const int dwellSec = 60);

   void             SetEnabled(const bool on) { m_enabled = on; }

   //--- Energy などから「いま上げてくれ」と頼む口
   void             RequestAlert(const bool on) { m_externalAlert = on; }

   //--- 段を評価する。間隔が変わったときだけ true を返す
   bool             Evaluate(void);

   int              GetIntervalMs(void)   { return(m_currentMs); }
   ENUM_UPDATE_TIER GetTier(void)         { return(m_tier); }
   int              GetChangeCount(void)  { return(m_changeCount); }
   bool             IsReady(void)         { return(m_ready); }

   string           GetDisplayText(void);
  };

//+------------------------------------------------------------------+
CAdaptiveUpdate::CAdaptiveUpdate(void) : m_log(NULL),
                                         m_clock(NULL),
                                         m_msIdle(2000),
                                         m_msNormal(1000),
                                         m_msAlert(300),
                                         m_tier(TIER_NORMAL),
                                         m_currentMs(1000),
                                         m_lastChange(0),
                                         m_dwellSec(60),
                                         m_changeCount(0),
                                         m_externalAlert(false),
                                         m_enabled(true),
                                         m_ready(false)
  {
  }

CAdaptiveUpdate::~CAdaptiveUpdate(void) {}

//+------------------------------------------------------------------+
bool CAdaptiveUpdate::Init(CLogger *logger,
                           CSessionClock *clock,
                           const int msNormal,
                           const int msAlert,
                           const int msIdle,
                           const int dwellSec)
  {
   m_log   = logger;
   m_clock = clock;

   //--- 下限を設ける。100ms を下回る設定は受け付けない。
   //    MT5のタイマーは単一スレッドで、描画とイベント処理を共有する。
   //    刻みすぎると端末全体が重くなり、他のチャートまで巻き添えになる
   m_msNormal = (msNormal < 100 ? 100 : msNormal);
   m_msAlert  = (msAlert  < 100 ? 100 : msAlert);
   m_msIdle   = (msIdle   < 100 ? 100 : msIdle);

   //--- 大小関係を強制する。逆転設定は事故のもと
   if(m_msAlert > m_msNormal)
      m_msAlert = m_msNormal;
   if(m_msIdle < m_msNormal)
      m_msIdle = m_msNormal;

   m_dwellSec  = (dwellSec < 10 ? 10 : dwellSec);

   m_tier       = TIER_NORMAL;
   m_currentMs  = m_msNormal;
   m_lastChange = 0;
   m_ready      = true;

   if(m_log != NULL)
      m_log.Info(StringFormat("AdaptiveUpdate init: idle=%d normal=%d alert=%d dwell=%ds",
                              m_msIdle, m_msNormal, m_msAlert, m_dwellSec));
   return(true);
  }

//+------------------------------------------------------------------+
int CAdaptiveUpdate::MsOf(const ENUM_UPDATE_TIER t)
  {
   switch(t)
     {
      case TIER_ALERT: return(m_msAlert);
      case TIER_IDLE:  return(m_msIdle);
      default:         return(m_msNormal);
     }
  }

//+------------------------------------------------------------------+
//| どの段にすべきかを決める                                          |
//+------------------------------------------------------------------+
ENUM_UPDATE_TIER CAdaptiveUpdate::DecideTier(void)
  {
   //--- 外部要求（高圧縮など）は最優先
   if(m_externalAlert)
      return(TIER_ALERT);

   if(m_clock == NULL || !m_clock.IsReady())
      return(TIER_NORMAL);

   //--- セッション開始前後
   if(m_clock.IsAnyPreOrOpen())
      return(TIER_ALERT);

   //--- どこも開いていない = 東京早朝や週末。ここで負荷を落とす
   if(m_clock.GetOpenCount() == 0)
      return(TIER_IDLE);

   return(TIER_NORMAL);
  }

//+------------------------------------------------------------------+
//| 間隔が変わったときだけ true。呼び出し側はそのときだけ            |
//| EventKillTimer / EventSetMillisecondTimer をやり直す              |
//+------------------------------------------------------------------+
bool CAdaptiveUpdate::Evaluate(void)
  {
   if(!m_ready)
      return(false);

   if(!m_enabled)
     {
      if(m_currentMs == m_msNormal)
         return(false);
      m_tier      = TIER_NORMAL;
      m_currentMs = m_msNormal;
      return(true);
     }

   const ENUM_UPDATE_TIER want = DecideTier();

   if(want == m_tier)
      return(false);

   //--- 滞留時間。ただし段を上げる方向（速くする）は即座に許す。
   //    「危ないときに反応が遅れる」より「静かなときに少し無駄が残る」
   //    ほうが安全である
   const bool goingFaster = (MsOf(want) < m_currentMs);

   if(!goingFaster && m_lastChange > 0 &&
      (TimeCurrent() - m_lastChange) < m_dwellSec)
      return(false);

   const ENUM_UPDATE_TIER from = m_tier;

   m_tier       = want;
   m_currentMs  = MsOf(want);
   m_lastChange = TimeCurrent();
   m_changeCount++;

   if(m_log != NULL)
      m_log.Info(StringFormat("update tier %s -> %s (%dms)",
                              UpdateTierToString(from),
                              UpdateTierToString(m_tier),
                              m_currentMs));
   return(true);
  }

//+------------------------------------------------------------------+
string CAdaptiveUpdate::GetDisplayText(void)
  {
   if(!m_ready)
      return("Update  --");

   if(!m_enabled)
      return(StringFormat("Update  %dms  (fixed)", m_currentMs));

   return(StringFormat("Update  %dms  (%s)",
                       m_currentMs, UpdateTierToString(m_tier)));
  }

#endif // __GMD_ADAPTIVEUPDATE_MQH__
//+------------------------------------------------------------------+
