//+------------------------------------------------------------------+
//|                                               AssetDetection.mqh |
//|                        Global Market Dashboard Ultimate (GMD)     |
//|                                                                   |
//|  役割 : ブローカーごとに異なる銘柄名を自動検出し、                |
//|         「この口座で何が使えるか」を確定させる                    |
//|  依存 : Types.mqh, Logger.mqh                                     |
//|  仕様 : Project Specification v1.6 第26章                         |
//|                                                                   |
//|  実装範囲 [2.11] : Detect / Validation / Availability / Refresh   |
//|                    / L1キャッシュ（メモリ内レジストリ）           |
//|  未実装   [2.20] : RetryPending / L2キャッシュ(CSV) / Stale判定    |
//|                                                                   |
//|  設計原則 : 検出に失敗しても絶対に停止しない。                    |
//|             INIT_FAILED を返さない。Alert() を出さない。          |
//+------------------------------------------------------------------+
#property strict

#ifndef __GMD_ASSETDETECTION_MQH__
#define __GMD_ASSETDETECTION_MQH__

#include "Types.mqh"
#include "Logger.mqh"

//+------------------------------------------------------------------+
//| CAssetDetection                                                   |
//+------------------------------------------------------------------+
class CAssetDetection
  {
private:
   SAssetRegistry    m_registry;         // L1キャッシュの実体
   CLogger          *m_log;
   bool              m_initialized;

   //--- 入力パラメータの控え
   int               m_minBars;          // 検証に必要な最低バー数
   bool              m_verbose;          // 検出結果を1件ずつログ出力するか
   string            m_userSuffix;       // 手動指定サフィックス（空なら自動）

   //--- 検出処理
   void              ResetRegistry(void);
   void              InitAssetMeta(void);
   bool              DetectAffix(void);
   bool              ConfirmAffix(const string prefix, const string suffix);
   void              DetectAssets(void);
   void              DetectFxPairs(void);

   //--- 検証
   bool              SymbolExists(const string name);
   ENUM_ASSET_STATE  ValidateSymbol(const string name, int &barsOut, datetime &tickTimeOut);

   //--- 候補名
   int               GetCandidates(const ENUM_ASSET_ID id, string &out[]);
   string            ApplyAffix(const string core);

public:
                     CAssetDetection(void);
                    ~CAssetDetection(void);

   //--- ライフサイクル
   bool              Init(CLogger *logger,
                          const int  minBars   = 100,
                          const bool verbose   = true,
                          const string suffix  = "");
   void              Deinit(void);
   bool              Refresh(void);           // 手動再検出

   //--- 参照（Engine 側はこれだけを使う）
   string            GetSymbol(const ENUM_ASSET_ID id);
   bool              IsAvailable(const ENUM_ASSET_ID id);
   ENUM_ASSET_STATE  GetState(const ENUM_ASSET_ID id);
   int               GetDigits(const ENUM_ASSET_ID id);

   string            GetFxSymbol(const ENUM_CURRENCY base, const ENUM_CURRENCY quote,
                                 bool &inverted);
   bool              IsFxAvailable(const ENUM_CURRENCY base, const ENUM_CURRENCY quote);
   int               GetFxPairCount(void) const { return(m_registry.fxPairCount); }

   string            GetSuffix(void) const { return(m_registry.detectedSuffix); }
   string            GetPrefix(void) const { return(m_registry.detectedPrefix); }
   int               GetOkCount(void) const { return(m_registry.okCount); }

   //--- ログ
   string            BuildSummaryText(void);
   void              PrintRegistry(void);
  };

//+------------------------------------------------------------------+
CAssetDetection::CAssetDetection(void) : m_log(NULL),
                                         m_initialized(false),
                                         m_minBars(100),
                                         m_verbose(true),
                                         m_userSuffix("")
  {
   ResetRegistry();
  }

//+------------------------------------------------------------------+
CAssetDetection::~CAssetDetection(void)
  {
  }

