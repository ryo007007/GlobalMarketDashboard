//+------------------------------------------------------------------+
//|                                     CCompression_Scanner.mq5      |
//|  複数通貨ペア × 複数時間足のCCompression状態を一覧表示するスキャナー |
//|                                                                    |
//|  ・Compression状態(NORMAL以外)の銘柄/時間足のみ表示                |
//|  ・圧縮が強い順(TRANSITION優先 → Score降順)にソート                |
//|  ・検証ログを MQL5/Files/GlobalMarketDashboardVerification log に出力 |
//|  ・行をクリックするとその通貨ペア・時間足にチャートが切り替わる    |
//|                                                                    |
//|  まずはこのスタンドアロン版で検証し、問題なければMTF_TrendSign     |
//|  パネルへの統合を検討する。                                        |
//+------------------------------------------------------------------+
#property copyright "CCompression scanner"
#property version   "1.11"
#property indicator_chart_window
#property indicator_plots 0

#include "CCompressionScannerCompat.mqh"  // Scanner専用API。src側のCCompression.mqhは変更しない
#include "../src/Modules/Engines/SuddenMoveDetector.mqh"   // 急変検知(SMD_CheckSpike)を使用

//---------------- 入力パラメータ ----------------
input string InpSymbols = "USDJPY,EURUSD,GBPUSD,AUDUSD,NZDUSD,USDCAD,USDCHF,EURJPY,GBPJPY,AUDJPY,NZDJPY,CADJPY,CHFJPY,EURGBP,GBPCHF,EURCAD,EURCHF,AUDNZD,CADCHF,AUDCHF,GBPCAD,AUDCAD,EURAUD,GBPAUD,EURNZD,XAUUSD,BTCUSD";

input group "=== 監視する時間足 ==="
input bool ScanD1  = true;  // 日足
input bool ScanH4  = true;  // 4時間足
input bool ScanH1  = true;  // 1時間足
input bool ScanM30 = true;  // 30分足
input bool ScanM15 = true;  // 15分足
input bool ScanM5  = false; // 5分足（監視対象が多いと重くなるのでデフォルトOFF）
input bool ScanM1  = false; // 1分足（同上）

input group "=== 表示設定 ==="
input int  PanelX           = 10;   // パネルX座標
input int  PanelY           = 20;   // パネルY座標
input int  MaxRows          = 40;   // 最大表示行数
input int  RefreshSeconds   = 1;    // 再計算の最小間隔(秒)
input bool OpenInNewChart   = false; // trueなら新規チャート、falseなら現在のチャートを切替

input group "=== 検証ログ設定 ==="
input bool InpEnableVerificationLog = true; // 検証ログを出力する(true/false)
input bool InpLogStateChanges       = true; // 圧縮状態の変化も記録する
input int  InpTransitionMeasureBars = 12;   // TRANSITION発生後、最大値幅を計測する確定足数
input int  InpTransitionDisplayHoldBars = 3; // TRANSITION判定後、一覧表示を保持する確定足数

input group "=== 解説パネル(現在のチャートの通貨・時間足) ==="
input bool ShowDetailPanel = true;               // 解説パネルを表示する
input ENUM_BASE_CORNER DetailCorner = CORNER_LEFT_LOWER; // 表示する隅
input int  DetailX         = 10;                 // 隅からのX距離
input int  DetailY         = 20;                 // 隅からのY距離

input group "=== 表示する最低状態 ==="
input bool ShowCompression       = true; // COMPRESSION以上を表示
input bool ShowOnlyStrongOrAbove = false; // trueならSTRONG COMPRESSION以上のみ表示
input bool ShowTransition        = true; // TRANSITION(圧縮解除中)を表示

input group "=== 急変検知との連携 ==="
input bool UseSpikeOverride  = true;  // 急変を検知したら圧縮表示を解除して「急変」として表示する
input int  SpikeHoldBars     = 3;     // 急変表示を保持する本数(その時間足の本数)
input bool SpikeShowAlways   = false; // trueなら圧縮中でない行の急変も表示(falseは圧縮中の行のみ対象)
input color SpikeUpColor     = clrLime;      // 急変(上昇)の表示色
input color SpikeDownColor   = clrDeepPink;  // 急変(下落)の表示色

//---------------- グローバル ----------------
string          g_symbols[];
int             g_symbolCount = 0;
ENUM_TIMEFRAMES g_tfList[];
int             g_tfCount = 0;

CCOMP_Instance  g_scan[];     // symbolCount * tfCount 分のインスタンス
int             g_scanTotal = 0;

// 現在表示中の行がどの(symbol, tf)に対応するか（クリック処理用。描画のたびに更新）
string          g_rowSymbol[];
ENUM_TIMEFRAMES g_rowTF[];
int             g_rowCount = 0;

// (通貨ペア×時間足)ごとの急変状態。g_scanと同じインデックスで対応する
datetime        g_spikeUntil[];   // この時刻までは「急変」として表示する
bool            g_spikeUp[];      // 急変の方向(true=上昇)
double          g_spikeRatio[];   // 急変検知時のATR比
double          g_spikeZ[];       // 急変検知時のROC Zスコア
bool            g_suppressed[];   // 急変で圧縮表示を解除済み(圧縮がNORMALに戻るまで非表示)
bool            g_spikeWasDetected[]; // 急変ログの重複防止(連続検知中は1回だけ)
int             g_verificationLog = INVALID_HANDLE;
string          g_verificationLogPath = "";

struct CCOMP_VerificationEvent
  {
   bool     active;
   datetime startTime;
   double   startPrice;
   double   maxHigh;
   double   minLow;
   int      barsElapsed;
   int      startScore;
  };
