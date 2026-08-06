//+------------------------------------------------------------------+
//|                                                 AnomalyEngine.mqh |
//|                        Global Market Dashboard Ultimate (GMD)      |
//|                                                                    |
//|  役割 : 暦から決まる統計的な偏りを点数化する                      |
//|  依存 : Types.mqh, Logger.mqh, Utils.mqh                           |
//|  仕様 : Project Specification v1.4 第10章                          |
//|                                                                    |
//|  このエンジンは価格を一切見ない。                                  |
//|  見るのは日付と時刻だけ。だから他のエンジンと完全に独立していて、  |
//|  ブローカーに銘柄が無くても必ず動く。                              |
//|                                                                    |
//|  設計上の約束                                                      |
//|    1. 規則は表（m_rules）で持つ。判定を if の羅列にしない          |
//|    2. 規則は必ず適用範囲（scope）を持つ。                          |
//|       Sell in May は株の話であって、USDJPY に足してはいけない      |
//|    3. 合計は ±GMD_ANOMALY_CAP で打ち止める。                       |
//|       アノマリーは足せば足すほど当たるものではない                 |
//|    4. 根拠の弱い規則は既定で無効。星3以下は自分でONにする          |
//+------------------------------------------------------------------+
#property strict

#ifndef __GMD_ANOMALYENGINE_MQH__
#define __GMD_ANOMALYENGINE_MQH__

#include "../Core/Types.mqh"
#include "../Core/Logger.mqh"
#include "../Core/Utils.mqh"

//+------------------------------------------------------------------+
class CAnomalyEngine : public IEngine
  {
private:
   CLogger         *m_log;

   //--- 規則表
   SAnomalyRule     m_rules[GMD_ANOMALY_MAX];
   int              m_ruleCount;

   //--- 判定結果
   SAnomalyHit      m_hits[GMD_ANOMALY_MAX];
   int              m_hitCount;

   //--- 設定
   int              m_serverGmtOffset;   // サーバ時刻とGMTの差（時間）
   int              m_minStars;          // この星数未満は無効にする
   bool             m_useSeason;         // 月別季節性を使うか
   int              m_seasonTable[13];   // [1..12] 月別スコア

   //--- 集計結果（scope別）
   int              m_scopeScore[7];     // ENUM_ANOMALY_SCOPE をそのまま添字に使う
   ENUM_SEASON_STATE m_season;
   bool             m_ready;

   //--- 内部
   void             AddRule(const string code, const string label,
                            const ENUM_ANOMALY_SCOPE scope,
                            const int score, const int stars,
                            const bool implemented = true);
   void             BuildRuleTable(void);
   int              FindRule(const string code);
   void             Hit(const int ruleIndex);

   datetime         CalcTokyoTime(void);
   bool             DetectGotobi(const MqlDateTime &tokyo);
   bool             DetectMonthEnd(const MqlDateTime &t);
   bool             DetectQuarterEnd(const MqlDateTime &t);
   bool             DetectTurnOfMonth(const MqlDateTime &t);
   bool             DetectSantaRally(const MqlDateTime &t);
   bool             DetectYearEnd(const MqlDateTime &t);
   bool             DetectYearStart(const MqlDateTime &t);
   int              CalcDaysInMonth(const int year, const int month);

public:
                     CAnomalyEngine(void);
                    ~CAnomalyEngine(void);

   bool              Init(CLogger *logger,
                          const int serverGmtOffset = 3,
                          const int minStars = 4,
                          const bool useSeason = true);

   void              SetRuleEnabled(const string code, const bool enabled);
   void              SetSeasonScore(const int month, const int score);

   //--- IEngine
   bool              Calculate(void);
   bool              IsReady(void) { return(m_ready); }
   string            GetName(void) { return("Anomaly"); }

   //--- 参照
   int               GetScore(const ENUM_ANOMALY_SCOPE scope);
   int               GetRawScore(const ENUM_ANOMALY_SCOPE scope);
   int               GetHitCount(void) { return(m_hitCount); }
   string            GetHitLabel(const int index);
   int               GetHitScore(const int index);
   ENUM_SEASON_STATE GetSeason(void) { return(m_season); }
   int               GetSeasonScore(void);

   //--- リスク志向バイアス（仕様書10.13）
   //    株の季節性から「リスクを取りやすい季節か」だけを導く。
   //    FXのスコアには足さない。MarketRegime[2.20]が入力の1つとして読む
   int               GetRiskBiasScore(void);
   ENUM_RISK_BIAS    GetRiskBias(void);
   string            GetRiskBiasText(void);
   int               GetRuleCount(void) { return(m_ruleCount); }

   string            GetDisplayText(const ENUM_ANOMALY_SCOPE scope = SCOPE_FX);
   string            BuildDetailText(const ENUM_ANOMALY_SCOPE scope = SCOPE_FX);
   color             GetColor(const ENUM_ANOMALY_SCOPE scope = SCOPE_FX);
  };