//+------------------------------------------------------------------+
//| レジストリを初期状態に戻す                                        |
//+------------------------------------------------------------------+
void CAssetDetection::ResetRegistry(void)
  {
   for(int i = 0; i < ASSET_COUNT; i++)
     {
      m_registry.assets[i].id            = (ENUM_ASSET_ID)i;
      m_registry.assets[i].symbol        = "";
      m_registry.assets[i].state         = ASSET_UNKNOWN;
      m_registry.assets[i].digits        = 0;
      m_registry.assets[i].barsAvailable = 0;
      m_registry.assets[i].lastTickTime  = 0;
      m_registry.assets[i].detectedAt    = 0;
      m_registry.assets[i].retryCount    = 0;
      m_registry.assets[i].note          = "";
     }

   for(int i = 0; i < GMD_FX_PAIR_MAX; i++)
     {
      m_registry.fxPairs[i].symbol    = "";
      m_registry.fxPairs[i].inverted  = false;
      m_registry.fxPairs[i].available = false;
     }

   m_registry.fxPairCount      = 0;
   m_registry.detectedSuffix   = "";
   m_registry.detectedPrefix   = "";
   m_registry.builtAt          = 0;
   m_registry.okCount          = 0;
   m_registry.unavailableCount = 0;

   InitAssetMeta();
  }

//+------------------------------------------------------------------+
//| 各アセットの固定情報（表示名・カテゴリ）を設定する                |
//+------------------------------------------------------------------+
void CAssetDetection::InitAssetMeta(void)
  {
   m_registry.assets[ASSET_GOLD].logicalName   = "Gold";
   m_registry.assets[ASSET_GOLD].category      = CAT_METAL;

   m_registry.assets[ASSET_SILVER].logicalName = "Silver";
   m_registry.assets[ASSET_SILVER].category    = CAT_METAL;

   m_registry.assets[ASSET_US30].logicalName   = "US30";
   m_registry.assets[ASSET_US30].category      = CAT_INDEX;

   m_registry.assets[ASSET_NAS100].logicalName = "NAS100";
   m_registry.assets[ASSET_NAS100].category    = CAT_INDEX;

   m_registry.assets[ASSET_SPX500].logicalName = "SPX500";
   m_registry.assets[ASSET_SPX500].category    = CAT_INDEX;

   m_registry.assets[ASSET_JP225].logicalName  = "JP225";
   m_registry.assets[ASSET_JP225].category     = CAT_INDEX;

   m_registry.assets[ASSET_BTC].logicalName    = "BTC";
   m_registry.assets[ASSET_BTC].category       = CAT_CRYPTO;

   m_registry.assets[ASSET_ETH].logicalName    = "ETH";
   m_registry.assets[ASSET_ETH].category       = CAT_CRYPTO;
  }

//+------------------------------------------------------------------+
//| 初期化：ここが Ver2.11 のパイプライン本体                         |
//|   Detect → Validation → Availability                             |
//| 戻り値は常に true（検出失敗でも起動を止めない）                   |
//+------------------------------------------------------------------+
bool CAssetDetection::Init(CLogger *logger, const int minBars,
                           const bool verbose, const string suffix)
  {
   m_log        = logger;
   m_minBars    = (minBars > 0 ? minBars : 1);
   m_verbose    = verbose;
   m_userSuffix = suffix;

   const uint t0 = GetTickCount();

   ResetRegistry();

   //--- [1] Detect : サフィックス／プレフィックスの推定
   if(!DetectAffix())
     {
      if(m_log != NULL)
         m_log.Warn("AD-002", "Suffix detection failed. Falling back to plain symbol names.");
     }

   //--- [2] Detect + [3] Validation : アセットとFXペア
   DetectAssets();
   DetectFxPairs();

   m_registry.builtAt = TimeCurrent();
   m_initialized      = true;

   const uint elapsed = GetTickCount() - t0;

   if(m_log != NULL)
     {
      m_log.Info(BuildSummaryText());
      m_log.Info(StringFormat("Asset detection finished in %u ms", elapsed));

      if(m_verbose)
         PrintRegistry();

      if(m_registry.okCount == 0)
         m_log.Warn("AD-001", "No asset could be detected. Dashboard will run in limited mode.");

      if(m_registry.fxPairCount < 20)
         m_log.Warn("CS-101",
                    StringFormat("FX pairs available: %d/28 (limited data)", m_registry.fxPairCount));
     }

   return(true);          // 検出失敗でも INIT_FAILED にしない
  }

//+------------------------------------------------------------------+
void CAssetDetection::Deinit(void)
  {
   m_initialized = false;
   m_log         = NULL;
  }

