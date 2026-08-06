//+------------------------------------------------------------------+
//|                                      MarketDashboard_Ultimate.mq5 |
//|                        Global Market Dashboard Ultimate (GMD)      |
//|                                                                    |
//|  相場を見るのではなく、世界のお金の流れを見る。                   |
//|                                                                    |
//|  Version : 2.11.0                                                  |
//|  仕様書  : docs/ProjectSpecification.md (v1.6)                     |
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
#include "Modules/Core/SessionClock.mqh"

//--- Engines
#include "Modules/Engines/CurrencyStrength.mqh"
#include "Modules/Engines/BestPair.mqh"
#include "Modules/Engines/Confidence.mqh"
#include "Modules/Engines/AnomalyEngine.mqh"
#include "Modules/Engines/MoneyFlow.mqh"
#include "Modules/Engines/AdaptiveUpdate.mqh"
#include "Modules/Engines/EnergyEngine.mqh"
#include "Modules/Engines/MarketRegime.mqh"
#include "Modules/Engines/MarketState.mqh"
#include "Modules/Engines/AlertEngine.mqh"

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

input group "=== Anomaly ==="
input bool             Inp_EnableAnomaly      = true;        // アノマリーを評価
input int              Inp_AnomalyMinStars    = 4;           // この星数未満は使わない
input int              Inp_ServerGmtOffset    = 3;           // サーバ時刻のGMT差（五十日判定用）
input bool             Inp_UseSeasonScore     = true;        // 月別季節性を使う
input bool             Inp_AnomalyToConfidence = false;      // 信頼度に加算する（推奨: false）

input group "=== Energy ==="
input bool             Inp_EnableEnergy       = true;        // 圧縮（Energy）を評価
input int              Inp_EnergyAtrPeriod    = 14;          // ATR期間
input int              Inp_EnergyBbPeriod     = 20;          // ボリンジャー期間
input int              Inp_EnergyAdxPeriod    = 14;          // ADX期間
input int              Inp_EnergyLookback     = 100;         // 圧縮度を比べる母数（本）
input int              Inp_EnergyThBuilding   = 60;          // Building とみなす点
input int              Inp_EnergyThLoaded     = 80;          // Loaded とみなす点

input group "=== 更新 ==="
input int              Inp_UpdateIntervalMs   = 1000;        // 通常の更新間隔（ミリ秒）
input bool             Inp_UpdateOnNewBarOnly = false;       // 足の確定時だけ更新
input bool             Inp_EnableAdaptive     = true;        // 市場時間で更新間隔を変える
input int              Inp_UpdateMsAlert      = 300;         // 警戒時（セッション前後）
input int              Inp_UpdateMsIdle       = 2000;        // 静穏時（どこも開いていない）
input int              Inp_AdaptiveDwellSec   = 60;          // 段を変えた後の最低滞留秒
input bool             Inp_EnergyRaisesTier   = true;        // 高圧縮時も更新を速める

input group "=== セッション ==="
input int              Inp_ServerStdGmtOffset = 2;           // 冬時間のサーバGMT差
input bool             Inp_ServerFollowsEuDst = true;        // サーバが欧州夏時間に追従する
input int              Inp_SessionPreMinutes  = 15;          // 開始何分前から警戒するか
input int              Inp_SessionOpenMinutes = 30;          // 開始後 何分を急変帯とみなすか

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
CAnomalyEngine    g_anomaly;
CEnergyEngine     g_energy;
CMoneyFlow        g_moneyFlow;      // [2.20] 枠のみ
CMarketRegime     g_marketRegime;   // [2.20] 枠のみ
CMarketState      g_marketState;    // [2.30] 枠のみ
CAlertEngine      g_alert;          // [2.30] 枠のみ

CSessionClock     g_clock;
CAdaptiveUpdate   g_adaptive;

CDashboard        g_dashboard;

uint              g_lastUpdateTick = 0;
int               g_currentTimerMs = 1000;
datetime          g_lastBarTime    = 0;
bool              g_initialized    = false;