CCOMP_VerificationEvent g_verification[];
int g_transitionHoldRemaining[]; // TRANSITION表示保持の残り確定足数

void DrawDetailPanel();   // 解説パネル描画(定義はファイル末尾)

//+------------------------------------------------------------------+
int ParseSymbols(string src, string &outArr[])
  {
   string raw[];
   int n = StringSplit(src, ',', raw);
   int count = 0;
   ArrayResize(outArr, n);
   for(int i = 0; i < n; i++)
     {
      string s = raw[i];
      StringTrimLeft(s); StringTrimRight(s);
      if(StringLen(s) == 0) continue;
      outArr[count] = s;
      count++;
     }
   ArrayResize(outArr, count);
   return count;
  }

//+------------------------------------------------------------------+
color CCOMP_StateColor(const CCOMP_STATE st)
  {
   switch(st)
     {
      case CCOMP_COMPRESSION:        return clrYellow;
      case CCOMP_STRONG_COMPRESSION: return clrOrange;
      case CCOMP_TIGHT_COMPRESSION:  return clrRed;
      case CCOMP_TRANSITION:         return clrAqua;
      default:                       return clrWhite;
     }
  }

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| 急変状態の保存・復元                                               |
//| 行クリックでチャートの通貨/時間足が変わるとインジケーターが         |
//| 読み込み直されるため、急変の保持状態を端末のグローバル変数に        |
//| 保存して引き継ぐ。                                                 |
//+------------------------------------------------------------------+
string GVKey(const int i, const string field)
  {
   return "CCOMP_" + field + "_" + g_scan[i].symbol + "_" + IntegerToString(PeriodSeconds(g_scan[i].tf));
  }

// TRANSITIONの表示保持状態を端末グローバル変数に保存する。
void SaveTransitionHoldState(const int i)
  {
   string key = GVKey(i, "TH");
   if(g_transitionHoldRemaining[i] > 0)
      GlobalVariableSet(key, (double)g_transitionHoldRemaining[i]);
   else if(GlobalVariableCheck(key))
      GlobalVariableDel(key);
  }

void LoadTransitionHoldStates()
  {
   for(int i = 0; i < g_scanTotal; i++)
     {
      string key = GVKey(i, "TH");
      if(GlobalVariableCheck(key))
         g_transitionHoldRemaining[i] = (int)GlobalVariableGet(key);
      if(g_transitionHoldRemaining[i] < 0)
         g_transitionHoldRemaining[i] = 0;
     }
  }

// 実際のエンジン状態は変更せず、一覧表示用にTRANSITIONだけ保持する。
CCOMP_STATE DisplayStateForRow(const int i)
  {
   if(g_scan[i].state == CCOMP_TRANSITION || g_transitionHoldRemaining[i] > 0)
      return CCOMP_TRANSITION;
   return g_scan[i].state;
  }

void SaveSpikeState(const int i)
  {
   GlobalVariableSet(GVKey(i, "SU"), (double)g_spikeUntil[i]);
   GlobalVariableSet(GVKey(i, "SD"), g_spikeUp[i] ? 1.0 : 0.0);
   GlobalVariableSet(GVKey(i, "SR"), g_spikeRatio[i]);
   GlobalVariableSet(GVKey(i, "SZ"), g_spikeZ[i]);
  }

void SaveSuppressed(const int i, const bool on)
  {
   string k = GVKey(i, "SP");
   if(on)
      GlobalVariableSet(k, 1.0);
   else if(GlobalVariableCheck(k))
      GlobalVariableDel(k);
  }

void LoadSpikeStates()
  {
   datetime now = TimeCurrent();
   for(int i = 0; i < g_scanTotal; i++)
     {
      string ku = GVKey(i, "SU");
      if(GlobalVariableCheck(ku))
        {
         datetime until = (datetime)(long)GlobalVariableGet(ku);
         if(until > now)
           {
            g_spikeUntil[i] = until;
            g_spikeUp[i]    = (GlobalVariableGet(GVKey(i, "SD")) > 0.5);
            g_spikeRatio[i] = GlobalVariableGet(GVKey(i, "SR"));
            g_spikeZ[i]     = GlobalVariableGet(GVKey(i, "SZ"));
           }
         else
           {
            // 期限切れは削除
            GlobalVariableDel(ku);
            GlobalVariableDel(GVKey(i, "SD"));
            GlobalVariableDel(GVKey(i, "SR"));
            GlobalVariableDel(GVKey(i, "SZ"));
           }
        }
      if(GlobalVariableCheck(GVKey(i, "SP")))
         g_suppressed[i] = true;
     }
  }

//+------------------------------------------------------------------+
//| 検証ログ                                                         |
//| 保存先: MQL5/Files/GlobalMarketDashboardVerification log/       |
//| 形式: UTF-8テキスト、タブ区切り。1日ごとにファイル作成       |
//+------------------------------------------------------------------+
string VerificationKey(const string field, const int i)
  {
   return "CCV_" + field + "_" + g_scan[i].symbol + "_" + IntegerToString(PeriodSeconds(g_scan[i].tf));
  }

string VerificationSessionJST(const datetime serverTime)
  {
   // 直近のサーバーUTC差を使ってJSTへ概算変換。DST切替日の過去データは目安。
   int serverUtcOffset = (int)(TimeCurrent() - TimeGMT());
   datetime jst = serverTime - serverUtcOffset + 9 * 3600;
   MqlDateTime dt;
   TimeToStruct(jst, dt);
   int h = dt.hour;
   if(h >= 9 && h < 15) return "東京";
   if(h >= 15 && h < 17) return "東京後半/欧州前";
   if(h >= 17 && h < 21) return "欧州";
   if(h >= 21 || h < 2) return "欧州+NY";
   if(h >= 2 && h < 6) return "NY";
   return "その他";
  }

