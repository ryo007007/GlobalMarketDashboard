//+------------------------------------------------------------------+
//|                                           Interfaces/IDashboard.mqh|
//|                        Global Market Dashboard Ultimate (GMD)     |
//|                                                                   |
//|  役割 : ダッシュボード系UIの共通ライフサイクル契約                |
//|  依存 : なし                                                      |
//|  備考 : Ver2.11では CDashboard 1実装のみ。将来の複数UI方式に備える|
//+------------------------------------------------------------------+
#property strict

#ifndef __GMD_IDASHBOARD_MQH__
#define __GMD_IDASHBOARD_MQH__

interface IDashboard
  {
   bool    Build(void);            // 初回構築
   bool    Update(void);           // 値だけ更新
   void    Destroy(void);          // オブジェクト一括破棄
   string  GetName(void);          // 診断用名
  };

#endif // __GMD_IDASHBOARD_MQH__
//+------------------------------------------------------------------+