//--- 前方宣言
void CalcAll();
void UpdateDisplay();
void ApplyAdaptiveTimer();

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

   //--- アノマリーは価格を見ないので、銘柄検出の結果に依存しない
   g_anomaly.Init(GetPointer(g_logger),
                  Inp_ServerGmtOffset,
                  Inp_AnomalyMinStars,
                  Inp_UseSeasonScore);

   g_confidence.Init(GetPointer(g_strength), GetPointer(g_logger));

   //--- 既定では「参照するが信頼度の値は変えない」
   g_confidence.SetAnomaly(GetPointer(g_anomaly),
                           Inp_AnomalyToConfidence,
                           (StringFind(_Symbol, "JPY") >= 0 ? SCOPE_JPY : SCOPE_FX));

   //--- セッション時計。現地時刻でセッションを定義し、夏時間を自動追従する
   g_clock.Init(GetPointer(g_logger),
                Inp_ServerStdGmtOffset,
                Inp_ServerFollowsEuDst,
                Inp_SessionPreMinutes,
                Inp_SessionOpenMinutes);

   //--- 圧縮の評価は「今見ているチャート1本」だけに掛ける。
   //    28ペア分やると計算量が跳ね上がるうえ、見ていない銘柄の
   //    圧縮を知っても行動につながらない
   if(Inp_EnableEnergy)
     {
      g_energy.Init(GetPointer(g_logger), _Symbol, (ENUM_TIMEFRAMES)_Period,
                    Inp_EnergyAtrPeriod, Inp_EnergyBbPeriod,
                    Inp_EnergyAdxPeriod, Inp_EnergyLookback);
      g_energy.SetThresholds(Inp_EnergyThBuilding, Inp_EnergyThLoaded);
     }

   g_adaptive.Init(GetPointer(g_logger), GetPointer(g_clock),
                   Inp_UpdateIntervalMs,
                   Inp_UpdateMsAlert,
                   Inp_UpdateMsIdle,
                   Inp_AdaptiveDwellSec);
   g_adaptive.SetEnabled(Inp_EnableAdaptive);

   g_moneyFlow.Init(GetPointer(g_assets), GetPointer(g_logger));
   g_marketRegime.Init(GetPointer(g_assets), GetPointer(g_logger));
   g_marketState.Init(GetPointer(g_logger));
   g_alert.Init(GetPointer(g_logger));

   //--- 3. 表示
   if(Inp_ShowDashboard)
     {
      g_dashboard.Init(GetPointer(g_strength),
                       GetPointer(g_bestPair),
                       GetPointer(g_confidence),
                       GetPointer(g_logger));

      if(Inp_EnableAnomaly)
         g_dashboard.SetAnomaly(GetPointer(g_anomaly));

      if(Inp_EnableEnergy)
         g_dashboard.SetEnergy(GetPointer(g_energy));

      g_dashboard.SetClock(GetPointer(g_clock));
      g_dashboard.SetAdaptive(GetPointer(g_adaptive));

      g_dashboard.SetLayout(Inp_PanelX, Inp_PanelY, Inp_FontSize, Inp_PanelCorner);
      g_dashboard.Build();
     }

   //--- 4. 初回計算（起動直後に空白のパネルを見せない）
   CalcAll();
   UpdateDisplay();

   g_currentTimerMs = g_adaptive.GetIntervalMs();
   EventSetMillisecondTimer((uint)MathMax(100, g_currentTimerMs));

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

   g_energy.Deinit();           // 指標ハンドルを必ず返す
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
      if(!DetectIntervalElapsed(g_lastUpdateTick, (uint)g_currentTimerMs))
         return;
     }

   CalcAll();
   UpdateDisplay();
   ApplyAdaptiveTimer();
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
//|    Strength → Anomaly → BestPair → Confidence                    |
//|                                                                   |
//|  Anomaly を Confidence より先に置くのは、Confidence が            |
//|  Anomaly の結果を参照するから。逆にすると 1回分古い値を使う。    |
//+------------------------------------------------------------------+
void CalcAll()
  {
   const uint t0 = GetTickCount();

   if(Inp_EnableStrength)
      g_strength.Calculate();

   if(Inp_EnableAnomaly)
      g_anomaly.Calculate();

   //--- Energy は価格を読むが、見ているチャート1本だけなので軽い
   if(Inp_EnableEnergy)
      g_energy.Calculate();

   if(Inp_EnableBestPair)
      g_bestPair.Calculate();

   if(Inp_EnableConfidence)
      g_confidence.Calculate();

   //--- [2.20] / [2.30] 呼んでも何もしない。順番だけ先に確定させておく
   g_moneyFlow.Calculate();
   g_marketRegime.Calculate();
   g_marketState.Calculate();

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
//| 更新間隔の段を評価し、変わったときだけタイマーを張り直す          |
//|                                                                   |
//|  毎回 EventKillTimer / EventSetMillisecondTimer を呼ばないのは、  |
//|  張り直しの瞬間にイベントが1回落ちることがあるためである。        |
//|  段が変わったときだけに限れば、落ちるのは1日に数回で済む。        |
//+------------------------------------------------------------------+
void ApplyAdaptiveTimer()
  {
   g_clock.Refresh();

   //--- 圧縮が高いときも更新を速める。
   //    ただし「解けた瞬間」を捉えるためであって、
   //    数字を細かく見せるためではない
   if(Inp_EnergyRaisesTier && Inp_EnableEnergy)
     {
      const ENUM_ENERGY_STATE es = g_energy.GetState();
      g_adaptive.RequestAlert(es == ENERGY_LOADED || es == ENERGY_RELEASED);
     }

   if(!g_adaptive.Evaluate())
      return;

   g_currentTimerMs = g_adaptive.GetIntervalMs();

   EventKillTimer();
   EventSetMillisecondTimer((uint)MathMax(100, g_currentTimerMs));
  }
//+------------------------------------------------------------------+