string VerificationTimeJST(const datetime serverTime)
  {
   int serverUtcOffset = (int)(TimeCurrent() - TimeGMT());
   datetime jst = serverTime - serverUtcOffset + 9 * 3600;
   return TimeToString(jst, TIME_DATE|TIME_MINUTES);
  }

void VerificationWriteLine(const string line)
  {
   if(!InpEnableVerificationLog)
      return;

   string datePart = TimeToString(TimeCurrent(), TIME_DATE);
   StringReplace(datePart, ".", "-");
   if(g_verificationLog != INVALID_HANDLE && StringFind(g_verificationLogPath, datePart) < 0)
     {
      FileFlush(g_verificationLog);
      FileClose(g_verificationLog);
      g_verificationLog = INVALID_HANDLE;
     }
   if(g_verificationLog == INVALID_HANDLE)
      VerificationLogOpen();
   if(g_verificationLog == INVALID_HANDLE)
      return;

   FileSeek(g_verificationLog, 0, SEEK_END);
   FileWriteString(g_verificationLog, line + "\r\n");
   FileFlush(g_verificationLog);
  }

void VerificationLogOpen()
  {
   if(!InpEnableVerificationLog)
      return;

   string folder = "GlobalMarketDashboardVerification log";
   // 既に存在する場合 FolderCreate は失敗することがあるため、
   // 戻り値だけで既存フォルダをエラー扱いせず、その後の FileOpen で確認する。
   FolderCreate(folder);

   string datePart = TimeToString(TimeCurrent(), TIME_DATE);
   StringReplace(datePart, ".", "-");
   g_verificationLogPath = folder + "\\CCompression_Verification_" + datePart + ".txt";

   g_verificationLog = FileOpen(g_verificationLogPath,
                                FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE,
                                '\t', CP_UTF8);
   if(g_verificationLog == INVALID_HANDLE)
     {
      Print("検証ログを開けません: MQL5/Files/", g_verificationLogPath,
            " / error=", GetLastError());
      return;
     }

   if(FileSize(g_verificationLog) == 0)
     {
      string header = "記録種別\t銘柄\t時間足\t発生時刻(JST)\t状態\tスコア(0-8)" +
                      "\t最大値幅(価格差)\t最大上昇幅\t最大下落幅\t最大値幅(%)" +
                      "\t経過時間\tだましの有無\t時間帯(JST)\t補足";
      FileWriteString(g_verificationLog, header + "\r\n");
      FileFlush(g_verificationLog);
     }
   FileSeek(g_verificationLog, 0, SEEK_END);
   Print("検証ログ出力先: MQL5/Files/", g_verificationLogPath);
  }

void VerificationLogStateChange(const int i, const CCOMP_STATE oldState,
                                const CCOMP_STATE newState, const datetime eventTime)
  {
   if(!InpEnableVerificationLog || !InpLogStateChanges)
      return;
   string key = VerificationKey("STATELOG", i);
   double previousTime = GlobalVariableCheck(key) ? GlobalVariableGet(key) : 0.0;
   if((datetime)previousTime == eventTime)
      return; // チャート切替・再読み込み時の同じ確定足の重複記録を防止
   GlobalVariableSet(key, (double)eventTime);

   string tf = EnumToString(g_scan[i].tf);
   StringReplace(tf, "PERIOD_", "");
   string note = CCOMP_StateText(oldState) + " -> " + CCOMP_StateText(newState);
   VerificationWriteLine(StringFormat("STATE\t%s\t%s\t%s\t%s\t%d\t\t\t\t\t未判定\t%s\t%s",
                         g_scan[i].symbol, tf, VerificationTimeJST(eventTime),
                         CCOMP_StateText(newState), g_scan[i].score,
                         VerificationSessionJST(eventTime), note));
  }

void VerificationSaveEvent(const int i)
  {
   CCOMP_VerificationEvent e = g_verification[i];
   string fields[7];
   fields[0] = "ACTIVE";
   fields[1] = DoubleToString((double)e.startTime, 0);
   fields[2] = DoubleToString(e.startPrice, 16);
   fields[3] = DoubleToString(e.maxHigh, 16);
   fields[4] = DoubleToString(e.minLow, 16);
   fields[5] = IntegerToString(e.barsElapsed);
   fields[6] = IntegerToString(e.startScore);
   for(int k=0; k<7; k++)
      GlobalVariableSet(VerificationKey("TR" + IntegerToString(k), i),
                        (k==0 ? 1.0 : StringToDouble(fields[k])));
  }

void VerificationClearEvent(const int i)
  {
   for(int k=0; k<7; k++)
     {
      string key = VerificationKey("TR" + IntegerToString(k), i);
      if(GlobalVariableCheck(key)) GlobalVariableDel(key);
     }
   g_verification[i].active = false;
  }

void VerificationLoadEvents()
  {
   for(int i=0; i<g_scanTotal; i++)
     {
      string key = VerificationKey("TR0", i);
      if(!GlobalVariableCheck(key) || GlobalVariableGet(key) < 0.5)
         continue;
      g_verification[i].active      = true;
      g_verification[i].startTime   = (datetime)(long)GlobalVariableGet(VerificationKey("TR1", i));
      g_verification[i].startPrice  = GlobalVariableGet(VerificationKey("TR2", i));
      g_verification[i].maxHigh     = GlobalVariableGet(VerificationKey("TR3", i));
      g_verification[i].minLow      = GlobalVariableGet(VerificationKey("TR4", i));
      g_verification[i].barsElapsed = (int)GlobalVariableGet(VerificationKey("TR5", i));
      g_verification[i].startScore  = (int)GlobalVariableGet(VerificationKey("TR6", i));
     }
  }

