
【v1.42で変更した内容】

1. 経過時間の表示方法をバー数基準に統一
   - 旧: 計測開始時刻と終了時刻の差から経過時間を算出
   - 新: barsElapsed × PeriodSeconds(timeframe) で算出
   - これにより、週末・祝日などの時間ギャップがあっても
     「16本/16時間」のようにバー数と時間表示が一致します。
   - 注意: ここで表示する時間は実際の壁時計経過時間ではなく、
     完了バー数に対応する理論上の時間です。
     実際の日時はCSVの計測開始時刻・計測終了時刻で確認できます。

2. SUDDEN_MOVEの同一バー重複防止を原子的な更新に変更
   - GlobalVariableSetOnCondition() による比較交換(CAS)を採用。
   - 同一MT5端末内で複数チャート/複数インスタンスが同時に検知しても、
     同一銘柄・同一時間足・同一バーのログ記録権は1つだけになります。
   - チャート再初期化後も端末グローバル変数で重複を抑止します。
   - 競合が解消できない場合は、重複記録を避けるためその行を記録しません。

【変更していない内容】
- 圧縮/TRANSITIONの検出条件
- 開始Scoreの計算
- TRANSITION後の判定条件
- Outcome統計の計算
- TRANSITIONランキングの計算
- 表示・並び順・急変検知ロジック

【CSVファイル名】
CSVの互換性を維持するため、出力ファイル名の v1.40 表記は変更していません。
MQ5本体のバージョンは1.42です。

【必要ファイルと配置】
- CCompression_Scanner_v1.42_検証ログ品質修正版.mq5
- CCompressionScannerCompat.mqh
- ../src/Modules/Engines/SuddenMoveDetector.mqh

既存のv1.41と同じインクルード配置を維持してください。
MQ5ファイルと CCompressionScannerCompat.mqh は同じフォルダに置きます。
SuddenMoveDetector.mqh は、MQ5フォルダから相対パス
../src/Modules/Engines/SuddenMoveDetector.mqh
で参照できる位置に置いてください。

【検証上の注意】
この環境ではMetaEditorによるコンパイルおよびMT5実機動作確認は行っていません。
MetaEditorでコンパイルし、エラーがあればエラー一覧を送ってください。
コンパイル後は新しい日付のCSVで次を確認してください。
1. TRANSITION_RESULTの「経過時間」がバー数×時間足と一致すること
2. 同じ銘柄・時間足・バーのSUDDEN_MOVEが1行だけになること

旧版のMQ5とCSVは上書きせず、バックアップを残してください。
