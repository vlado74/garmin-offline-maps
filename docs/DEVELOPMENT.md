# Development

Python 3.9+ and Pillow cover generation, composition, and 175+ tests. The Garmin
Connect IQ SDK and an accepted device licence are required to compile.

```bash
make doctor KEY=/absolute/path/to/developer_key
make test
make lint
make build KEY=/absolute/path/to/developer_key
```

The host tests verify grid projection, palette limits, tile coverage, bitmap
residency, trail compaction, FIT state transitions, physical keys, localization,
and raster-only packaging. `monkeyc -w` is the authority for Monkey C API and
type compatibility.

`make regression` requires a clean tree. It regenerates the synthetic map,
checks for drift, builds a warning-free `fr265s` PRG, and exports the Connect IQ
package. Simulator execution is omitted because SDK 9.2.0 crashes while drawing
on the current macOS host; final graphics and FIT behavior require the physical
acceptance procedure in [DEVICES.md](DEVICES.md).