void VerificationLogTransitionStart(const int i, const datetime eventTime)
  {
   string key = VerificationKey("TRLOG", i);
   double previousTime = GlobalVariableCheck(key) ? GlobalVariableGet(key) : 0.0;
   if((datetime)previousTime == eventTime)
      return;
   GlobalVariableSet(key, (double)eventTime);

   g_verification[i].active      = true;
   g_verification[i].startTime   = eventTime;
   g_verification[i].startPrice  = iClose(g_scan[i].symbol, g_scan[i].tf, 1);
   g_verification[i].maxHigh     = iHigh(g_scan[i].symbol, g_scan[i].tf, 1);
   g_verification[i].minLow      = iLow(g_scan[i].symbol, g_scan[i].tf, 1);
   g_verification[i].barsElapsed = 0;
   g_verification[i].startScore  = g_scan[i].score;
   VerificationSaveEvent(i);

   string tf = EnumToString(g_scan[i].tf);
   StringReplace(tf, "PERIOD_", "");
   VerificationWriteLine(StringFormat("TRANSITION_START\t%s\t%s\t%s\tTRANSITION\t%d\t\t\t\t\t計測中\t未判定（目視評価）\t%s\t開始価格=%s",
                         g_scan[i].symbol, tf, VerificationTimeJST(eventTime), g_scan[i].score,
                         VerificationSessionJST(eventTime),
                         DoubleToString(g_verification[i].startPrice, (int)SymbolInfoInteger(g_scan[i].symbol, SYMBOL_DIGITS))));
  }

void VerificationLogTransitionFinish(const int i, const string reason)
  {
   if(!g_verification[i].active)
      return;
   CCOMP_VerificationEvent e = g_verification[i];
   double upMove = MathMax(0.0, e.maxHigh - e.startPrice);
   double downMove = MathMax(0.0, e.startPrice - e.minLow);
   double maxMove = MathMax(upMove, downMove);
   double maxPct = (e.startPrice != 0.0) ? maxMove / e.startPrice * 100.0 : 0.0;
   int digits = (int)SymbolInfoInteger(g_scan[i].symbol, SYMBOL_DIGITS);
   string tf = EnumToString(g_scan[i].tf);
   StringReplace(tf, "PERIOD_", "");
   int elapsedSeconds = e.barsElapsed * PeriodSeconds(g_scan[i].tf);
   string elapsed = StringFormat("%d本/%s", e.barsElapsed,
                                 (elapsedSeconds >= 3600 ? IntegerToString(elapsedSeconds/3600) + "時間" :
                                  IntegerToString(elapsedSeconds/60) + "分"));
   VerificationWriteLine(StringFormat("TRANSITION_RESULT\t%s\t%s\t%s\tTRANSITION\t%d\t%s\t%s\t%s\t%.5f\t%s\t未判定（目視評価）\t%s\t計測終了=%s;開始価格=%s;最高値=%s;最安値=%s",
                         g_scan[i].symbol, tf, VerificationTimeJST(e.startTime), e.startScore,
                         DoubleToString(maxMove, digits), DoubleToString(upMove, digits),
                         DoubleToString(downMove, digits), maxPct, elapsed,
                         VerificationSessionJST(e.startTime), reason,
                         DoubleToString(e.startPrice, digits), DoubleToString(e.maxHigh, digits),
                         DoubleToString(e.minLow, digits)));
   VerificationClearEvent(i);
  }

void VerificationUpdateTransition(const int i)
  {
   if(!g_verification[i].active)
      return;
   double hi = iHigh(g_scan[i].symbol, g_scan[i].tf, 1);
   double lo = iLow(g_scan[i].symbol, g_scan[i].tf, 1);
   if(hi > g_verification[i].maxHigh) g_verification[i].maxHigh = hi;
   if(lo < g_verification[i].minLow)  g_verification[i].minLow  = lo;
   g_verification[i].barsElapsed++;
   VerificationSaveEvent(i);
   if(g_verification[i].barsElapsed >= MathMax(1, InpTransitionMeasureBars))
      VerificationLogTransitionFinish(i, "指定計測本数に到達");
  }

void VerificationLogSpike(const int i, const datetime eventTime, const bool isUp,
                          const double ratio, const double z)
  {
   string tf = EnumToString(g_scan[i].tf);
   StringReplace(tf, "PERIOD_", "");
   VerificationWriteLine(StringFormat("SUDDEN_MOVE\t%s\t%s\t%s\t急変%s\t%d\t\t\t\t\t検知中\t未判定（目視評価）\t%s\tATR比=%.2f; ROC Z=%+.2f; 検知ロジックは変更なし",
                         g_scan[i].symbol, tf, VerificationTimeJST(eventTime),
                         isUp ? "上昇" : "下落", g_scan[i].score,
                         VerificationSessionJST(eventTime), ratio, z));
  }

