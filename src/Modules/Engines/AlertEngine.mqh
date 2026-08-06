//+------------------------------------------------------------------+
//|                                                   AlertEngine.mqh |
//|                        Global Market Dashboard Ultimate (GMD)     |
//|                                                                   |
//|  役割 : 条件が成立した「瞬間」に1回だけ知らせる                   |
//|  依存 : Types.mqh, Logger.mqh                                     |
//|  仕様 : Project Specification v1.5 第39章                         |
//|                                                                   |
//|  状態 : [2.30] 未実装。枠だけ置いてある。                         |
//|                                                                   |
//|  ============ 通知機能で必ず起きる失敗 ============               |
//|                                                                   |
//|  1. 鳴りやまない                                                  |
//|     「Energy >= 90 で通知」と書くと、90以上である限り毎回鳴る。   |
//|     1秒更新なら1分で60回である。                                  |
//|     → 水準ではなく「またいだ瞬間」で判定する（エッジ検出）。      |
//|                                                                   |
//|  2. 境界で震える                                                  |
//|     89.6 → 90.1 → 89.8 → 90.2 と往復すると、エッジ検出でも        |
//|     連発する。                                                    |
//|     → 立ち上がりと立ち下がりで閾値をずらす（ヒステリシス）。      |
//|       例：90で点灯、85で消灯。                                    |
//|                                                                   |
//|  3. 同じことを何度も言う                                          |
//|     → 種類ごとに冷却時間を置く。既定は同一足内で1回まで。         |
//|                                                                   |
//|  4. 深夜に鳴る                                                    |
//|     → 静音時間帯を設ける。                                        |
//|                                                                   |
//|  5. Alert() の乱用                                                |
//|     Alert() はモーダルの窓を出し、他の操作を止める。              |
//|     仕様書31.1で「FATAL以外で Alert() を使わない」と決めたのは    |
//|     エラー通知の話だが、利用者向け通知でも既定はOFFにする。       |
//|     既定は チャート表示 + Print のみ。音と窓は明示的に有効化する。|
//|                                                                   |
//|  ============ 通知する条件（Ver2.30の対象） ============          |
//|                                                                   |
//|    A. Energy が LOADED から抜けた（= RELEASED）                   |
//|       水準ではなく遷移。ここだけが事象である                      |
//|    B. Confidence が閾値をまたいだ                                 |
//|    C. Market State が変化した                                     |
//|    D. セッション開始 n 分前                                       |
//|                                                                   |
//|  「Energy 90%」を通知条件にしないのは、圧縮は数日続くことが       |
//|  あり、その間ずっと鳴らす価値が無いためである（37.6）。           |
//+------------------------------------------------------------------+
#property strict

#ifndef __GMD_ALERTENGINE_MQH__
#define __GMD_ALERTENGINE_MQH__

#include "../Core/Types.mqh"
#include "../Core/Logger.mqh"

//+------------------------------------------------------------------+
//| 通知の出口。既定は CHANNEL_PANEL | CHANNEL_PRINT                  |
//+------------------------------------------------------------------+
enum ENUM_ALERT_CHANNEL
  {
   CHANNEL_PANEL  = 1,     // ダッシュボード内に1行出す
   CHANNEL_PRINT  = 2,     // エキスパートログ
   CHANNEL_POPUP  = 4,     // Alert()。既定OFF
   CHANNEL_SOUND  = 8,     // PlaySound()。既定OFF
   CHANNEL_PUSH   = 16     // SendNotification()。既定OFF
  };

//+------------------------------------------------------------------+
class CAlertEngine
  {
private:
   CLogger         *m_log;
   int              m_channels;
   int              m_cooldownSec;
   bool             m_quietHours;
   string           m_lastMessage;
   datetime         m_lastFired;
   int              m_firedCount;
   bool             m_ready;

public:
                    CAlertEngine(void);
                   ~CAlertEngine(void);

   bool             Init(CLogger *logger,
                         const int channels = (CHANNEL_PANEL | CHANNEL_PRINT),
                         const int cooldownSec = 300);

   //--- [2.30] で実装。エッジ検出は呼び出し側ではなくここで持つ
   bool             Raise(const string key,
                          const string message,
                          const ENUM_ALERT_LEVEL level = ALERT_NOTICE);

   string           GetLastMessage(void) { return(m_lastMessage); }
   int              GetFiredCount(void)  { return(m_firedCount); }
   bool             IsReady(void)        { return(m_ready); }

   string           GetDisplayText(void);
  };

//+------------------------------------------------------------------+
CAlertEngine::CAlertEngine(void) : m_log(NULL),
                                   m_channels(CHANNEL_PANEL | CHANNEL_PRINT),
                                   m_cooldownSec(300),
                                   m_quietHours(false),
                                   m_lastMessage(""),
                                   m_lastFired(0),
                                   m_firedCount(0),
                                   m_ready(false)
  {
  }

CAlertEngine::~CAlertEngine(void) {}

//+------------------------------------------------------------------+
bool CAlertEngine::Init(CLogger *logger, const int channels,
                        const int cooldownSec)
  {
   m_log         = logger;
   m_channels    = channels;
   m_cooldownSec = (cooldownSec < 0 ? 0 : cooldownSec);
   m_ready       = false;      // [2.30] で true にする

   if(m_log != NULL)
      m_log.Info("AlertEngine: reserved for [2.30]");
   return(true);
  }

//+------------------------------------------------------------------+
bool CAlertEngine::Raise(const string key, const string message,
                         const ENUM_ALERT_LEVEL level)
  {
   //--- [2.30] で実装
   return(false);
  }

//+------------------------------------------------------------------+
string CAlertEngine::GetDisplayText(void)
  {
   if(!m_ready)
      return("");      // 未実装のうちは行を占有しない

   if(StringLen(m_lastMessage) == 0)
      return("");

   return(m_lastMessage);
  }

#endif // __GMD_ALERTENGINE_MQH__
//+------------------------------------------------------------------+
