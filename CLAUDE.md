# garmin-offline-maps

Offline raster running map for Garmin Forerunner 265S. The public build uses
the synthetic pack in `mapdata/raster-demo`; personal packs in
`mapdata/raster` and their generated index must never be committed.

## Required checks

```bash
make test
make lint
make build KEY=/absolute/path/to/developer_key
make regression KEY=/absolute/path/to/developer_key  # clean tree only
```

The watch runtime is Monkey C in `source/`. The Python raster pipeline is
`mappack.raster`, `mappack.raster_emit`, `mappack.raster_cli`, and
`mappack.raster_preview`. Keep the generated bitmap grid at zoom 13 and 15,
120×120 pixels, no more than 32 colours per cell, and no more than 16 bitmap
references in a viewport.

Use physical keys only. GPS must remain centred and north-up. One
`ActivityRecording.Session` owns a run; failed operations retain it for retry,
and lifecycle shutdown never discards it. Run `monkeyc -w` and keep the FR265S
build warning-free.