int OnInit()
  {
   g_symbolCount = ParseSymbols(InpSymbols, g_symbols);

   ENUM_TIMEFRAMES tmp[];
   ArrayResize(tmp, 7);
   int c = 0;
   if(ScanD1)  tmp[c++] = PERIOD_D1;
   if(ScanH4)  tmp[c++] = PERIOD_H4;
   if(ScanH1)  tmp[c++] = PERIOD_H1;
   if(ScanM30) tmp[c++] = PERIOD_M30;
   if(ScanM15) tmp[c++] = PERIOD_M15;
   if(ScanM5)  tmp[c++] = PERIOD_M5;
   if(ScanM1)  tmp[c++] = PERIOD_M1;
   g_tfCount = c;
   ArrayResize(g_tfList, c);
   for(int i = 0; i < c; i++) g_tfList[i] = tmp[i];

   if(g_symbolCount == 0 || g_tfCount == 0)
     {
      Print("CCompression_Scanner: 監視対象の通貨ペアまたは時間足が0件です");
      return(INIT_FAILED);
     }

   g_scanTotal = g_symbolCount * g_tfCount;
   ArrayResize(g_scan, g_scanTotal);

   ArrayResize(g_spikeUntil, g_scanTotal);
   ArrayResize(g_spikeUp,    g_scanTotal);
   ArrayResize(g_spikeRatio, g_scanTotal);
   ArrayResize(g_spikeZ,     g_scanTotal);
   ArrayResize(g_suppressed, g_scanTotal);
   ArrayResize(g_spikeWasDetected, g_scanTotal);
   ArrayResize(g_verification, g_scanTotal);
   ArrayResize(g_transitionHoldRemaining, g_scanTotal);
   for(int k = 0; k < g_scanTotal; k++)
     {
      g_spikeUntil[k] = 0;
      g_spikeUp[k]    = false;
      g_spikeRatio[k] = 0.0;
      g_spikeZ[k]     = 0.0;
      g_suppressed[k] = false;
      g_spikeWasDetected[k] = false;
      g_transitionHoldRemaining[k] = 0;
      g_verification[k].active = false;
      g_verification[k].startTime = 0;
      g_verification[k].startPrice = 0.0;
      g_verification[k].maxHigh = 0.0;
      g_verification[k].minLow = 0.0;
      g_verification[k].barsElapsed = 0;
      g_verification[k].startScore = 0;
     }

   for(int si = 0; si < g_symbolCount; si++)
      for(int ti = 0; ti < g_tfCount; ti++)
        {
         int idx = si * g_tfCount + ti;
         if(!CCOMP_InitInstance(g_scan[idx], g_symbols[si], g_tfList[ti]))
            PrintFormat("初期化失敗: %s %s", g_symbols[si], EnumToString(g_tfList[ti]));
        }

   LoadSpikeStates();   // チャート切替で読み込み直された場合に急変状態を引き継ぐ
   LoadTransitionHoldStates(); // チャート切替後もTRANSITION表示の残り本数を引き継ぐ
   VerificationLogOpen();
   VerificationLoadEvents(); // チャート切替後も計測中のTRANSITION検証を引き継ぐ

   EventSetTimer(MathMax(1, RefreshSeconds));
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   for(int i = 0; i < g_scanTotal; i++)
      CCOMP_ReleaseInstance(g_scan[i]);
   if(g_verificationLog != INVALID_HANDLE)
     {
      FileFlush(g_verificationLog);
      FileClose(g_verificationLog);
      g_verificationLog = INVALID_HANDLE;
     }
   ObjectsDeleteAll(0, "CCOMP_Scan_");
   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
//| 表示対象とすべき状態かどうかを入力設定に従って判定                 |
//+------------------------------------------------------------------+
bool ShouldDisplay(const CCOMP_STATE st)
  {
   if(st == CCOMP_NORMAL) return false;
   if(st == CCOMP_TRANSITION) return ShowTransition;
   if(ShowOnlyStrongOrAbove)
      return (st == CCOMP_STRONG_COMPRESSION || st == CCOMP_TIGHT_COMPRESSION);
   return ShowCompression; // COMPRESSION / STRONG / TIGHT すべて含む
  }

//+------------------------------------------------------------------+
//| 行の表示用ラベルを作成/更新                                        |
//+------------------------------------------------------------------+
void DrawRow(const int r, const string text, const color clr)
  {
   string name = "CCOMP_Scan_Row_" + IntegerToString(r);
   if(ObjectFind(0, name) < 0)
     {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
      ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
     }
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, PanelX);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, PanelY + 18 + r * 14);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
  }

