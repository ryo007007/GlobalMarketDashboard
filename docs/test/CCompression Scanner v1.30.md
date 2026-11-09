CCompression Scanner v1.30
============================

追加内容
- TRANSITION判定結果を銘柄・時間足別に累積集計
- TRANSITION開始時のScore（0～8）別に集計
- 上方/下方ブレイク、だまし候補、不発、方向感なし、未確定を記録
- レポートボタンで全監視対象の累積統計CSVを出力
- 統計はMT5ターミナルのグローバル変数に保存し、再起動後も保持

出力先
MQL5/Files/GlobalMarketDashboardVerification log/

- CCompression_Verification_v1.30_YYYY-MM-DD.csv
- CCompression_OutcomeSummary_v1.30_YYYY-MM-DD.csv
- 個別検証レポートTXT

互換性
計測中イベントを引き継ぐため、既存のイベント保存キー CCV120_ は維持しています。
累積統計は CCV130_ の新しいキーに保存します。
過去のv1.20 CSVを自動で集計する機能ではありません。v1.30稼働後に完了した判定から蓄積します。

必要な外部インクルード（v1.20と同じ）
- CCompressionScannerCompat.mqh
- ../src/Modules/Engines/SuddenMoveDetector.mqh

元のv1.20 ZIPにこれらが含まれていなかったため、本ZIPにも同梱していません。
既存環境のフォルダ構成を維持して配置してください。

注意
MetaEditorでのコンパイル・MT5実機動作確認は未実施です。
圧縮検出条件、Score計算、TRANSITION判定条件は変更していません。