//+------------------------------------------------------------------+
CAnomalyEngine::CAnomalyEngine(void) : m_log(NULL),
                                       m_ruleCount(0),
                                       m_hitCount(0),
                                       m_serverGmtOffset(3),
                                       m_minStars(4),
                                       m_useSeason(true),
                                       m_season(SEASON_NEUTRAL),
                                       m_ready(false)
  {
   ArrayInitialize(m_scopeScore, 0);
   ArrayInitialize(m_seasonTable, 0);
  }

//+------------------------------------------------------------------+
CAnomalyEngine::~CAnomalyEngine(void)
  {
  }

//+------------------------------------------------------------------+
//| 初期化                                                            |
//|  serverGmtOffset : ブローカーのサーバ時刻がGMT+いくつか。         |
//|                    五十日は東京時間で判定するため、これが要る。   |
//|                    多くの業者は夏時間GMT+3 / 冬時間GMT+2。        |
//+------------------------------------------------------------------+
bool CAnomalyEngine::Init(CLogger *logger,
                          const int serverGmtOffset,
                          const int minStars,
                          const bool useSeason)
  {
   m_log             = logger;
   m_serverGmtOffset = serverGmtOffset;
   m_minStars        = minStars;
   m_useSeason       = useSeason;
   m_ready           = false;

   BuildRuleTable();

   //--- 月別季節性の既定値
   //    これは株価指数の季節性。FXにそのまま当てるべきではないので
   //    scope は SCOPE_EQUITY として扱う
   m_seasonTable[1]  = +1;   // January Effect
   m_seasonTable[2]  = +1;
   m_seasonTable[3]  =  0;
   m_seasonTable[4]  =  0;
   m_seasonTable[5]  = -1;   // Sell in May の入口
   m_seasonTable[6]  =  0;
   m_seasonTable[7]  =  0;
   m_seasonTable[8]  = -2;   // 夏枯れ。流動性が薄い
   m_seasonTable[9]  = -2;   // 統計上いちばん弱い月
   m_seasonTable[10] =  0;
   m_seasonTable[11] = +2;   // Halloween Effect の入口
   m_seasonTable[12] = +2;

   if(m_log != NULL)
      m_log.Info(StringFormat("Anomaly: %d rules loaded. minStars=%d, GMT%+d",
                              m_ruleCount, m_minStars, m_serverGmtOffset));

   return(true);
  }

