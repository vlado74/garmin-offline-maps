# Device scope

This release targets exactly the Garmin Forerunner 265S (`fr265s`), a 360×360
round AMOLED device. The layout places side metrics below the narrow top arc so
all three values fit within the circular safe area.

The runtime caps bitmap residency at 16 cells. The breadcrumb uses parallel
coordinate arrays, samples at 5 m, rejects jumps above 200 m, and compacts at
512 points. These limits keep the app within the device's Connect IQ memory.

## Physical acceptance

Install the PRG, go outdoors, and wait for the green start state. Then:

1. start a short run with START/STOP;
2. switch detail and overview with UP and DOWN;
3. cross at least one raster-cell boundary and check for seams or blank cells;
4. pause and resume, confirming the same timer and trail continue;
5. press BACK, save, and synchronize the watch;
6. confirm Garmin Connect shows one street-running activity with route geometry.

Repeat briefly with GPS loss or outside the pack. The status should turn red and
FIT recording must remain recoverable.
