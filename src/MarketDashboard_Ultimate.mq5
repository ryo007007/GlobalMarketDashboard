//+------------------------------------------------------------------+
//|                                      MarketDashboard_Ultimate.mq5 |
//|                        Global Market Dashboard Ultimate (GMD)      |
//|                                                                    |
//|  相場を見るのではなく、世界のお金の流れを見る。                   |
//|                                                                    |
//|  Version : 2.11.0                                                  |
//|  仕様書  : docs/ProjectSpecification.md (v1.3)                     |
//|                                                                    |
//|  Ver2.11 で動く範囲                                                |
//|    Asset Detection → Currency Strength → Best Pair → Confidence   |
//|    → Dashboard                                                     |
//|  Money Flow / Market Regime は枠だけ用意してある（Ver2.20）。      |
//+------------------------------------------------------------------+
#property copyright "GMD Project"
#property link      "https://github.com/"
#property version   "2.11"
#property description "Global Market Dashboard Ultimate - Currency Strength / Best Pair / Confidence"
#property strict

#property indicator_chart_window
#property indicator_plots   0
#property indicator_buffers 0

//--- Core
#include "Modules/Core/Types.mqh"
#include "Modules/Core/Utils.mqh"
#include "Modules/Core/Logger.mqh"
#include "Modules/Core/AssetDetection.mqh"

//--- Engines
#include "Modules/Engines/CurrencyStrength.mqh"
#include "Modules/Engines/BestPair.mqh"
#include "Modules/Engines/Confidence.mqh"
#include "Modules/Engines/MoneyFlow.mqh"
#include "Modules/Engines/MarketRegime.mqh"

//--- Display
#include "Modules/Display/DrawObjects.mqh"
#include "Modules/Display/Dashboard.mqh"

//+------------------------------------------------------------------+
//| 入力パラメータ                                                    |
//|  すべての機能を個別に ON/OFF できるようにする（開発方針）         |
//+------------------------------------------------------------------+
input group "=== 表示 ==="
input bool             Inp_ShowDashboard      = true;        // ダッシュボードを表示
input int              Inp_PanelX             = 20;          // パネル位置 X
input int              Inp_PanelY             = 30;          // パネル位置 Y
input int              Inp_FontSize           = 9;           // 文字サイズ
input ENUM_BASE_CORNER Inp_PanelCorner        = CORNER_LEFT_UPPER; // 基準の角

input group "=== Currency Strength ==="
input bool             Inp_EnableStrength     = true;        // 通貨強弱を計算
input ENUM_TIMEFRAMES  Inp_StrengthTimeframe  = PERIOD_M1;   // 判定時間足
input int              Inp_StrengthBars       = 3;           // 判定本数
input bool             Inp_UseWeighting       = true;        // 重み付け（新しい足を重く）
input int              Inp_StrengthMinPairs   = 20;          // 計算に必要な最低ペア数

input group "=== Best Pair / Confidence ==="
input bool             Inp_EnableBestPair     = true;        // 推奨ペアを出す
input double           Inp_BestPairMinSpread  = 20.0;        // 方向を出す最低点差
input bool             Inp_EnableConfidence   = true;        // 信頼度を出す

input group "=== 更新 ==="
input int              Inp_UpdateIntervalMs   = 1000;        // 更新間隔（ミリ秒）
input bool             Inp_UpdateOnNewBarOnly = false;       // 足の確定時だけ更新

input group "=== システム ==="
input ENUM_LOG_LEVEL   Inp_LogLevel           = LOG_WARN;    // ログレベル
input int              Inp_ValidationMinBars  = 100;         // 銘柄検証の最低バー数
input string           Inp_SymbolSuffix       = "";          // 接尾辞を手動指定（空=自動）

//+------------------------------------------------------------------+
//| グローバル                                                        |
//+------------------------------------------------------------------+
CLogger           g_logger;
CAssetDetection   g_assets;

CCurrencyStrength g_strength;
CBestPair         g_bestPair;
CConfidence       g_confidence;
CMoneyFlow        g_moneyFlow;      // [2.20] 枠のみ
CMarketRegime     g_marketRegime;   // [2.20] 枠のみ

CDashboard        g_dashboard;

uint              g_lastUpdateTick = 0;
datetime          g_lastBarTime    = 0;
bool              g_initialized    = false;

//--- 前方宣言
void CalcAll();
void UpdateDisplay();

