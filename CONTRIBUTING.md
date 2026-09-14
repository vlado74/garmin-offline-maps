# Contributing

The project has two loops: Python generates and verifies raster resources;
Monkey C displays those resources and records FIT activities on a Forerunner
265S.

```bash
make test
make lint
make build KEY=/absolute/path/to/developer_key
```

Use `make raster-demo` to regenerate the committed synthetic fixture. It must
leave `mapdata/raster-demo` and `source/generated/RasterMapIndex.mc` unchanged.
Personal map packs belong in `mapdata/raster`, which is ignored by Git.

Before a pull request, commit all public changes and run:

```bash
make regression KEY=/absolute/path/to/developer_key
```

Keep the watch runtime within its current bounds: at most 16 resident 120 px
bitmaps and 512 trail points. Check rendering changes with both 360 px previews
and compile for `fr265s` with warnings enabled.
