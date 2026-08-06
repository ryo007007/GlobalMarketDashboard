//+------------------------------------------------------------------+
//|                                              Interfaces/IEngine.mqh|
//|                        Global Market Dashboard Ultimate (GMD)     |
//|                                                                   |
//|  役割 : すべての分析エンジンが実装する最小インターフェース         |
//|  依存 : なし                                                      |
//|  導入 : レビュー指摘に基づき、型定義からインターフェースを分離     |
//+------------------------------------------------------------------+
#property strict

#ifndef __GMD_IENGINE_MQH__
#define __GMD_IENGINE_MQH__

interface IEngine
  {
   bool    Calculate(void);        // 計算実行。成功で true
   bool    IsReady(void);          // 表示可能な状態か
   string  GetName(void);          // ログ・診断用の名前
  };

#endif // __GMD_IENGINE_MQH__
//+------------------------------------------------------------------+