//+------------------------------------------------------------------+
//| 初期化                                                            |
//|  検出に失敗しても INIT_FAILED は返さない（仕様書31.2）。          |
//|  ブローカーに銘柄が無いだけで動かなくなるのは不便すぎる。         |
//+------------------------------------------------------------------+
int OnInit()
  {
   IndicatorSetString(INDICATOR_SHORTNAME, "GMD Ultimate " + GMD_VERSION);

   g_logger.Init(Inp_LogLevel);
   g_logger.Info("Global Market Dashboard Ultimate " + GMD_VERSION + " starting.");

   //--- 1. 銘柄検出
   g_assets.Init(GetPointer(g_logger),
                 Inp_ValidationMinBars,
                 (Inp_LogLevel >= LOG_INFO),
                 Inp_SymbolSuffix);

   g_logger.Info(g_assets.BuildSummaryText());

   //--- 2. エンジン
   g_strength.Init(GetPointer(g_assets), GetPointer(g_logger),
                   Inp_StrengthTimeframe,
                   Inp_StrengthBars,
                   Inp_UseWeighting,
                   Inp_StrengthMinPairs);

   g_bestPair.Init(GetPointer(g_strength), GetPointer(g_assets),
                   GetPointer(g_logger), Inp_BestPairMinSpread);

   g_confidence.Init(GetPointer(g_strength), GetPointer(g_logger));

   g_moneyFlow.Init(GetPointer(g_assets), GetPointer(g_logger));
   g_marketRegime.Init(GetPointer(g_assets), GetPointer(g_logger));

   //--- 3. 表示
   if(Inp_ShowDashboard)
     {
      g_dashboard.Init(GetPointer(g_strength),
                       GetPointer(g_bestPair),
                       GetPointer(g_confidence),
                       GetPointer(g_logger));

      g_dashboard.SetLayout(Inp_PanelX, Inp_PanelY, Inp_FontSize, Inp_PanelCorner);
      g_dashboard.Build();
     }

   //--- 4. 初回計算（起動直後に空白のパネルを見せない）
   CalcAll();
   UpdateDisplay();

   EventSetMillisecondTimer((uint)MathMax(100, Inp_UpdateIntervalMs));

   g_initialized = true;
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| 終了                                                              |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();

   g_dashboard.Destroy();
   DeleteAllObjects();          // 念のため二重に消す

   g_logger.PrintSummary();

   g_assets.Deinit();
   g_logger.Deinit();

   g_initialized = false;
  }

//+------------------------------------------------------------------+
//| ティック                                                          |
//|  ここでは計算しない。間隔の判定だけして OnTimer に任せる。        |
//|  ティックの多い時間帯に計算すると簡単に重くなる。                 |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
   return(rates_total);
  }

//+------------------------------------------------------------------+
//| タイマー：ここが実質のメインループ                                |
//+------------------------------------------------------------------+
void OnTimer()
  {
   if(!g_initialized)
      return;

   //--- 足の確定時だけ更新する設定なら、確定していないときは何もしない
   if(Inp_UpdateOnNewBarOnly)
     {
      if(!DetectNewBar(_Symbol, Inp_StrengthTimeframe, g_lastBarTime))
         return;
     }
   else
     {
      if(!DetectIntervalElapsed(g_lastUpdateTick, (uint)Inp_UpdateIntervalMs))
         return;
     }

   CalcAll();
   UpdateDisplay();
  }

//+------------------------------------------------------------------+
//| チャートイベント                                                  |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
  {
   //--- 時間足を変えてもパネルの位置は保つ
   if(id == CHARTEVENT_CHART_CHANGE)
      ChartRedraw(0);
  }

//+------------------------------------------------------------------+
//| 全エンジンを固定順で計算する（仕様書30.2）                        |
//|  順序は依存関係で決まっている。入れ替えてはいけない。             |
//|    Strength → BestPair → Confidence                              |
//+------------------------------------------------------------------+
void CalcAll()
  {
   const uint t0 = GetTickCount();

   if(Inp_EnableStrength)
      g_strength.Calculate();

   if(Inp_EnableBestPair)
      g_bestPair.Calculate();

   if(Inp_EnableConfidence)
      g_confidence.Calculate();

   //--- [2.20] 呼んでも何もしない。順番だけ先に確定させておく
   g_moneyFlow.Calculate();
   g_marketRegime.Calculate();

   const uint elapsed = GetTickCount() - t0;

   //--- 性能の監視（32.1：目標20ms / 上限50ms）
   if(elapsed > 50)
      g_logger.Warn("SY-901", StringFormat("Calc took %u ms (limit 50 ms)", elapsed));
  }

//+------------------------------------------------------------------+
//| 表示を更新する                                                    |
//+------------------------------------------------------------------+
void UpdateDisplay()
  {
   if(!Inp_ShowDashboard)
      return;

   g_dashboard.Update();
  }
//+------------------------------------------------------------------+
