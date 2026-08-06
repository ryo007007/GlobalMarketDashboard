//+------------------------------------------------------------------+
//|                                                    MoneyFlow.mqh |
//|                        Global Market Dashboard Ultimate (GMD)     |
//|                                                                   |
//|  役割 : 資金がどこへ向かっているかを判定する                      |
//|  依存 : Types.mqh, Logger.mqh, AssetDetection.mqh                 |
//|  仕様 : Project Specification v1.6 第6章                          |
//|                                                                   |
//|  状態 : [2.20] 未実装。ここは「枠」だけ置いてある。               |
//|                                                                   |
//|  なぜ空のまま置くのか                                             |
//|    Ver2.11 の時点で Dashboard 側から呼べる形を確定させておくと、  |
//|    Ver2.20 で中身を入れるときに他のファイルを触らずに済む。       |
//|    IsReady() が常に false を返すので、表示は "--" のままになる。  |
//|                                                                   |
//|  Ver2.20 で実装する内容                                           |
//|    ・Gold / Bond / Index / BTC / VIX の騰落から資金の向きを判定   |
//|    ・Risk-On / Risk-Off の資金移動を ENUM_FLOW_STATE で返す       |
//|    ・銘柄が無いブローカーでは FLOW_UNAVAILABLE を返して降りる     |
//+------------------------------------------------------------------+
#property strict

#ifndef __GMD_MONEYFLOW_MQH__
#define __GMD_MONEYFLOW_MQH__

#include "../Core/Types.mqh"
#include "../Core/Logger.mqh"
#include "../Core/AssetDetection.mqh"

//+------------------------------------------------------------------+
class CMoneyFlow : public IEngine
  {
private:
   CAssetDetection *m_assets;
   CLogger         *m_log;

   ENUM_FLOW_STATE  m_state;
   bool             m_ready;

public:
                     CMoneyFlow(void);
                    ~CMoneyFlow(void);

   bool              Init(CAssetDetection *assets, CLogger *logger);

   //--- IEngine
   bool              Calculate(void);
   bool              IsReady(void) { return(m_ready); }
   string            GetName(void) { return("MoneyFlow"); }

   //--- 参照
   ENUM_FLOW_STATE   GetState(void)       { return(m_state); }
   string            GetDisplayText(void) { return("Flow  --  [2.20]"); }
   color             GetColor(void)       { return(clrGray); }
  };

//+------------------------------------------------------------------+
CMoneyFlow::CMoneyFlow(void) : m_assets(NULL),
                               m_log(NULL),
                               m_state(FLOW_UNAVAILABLE),
                               m_ready(false)
  {
  }

//+------------------------------------------------------------------+
CMoneyFlow::~CMoneyFlow(void)
  {
  }

//+------------------------------------------------------------------+
bool CMoneyFlow::Init(CAssetDetection *assets, CLogger *logger)
  {
   m_assets = assets;
   m_log    = logger;
   m_state  = FLOW_UNAVAILABLE;
   m_ready  = false;

   if(m_log != NULL)
      m_log.Debug("MoneyFlow: reserved for Ver2.20. Not active.");

   return(true);
  }

//+------------------------------------------------------------------+
//| [2.20] 未実装。常に「使えない」を返す                             |
//|  ここで false を返しても異常ではない。呼び出し側は表示を "--"     |
//|  にするだけで、他のエンジンは通常どおり動く。                     |
//+------------------------------------------------------------------+
bool CMoneyFlow::Calculate(void)
  {
   m_state = FLOW_UNAVAILABLE;
   m_ready = false;
   return(true);
  }

#endif // __GMD_MONEYFLOW_MQH__
//+------------------------------------------------------------------+
