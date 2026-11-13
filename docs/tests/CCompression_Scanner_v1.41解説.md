CCompression Scanner v1.41 変更内容

基準ファイル:
CCompression_Scanner_v1.40_CSV整理版.mq5

変更点:
1. 経過時間の計算基準を修正
   - startTimeは開始足の始値時刻
   - startPriceは開始足の終値
   - 表示経過時間を「開始足の終値時刻」から「終了足の終値時刻」までで計算
   - barsElapsedの計算式は変更せず、既存の本数定義に時間表示を合わせる

2. SUDDEN_MOVEの同一バー重複ログを抑止
   - 同じ銘柄・時間足の同一バーでは1件だけ記録
   - GlobalVariableで記録済みバー時刻を保持し、チャート再初期化後も重複を抑止
   - 急変検知関数・検知条件・表示動作は変更しない

変更していないもの:
- 圧縮/TRANSITION検出条件
- Score計算
- 事後判定条件
- ランキング計算式
- CSVのバージョン名（v1.40のまま）
- 既存の統計保存キー

注意:
このファイルはソース上の静的チェックのみです。MetaEditorでのコンパイルおよびMT5実機テストは未実施です。
CCompressionScannerCompat.mqh と SuddenMoveDetector.mqh は従来の配置・相対パスを維持してください。