//+------------------------------------------------------------------+
//| 規則表の構築                                                      |
//|  ここが唯一の「アノマリー一覧」。追加はこの関数に1行足すだけ。    |
//|                                                                   |
//|  implemented=false のものは判定処理がまだ無い予約枠。             |
//|  経済カレンダー系は MQL5 の CalendarValueHistory が業者依存で     |
//|  使えない環境があるため、Ver2.20 に回している。                   |
//+------------------------------------------------------------------+
void CAnomalyEngine::BuildRuleTable(void)
  {
   m_ruleCount = 0;

   //--- FX / 円 ------------------------------------------------------
   AddRule("GOTOBI",      "五十日",            SCOPE_JPY,     3, 5);
   AddRule("MONTH_END",   "月末",              SCOPE_FX,      2, 5);
   AddRule("QUARTER_END", "四半期末",          SCOPE_FX,      3, 5);
   AddRule("YEAR_END",    "年末（流動性低下）", SCOPE_FX,     -2, 5);
   AddRule("YEAR_START",  "年始",              SCOPE_FX,      2, 5);

   //--- 株価指数 ----------------------------------------------------
   AddRule("HALLOWEEN",   "Halloween Effect",  SCOPE_EQUITY,  3, 5);
   AddRule("SELL_IN_MAY", "Sell in May",       SCOPE_EQUITY, -3, 5);
   AddRule("TURN_MONTH",  "Turn of the Month", SCOPE_EQUITY,  2, 5);
   AddRule("SANTA",       "Santa Claus Rally", SCOPE_EQUITY,  3, 5);
   AddRule("JANUARY",     "January Effect",    SCOPE_EQUITY,  2, 4);

   //--- 曜日効果（根拠が弱い。既定では minStars で落ちる）----------
   AddRule("MONDAY",      "Monday Effect",     SCOPE_EQUITY, -1, 3);
   AddRule("FRIDAY",      "Friday Effect",     SCOPE_EQUITY,  1, 3);

   //--- 暗号資産 ----------------------------------------------------
   AddRule("WEEKEND_BTC", "Weekend Effect",    SCOPE_CRYPTO, -1, 3);

   //--- [2.20] 予約枠：経済カレンダーが必要なもの -------------------
   AddRule("PRE_FOMC",    "FOMC前",            SCOPE_BOND,    2, 4, false);
   AddRule("PRE_CPI",     "CPI前",             SCOPE_BOND,   -2, 4, false);
   AddRule("PRE_NFP",     "雇用統計前",        SCOPE_BOND,   -3, 5, false);
   AddRule("PRE_HOLIDAY", "連休前",            SCOPE_FX,     -2, 4, false);

   //--- [2.20] 予約枠：Money Flow の結果が必要なもの ---------------
   AddRule("VIX_SPIKE",   "VIX急騰→金",       SCOPE_METAL,   3, 4, false);
  }

//+------------------------------------------------------------------+
void CAnomalyEngine::AddRule(const string code, const string label,
                             const ENUM_ANOMALY_SCOPE scope,
                             const int score, const int stars,
                             const bool implemented)
  {
   if(m_ruleCount >= GMD_ANOMALY_MAX)
     {
      if(m_log != NULL)
         m_log.Warn("AN-701", "Anomaly rule table is full. " + code + " skipped.");
      return;
     }

   m_rules[m_ruleCount].code        = code;
   m_rules[m_ruleCount].label       = label;
   m_rules[m_ruleCount].scope       = scope;
   m_rules[m_ruleCount].score       = score;
   m_rules[m_ruleCount].stars       = stars;
   m_rules[m_ruleCount].enabled     = true;
   m_rules[m_ruleCount].implemented = implemented;

   m_ruleCount++;
  }

//+------------------------------------------------------------------+
int CAnomalyEngine::FindRule(const string code)
  {
   for(int i = 0; i < m_ruleCount; i++)
      if(m_rules[i].code == code)
         return(i);
   return(-1);
  }

//+------------------------------------------------------------------+
void CAnomalyEngine::SetRuleEnabled(const string code, const bool enabled)
  {
   const int i = FindRule(code);

   if(i < 0)
     {
      if(m_log != NULL)
         m_log.Warn("AN-702", "Unknown anomaly code: " + code);
      return;
     }

   m_rules[i].enabled = enabled;
  }