//+------------------------------------------------------------------+
//| 手動再検出                                                        |
//+------------------------------------------------------------------+
bool CAssetDetection::Refresh(void)
  {
   if(m_log != NULL)
      m_log.Info("Asset detection: manual refresh requested");

   return(Init(m_log, m_minBars, m_verbose, m_userSuffix));
  }

//+------------------------------------------------------------------+
//| 銘柄がターミナルに存在するか                                      |
//+------------------------------------------------------------------+
bool CAssetDetection::SymbolExists(const string name)
  {
   if(name == "")
      return(false);

   long exist = 0;
   if(!SymbolInfoInteger(name, SYMBOL_EXIST, exist))
      return(false);

   return(exist != 0);
  }

//+------------------------------------------------------------------+
//| Validation : 4つのゲートを順に通す                                |
//|   1. SymbolSelect         気配値表示に追加できるか                |
//|   2. SymbolIsSynchronized ターミナルとサーバーが同期しているか    |
//|   3. SymbolInfoTick        気配値が取得でき bid > 0 か            |
//|   4. Bars                  最低限のヒストリーがあるか             |
//+------------------------------------------------------------------+
ENUM_ASSET_STATE CAssetDetection::ValidateSymbol(const string name,
                                                 int &barsOut,
                                                 datetime &tickTimeOut)
  {
   barsOut     = 0;
   tickTimeOut = 0;

   //--- Gate 1
   if(!SymbolSelect(name, true))
      return(ASSET_UNAVAILABLE);

   //--- Gate 2 : 未同期はまだ諦めない（PENDING）
   if(!SymbolIsSynchronized(name))
      return(ASSET_PENDING);

   //--- Gate 3
   MqlTick tick;
   if(!SymbolInfoTick(name, tick))
      return(ASSET_PENDING);

   if(tick.bid <= 0.0)
      return(ASSET_PENDING);

   tickTimeOut = tick.time;

   //--- Gate 4 : ヒストリーは非同期に読み込まれるため、不足は PENDING
   barsOut = Bars(name, PERIOD_CURRENT);
   if(barsOut < m_minBars)
      return(ASSET_PENDING);

   return(ASSET_OK);
  }

//+------------------------------------------------------------------+
//| コア名に推定済みのプレフィックス／サフィックスを付ける            |
//+------------------------------------------------------------------+
string CAssetDetection::ApplyAffix(const string core)
  {
   return(m_registry.detectedPrefix + core + m_registry.detectedSuffix);
  }

//+------------------------------------------------------------------+
//| サフィックス／プレフィックスの推定                                |
//|  1. 手動指定があればそれを使う                                    |
//|  2. チャート銘柄(_Symbol)から推定する                             |
//|  3. 全銘柄から EURUSD を含むものを探して推定する                  |
//|  いずれも 50%ルール（28ペア中14以上が存在）で確認する             |
//+------------------------------------------------------------------+
bool CAssetDetection::DetectAffix(void)
  {
   //--- 1. 手動指定
   if(m_userSuffix != "")
     {
      m_registry.detectedPrefix = "";
      m_registry.detectedSuffix = m_userSuffix;
      if(ConfirmAffix("", m_userSuffix))
        {
         if(m_log != NULL)
            m_log.Info("Suffix (manual): '" + m_userSuffix + "'");
         return(true);
        }
      if(m_log != NULL)
         m_log.Warn("AD-003", "Manual suffix '" + m_userSuffix + "' did not pass confirmation.");
     }

   //--- 2. チャート銘柄から推定
   const string chartSym = _Symbol;
   const string anchors[] = {"EURUSD", "USDJPY", "GBPUSD", "AUDUSD", "USDCHF", "USDCAD", "NZDUSD"};

   for(int i = 0; i < ArraySize(anchors); i++)
     {
      const int pos = StringFind(chartSym, anchors[i]);
      if(pos < 0)
         continue;

      const string pre = StringSubstr(chartSym, 0, pos);
      const string suf = StringSubstr(chartSym, pos + StringLen(anchors[i]));

      if(ConfirmAffix(pre, suf))
        {
         m_registry.detectedPrefix = pre;
         m_registry.detectedSuffix = suf;
         if(m_log != NULL)
            m_log.Info(StringFormat("Affix detected from chart symbol: prefix='%s' suffix='%s'",
                                    pre, suf));
         return(true);
        }
     }

   //--- 3. 全銘柄を走査（起動時の1回だけ）
   const int total = SymbolsTotal(false);
   for(int i = 0; i < total; i++)
     {
      const string name = SymbolName(i, false);
      const int pos = StringFind(name, "EURUSD");
      if(pos < 0)
         continue;

      const string pre = StringSubstr(name, 0, pos);
      const string suf = StringSubstr(name, pos + 6);

      if(ConfirmAffix(pre, suf))
        {
         m_registry.detectedPrefix = pre;
         m_registry.detectedSuffix = suf;
         if(m_log != NULL)
            m_log.Info(StringFormat("Affix detected by scan: prefix='%s' suffix='%s' (from %s)",
                                    pre, suf, name));
         return(true);
        }
     }

   //--- 見つからない場合は装飾なしで進める
   m_registry.detectedPrefix = "";
   m_registry.detectedSuffix = "";
   return(false);
  }

