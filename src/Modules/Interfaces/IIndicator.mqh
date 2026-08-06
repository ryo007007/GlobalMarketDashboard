//+------------------------------------------------------------------+
//|                                           Interfaces/IIndicator.mqh|
//|                        Global Market Dashboard Ultimate (GMD)     |
//|                                                                   |
//|  役割 : 将来の表示/補助モジュール向けの共通入口                    |
//|  依存 : なし                                                      |
//|  備考 : Ver2.11では未使用。補助インジケーター追加時の受け皿        |
//+------------------------------------------------------------------+
#property strict

#ifndef __GMD_IINDICATOR_MQH__
#define __GMD_IINDICATOR_MQH__

interface IIndicator
  {
   bool    Init(void);
   bool    Refresh(void);
   void    Deinit(void);
   string  GetName(void);
  };

#endif // __GMD_IINDICATOR_MQH__
//+------------------------------------------------------------------+
