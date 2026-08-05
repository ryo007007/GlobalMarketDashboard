//+------------------------------------------------------------------+
//|                                          Test_AssetDetection.mq5 |
//|                        Global Market Dashboard Ultimate (GMD)     |
//|                                                                   |
//|  役割 : Core/AssetDetection.mqh の単体確認スクリプト              |
//|  仕様 : Project Specification v1.2 第27章 27.0 最小スモークテスト |
//|                                                                   |
//|  使い方 :                                                         |
//|    1. MetaEditor でコンパイル（警告0・エラー0 = S1合格）          |
//|    2. 任意のチャートにドラッグ&ドロップ                           |
//|    3. ツールボックスの「エキスパート」タブで結果を確認            |
//+------------------------------------------------------------------+
#property copyright "GMD Project"
#property version   "1.00"
#property script_show_inputs
#property strict

#include "../src/Modules/Core/Types.mqh"
#include "../src/Modules/Core/Logger.mqh"
#include "../src/Modules/Core/AssetDetection.mqh"

//--- 入力パラメータ
input ENUM_LOG_LEVEL Inp_LogLevel            = LOG_INFO;   // ログレベル
input int            Inp_ValidationMinBars   = 100;        // 検証に必要な最低バー数
input bool           Inp_VerboseDetection    = true;       // 検出結果を1件ずつ出力
input string         Inp_SymbolSuffix        = "";         // サフィックス手動指定（空=自動）

//--- グローバル
CLogger         g_logger;
CAssetDetection g_assets;

//+------------------------------------------------------------------+
void OnStart()
  {
   Print("========================================");
   Print(" GMD Asset Detection - smoke test");
   Print("========================================");

   //--- S2 : 初期化してエラーが出ないこと
   g_logger.Init(Inp_LogLevel);

   const uint t0 = GetTickCount();

   g_assets.Init(GetPointer(g_logger),
                 Inp_ValidationMinBars,
                 Inp_VerboseDetection,
                 Inp_SymbolSuffix);

   const uint elapsed = GetTickCount() - t0;

   //--- S3 : 検出結果が全件出力されること
   Print("---- detection result ----");
   Print("  suffix        : '", g_assets.GetSuffix(), "'");
   Print("  prefix        : '", g_assets.GetPrefix(), "'");
   Print("  assets OK     : ", g_assets.GetOkCount(), " / ", (int)ASSET_COUNT);
   Print("  fx pairs OK   : ", g_assets.GetFxPairCount(), " / 28");
   Print("  elapsed       : ", elapsed, " ms");

   //--- 個別アセットの確認
   Print("---- per asset ----");
   for(int i = 0; i < ASSET_COUNT; i++)
     {
      const ENUM_ASSET_ID id = (ENUM_ASSET_ID)i;
      PrintFormat("  [%d] %-14s state=%-12s digits=%d",
                  i,
                  (g_assets.GetSymbol(id) == "" ? "(none)" : g_assets.GetSymbol(id)),
                  AssetStateToString(g_assets.GetState(id)),
                  g_assets.GetDigits(id));
     }

   //--- FXペアの確認（Currency Strength Engine が使う形）
   Print("---- fx matrix ----");
   for(int b = 0; b < CUR_COUNT; b++)
     {
      string line = CurrencyToString((ENUM_CURRENCY)b) + " : ";
      for(int q = 0; q < CUR_COUNT; q++)
        {
         if(b == q)
            continue;
         bool inv = false;
         const string sym = g_assets.GetFxSymbol((ENUM_CURRENCY)b, (ENUM_CURRENCY)q, inv);
         line += (sym == "" ? "---- " : (inv ? "[i]" : "   ") + sym + " ");
        }
      Print("  ", line);
     }

   //--- S4 : 存在しない銘柄を含んでもクラッシュしないこと
   Print("---- graceful degradation check ----");
   if(g_assets.GetOkCount() < ASSET_COUNT)
      Print("  OK: some assets are unavailable, but the module kept running.");
   else
      Print("  OK: all assets detected.");

   //--- 性能基準（仕様書 32.1：初回検出 500ms 目標 / 1000ms 上限）
   Print("---- performance ----");
   if(elapsed <= 500)
      Print("  PASS: ", elapsed, " ms (target <= 500 ms)");
   else
      if(elapsed <= 1000)
         Print("  WARN: ", elapsed, " ms (over target, within limit)");
      else
         Print("  FAIL: ", elapsed, " ms (over 1000 ms limit)");

   //--- Refresh の確認
   Print("---- refresh check ----");
   g_assets.Refresh();
   Print("  refresh done. assets OK = ", g_assets.GetOkCount());

   g_assets.Deinit();
   g_logger.Deinit();

   Print("========================================");
   Print(" smoke test finished");
   Print("========================================");
  }
//+------------------------------------------------------------------+
