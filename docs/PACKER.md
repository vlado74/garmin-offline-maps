# Raster packer

`make raster-pack` requires an explicit `RASTER_BBOX=west,south,east,north`.
It downloads only the OSM features used by the renderer and caches the response
in the ignored `tools/mappack/eur.osm.cache` file. Pass `--input` directly to
`mappack.raster_cli` when working from a local `.osm` extract.

The output in `mapdata/raster` contains:

- `tiles/r<zoom>_<column>_<row>.png` indexed-colour 120 px cells;
- `mapdata.xml`, declaring each bitmap to Connect IQ;
- `pack.json`, with bounds, centre, grid origins, dimensions, and attribution;
- a generated `RasterMapIndex.mc` in `source/generated`.

The two supported scales are fixed at 13 and 15. Each bitmap must use no more
than 32 colours, the pack should remain below 230 resources, and every centred
360 px view must use no more than 16 cells.

Inspect both scales before compiling:

```bash
make raster-preview PACK=mapdata/raster ZOOM=13 OUTPUT=overview.png
make raster-preview PACK=mapdata/raster ZOOM=15 OUTPUT=detail.png
```

Check that street names remain legible, primary and minor roads are distinct,
parks and water are recognizable, adjacent cells have no seams, and the cyan
marker is exactly centred. Personal output, coordinates, and previews must not
be committed.