//+------------------------------------------------------------------+
void CAnomalyEngine::SetSeasonScore(const int month, const int score)
  {
   if(month < 1 || month > 12)
      return;

   m_seasonTable[month] = score;
  }

//+------------------------------------------------------------------+
//| 該当した規則を記録する                                            |
//+------------------------------------------------------------------+
void CAnomalyEngine::Hit(const int ruleIndex)
  {
   if(ruleIndex < 0 || ruleIndex >= m_ruleCount)
      return;

   //--- 無効・未実装・星不足は素通し
   if(!m_rules[ruleIndex].enabled)
      return;
   if(!m_rules[ruleIndex].implemented)
      return;
   if(m_rules[ruleIndex].stars < m_minStars)
      return;

   if(m_hitCount >= GMD_ANOMALY_MAX)
      return;

   m_hits[m_hitCount].code  = m_rules[ruleIndex].code;
   m_hits[m_hitCount].label = m_rules[ruleIndex].label;
   m_hits[m_hitCount].score = m_rules[ruleIndex].score;
   m_hits[m_hitCount].scope = m_rules[ruleIndex].scope;
   m_hitCount++;

   const int s = (int)m_rules[ruleIndex].scope;

   if(s >= 0 && s < 7)
      m_scopeScore[s] += m_rules[ruleIndex].score;
  }

//+------------------------------------------------------------------+
//| 東京時間を求める                                                  |
//|  サーバ時刻からGMTに戻し、そこへ+9時間する。                      |
//|  TimeGMT() を使わないのは、バックテスト中に実時間が返るため。     |
//+------------------------------------------------------------------+
datetime CAnomalyEngine::CalcTokyoTime(void)
  {
   return(TimeCurrent() - (datetime)(m_serverGmtOffset * 3600) + (datetime)(9 * 3600));
  }

//+------------------------------------------------------------------+
int CAnomalyEngine::CalcDaysInMonth(const int year, const int month)
  {
   const int days[13] = {0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31};

   if(month < 1 || month > 12)
      return(30);

   if(month == 2)
     {
      const bool leap = ((year % 4 == 0 && year % 100 != 0) || year % 400 == 0);
      return(leap ? 29 : 28);
     }

   return(days[month]);
  }

//+------------------------------------------------------------------+
//| 五十日                                                            |
//|  日本企業の決済日。仲値（東京9:55）付近でUSDJPYが動きやすい。     |
//|                                                                   |
//|  実装で気をつけた点                                               |
//|    ・東京時間で判定する。サーバ時刻の日付では1日ずれる            |
//|    ・土日にあたる場合は前営業日（金曜）へ繰り上げる               |
//|    ・仲値を過ぎたら効果は終わる。終日加点しない                   |
//|      東京 8:00〜10:30 の間だけ有効とした                          |
//+------------------------------------------------------------------+
bool CAnomalyEngine::DetectGotobi(const MqlDateTime &tokyo)
  {
   //--- 時間帯の門番。仲値の前後だけ
   const int minutes = tokyo.hour * 60 + tokyo.min;

   if(minutes < 8 * 60 || minutes > 10 * 60 + 30)
      return(false);

   const int day     = tokyo.day;
   const int lastDay = CalcDaysInMonth(tokyo.year, tokyo.mon);

   //--- 当日が5の倍数、または月末
   bool isTarget = (day % 5 == 0) || (day == lastDay);

   //--- 土日なら前営業日へ繰り上がる
   //    金曜なら 土(+1) 日(+2) が五十日かどうかも見る
   if(!isTarget && tokyo.day_of_week == 5)
     {
      for(int add = 1; add <= 2; add++)
        {
         const int d = day + add;

         if(d > lastDay)
            break;                       // 月をまたぐ分は簡略化して見ない

         if(d % 5 == 0 || d == lastDay)
           {
            isTarget = true;
            break;
           }
        }
     }

   //--- 土日そのものは決済が無い
   if(tokyo.day_of_week == 0 || tokyo.day_of_week == 6)
      return(false);

   return(isTarget);
  }

