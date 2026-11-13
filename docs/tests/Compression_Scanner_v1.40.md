# CCompression Scanner v1.40

## v1.40 additions
- TRANSITION rows receive a ranking number.
- Ranking is based primarily on the live start Score (higher Score first).
- A historical quality adjustment uses per-symbol/per-timeframe results:
  - breakout frequency (up + down),
  - directional bias (up vs down),
  - false-break candidate rate.
- Historical adjustment is sample-size damped; small samples have limited influence.
- The existing detector and compression scoring conditions are unchanged.
- The report-save button also exports `CCompression_TransitionRanking_v1.40_YYYY-MM-DD.csv`.

## Installation
1. Copy `CCompression_Scanner_v1.40.mq5` into your MT5 Indicators folder.
2. Keep `CCompressionScannerCompat.mqh` beside the MQ5 file.
3. Preserve the existing project include path for `../src/Modules/Engines/SuddenMoveDetector.mqh`.
4. Compile in MetaEditor.

## Important
This source has been structurally edited but has NOT been compiled in MetaEditor or run in MT5 in this environment. Please keep the v1.30 file as rollback until v1.40 is compiled and checked.
