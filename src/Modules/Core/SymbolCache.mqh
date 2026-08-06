//+------------------------------------------------------------------+
//|                                                 SymbolCache.mqh   |
//|                        Global Market Dashboard Ultimate (GMD)     |
//|                                                                   |
//|  役割 : AssetDetection のL2キャッシュ境界を先に切り出す            |
//|  依存 : Types.mqh, Logger.mqh                                     |
//|  状態 : [2.20] 実装予定。現段階では契約だけ定義                   |
//+------------------------------------------------------------------+
#property strict

#ifndef __GMD_SYMBOLCACHE_MQH__
#define __GMD_SYMBOLCACHE_MQH__

#include "Types.mqh"
#include "Logger.mqh"

class CSymbolCache
  {
private:
   CLogger *m_log;
   bool     m_enabled;
   string   m_lastKey;

public:
                    CSymbolCache(void);
                   ~CSymbolCache(void);

   bool             Init(CLogger *logger, const bool enabled = true);
   string           BuildCacheKey(const string broker, const string server);
   bool             LoadCsv(const string fileName, SAssetRegistry &outRegistry);
   bool             SaveCsv(const string fileName, const SAssetRegistry &registry);
   void             Invalidate(void);
   bool             IsEnabled(void) const { return(m_enabled); }
  };

CSymbolCache::CSymbolCache(void) : m_log(NULL),
                                   m_enabled(true),
                                   m_lastKey("")
  {
  }

CSymbolCache::~CSymbolCache(void) {}

bool CSymbolCache::Init(CLogger *logger, const bool enabled)
  {
   m_log     = logger;
   m_enabled = enabled;
   m_lastKey = "";
   return(true);
  }

string CSymbolCache::BuildCacheKey(const string broker, const string server)
  {
   m_lastKey = broker + "_" + server;
   return(m_lastKey);
  }

bool CSymbolCache::LoadCsv(const string fileName, SAssetRegistry &outRegistry)
  {
   // [2.20] で実装
   return(false);
  }

bool CSymbolCache::SaveCsv(const string fileName, const SAssetRegistry &registry)
  {
   // [2.20] で実装
   return(false);
  }

void CSymbolCache::Invalidate(void)
  {
   m_lastKey = "";
  }

#endif // __GMD_SYMBOLCACHE_MQH__
//+------------------------------------------------------------------+