//+------------------------------------------------------------------+
bool CAnomalyEngine::DetectMonthEnd(const MqlDateTime &t)
  {
   const int lastDay = CalcDaysInMonth(t.year, t.mon);
   return(t.day >= lastDay - 1);          // 月末2営業日相当
  }

//+------------------------------------------------------------------+
bool CAnomalyEngine::DetectQuarterEnd(const MqlDateTime &t)
  {
   const bool quarterMonth = (t.mon == 3 || t.mon == 6 || t.mon == 9 || t.mon == 12);
   return(quarterMonth && DetectMonthEnd(t));
  }

//+------------------------------------------------------------------+
//| Turn of the Month : 月末3営業日〜月初3営業日                       |
//+------------------------------------------------------------------+
bool CAnomalyEngine::DetectTurnOfMonth(const MqlDateTime &t)
  {
   const int lastDay = CalcDaysInMonth(t.year, t.mon);
   return(t.day <= 3 || t.day >= lastDay - 2);
  }

//+------------------------------------------------------------------+
//| Santa Claus Rally : 12月最終5営業日〜1月最初2営業日                |
//|  暦日で近似する（12/24以降、または1/1〜1/3）                      |
//+------------------------------------------------------------------+
bool CAnomalyEngine::DetectSantaRally(const MqlDateTime &t)
  {
   if(t.mon == 12 && t.day >= 24)
      return(true);
   if(t.mon == 1 && t.day <= 3)
      return(true);
   return(false);
  }

//+------------------------------------------------------------------+
bool CAnomalyEngine::DetectYearEnd(const MqlDateTime &t)
  {
   return(t.mon == 12 && t.day >= 25);
  }

//+------------------------------------------------------------------+
bool CAnomalyEngine::DetectYearStart(const MqlDateTime &t)
  {
   return(t.mon == 1 && t.day <= 7);
  }

//+------------------------------------------------------------------+
//| 計算                                                              |
//|  価格を読まないので必ず成功する。IsReady() は常に true になる。   |
//+------------------------------------------------------------------+
bool CAnomalyEngine::Calculate(void)
  {
   m_hitCount = 0;
   m_season   = SEASON_NEUTRAL;
   ArrayInitialize(m_scopeScore, 0);

   //--- サーバ時刻と東京時刻の両方を用意する
   MqlDateTime srv, tky;
   TimeToStruct(TimeCurrent(),     srv);
   TimeToStruct(CalcTokyoTime(),   tky);

   //--- FX / 円 ------------------------------------------------------
   if(DetectGotobi(tky))
      Hit(FindRule("GOTOBI"));

   if(DetectMonthEnd(srv))
      Hit(FindRule("MONTH_END"));

   if(DetectQuarterEnd(srv))
      Hit(FindRule("QUARTER_END"));

   if(DetectYearEnd(srv))
      Hit(FindRule("YEAR_END"));

   if(DetectYearStart(srv))
      Hit(FindRule("YEAR_START"));

   //--- 株価指数 ----------------------------------------------------
   //    Halloween と Sell in May は同じ現象の裏表なので、
   //    片方しか成立しない。両方足して打ち消すことはない
   if(srv.mon >= 11 || srv.mon <= 4)
      Hit(FindRule("HALLOWEEN"));
   else
      Hit(FindRule("SELL_IN_MAY"));

   if(DetectTurnOfMonth(srv))
      Hit(FindRule("TURN_MONTH"));

   if(DetectSantaRally(srv))
      Hit(FindRule("SANTA"));

   if(srv.mon == 1)
      Hit(FindRule("JANUARY"));

   if(srv.day_of_week == 1)
      Hit(FindRule("MONDAY"));

   if(srv.day_of_week == 5)
      Hit(FindRule("FRIDAY"));

   //--- 暗号資産 ----------------------------------------------------
   if(srv.day_of_week == 0 || srv.day_of_week == 6)
      Hit(FindRule("WEEKEND_BTC"));

   //--- 月別季節性（株価指数の枠に加算する）------------------------
   if(m_useSeason)
     {
      const int s = m_seasonTable[srv.mon];

      m_scopeScore[SCOPE_EQUITY] += s;

      if(s > 0)
         m_season = SEASON_BULL;
      else
         if(s < 0)
            m_season = SEASON_BEAR;
     }

   m_ready = true;
   return(true);
  }