//+------------------------------------------------------------------+
//| 全インスタンス更新 → フィルタ・ソート → 描画                      |
//+------------------------------------------------------------------+
void UpdateAndDraw()
  {
   for(int i = 0; i < g_scanTotal; i++)
     {
      CCOMP_STATE oldState = g_scan[i].state;
      bool wasReady = g_scan[i].ready;
      bool hadActiveTransition = g_verification[i].active;
      bool updated = CCOMP_UpdateInstance(g_scan[i]);
      if(updated)
        {
         datetime closedBarTime = g_scan[i].lastBarTime;

         // TRANSITIONは判定自体を変えず、一覧上の見落としを防ぐため表示だけ数本保持する。
         if(g_scan[i].state == CCOMP_TRANSITION)
            g_transitionHoldRemaining[i] = MathMax(1, InpTransitionDisplayHoldBars);
         else if(g_transitionHoldRemaining[i] > 0)
            g_transitionHoldRemaining[i]--;
         SaveTransitionHoldState(i);

         // 計測中のイベントは新しい確定足ごとに値幅を更新
         if(hadActiveTransition)
            VerificationUpdateTransition(i);

         if(InpEnableVerificationLog && InpLogStateChanges && wasReady &&
            oldState != g_scan[i].state)
            VerificationLogStateChange(i, oldState, g_scan[i].state, closedBarTime);

         if(g_scan[i].state == CCOMP_TRANSITION && oldState != CCOMP_TRANSITION)
           {
            if(g_verification[i].active && g_verification[i].startTime != closedBarTime)
               VerificationLogTransitionFinish(i, "次のTRANSITIONが発生");
            if(InpEnableVerificationLog && !g_verification[i].active)
               VerificationLogTransitionStart(i, closedBarTime);
           }
        }
     }

   //--- 急変検知(圧縮中の行が対象。SpikeShowAlways=trueなら全行) ---
   datetime nowT = TimeCurrent();
   if(UseSpikeOverride)
     {
      for(int i = 0; i < g_scanTotal; i++)
        {
         if(!g_scan[i].ready) continue;

         // 圧縮が一度NORMALに戻ったら抑制を解除(次に圧縮が再形成されたら再び表示する)
         if(g_suppressed[i] && g_scan[i].state == CCOMP_NORMAL)
           {
            g_suppressed[i] = false;
            SaveSuppressed(i, false);
           }

         if(g_scan[i].state == CCOMP_NORMAL && !SpikeShowAlways) continue;

         bool isSp, isUp;
         double ratio, z;
         if(!SMD_CheckSpike(g_scan[i].symbol, g_scan[i].tf, g_scan[i].atrHandle, isSp, isUp, ratio, z))
            continue;

         if(isSp && !g_spikeWasDetected[i])
           {
            if(InpEnableVerificationLog)
               VerificationLogSpike(i, TimeCurrent(), isUp, ratio, z);
            g_spikeWasDetected[i] = true;
           }
         else if(!isSp)
            g_spikeWasDetected[i] = false;

         if(isSp)
           {
            g_spikeUntil[i] = nowT + SpikeHoldBars * PeriodSeconds(g_scan[i].tf);
            g_spikeUp[i]    = isUp;
            g_spikeRatio[i] = ratio;
            g_spikeZ[i]     = z;
            // 圧縮中だった行は、急変で圧縮表示を解除(NORMALに戻るまで圧縮としては出さない)
            SaveSpikeState(i);
            if(g_scan[i].state != CCOMP_NORMAL)
              {
               g_suppressed[i] = true;
               SaveSuppressed(i, true);
              }
           }
        }
     }

   //--- フィルタして対象indexと優先度キーを収集 ---
   int    candIdx[];
   double candKey[];
   int    candKind[];   // 0=圧縮表示 / 1=急変表示
   ArrayResize(candIdx, g_scanTotal);
   ArrayResize(candKey, g_scanTotal);
   ArrayResize(candKind, g_scanTotal);
   int n = 0;
   int nSpike = 0;
   for(int i = 0; i < g_scanTotal; i++)
     {
      if(!g_scan[i].ready) continue;

      // 急変表示(最優先)。保持期間中は圧縮表示の代わりにこちらを出す
      if(UseSpikeOverride && nowT < g_spikeUntil[i])
        {
         candIdx[n]  = i;
         candKind[n] = 1;
         candKey[n]  = 200.0 + MathMin(g_spikeRatio[i], 50.0);
         n++;
         nSpike++;
         continue;
        }

      // 急変で圧縮表示を解除された行は、圧縮がNORMALに戻るまで出さない
      if(UseSpikeOverride && g_suppressed[i]) continue;

      CCOMP_STATE rowState = DisplayStateForRow(i);
      if(!ShouldDisplay(rowState)) continue;
      candIdx[n]  = i;
      candKind[n] = 0;
      // TRANSITIONは圧縮表示の中で最優先、それ以外はScoreの高い順
      candKey[n]  = (rowState == CCOMP_TRANSITION) ? (100.0 + g_scan[i].score) : (double)g_scan[i].score;
      n++;
     }

   //--- 優先度キー降順にソート(単純選択ソート。件数は多くても数百件程度なので十分) ---
   for(int a = 0; a < n - 1; a++)
     {
      int best = a;
      for(int b = a + 1; b < n; b++)
        {
         if(candKey[b] > candKey[best])
            best = b;
         else if(candKey[b] == candKey[best])
           {
            // 同順位なら短い時間足を上段に、時間足も同じなら通貨ペア名順
            int pb = PeriodSeconds(g_scan[candIdx[b]].tf);
            int pBest = PeriodSeconds(g_scan[candIdx[best]].tf);
            if(pb < pBest)
               best = b;
            else if(pb == pBest && g_scan[candIdx[b]].symbol < g_scan[candIdx[best]].symbol)
               best = b;
           }
        }
      if(best != a)
        {
         double tk = candKey[a];  candKey[a]  = candKey[best];  candKey[best]  = tk;
         int    ti = candIdx[a];  candIdx[a]  = candIdx[best];  candIdx[best]  = ti;
         int    tn = candKind[a]; candKind[a] = candKind[best]; candKind[best] = tn;
        }
     }

   int shown = MathMin(n, MaxRows);

   //--- タイトル行 ---
   string title = StringFormat("CCompression Scanner  (圧縮%d件 急変%d件 / 全%d組)", n - nSpike, nSpike, g_scanTotal);
   {
      string tname = "CCOMP_Scan_Title";
      if(ObjectFind(0, tname) < 0)
        {
         ObjectCreate(0, tname, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, tname, OBJPROP_FONTSIZE, 10);
         ObjectSetString(0, tname, OBJPROP_FONT, "Consolas");
         ObjectSetInteger(0, tname, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, tname, OBJPROP_BACK, false);
         ObjectSetInteger(0, tname, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, tname, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
        }
      ObjectSetInteger(0, tname, OBJPROP_XDISTANCE, PanelX);
      ObjectSetInteger(0, tname, OBJPROP_YDISTANCE, PanelY);
      ObjectSetString(0, tname, OBJPROP_TEXT, title);
      ObjectSetInteger(0, tname, OBJPROP_COLOR, clrWhite);
   }
   //--- 既存行を一旦全削除してから再構築(件数が増減するため) ---
   ObjectsDeleteAll(0, "CCOMP_Scan_Row_");
   ArrayResize(g_rowSymbol, shown);
   ArrayResize(g_rowTF, shown);
   g_rowCount = shown;

   for(int r = 0; r < shown; r++)
     {
      int idx = candIdx[r];
      CCOMP_Instance inst = g_scan[idx];

      string tfName = EnumToString(inst.tf);
      StringReplace(tfName, "PERIOD_", "");

      string line;
      color  rowClr;
      if(candKind[r] == 1)
        {
         // 急変表示: 圧縮表示の代わりに方向つきで表示する
         line = StringFormat("%-9s %-4s %-20s ATR比%.1f Z%+.1f",
            inst.symbol, tfName, g_spikeUp[idx] ? "急変 ↑ (上昇)" : "急変 ↓ (下落)",
            g_spikeRatio[idx], g_spikeZ[idx]);
         rowClr = g_spikeUp[idx] ? SpikeUpColor : SpikeDownColor;
        }
      else
        {
         CCOMP_STATE rowState = DisplayStateForRow(idx);
         string stateLabel = CCOMP_StateText(rowState);
         if(rowState == CCOMP_TRANSITION && inst.state != CCOMP_TRANSITION)
            stateLabel = "TRANSITION*"; // * = 表示保持中（判定そのものは終了）
         line = StringFormat("%-9s %-4s %-20s Sc%d Δ%+d Age%d",
            inst.symbol, tfName, stateLabel, inst.score, inst.delta, inst.age);
         rowClr = CCOMP_StateColor(rowState);
        }

      DrawRow(r, line, rowClr);

      g_rowSymbol[r] = inst.symbol;
      g_rowTF[r]     = inst.tf;
     }

   if(n > shown)
     {
      string moreName = "CCOMP_Scan_More";
      if(ObjectFind(0, moreName) < 0)
        {
         ObjectCreate(0, moreName, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, moreName, OBJPROP_FONTSIZE, 9);
         ObjectSetString(0, moreName, OBJPROP_FONT, "Consolas");
         ObjectSetInteger(0, moreName, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, moreName, OBJPROP_BACK, false);
         ObjectSetInteger(0, moreName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, moreName, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
        }
      ObjectSetInteger(0, moreName, OBJPROP_XDISTANCE, PanelX);
      ObjectSetInteger(0, moreName, OBJPROP_YDISTANCE, PanelY + 18 + shown * 14);
      ObjectSetString(0, moreName, OBJPROP_TEXT, StringFormat("...他 %d件", n - shown));
      ObjectSetInteger(0, moreName, OBJPROP_COLOR, clrGray);
     }
   else
      ObjectDelete(0, "CCOMP_Scan_More");

   DrawDetailPanel();

   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int prev_calculated,
                 const datetime &time[], const double &open[], const double &high[],
                 const double &low[], const double &close[],
                 const long &tick_volume[], const long &volume[], const int &spread[])
  {
   UpdateAndDraw();
   return(rates_total);
  }

//+------------------------------------------------------------------+
void OnTimer()
  {
   UpdateAndDraw();
  }

//+------------------------------------------------------------------+
//| 行クリックでその通貨ペア・時間足にチャートを切り替える             |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
  {
   if(id != CHARTEVENT_OBJECT_CLICK) return;

   string prefix = "CCOMP_Scan_Row_";
   if(StringFind(sparam, prefix) != 0) return;

   string idxStr = StringSubstr(sparam, StringLen(prefix));
   int r = (int)StringToInteger(idxStr);
   if(r < 0 || r >= g_rowCount) return;

   string sym          = g_rowSymbol[r];
   ENUM_TIMEFRAMES tf   = g_rowTF[r];

   if(OpenInNewChart)
     {
      long newChartId = ChartOpen(sym, tf);
      if(newChartId == 0) Print("チャートを開けませんでした: ", sym);
     }
   else
     {
      bool ok = ChartSetSymbolPeriod(0, sym, tf);
      if(!ok) Print("通貨ペア/時間足の切り替えに失敗しました: ", sym, " ", EnumToString(tf));
     }
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| 解説パネル                                                         |
//| チャートに表示中の(通貨ペア, 時間足)について、各指標の状態を       |
//| 日本語で解説する。行クリックで切り替えた直後もこの内容が表示される  |
//+------------------------------------------------------------------+
string GetATRExplanation(const int score)
  {
   if(score >= 2) return("1本の値動き：かなり小さい");
   if(score == 1) return("1本の値動き：やや小さい");
   return("1本の値動き：通常～大きめ");
  }

string GetBBExplanation(const int score)
  {
   if(score >= 2) return("価格の広がり：かなり狭い");
   if(score == 1) return("価格の広がり：やや狭い");
   return("価格の広がり：通常～大きい");
  }

string GetRangeExplanation(const int score)
  {
   if(score >= 2) return("20期間の活動範囲：かなり狭い");
   if(score == 1) return("20期間の活動範囲：やや狭い");
   return("20期間の活動範囲：通常～大きい");
  }

string GetADXExplanation(const int score)
  {
   if(score >= 2) return("トレンド強度：弱い");
   if(score == 1) return("トレンド強度：やや弱い");
   return("トレンド強度：強め");
  }

string GetStateExplanation(const CCOMP_STATE st)
  {
   switch(st)
     {
      case CCOMP_NORMAL:             return("通常の値動きです。圧縮は見られません");
      case CCOMP_COMPRESSION:        return("値動きが縮み始めています（弱い圧縮）");
      case CCOMP_STRONG_COMPRESSION: return("値動きがかなり縮んでいます（強い圧縮）");
      case CCOMP_TIGHT_COMPRESSION:  return("値動きが極めて縮んでいます（非常に強い圧縮）");
      case CCOMP_TRANSITION:         return("強い圧縮から値幅が広がり始めました（方向は不明）");
     }
   return("");
  }

string GetDeltaExplanation(const int delta)
  {
   if(delta > 0) return("前回よりScoreが上がり、圧縮が強まっています");
   if(delta < 0) return("前回よりScoreが下がり、圧縮が弱まっています");
   return("前回からScoreの変化はありません");
  }

int g_detailLineCount = 0;   // 前回描画した解説行数(余った行を消すため)

//--- 解説1行を描画。j=上から何行目か、total=全行数
void SetDetailLine(const int j, const int total, const string text, const color clr)
  {
   string name = "CCOMP_Scan_Detail_" + IntegerToString(j);
   bool lower = (DetailCorner == CORNER_LEFT_LOWER  || DetailCorner == CORNER_RIGHT_LOWER);
   bool right = (DetailCorner == CORNER_RIGHT_UPPER || DetailCorner == CORNER_RIGHT_LOWER);

   if(ObjectFind(0, name) < 0)
     {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
      ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
     }

   ENUM_ANCHOR_POINT anchor;
   if(lower) anchor = right ? ANCHOR_RIGHT_LOWER : ANCHOR_LEFT_LOWER;
   else      anchor = right ? ANCHOR_RIGHT_UPPER : ANCHOR_LEFT_UPPER;

   int lineH = 16;
   int y = lower ? DetailY + (total - 1 - j) * lineH : DetailY + j * lineH;

   ObjectSetInteger(0, name, OBJPROP_CORNER, DetailCorner);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, anchor);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, DetailX);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
  }

void DrawDetailPanel()
  {
   if(!ShowDetailPanel)
     {
      ObjectsDeleteAll(0, "CCOMP_Scan_Detail_");
      g_detailLineCount = 0;
      return;
     }

   string lines[16];
   color  clrs[16];
   int    L = 0;

   ENUM_TIMEFRAMES curTF = (ENUM_TIMEFRAMES)_Period;
   string tfName = EnumToString(curTF);
   StringReplace(tfName, "PERIOD_", "");

   int idx = -1;
   for(int i = 0; i < g_scanTotal; i++)
      if(g_scan[i].symbol == _Symbol && g_scan[i].tf == curTF) { idx = i; break; }

   if(idx < 0)
     {
      lines[L] = StringFormat("【解説】%s %s は監視対象外です（時間足の選択ONを確認してください）", _Symbol, tfName);
      clrs[L]  = clrGray; L++;
     }
   else if(!g_scan[idx].ready)
     {
      lines[L] = StringFormat("【解説】%s %s 計算中...", _Symbol, tfName);
      clrs[L]  = clrGray; L++;
     }
   else
     {
      CCOMP_Instance inst = g_scan[idx];
      color base = clrSilver;

      lines[L] = StringFormat("【解説】%s %s   状態: %s   Score %d/8",
                              inst.symbol, tfName, CCOMP_StateText(inst.state), inst.score);
      clrs[L]  = CCOMP_StateColor(inst.state); L++;

      lines[L] = "  " + GetStateExplanation(inst.state);
      clrs[L]  = base; L++;

      lines[L] = StringFormat("  ATR    %d/2  %s  (ATR%% %.3f / 過去%d本中 下位%.0f%%)",
                              inst.atrScore, GetATRExplanation(inst.atrScore),
                              inst.atrPct, inst.lookback, inst.atrPctile);
      clrs[L]  = base; L++;

      lines[L] = StringFormat("  BB幅   %d/2  %s  (BB幅%% %.3f / 過去%d本中 下位%.0f%%)",
                              inst.bbScore, GetBBExplanation(inst.bbScore),
                              inst.bbWidthPct, inst.lookback, inst.bbPctile);
      clrs[L]  = base; L++;

      lines[L] = StringFormat("  Range  %d/2  %s  (Range%% %.3f / 過去%d本中 下位%.0f%%)",
                              inst.rangeScore, GetRangeExplanation(inst.rangeScore),
                              inst.range20Pct, inst.lookback, inst.rangePctile);
      clrs[L]  = base; L++;

      lines[L] = StringFormat("  ADX    %d/2  %s  (ADX %.1f)",
                              inst.adxScore, GetADXExplanation(inst.adxScore), inst.adxValue);
      clrs[L]  = base; L++;

      lines[L] = StringFormat("  Delta %+d : %s", inst.delta, GetDeltaExplanation(inst.delta));
      clrs[L]  = base; L++;

      lines[L] = StringFormat("  Age %d : 同じ状態が%d本続いています（%s足の確定足ベース）",
                              inst.age, inst.age, tfName);
      clrs[L]  = base; L++;

      // 急変との連携状況
      if(UseSpikeOverride && TimeCurrent() < g_spikeUntil[idx])
        {
         lines[L] = StringFormat("  急変検知中: %s  ATR比%.1f Z%+.1f  （一覧では圧縮表示を解除し急変として表示）",
                                 g_spikeUp[idx] ? "上昇" : "下落", g_spikeRatio[idx], g_spikeZ[idx]);
         clrs[L]  = g_spikeUp[idx] ? SpikeUpColor : SpikeDownColor; L++;
        }
      else if(UseSpikeOverride && g_suppressed[idx])
        {
         lines[L] = "  急変により圧縮表示を解除中（圧縮がNORMALに戻るまで一覧には出ません）";
         clrs[L]  = clrGray; L++;
        }
     }

   for(int j = 0; j < L; j++)
      SetDetailLine(j, L, lines[j], clrs[j]);

   // 前回より行数が減った場合、余った行を消す
   for(int j = L; j < g_detailLineCount; j++)
      ObjectDelete(0, "CCOMP_Scan_Detail_" + IntegerToString(j));
   g_detailLineCount = L;
  }
//+------------------------------------------------------------------+
