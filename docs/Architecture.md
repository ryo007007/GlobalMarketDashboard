# システムアーキテクチャ（プログラム設計図）

本ドキュメントでは、インジケーターの内部処理フローおよび設計構造について記述します。

## 処理フロー

プログラム実行時のメイン処理（`OnInit` 〜 描画まで）の流れは以下の通りです。
```
[ OnInit() ]
│
▼
[ Symbol Detection ]  （銘柄の自動検出）
│
▼
[ Currency Strength ] （通貨強弱の計算）
│
▼
[ Money Flow ]        （資金移動の分析）
│
▼
[ Confidence ]        （信頼度・スコア算出）
│
▼
[ Draw Dashboard ]    （ダッシュボードの画面描画）
```
## 各プロセスの概要

- **OnInit()**: 初期化処理およびパラメータの読み込み
- **Symbol Detection**: 対象となる通貨ペアやシンボルの判定
- **Currency Strength**: 各通貨の強弱インデックス算出
- **Money Flow**: 通貨間の資金フローの追跡
- **Confidence**: シグナルの信頼度判定
- **Draw Dashboard**: チャート上にUI（ダッシュボード）を描画