//+------------------------------------------------------------------+
//| 50%ルール : 28ペア中14以上が存在すれば、その装飾を正とする        |
//+------------------------------------------------------------------+
bool CAssetDetection::ConfirmAffix(const string prefix, const string suffix)
  {
   int found = 0;

   for(int b = 0; b < CUR_COUNT; b++)
     {
      for(int q = b + 1; q < CUR_COUNT; q++)
        {
         const string base  = CurrencyToString((ENUM_CURRENCY)b);
         const string quote = CurrencyToString((ENUM_CURRENCY)q);

         if(SymbolExists(prefix + base + quote + suffix) ||
            SymbolExists(prefix + quote + base + suffix))
            found++;
        }
     }

   return(found >= 14);            // 28ペアの50%
  }

//+------------------------------------------------------------------+
//| アセット候補名（ブローカー別の表記ゆれを吸収する）                |
//|  優先順位が高いものを先に並べる                                   |
//+------------------------------------------------------------------+
int CAssetDetection::GetCandidates(const ENUM_ASSET_ID id, string &out[])
  {
   switch(id)
     {
      case ASSET_GOLD:
         ArrayResize(out, 6);
         out[0] = "XAUUSD";  out[1] = "GOLD";     out[2] = "GOLDmicro";
         out[3] = "GOLD.spot"; out[4] = "XAUUSD_"; out[5] = "Gold";
         break;

      case ASSET_SILVER:
         ArrayResize(out, 5);
         out[0] = "XAGUSD";  out[1] = "SILVER";   out[2] = "SILVERmicro";
         out[3] = "SILVER.spot"; out[4] = "Silver";
         break;

      case ASSET_US30:
         ArrayResize(out, 7);
         out[0] = "US30";    out[1] = "US30Cash"; out[2] = "DJ30";
         out[3] = "DOW";     out[4] = "YM";       out[5] = "WS30";
         out[6] = "USA30";
         break;

      case ASSET_NAS100:
         ArrayResize(out, 7);
         out[0] = "NAS100";  out[1] = "USTEC";    out[2] = "NAS100Cash";
         out[3] = "NDX";     out[4] = "NQ";       out[5] = "USTECH100";
         out[6] = "USA100";
         break;

      case ASSET_SPX500:
         ArrayResize(out, 7);
         out[0] = "SPX500";  out[1] = "US500";    out[2] = "SP500";
         out[3] = "US500Cash"; out[4] = "ES";     out[5] = "SPX";
         out[6] = "USA500";
         break;

      case ASSET_JP225:
         ArrayResize(out, 7);
         out[0] = "JP225";   out[1] = "JPN225";   out[2] = "NIKKEI";
         out[3] = "JP225Cash"; out[4] = "N225";   out[5] = "Nikkei225";
         out[6] = "JPN225Cash";
         break;

      case ASSET_BTC:
         ArrayResize(out, 6);
         out[0] = "BTCUSD";  out[1] = "BTCUSDT";  out[2] = "BTC/USD";
         out[3] = "Bitcoin"; out[4] = "XBTUSD";   out[5] = "BTCUSD.spot";
         break;

      case ASSET_ETH:
         ArrayResize(out, 5);
         out[0] = "ETHUSD";  out[1] = "ETHUSDT";  out[2] = "ETH/USD";
         out[3] = "Ethereum"; out[4] = "ETHUSD.spot";
         break;

      default:
         ArrayResize(out, 0);
         return(0);
     }

   return(ArraySize(out));
  }