//+------------------------------------------------------------------+
//| 打ち止め前の素点                                                  |
//+------------------------------------------------------------------+
int CAnomalyEngine::GetRawScore(const ENUM_ANOMALY_SCOPE scope)
  {
   const int s = (int)scope;

   if(s < 0 || s >= 7)
      return(0);

   int total = m_scopeScore[s];

   //--- SCOPE_JPY は FX の一部。円のペアを見るときは両方が乗る
   if(scope == SCOPE_JPY)
      total += m_scopeScore[SCOPE_FX];

   return(total);
  }

//+------------------------------------------------------------------+
//| 打ち止め後のスコア。これを外へ出す                                |
//|  アノマリーは重ねるほど効くものではない。上限で止める             |
//+------------------------------------------------------------------+
int CAnomalyEngine::GetScore(const ENUM_ANOMALY_SCOPE scope)
  {
   const int raw = GetRawScore(scope);

   if(raw >  GMD_ANOMALY_CAP)
      return(GMD_ANOMALY_CAP);
   if(raw < -GMD_ANOMALY_CAP)
      return(-GMD_ANOMALY_CAP);

   return(raw);
  }

//+------------------------------------------------------------------+
//| リスク志向バイアス                                                |
//|                                                                   |
//|  株が強い季節はリスクが取られやすく、金利差取引（キャリー）が     |
//|  乗りやすい。この関係自体は広く知られている。                     |
//|                                                                   |
//|  ただしこれは「株の季節性」→「リスク志向」→「特定通貨の需要」    |
//|  という二次・三次の推論である。仮定の上に仮定を積むため、         |
//|  次の3つの制限をかける。                                          |
//|                                                                   |
//|   1. 株のスコアを半分にする（推論を1段経ているため確度が下がる）  |
//|   2. 上限を ±5 に絞る（アノマリー本体の ±15 より狭い）            |
//|   3. 通貨ペアのスコアには一切足さない                             |
//|                                                                   |
//|  「どの通貨が買われるか」は言わない。高金利通貨の顔ぶれは         |
//|  政策金利の変化で入れ替わるが、このエンジンは金利を読まない。     |
//|  実際に買われている通貨は CurrencyStrength が価格から出している。 |
//|  ここが出すのは「季節としてリスクを取りやすいか」だけである。     |
//+------------------------------------------------------------------+
int CAnomalyEngine::GetRiskBiasScore(void)
  {
   if(!m_ready)
      return(0);

   const int equity = GetScore(SCOPE_EQUITY);

   //--- 半分にする。0方向へ丸める（-3 → -1, +3 → +1）
   int bias = equity / 2;

   if(bias >  GMD_RISK_BIAS_CAP)
      bias =  GMD_RISK_BIAS_CAP;
   if(bias < -GMD_RISK_BIAS_CAP)
      bias = -GMD_RISK_BIAS_CAP;

   return(bias);
  }

//+------------------------------------------------------------------+
ENUM_RISK_BIAS CAnomalyEngine::GetRiskBias(void)
  {
   const int bias = GetRiskBiasScore();

   //--- ±1 は誤差として扱う。2以上でようやく「傾き」と呼ぶ
   if(bias >=  2)
      return(RISK_BIAS_ON);
   if(bias <= -2)
      return(RISK_BIAS_OFF);

   return(RISK_BIAS_FLAT);
  }

