//+------------------------------------------------------------------+
//|                                                      Config.mqh   |
//|                        Global Market Dashboard Ultimate (GMD)     |
//|                                                                   |
//|  役割 : 入力パラメータを将来的に集約するための設定モデル           |
//|  依存 : Types.mqh                                                 |
//|  備考 : Ver2.11では本体 input を温存し、この構造体は整理の受け皿   |
//+------------------------------------------------------------------+
#property strict

#ifndef __GMD_CONFIG_MQH__
#define __GMD_CONFIG_MQH__

#include "Types.mqh"

struct SGmdDisplayConfig
  {
   bool              showDashboard;
   int               panelX;
   int               panelY;
   int               fontSize;
   ENUM_BASE_CORNER  panelCorner;
  };

struct SGmdStrengthConfig
  {
   bool              enabled;
   ENUM_TIMEFRAMES   timeframe;
   int               bars;
   bool              useWeighting;
   int               minPairs;
  };

struct SGmdAnomalyConfig
  {
   bool              enabled;
   int               minStars;
   int               serverGmtOffset;
   bool              useSeasonScore;
   bool              addToConfidence;
  };

struct SGmdEnergyConfig
  {
   bool              enabled;
   int               atrPeriod;
   int               bbPeriod;
   int               adxPeriod;
   int               lookback;
   int               thresholdBuilding;
   int               thresholdLoaded;
  };

struct SGmdUpdateConfig
  {
   int               normalMs;
   bool              onNewBarOnly;
   bool              adaptiveEnabled;
   int               alertMs;
   int               idleMs;
   int               dwellSec;
   bool              energyRaisesTier;
  };

struct SGmdSessionConfig
  {
   int               serverStdGmtOffset;
   bool              serverFollowsEuDst;
   int               preMinutes;
   int               openMinutes;
  };

struct SGmdSystemConfig
  {
   ENUM_LOG_LEVEL    logLevel;
   int               validationMinBars;
   string            symbolSuffix;
  };

struct SGmdConfig
  {
   SGmdDisplayConfig display;
   SGmdStrengthConfig strength;
   SGmdAnomalyConfig anomaly;
   SGmdEnergyConfig energy;
   SGmdUpdateConfig update;
   SGmdSessionConfig session;
   SGmdSystemConfig system;
  };

void GmdConfigSetDefaults(SGmdConfig &cfg)
  {
   cfg.display.showDashboard     = true;
   cfg.display.panelX            = 20;
   cfg.display.panelY            = 30;
   cfg.display.fontSize          = 9;
   cfg.display.panelCorner       = CORNER_LEFT_UPPER;

   cfg.strength.enabled          = true;
   cfg.strength.timeframe        = PERIOD_M1;
   cfg.strength.bars             = 3;
   cfg.strength.useWeighting     = true;
   cfg.strength.minPairs         = 20;

   cfg.anomaly.enabled           = true;
   cfg.anomaly.minStars          = 4;
   cfg.anomaly.serverGmtOffset   = 3;
   cfg.anomaly.useSeasonScore    = true;
   cfg.anomaly.addToConfidence   = false;

   cfg.energy.enabled            = true;
   cfg.energy.atrPeriod          = 14;
   cfg.energy.bbPeriod           = 20;
   cfg.energy.adxPeriod          = 14;
   cfg.energy.lookback           = GMD_ENERGY_LOOKBACK;
   cfg.energy.thresholdBuilding  = 60;
   cfg.energy.thresholdLoaded    = 80;

   cfg.update.normalMs           = 1000;
   cfg.update.onNewBarOnly       = false;
   cfg.update.adaptiveEnabled    = true;
   cfg.update.alertMs            = 300;
   cfg.update.idleMs             = 2000;
   cfg.update.dwellSec           = 60;
   cfg.update.energyRaisesTier   = true;

   cfg.session.serverStdGmtOffset = 2;
   cfg.session.serverFollowsEuDst = true;
   cfg.session.preMinutes         = 15;
   cfg.session.openMinutes        = 30;

   cfg.system.logLevel           = LOG_WARN;
   cfg.system.validationMinBars  = 100;
   cfg.system.symbolSuffix       = "";
  }

#endif // __GMD_CONFIG_MQH__
//+------------------------------------------------------------------+