//+------------------------------------------------------------------+
//| アセット検出本体                                                  |
//|  候補名 × (装飾あり / 装飾なし) の順で探し、最初に検証を通った    |
//|  ものを採用する                                                   |
//+------------------------------------------------------------------+
void CAssetDetection::DetectAssets(void)
  {
   m_registry.okCount          = 0;
   m_registry.unavailableCount = 0;

   string cands[];

   for(int a = 0; a < ASSET_COUNT; a++)
     {
      const ENUM_ASSET_ID id = (ENUM_ASSET_ID)a;
      const int n = GetCandidates(id, cands);

      bool resolved = false;

      for(int c = 0; c < n && !resolved; c++)
        {
         //--- 装飾あり → 装飾なし の順に試す
         string tries[2];
         tries[0] = ApplyAffix(cands[c]);
         tries[1] = cands[c];

         for(int t = 0; t < 2; t++)
           {
            const string name = tries[t];

            if(t == 1 && tries[0] == tries[1])
               continue;                       // 装飾が空なら二度手間を避ける

            if(!SymbolExists(name))
               continue;

            int      bars = 0;
            datetime tick = 0;
            const ENUM_ASSET_STATE st = ValidateSymbol(name, bars, tick);

            if(st == ASSET_UNAVAILABLE)
               continue;                       // 次の候補へ

            m_registry.assets[a].symbol        = name;
            m_registry.assets[a].state         = st;
            m_registry.assets[a].barsAvailable = bars;
            m_registry.assets[a].lastTickTime  = tick;
            m_registry.assets[a].detectedAt    = TimeCurrent();
            m_registry.assets[a].digits        = (int)SymbolInfoInteger(name, SYMBOL_DIGITS);

            if(st == ASSET_OK)
               m_registry.okCount++;
            else
               m_registry.assets[a].note = "waiting for history sync";

            resolved = true;
            break;
           }
        }

      if(!resolved)
        {
         m_registry.assets[a].state = ASSET_UNAVAILABLE;
         m_registry.assets[a].note  = "not offered by this broker";
         m_registry.unavailableCount++;
        }
     }
  }

//+------------------------------------------------------------------+
//| FXペア検出（8通貨・28ペア）                                       |
//|  正順で見つからなければ逆順を探し、見つかれば inverted = true     |
//+------------------------------------------------------------------+
void CAssetDetection::DetectFxPairs(void)
  {
   int idx = 0;

   for(int b = 0; b < CUR_COUNT; b++)
     {
      for(int q = b + 1; q < CUR_COUNT; q++)
        {
         if(idx >= GMD_FX_PAIR_MAX)
            break;

         const string base  = CurrencyToString((ENUM_CURRENCY)b);
         const string quote = CurrencyToString((ENUM_CURRENCY)q);

         m_registry.fxPairs[idx].base      = (ENUM_CURRENCY)b;
         m_registry.fxPairs[idx].quote     = (ENUM_CURRENCY)q;
         m_registry.fxPairs[idx].symbol    = "";
         m_registry.fxPairs[idx].inverted  = false;
         m_registry.fxPairs[idx].available = false;

         const string direct   = ApplyAffix(base + quote);
         const string inverted = ApplyAffix(quote + base);

         int      bars = 0;
         datetime tick = 0;

         //--- CurrencyStrength は履歴同期を自分で非同期に待つ。
         //    したがって AssetDetection では「銘柄が存在するか」を確定し、
         //    ASSET_PENDING でもシンボルをレジストリへ登録する。
         //    以前は ASSET_OK のときだけ登録していたため、起動直後は
         //    履歴同期前の 28 ペアがすべて 0/28 になっていた。
         ENUM_ASSET_STATE directState = ASSET_UNAVAILABLE;
         if(SymbolExists(direct))
            directState = ValidateSymbol(direct, bars, tick);

         if(directState == ASSET_OK || directState == ASSET_PENDING)
           {
            m_registry.fxPairs[idx].symbol    = direct;
            m_registry.fxPairs[idx].inverted  = false;
            m_registry.fxPairs[idx].available = true;
           }
         else
           {
            ENUM_ASSET_STATE invertedState = ASSET_UNAVAILABLE;
            if(SymbolExists(inverted))
               invertedState = ValidateSymbol(inverted, bars, tick);

            if(invertedState == ASSET_OK || invertedState == ASSET_PENDING)
              {
               m_registry.fxPairs[idx].symbol    = inverted;
               m_registry.fxPairs[idx].inverted  = true;
               m_registry.fxPairs[idx].available = true;
              }
           }

         idx++;
        }
     }

   //--- available なペアだけを数える
   int available = 0;
   for(int i = 0; i < idx; i++)
      if(m_registry.fxPairs[i].available)
         available++;

   m_registry.fxPairCount = available;
  }

