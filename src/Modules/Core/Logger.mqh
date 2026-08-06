//+------------------------------------------------------------------+
//|                                                       Logger.mqh |
//|                        Global Market Dashboard Ultimate (GMD)     |
//|                                                                   |
//|  役割 : レベル制御付きのログ出力。全モジュールがこれを経由する    |
//|  依存 : Types.mqh                                                 |
//|  仕様 : Project Specification v1.6 第31章                         |
//|                                                                   |
//|  重要 : Print() を直接呼ばないこと。レベル制御が効かなくなる。    |
//|         Alert() は通常のエラー通知に使わないこと。                |
//+------------------------------------------------------------------+
#property strict

#ifndef __GMD_LOGGER_MQH__
#define __GMD_LOGGER_MQH__

#include "Types.mqh"

#define GMD_LOG_SUPPRESS_MAX  32     // 抑制対象コードの記録上限

//+------------------------------------------------------------------+
//| CLogger                                                           |
//+------------------------------------------------------------------+
class CLogger
  {
private:
   ENUM_LOG_LEVEL    m_level;
   bool              m_initialized;
   int               m_warnCount;
   int               m_errorCount;
   datetime          m_startedAt;

   //--- 同一コードの連続出力を抑制するための記録
   string            m_seenCode[GMD_LOG_SUPPRESS_MAX];
   int               m_seenCount[GMD_LOG_SUPPRESS_MAX];
   int               m_seenTotal;

   void              Output(const string level, const string code, const string msg);
   bool              ShouldSuppress(const string code);

public:
                     CLogger(void);
                    ~CLogger(void);

   bool              Init(const ENUM_LOG_LEVEL level);
   void              Deinit(void);

   void              Debug(const string msg);
   void              Info(const string msg);
   void              Warn(const string code, const string msg);
   void              Error(const string code, const string msg);
   void              Fatal(const string code, const string msg);

   int               GetWarnCount(void)  const { return(m_warnCount);  }
   int               GetErrorCount(void) const { return(m_errorCount); }
   ENUM_LOG_LEVEL    GetLevel(void)      const { return(m_level);      }
   void              SetLevel(const ENUM_LOG_LEVEL level) { m_level = level; }

   void              PrintSummary(void);
  };

//+------------------------------------------------------------------+
CLogger::CLogger(void) : m_level(LOG_INFO),
                         m_initialized(false),
                         m_warnCount(0),
                         m_errorCount(0),
                         m_startedAt(0),
                         m_seenTotal(0)
  {
  }

//+------------------------------------------------------------------+
CLogger::~CLogger(void)
  {
  }

//+------------------------------------------------------------------+
//| 初期化                                                            |
//+------------------------------------------------------------------+
bool CLogger::Init(const ENUM_LOG_LEVEL level)
  {
   m_level       = level;
   m_warnCount   = 0;
   m_errorCount  = 0;
   m_seenTotal   = 0;
   m_startedAt   = TimeCurrent();
   m_initialized = true;

   Info(StringFormat("GMD v%s starting up (log level: %d)", GMD_VERSION, (int)level));
   return(true);
  }

//+------------------------------------------------------------------+
void CLogger::Deinit(void)
  {
   PrintSummary();
   m_initialized = false;
  }

//+------------------------------------------------------------------+
//| 実際の出力。書式は固定する（後から検索・集計できるように）        |
//|   [GMD][WARN][CS-101] message                                     |
//+------------------------------------------------------------------+
void CLogger::Output(const string level, const string code, const string msg)
  {
   if(code == "")
      Print("[GMD][", level, "] ", msg);
   else
      Print("[GMD][", level, "][", code, "] ", msg);
  }

//+------------------------------------------------------------------+
//| 同一コードの連続出力を抑制する（初回のみ出し、以降はカウント）    |
//|  戻り値 true = 出力を抑制する                                     |
//+------------------------------------------------------------------+
bool CLogger::ShouldSuppress(const string code)
  {
   if(code == "")
      return(false);

   for(int i = 0; i < m_seenTotal; i++)
     {
      if(m_seenCode[i] == code)
        {
         m_seenCount[i]++;
         return(true);            // 2回目以降は出力しない
        }
     }

   if(m_seenTotal < GMD_LOG_SUPPRESS_MAX)
     {
      m_seenCode[m_seenTotal]  = code;
      m_seenCount[m_seenTotal] = 1;
      m_seenTotal++;
     }
   return(false);                 // 初回は出力する
  }

//+------------------------------------------------------------------+
void CLogger::Debug(const string msg)
  {
   if(m_level < LOG_DEBUG)
      return;
   Output("DEBUG", "", msg);
  }

//+------------------------------------------------------------------+
void CLogger::Info(const string msg)
  {
   if(m_level < LOG_INFO)
      return;
   Output("INFO", "", msg);
  }

//+------------------------------------------------------------------+
void CLogger::Warn(const string code, const string msg)
  {
   m_warnCount++;
   if(m_level < LOG_WARN)
      return;
   if(ShouldSuppress(code))
      return;
   Output("WARN", code, msg);
  }

//+------------------------------------------------------------------+
void CLogger::Error(const string code, const string msg)
  {
   m_errorCount++;
   if(m_level < LOG_ERROR)
      return;
   if(ShouldSuppress(code))
      return;
   Output("ERROR", code, msg);
  }

//+------------------------------------------------------------------+
//| FATAL のみ Alert を許可する（継続不可能な場合だけ）               |
//+------------------------------------------------------------------+
void CLogger::Fatal(const string code, const string msg)
  {
   m_errorCount++;
   Output("FATAL", code, msg);
   Alert("[GMD] FATAL ", code, ": ", msg);
  }

//+------------------------------------------------------------------+
//| 終了時サマリ                                                      |
//+------------------------------------------------------------------+
void CLogger::PrintSummary(void)
  {
   const int uptimeSec = (int)(TimeCurrent() - m_startedAt);

   Print("[GMD][INFO] ---- session summary ----");
   Print(StringFormat("[GMD][INFO] uptime: %d sec / warnings: %d / errors: %d",
                      uptimeSec, m_warnCount, m_errorCount));

   for(int i = 0; i < m_seenTotal; i++)
     {
      if(m_seenCount[i] > 1)
         Print(StringFormat("[GMD][INFO] %s occurred %d times",
                            m_seenCode[i], m_seenCount[i]));
     }
   Print("[GMD][INFO] -------------------------");
  }

#endif // __GMD_LOGGER_MQH__
//+------------------------------------------------------------------+
