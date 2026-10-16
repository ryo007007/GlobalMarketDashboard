CCompression Scanner VerificationLog - TRANSITION表示保持修正版

変更内容:
- チャート切替・インジケーター再初期化後の最初の計算では、保存済みTRANSITION表示保持本数を減らさない。
- 再初期化後の初回計算では、進行中TRANSITIONの計測本数も誤って増やさない。
- それ以降、新しい確定足が来たときだけ表示保持と値幅計測を進める。
- CCompressionScannerCompat.mqh と SuddenMoveDetector.mqh は変更していません。

適用:
1. 現在の CCompression_Scanner_VerificationLog.mq5 をバックアップ。
2. このZIP内の CCompression_Scanner_VerificationLog.mq5 で置き換えてMetaEditorで再コンパイル。
3. CCompressionScannerCompat.mqh は、現在正常にコンパイルできているものをそのまま使用。
4. TRANSITION行をクリックしてチャート切替し、行が保持されるか確認。

注意:
- MetaEditorでの実コンパイルはこの環境では未実施です。
- この修正は、再初期化時に表示保持本数や検証計測本数が消費される問題への対策です。
  TRANSITION判定ロジック自体や、エンジンの過去状態の完全な再構築は変更していません。