//+------------------------------------------------------------------+
//| 参照系                                                            |
//+------------------------------------------------------------------+
string CAssetDetection::GetSymbol(const ENUM_ASSET_ID id)
  {
   if(id < 0 || id >= ASSET_COUNT)
      return("");
   return(m_registry.assets[id].symbol);
  }

//+------------------------------------------------------------------+
bool CAssetDetection::IsAvailable(const ENUM_ASSET_ID id)
  {
   if(id < 0 || id >= ASSET_COUNT)
      return(false);
   return(m_registry.assets[id].state == ASSET_OK);
  }

//+------------------------------------------------------------------+
ENUM_ASSET_STATE CAssetDetection::GetState(const ENUM_ASSET_ID id)
  {
   if(id < 0 || id >= ASSET_COUNT)
      return(ASSET_UNKNOWN);
   return(m_registry.assets[id].state);
  }

//+------------------------------------------------------------------+
int CAssetDetection::GetDigits(const ENUM_ASSET_ID id)
  {
   if(id < 0 || id >= ASSET_COUNT)
      return(0);
   return(m_registry.assets[id].digits);
  }

//+------------------------------------------------------------------+
//| FXペアの銘柄名を返す。見つからなければ空文字                      |
//+------------------------------------------------------------------+
string CAssetDetection::GetFxSymbol(const ENUM_CURRENCY base,
                                    const ENUM_CURRENCY quote,
                                    bool &inverted)
  {
   inverted = false;
   if(base == quote)
      return("");

   for(int i = 0; i < GMD_FX_PAIR_MAX; i++)
     {
      if(!m_registry.fxPairs[i].available)
         continue;

      if(m_registry.fxPairs[i].base == base && m_registry.fxPairs[i].quote == quote)
        {
         inverted = m_registry.fxPairs[i].inverted;
         return(m_registry.fxPairs[i].symbol);
        }

      if(m_registry.fxPairs[i].base == quote && m_registry.fxPairs[i].quote == base)
        {
         inverted = !m_registry.fxPairs[i].inverted;
         return(m_registry.fxPairs[i].symbol);
        }
     }
   return("");
  }

//+------------------------------------------------------------------+
bool CAssetDetection::IsFxAvailable(const ENUM_CURRENCY base, const ENUM_CURRENCY quote)
  {
   bool inv = false;
   return(GetFxSymbol(base, quote, inv) != "");
  }

//+------------------------------------------------------------------+
//| ログ用サマリ                                                      |
//+------------------------------------------------------------------+
string CAssetDetection::BuildSummaryText(void)
  {
   int pending = 0;
   for(int i = 0; i < ASSET_COUNT; i++)
      if(m_registry.assets[i].state == ASSET_PENDING)
         pending++;

   return(StringFormat("Assets: %d OK / %d pending / %d unavailable (of %d) | FX pairs: %d/28 | suffix:'%s'",
                       m_registry.okCount,
                       pending,
                       m_registry.unavailableCount,
                       (int)ASSET_COUNT,
                       m_registry.fxPairCount,
                       m_registry.detectedSuffix));
  }

//+------------------------------------------------------------------+
//| 検出結果を1件ずつ出力（開発時の確認用）                           |
//+------------------------------------------------------------------+
void CAssetDetection::PrintRegistry(void)
  {
   if(m_log == NULL)
      return;

   m_log.Info("---- asset registry ----");

   for(int i = 0; i < ASSET_COUNT; i++)
     {
      m_log.Info(StringFormat("  %-8s %-14s [%s] bars=%d %s",
                              m_registry.assets[i].logicalName,
                              (m_registry.assets[i].symbol == "" ? "-" : m_registry.assets[i].symbol),
                              AssetStateToString(m_registry.assets[i].state),
                              m_registry.assets[i].barsAvailable,
                              m_registry.assets[i].note));
     }

   m_log.Info(StringFormat("---- fx pairs: %d available ----", m_registry.fxPairCount));
  }

#endif // __GMD_ASSETDETECTION_MQH__
//+------------------------------------------------------------------+
