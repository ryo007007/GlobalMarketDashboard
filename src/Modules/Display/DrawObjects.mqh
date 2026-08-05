//+------------------------------------------------------------------+
//|                                                  DrawObjects.mqh |
//|                        Global Market Dashboard Ultimate (GMD)     |
//|                                                                   |
//|  役割 : チャートオブジェクトの生成・更新・削除だけを引き受ける    |
//|  依存 : Types.mqh                                                 |
//|  仕様 : Project Specification v1.3 第15章・第32.3節               |
//|                                                                   |
//|  原則 : 作り直さない。あれば更新する。                            |
//|         ObjectDelete → ObjectCreate を毎回繰り返すと、            |
//|         チャートがちらつき、CPUも無駄に使う。                     |
//|         テキストと色が前回と同じなら書き込みすらしない。          |
//+------------------------------------------------------------------+
#property strict

#ifndef __GMD_DRAWOBJECTS_MQH__
#define __GMD_DRAWOBJECTS_MQH__

#include "../Core/Types.mqh"

//+------------------------------------------------------------------+
//| オブジェクト名を組み立てる                                        |
//|  必ず GMD_ で始める。削除時に一括で消せるようにするため           |
//+------------------------------------------------------------------+
string CalcObjectName(const string group, const int index = -1)
  {
   if(index < 0)
      return(GMD_OBJ_PREFIX + group);

   return(StringFormat("%s%s_%d", GMD_OBJ_PREFIX, group, index));
  }

//+------------------------------------------------------------------+
//| ラベルを作る（既にあれば位置と書式だけ整える）                    |
//+------------------------------------------------------------------+
bool DrawLabel(const string name,
               const int x, const int y,
               const string text,
               const color clr,
               const int fontSize = 9,
               const string font = "Consolas",
               const ENUM_BASE_CORNER corner = CORNER_LEFT_UPPER)
  {
   if(ObjectFind(0, name) < 0)
     {
      if(!ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0))
         return(false);

      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_SELECTED,   false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN,     true);
      ObjectSetInteger(0, name, OBJPROP_BACK,       false);
      ObjectSetInteger(0, name, OBJPROP_ZORDER,     10);
     }

   ObjectSetInteger(0, name, OBJPROP_CORNER,    corner);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE,  fontSize);
   ObjectSetString (0, name, OBJPROP_FONT,      font);
   ObjectSetString (0, name, OBJPROP_TEXT,      text);
   ObjectSetInteger(0, name, OBJPROP_COLOR,     clr);

   return(true);
  }

//+------------------------------------------------------------------+
//| ラベルを差分更新する                                              |
//|  戻り値 true = 実際に書き換えた（= 再描画が必要）                 |
//+------------------------------------------------------------------+
bool UpdateLabel(const string name, const string text, const color clr)
  {
   if(ObjectFind(0, name) < 0)
      return(false);

   bool changed = false;

   if(ObjectGetString(0, name, OBJPROP_TEXT) != text)
     {
      ObjectSetString(0, name, OBJPROP_TEXT, text);
      changed = true;
     }

   if((color)ObjectGetInteger(0, name, OBJPROP_COLOR) != clr)
     {
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      changed = true;
     }

   return(changed);
  }

//+------------------------------------------------------------------+
//| 背景パネル（矩形ラベル）を作る                                    |
//+------------------------------------------------------------------+
bool DrawPanel(const string name,
               const int x, const int y,
               const int width, const int height,
               const color bgColor,
               const color borderColor,
               const ENUM_BASE_CORNER corner = CORNER_LEFT_UPPER)
  {
   if(ObjectFind(0, name) < 0)
     {
      if(!ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0))
         return(false);

      ObjectSetInteger(0, name, OBJPROP_SELECTABLE,  false);
      ObjectSetInteger(0, name, OBJPROP_SELECTED,    false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN,      true);
      ObjectSetInteger(0, name, OBJPROP_BACK,        false);
      ObjectSetInteger(0, name, OBJPROP_ZORDER,      0);
      ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, name, OBJPROP_STYLE,       STYLE_SOLID);
      ObjectSetInteger(0, name, OBJPROP_WIDTH,       1);
     }

   ObjectSetInteger(0, name, OBJPROP_CORNER,    corner);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE,     width);
   ObjectSetInteger(0, name, OBJPROP_YSIZE,     height);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR,   bgColor);
   ObjectSetInteger(0, name, OBJPROP_COLOR,     borderColor);

   return(true);
  }

//+------------------------------------------------------------------+
//| パネルの高さだけ変える（行数が変わったとき用）                    |
//+------------------------------------------------------------------+
void UpdatePanelSize(const string name, const int width, const int height)
  {
   if(ObjectFind(0, name) < 0)
      return;

   ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
  }

//+------------------------------------------------------------------+
//| 区切り線を引く（細い矩形で代用する）                              |
//+------------------------------------------------------------------+
bool DrawSeparator(const string name,
                   const int x, const int y, const int width,
                   const color clr,
                   const ENUM_BASE_CORNER corner = CORNER_LEFT_UPPER)
  {
   return(DrawPanel(name, x, y, width, 1, clr, clr, corner));
  }

//+------------------------------------------------------------------+
//| GMDが作ったオブジェクトを全部消す                                 |
//|  OnDeinit で必ず呼ぶ。消し忘れるとチャートにゴミが残る            |
//+------------------------------------------------------------------+
void DeleteAllObjects(void)
  {
   ObjectsDeleteAll(0, GMD_OBJ_PREFIX);
   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
//| 指定グループのオブジェクトだけ消す                                |
//+------------------------------------------------------------------+
void DeleteObjectGroup(const string group)
  {
   ObjectsDeleteAll(0, GMD_OBJ_PREFIX + group);
  }

#endif // __GMD_DRAWOBJECTS_MQH__
//+------------------------------------------------------------------+