//+------------------------------------------------------------------+
//| 表示用。「Season  Bull  (risk-on bias +2)」                        |
//+------------------------------------------------------------------+
string CAnomalyEngine::GetRiskBiasText(void)
  {
   if(!m_ready)
      return("Season  --");

   const ENUM_RISK_BIAS bias = GetRiskBias();

   if(bias == RISK_BIAS_FLAT)
      return(StringFormat("Season  %s  (%s)",
                          SeasonStateToString(m_season),
                          RiskBiasToString(bias)));

   return(StringFormat("Season  %s  (%s %s)",
                       SeasonStateToString(m_season),
                       RiskBiasToString(bias),
                       CalcSignedText(GetRiskBiasScore())));
  }

//+------------------------------------------------------------------+
int CAnomalyEngine::GetSeasonScore(void)
  {
   MqlDateTime t;
   TimeToStruct(TimeCurrent(), t);
   return(m_seasonTable[t.mon]);
  }

//+------------------------------------------------------------------+
string CAnomalyEngine::GetHitLabel(const int index)
  {
   if(index < 0 || index >= m_hitCount)
      return("");
   return(m_hits[index].label);
  }

//+------------------------------------------------------------------+
int CAnomalyEngine::GetHitScore(const int index)
  {
   if(index < 0 || index >= m_hitCount)
      return(0);
   return(m_hits[index].score);
  }

//+------------------------------------------------------------------+
//| "Anomaly  +5  (五十日, 月末)"                                     |
//+------------------------------------------------------------------+
string CAnomalyEngine::GetDisplayText(const ENUM_ANOMALY_SCOPE scope)
  {
   if(!m_ready)
      return("Anomaly  --");

   const int score = GetScore(scope);

   //--- 該当範囲のラベルだけ並べる
   string labels = "";
   int    shown  = 0;

   for(int i = 0; i < m_hitCount && shown < 2; i++)
     {
      const bool match = (m_hits[i].scope == scope) ||
                         (scope == SCOPE_JPY && m_hits[i].scope == SCOPE_FX);

      if(!match)
         continue;

      if(labels != "")
         labels += ", ";

      labels += m_hits[i].label;
      shown++;
     }

   if(labels == "")
      return("Anomaly   0");

   return(StringFormat("Anomaly %s  (%s)", CalcSignedText(score), labels));
  }

//+------------------------------------------------------------------+
//| ログ用の全件表示                                                  |
//+------------------------------------------------------------------+
string CAnomalyEngine::BuildDetailText(const ENUM_ANOMALY_SCOPE scope)
  {
   string out = StringFormat("Anomaly [%s] score=%s (raw=%s, cap=%d)\n",
                             AnomalyScopeToString(scope),
                             CalcSignedText(GetScore(scope)),
                             CalcSignedText(GetRawScore(scope)),
                             GMD_ANOMALY_CAP);

   if(m_hitCount == 0)
     {
      out += "  (no anomaly active today)";
      return(out);
     }

   for(int i = 0; i < m_hitCount; i++)
      out += StringFormat("  %-6s %-20s %s\n",
                          AnomalyScopeToString(m_hits[i].scope),
                          m_hits[i].label,
                          CalcSignedText(m_hits[i].score));

   return(out);
  }

//+------------------------------------------------------------------+
//| 色は赤・白・青の3つだけ（仕様書15.1）                             |
//+------------------------------------------------------------------+
color CAnomalyEngine::GetColor(const ENUM_ANOMALY_SCOPE scope)
  {
   if(!m_ready)
      return(clrGray);

   const int score = GetScore(scope);

   if(score >= 3)
      return(clrRed);
   if(score <= -3)
      return(clrDodgerBlue);

   return(clrWhite);
  }

#endif // __GMD_ANOMALYENGINE_MQH__
//+------------------------------------------------------------------+
