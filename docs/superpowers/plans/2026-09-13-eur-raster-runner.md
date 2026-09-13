# EUR Raster Runner Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Forerunner 265S watch app that displays an offline raster map covering a 5 km diameter around Via Alessio Baldovinetti, follows the runner's GPS position, draws the completed trail, and saves a running FIT activity for Garmin Connect.

**Architecture:** A Python/Pillow build pipeline renders OpenStreetMap ways into 120 x 120, 32-color PNG resources at Web Mercator zooms 13 and 15 and emits a Monkey C resource index. The watch loads only the raster cells intersecting its 360 x 360 viewport, draws a bounded adaptive trail above them, and delegates complete activity recording to `Toybox.ActivityRecording.Session`.

**Tech Stack:** Python 3.9 standard library, Pillow, existing `mappack.osmread`/`mappack.geom`/`mappack.classify`, Monkey C / Connect IQ API 5.2, Garmin bitmap resources, `Toybox.Position`, `Toybox.Activity`, and `Toybox.ActivityRecording`.

**Spec:** `docs/superpowers/specs/2026-09-13-eur-raster-runner-design.md`

## Global Constraints

- Target device is Forerunner 265S: 360 x 360 AMOLED, Connect IQ API 5.2, watch-app memory limit 786,432 bytes.
- Runtime is fully offline; never download public OpenStreetMap raster tiles.
- Coverage contains every point within 2.5 km of 41.8318579 N, 12.4946125 E; generated resources use the tile-aligned enclosing rectangle.
- Map is north-up, GPS-centred, not pannable, not rotated, and has exactly two manually selected scales: z13 overview and z15 detail.
- Raster cells are 120 x 120 pixels, use at most 32 colors, and are packed as PNG bitmap resources.
- Only visible bitmap references remain resident; the full region is never decoded at once.
- UI displays elapsed recording time, distance, average pace, recording state, GPS state, current position, and visible trail.
- FIT activity uses running/street classification and must continue through map failures or leaving map bounds.
- Generated personal EUR map artifacts and exact home-centred metadata remain local and must not be committed or pushed.

---

### Task 1: Define the raster grid and geographic contract

**Files:**
- Create: `tools/mappack/mappack/raster.py`
- Create: `tools/mappack/tests/unit/test_raster.py`
- Modify: `tools/mappack/tests/unit/__init__.py`

**Interfaces:**
- Consumes: `mappack.geom.lon_to_world_x`, `lat_to_world_y`, `world_x_to_lon`, `world_y_to_lat`; `mappack.geom.BBox`.
- Produces: `RasterGrid`, `grid_for(bounds, zoom, tile_size=120)`, `cell_bounds(grid, col, row)`, `visible_cells(grid, lon, lat, width, height)`.

- [ ] **Step 1: Write failing grid tests**

```python
from mappack.raster import RasterGrid, cell_bounds, grid_for, visible_cells

ROME = (12.4644720888, 41.8094001206, 12.5247529112, 41.8543156794)

def test_grid_is_anchored_to_120_pixel_world_cells(self):
    grid = grid_for(ROME, 15)
    self.assertEqual(grid.tile_size, 120)
    self.assertEqual(grid.origin_x % 120, 0)
    self.assertEqual(grid.origin_y % 120, 0)

def test_360_pixel_view_never_selects_more_than_sixteen_cells(self):
    grid = grid_for(ROME, 15)
    cells = visible_cells(grid, 12.4946125, 41.8318579, 360, 360)
    self.assertLessEqual(len(cells), 16)

def test_grid_cell_bounds_round_trip(self):
    grid = grid_for(ROME, 13)
    west, south, east, north = cell_bounds(grid, 0, 0)
    self.assertLess(west, east)
    self.assertLess(south, north)
```

- [ ] **Step 2: Run the tests and verify the missing module failure**

Run: `cd tools/mappack && python3 -m unittest tests.unit.test_raster -v`

Expected: FAIL with `ModuleNotFoundError: No module named 'mappack.raster'`.

- [ ] **Step 3: Implement immutable grid metadata and cell selection**

```python
@dataclass(frozen=True)
class RasterGrid:
    zoom: int
    tile_size: int
    origin_x: int
    origin_y: int
    cols: int
    rows: int

def grid_for(bounds: BBox, zoom: int, tile_size: int = 120) -> RasterGrid:
    west, south, east, north = bounds
    left = math.floor(geom.lon_to_world_x(west, zoom) / tile_size) * tile_size
    top = math.floor(geom.lat_to_world_y(north, zoom) / tile_size) * tile_size
    right = math.ceil(geom.lon_to_world_x(east, zoom) / tile_size) * tile_size
    bottom = math.ceil(geom.lat_to_world_y(south, zoom) / tile_size) * tile_size
    return RasterGrid(zoom, tile_size, left, top,
                      (right - left) // tile_size,
                      (bottom - top) // tile_size)
```

`visible_cells` must floor the screen rectangle against `grid.origin_x/y`, clamp columns and rows to the grid, and return stable `(col, row, screen_x, screen_y)` tuples in row-major order.

- [ ] **Step 4: Run the unit tests**

Run: `cd tools/mappack && python3 -m unittest tests.unit.test_raster -v`

Expected: all raster grid tests PASS.

- [ ] **Step 5: Commit the grid contract**

```bash
git add tools/mappack/mappack/raster.py tools/mappack/tests/unit/test_raster.py tools/mappack/tests/unit/__init__.py
git commit -m "feat: define the offline raster map grid"
```

---

### Task 2: Render high-contrast map cells and road labels

**Files:**
- Modify: `tools/mappack/mappack/raster.py`
- Modify: `tools/mappack/tests/unit/test_raster.py`
- Create: `tools/mappack/tests/integration/test_raster_render.py`

**Interfaces:**
- Consumes: `RasterGrid`; `osmread.Way`; `classify.classify`; Pillow `Image`, `ImageDraw`, `ImageFont`.
- Produces: `RasterStyle`, `build_scene(ways, zoom)`, `render_cell(scene, grid, col, row, fonts) -> PIL.Image.Image`, `resolve_fonts(regular_path=None, bold_path=None)`.

- [ ] **Step 1: Add failing style, palette, and render tests**

```python
def test_rendered_cell_is_120_square_and_palette_limited(self):
    image = render_cell(self.scene, self.grid, 0, 0, self.fonts)
    self.assertEqual(image.size, (120, 120))
    self.assertEqual(image.mode, "P")
    self.assertLessEqual(len(image.getcolors()), 32)

def test_primary_road_and_water_change_background_pixels(self):
    image = render_cell(self.scene, self.grid, 0, 0, self.fonts).convert("RGB")
    colors = set(image.getdata())
    self.assertIn(RasterStyle.PRIMARY, colors)
    self.assertIn(RasterStyle.WATER, colors)

def test_label_collision_keeps_higher_priority_name(self):
    placed = place_labels([low_priority, high_priority], (120, 120), self.fonts)
    self.assertEqual([label.text for label in placed], ["Via Principale"])
```

Use short synthetic `Way` objects projected into one cell; tests must not use the network or system fonts. Inject `ImageFont.load_default()`.

- [ ] **Step 2: Run the new tests and verify missing render APIs**

Run: `cd tools/mappack && python3 -m unittest tests.unit.test_raster tests.integration.test_raster_render -v`

Expected: FAIL because `RasterStyle`, `build_scene`, and `render_cell` are absent.

- [ ] **Step 3: Implement the fixed map style and scene preparation**

Use these semantic colors before final quantization:

```python
class RasterStyle:
    BACKGROUND = (242, 239, 231)
    WATER = (159, 198, 232)
    GREEN = (191, 224, 168)
    RAIL = (105, 105, 105)
    PATH = (150, 112, 72)
    MINOR = (255, 255, 255)
    TERTIARY = (245, 205, 92)
    PRIMARY = (240, 140, 40)
    MOTORWAY = (224, 74, 24)
    LABEL = (30, 30, 30)
    LABEL_HALO = (255, 255, 255)
```

Project each retained way once per zoom, index its bounding box to intersecting custom cells, and preserve `name`, geometry type, layer, importance, and projected points. Render at 2x resolution, draw filled areas first and roads in layer order with a darker one-pixel casing for minor roads, then downsample with `Image.Resampling.LANCZOS`.

- [ ] **Step 4: Implement deterministic labels**

Take labels from named highways, rail features, parks, and water features in the loaded ways. Rank motorway/primary/tertiary/residential first, followed by named parks, water, and rail. Choose the midpoint of the longest visible segment for lines and the visual centre for areas, draw horizontal text with a two-pixel light halo, and reject bounding boxes intersecting an earlier label. `resolve_fonts` uses explicitly supplied paths; otherwise on macOS it selects `/System/Library/Fonts/Supplemental/Arial.ttf` and `Arial Bold.ttf`, and raises a clear error if neither exists.

- [ ] **Step 5: Quantize to the fixed 32-color output palette**

Create a 768-entry Pillow palette whose first entries are the semantic colors above, pad with zeros, and call `image.quantize(palette=palette_image, dither=Image.Dither.NONE)`. This keeps road colors exact and prevents the resource compiler from inventing a large device palette.

- [ ] **Step 6: Run render tests and inspect a synthetic preview**

Run: `cd tools/mappack && python3 -m unittest tests.unit.test_raster tests.integration.test_raster_render -v`

Expected: PASS and a temporary preview from the integration test contains non-background roads, water, and at least one label halo.

- [ ] **Step 7: Commit the renderer**

```bash
git add tools/mappack/mappack/raster.py tools/mappack/tests/unit/test_raster.py tools/mappack/tests/integration/test_raster_render.py
git commit -m "feat: render labelled high-contrast raster cells"
```

---

### Task 3: Emit bitmap resources and a Monkey C index

**Files:**
- Create: `tools/mappack/mappack/raster_emit.py`
- Create: `tools/mappack/mappack/raster_cli.py`
- Create: `tools/mappack/tests/integration/test_raster_emit.py`
- Modify: `Makefile`
- Modify: `.gitignore`

**Interfaces:**
- Consumes: Task 1/2 grid and rendering APIs; `osmread.load`.
- Produces: `write_raster_pack(ways, bounds, zooms, out_dir, index_path, fonts)`, `python3 -m mappack.raster_cli`, `make raster-pack`, `mapdata/raster/mapdata.xml`, raster PNG cells, `mapdata/raster/pack.json`, `source/generated/RasterMapIndex.mc`.

- [ ] **Step 1: Write an integration test for all emitted artifacts**

```python
def test_emit_writes_png_resources_metadata_and_index(self):
    manifest = write_raster_pack(self.ways, self.bounds, (13, 15), self.out,
                                 self.index, fonts=self.fonts)
    self.assertEqual(manifest["tileSize"], 120)
    self.assertEqual(manifest["zooms"], [13, 15])
    self.assertTrue(os.path.exists(os.path.join(self.out, "mapdata.xml")))
    self.assertIn('packingFormat="png"', read("mapdata.xml"))
    self.assertIn("module RasterMapIndex", read(self.index))
    self.assertEqual(len(glob.glob(os.path.join(self.out, "tiles", "*.png"))),
                     manifest["resourceCount"])
```

Add a second test that parses every `<bitmap id>` and verifies exactly one matching `case` in `RasterMapIndex.resourceAt(zoom, col, row)`.

- [ ] **Step 2: Run the test and verify the emitter is missing**

Run: `cd tools/mappack && python3 -m unittest tests.integration.test_raster_emit -v`

Expected: FAIL with missing `mappack.raster_emit`.

- [ ] **Step 3: Implement artifact emission**

`write_raster_pack` must clear only its own `tiles/` directory, render every cell for z13 and z15, save optimized indexed PNGs, write one foreground `<bitmap>` resource per cell, and atomically replace metadata and index files. Resource IDs use `r<zoom>_<col>_<row>`.

Generate constants and lookup functions with concrete source lines. The emitter
builds the resource switch from each grid cell:

```python
lines = ["module RasterMapIndex {",
         "    const TILE_SIZE = %d;" % grids[0].tile_size,
         "    const ZOOMS = [%s];" % ", ".join(str(g.zoom) for g in grids)]
for grid in grids:
    lines.append("    function resourceAt%d(col, row) {" % grid.zoom)
    lines.append("        var key = col * %d + row;" % grid.rows)
    lines.append("        switch (key) {")
    for col in range(grid.cols):
        for row in range(grid.rows):
            key = col * grid.rows + row
            lines.append("            case %d: return Rez.Drawables.r%d_%d_%d;"
                         % (key, grid.zoom, col, row))
    lines.extend(["        }", "        return null;", "    }"])
lines.append("}")
```

Add generated `originX`, `originY`, `cols`, `rows`, bounds, centre, and the
top-level `resourceAt(zoom, col, row)` dispatcher in the same deterministic
order. Out-of-range calls return `null`.

- [ ] **Step 4: Add the raster CLI and Make target**

CLI arguments are `--bbox`, `--zooms` (exactly two), `--font`, `--bold-font`, `--cache`, `--out`, `--index`, and `--name`. Add:

```make
RASTER_BBOX ?= 12.4644720888,41.8094001206,12.5247529112,41.8543156794
RASTER_ZOOMS ?= 13,15
RASTER_FONT ?= /System/Library/Fonts/Supplemental/Arial.ttf
RASTER_BOLD_FONT ?= /System/Library/Fonts/Supplemental/Arial Bold.ttf

raster-pack:
	cd $(PACK_DIR) && $(PYTHON) -m mappack.raster_cli \
		--bbox "$(RASTER_BBOX)" --zooms "$(RASTER_ZOOMS)" \
		--font "$(RASTER_FONT)" --bold-font "$(RASTER_BOLD_FONT)" \
		--out "$(CURDIR)/mapdata/raster" \
		--index "$(CURDIR)/source/generated/RasterMapIndex.mc"
```

Ignore `mapdata/raster/` as personal generated data while force-allowing a later committed synthetic demo directory.

- [ ] **Step 5: Run emitter tests and CLI help**

Run: `cd tools/mappack && python3 -m unittest tests.integration.test_raster_emit -v && python3 -m mappack.raster_cli --help`

Expected: tests PASS; help lists every required argument.

- [ ] **Step 6: Commit the build pipeline**

```bash
git add tools/mappack/mappack/raster_emit.py tools/mappack/mappack/raster_cli.py tools/mappack/tests/integration/test_raster_emit.py Makefile .gitignore
git commit -m "feat: emit offline raster resources for Connect IQ"
```

---

### Task 4: Add a committed synthetic raster pack and cross-language contract

**Files:**
- Create: `mapdata/raster-demo/mapdata.xml`
- Create: `mapdata/raster-demo/tiles/*.png`
- Create: `mapdata/raster-demo/pack.json`
- Create: `source/generated/RasterMapIndex.mc`
- Create: `tools/mappack/tests/contract/test_raster_map.py`
- Modify: `monkey.jungle`

**Interfaces:**
- Consumes: Task 3 emitter.
- Produces: a buildable repository without exposing the user's home-centred pack; contract between generated bitmap IDs and Monkey C index.

- [ ] **Step 1: Write the contract test before generating resources**

```python
def test_every_index_resource_exists_in_xml(self):
    ids = set(re.findall(r'<bitmap id="([^"]+)"', self.xml))
    refs = set(re.findall(r'Rez\.Drawables\.(r\d+_\d+_\d+)', self.index))
    self.assertEqual(ids, refs)

def test_watch_and_host_agree_on_tile_size_and_zooms(self):
    self.assertIn("const TILE_SIZE = 120;", self.index)
    self.assertIn("const ZOOMS = [13, 15];", self.index)
```

- [ ] **Step 2: Run the contract and verify missing demo/index failure**

Run: `cd tools/mappack && python3 -m unittest tests.contract.test_raster_map -v`

Expected: FAIL because the demo resources do not exist yet.

- [ ] **Step 3: Generate a tiny synthetic pack from `tests/demo-city.osm`**

Add a `raster-demo` Make target that invokes the CLI with the fixture bounds, z13/z15, and test-injected Pillow fonts. Generate enough cells to cover a 360 x 360 viewport at each zoom. Do not use the user's Rome coordinates in committed metadata.

- [ ] **Step 4: Wire demo resources into the build**

Set `base.resourcePath = resources;mapdata/raster-demo`. The personal build step in Task 9 temporarily selects `mapdata/raster`; normal clones remain buildable with the demo.

- [ ] **Step 5: Run contract tests and compile the demo for fr265s**

Run: `make test && make build DEVICE=fr265s`

Expected: all Python tests PASS and Monkey C reports `BUILD SUCCESSFUL`.

- [ ] **Step 6: Commit the synthetic pack and contract**

```bash
git add mapdata/raster-demo source/generated/RasterMapIndex.mc tools/mappack/tests/contract/test_raster_map.py monkey.jungle Makefile
git commit -m "test: add a synthetic raster map contract"
```

---

### Task 5: Draw visible raster cells on the watch

**Files:**
- Create: `source/RasterPack.mc`
- Create: `source/RasterTileStore.mc`
- Create: `source/RunStyle.mc`
- Create: `source/RunMapView.mc`
- Create: `tools/mappack/tests/contract/test_raster_runtime.py`

**Interfaces:**
- Consumes: `RasterMapIndex`, `Mercator`, `Application.loadResource`, `Graphics.Dc.drawBitmap`.
- Produces: `RasterPack.contains(lat, lon)`, `RasterPack.visibleCells(lat, lon, zoom, width, height)`, `RasterTileStore.prepare(lat, lon, zoom, width, height)`, `RasterTileStore.draw(dc)`, `RasterTileStore.hadLoadFailure()`, `RasterTileStore.clear()`, `RunMapView` base map drawing.

- [ ] **Step 1: Write a host contract for watch-side selection math**

Read generated constants and assert that a Python mirror of the intended Monkey C formula returns the same cells as Task 1 `visible_cells`, including the map centre, every grid edge, and a point outside bounds. Also assert source contains `MAX_VISIBLE = 16` and no `Application.loadResource` call inside `RunMapView.onUpdate`.

- [ ] **Step 2: Run the contract and verify missing runtime classes**

Run: `cd tools/mappack && python3 -m unittest tests.contract.test_raster_runtime -v`

Expected: FAIL because `RasterPack.mc`, `RasterTileStore.mc`, and `RunMapView.mc` do not exist.

- [ ] **Step 3: Implement the map facade and visible-cell records**

```monkeyc
class RasterCell {
    var col; var row; var x; var y; var resource;
    function initialize(c, r, sx, sy, rez) {
        col = c; row = r; x = sx; y = sy; resource = rez;
    }
}

module RasterPack {
    const OVERVIEW = 13;
    const DETAIL = 15;
    function contains(lat, lon) {
        return lon >= RasterMapIndex.WEST && lon <= RasterMapIndex.EAST
            && lat >= RasterMapIndex.SOUTH && lat <= RasterMapIndex.NORTH;
    }
}
```

`visibleCells` uses this exact selection core before clamping to generated rows
and columns and producing row-major `RasterCell` objects:

```monkeyc
var cx = Mercator.lonToWorldX(lon, zoom);
var cy = Mercator.latToWorldY(lat, zoom);
var left = cx - width / 2.0;
var top = cy - height / 2.0;
var col0 = Math.floor((left - RasterMapIndex.originX(zoom))
                      / RasterMapIndex.TILE_SIZE).toNumber();
var row0 = Math.floor((top - RasterMapIndex.originY(zoom))
                      / RasterMapIndex.TILE_SIZE).toNumber();
```

It returns no more than 16 `RasterCell` instances.

- [ ] **Step 4: Implement resource residency outside the draw callback**

`RasterTileStore.prepare` compares the requested `(zoom,col,row)` set with the current set, reuses matching bitmap references, loads new IDs with `Application.loadResource`, catches graphics-memory errors, and releases references no longer visible. `draw` only clears to `RunStyle.MAP_BACKGROUND` and calls `dc.drawBitmap(cell.x, cell.y, bitmapReference)`.

Reset the load-failure flag at the start of each changed selection; set it when any required resource cannot load. `hadLoadFailure()` exposes that flag to the status overlay without throwing from the draw path.

- [ ] **Step 5: Implement the base view**

`RunMapView.onLayout` captures 360 x 360 dimensions and prepares the pack centre. `setPosition` stores the latest fix, calls `RasterTileStore.prepare`, and requests an update. `setZoom(13|15)` prepares the new scale. `onUpdate` draws the map, compact attribution, and a centred marker; no trail or metrics yet.

- [ ] **Step 6: Run contract and compiler checks**

Run: `cd tools/mappack && python3 -m unittest tests.contract.test_raster_runtime -v && cd ../.. && make build DEVICE=fr265s`

Expected: contract PASS and `BUILD SUCCESSFUL`.

- [ ] **Step 7: Commit raster runtime drawing**

```bash
git add source/RasterPack.mc source/RasterTileStore.mc source/RunStyle.mc source/RunMapView.mc tools/mappack/tests/contract/test_raster_runtime.py
git commit -m "feat: draw GPS-centred raster cells on the watch"
```

---

### Task 6: Add a bounded adaptive GPS trail

**Files:**
- Create: `source/RunTrail.mc`
- Modify: `source/RunMapView.mc`
- Create: `tools/mappack/tests/contract/test_run_trail.py`

**Interfaces:**
- Consumes: usable latitude/longitude fixes while recording; `Mercator` projection.
- Produces: `RunTrail.add(lat, lon)`, `clear()`, `size()`, `latAt(i)`, `lonAt(i)`, `draw(dc, centreLat, centreLon, zoom, width, height)`.

- [ ] **Step 1: Write a Python behavioral mirror test**

Test these invariants against constants parsed from `RunTrail.mc`:

```python
def test_jitter_and_jump_are_rejected(self):
    trail = TrailModel()
    self.assertTrue(trail.add(41.8318579, 12.4946125))
    self.assertFalse(trail.add(41.8318679, 12.4946125))  # about 1.1 m
    self.assertFalse(trail.add(41.8345579, 12.4946125))  # about 300 m

def test_compaction_is_bounded_and_keeps_ends(self):
    trail = TrailModel()
    first = (41.8318579, 12.4946125)
    trail.add(*first)
    for i in range(1, 700):
        trail.add(first[0] + i * 0.00018, first[1])
    self.assertLessEqual(len(trail.points), 512)
    self.assertEqual(trail.points[0], first)
    self.assertEqual(trail.points[-1][0], first[0] + 699 * 0.00018)

def test_scale_changes_projection_not_stored_coordinates(self):
    point = (41.8320, 12.4950)
    self.assertNotEqual(project(point, 13), project(point, 15))
```

- [ ] **Step 2: Run the test and verify missing trail class**

Run: `cd tools/mappack && python3 -m unittest tests.contract.test_run_trail -v`

Expected: FAIL because `source/RunTrail.mc` is missing.

- [ ] **Step 3: Implement adaptive storage**

```monkeyc
class RunTrail {
    const MAX_POINTS = 512;
    const INITIAL_SAMPLE_METRES = 5.0;
    const MAX_JUMP_METRES = 200.0;
    hidden var _lats;
    hidden var _lons;
    hidden var _sampleMetres;
}
```

Store parallel latitude/longitude arrays. Reject movement under `_sampleMetres` and jumps over 200 m. At 512 points, retain index 0, every second interior point, and the latest point; replace both arrays and double `_sampleMetres`. Use the same spherical distance approximation in the Python mirror.

- [ ] **Step 4: Draw the visible trail**

Project stored points at the active zoom relative to the current centre. Skip segments with both endpoints outside the 360 x 360 viewport plus a 10 px margin. Draw a four-pixel dark outline followed by a two-pixel cyan line, below the centre marker and above the raster map.

- [ ] **Step 5: Run trail contract and compile**

Run: `cd tools/mappack && python3 -m unittest tests.contract.test_run_trail -v && cd ../.. && make build DEVICE=fr265s`

Expected: PASS and `BUILD SUCCESSFUL`.

- [ ] **Step 6: Commit the visible trail**

```bash
git add source/RunTrail.mc source/RunMapView.mc tools/mappack/tests/contract/test_run_trail.py
git commit -m "feat: draw a bounded adaptive running trail"
```

---

### Task 7: Record, pause, resume, save, and discard FIT activities

**Files:**
- Create: `source/RunController.mc`
- Create: `tools/mappack/tests/contract/test_run_controller.py`
- Modify: `manifest.xml`

**Interfaces:**
- Consumes: `Toybox.ActivityRecording`, `Toybox.Activity.getActivityInfo`, GPS readiness.
- Produces: states `:waitingGps`, `:ready`, `:recording`, `:paused`, `:saveFailed`; methods `setGpsReady`, `toggle`, `save`, `discard`, `shutdown`, `state`, `hasSession`, `timerMs`, `distanceMetres`, `averagePaceSeconds`.

- [ ] **Step 1: Add the required FIT permission and a failing state-machine contract**

Add `<iq:uses-permission id="Fit"/>`. The contract parses state constants and transition table comments, then executes a Python fake-session mirror covering:

```python
def test_toggle_uses_one_session_for_start_pause_and_resume(self):
    session = FakeSession()
    run = ControllerModel(lambda: session)
    run.set_gps_ready(True)
    self.assertTrue(run.toggle())
    self.assertEqual((session.starts, session.stops), (1, 0))
    self.assertTrue(run.toggle())
    self.assertEqual((session.starts, session.stops), (1, 1))
    self.assertTrue(run.toggle())
    self.assertIs(run.session, session)
    self.assertEqual(session.starts, 2)

def test_failed_save_retains_session_for_retry(self):
    session = FakeSession(save_result=False)
    run = recording_controller(session)
    self.assertFalse(run.save())
    self.assertIs(run.session, session)
    self.assertEqual(run.state, "saveFailed")

def test_successful_save_and_shutdown_release_session(self):
    run = recording_controller(FakeSession(save_result=True))
    self.assertTrue(run.save())
    self.assertIsNone(run.session)
    run = recording_controller(FakeSession(save_result=True))
    self.assertTrue(run.shutdown())
    self.assertIsNone(run.session)
```

- [ ] **Step 2: Run the test and verify missing controller failure**

Run: `cd tools/mappack && python3 -m unittest tests.contract.test_run_controller -v`

Expected: FAIL because `RunController.mc` does not exist.

- [ ] **Step 3: Implement the controller with Garmin's actual session semantics**

Create one session with:

```monkeyc
_session = ActivityRecording.createSession({
    :name => "EUR Run",
    :sport => Activity.SPORT_RUNNING,
    :subSport => Activity.SUB_SPORT_STREET
});
```

Use `session.start()` for initial start and resume, `session.stop()` for pause, `session.save()` to finish and retain the object when it returns false, and `session.discard()` only after explicit user choice. Catch exceptions and set `:saveFailed` without losing `_session`.

- [ ] **Step 4: Implement activity metrics**

Read `Activity.getActivityInfo()`. Return zero for null `timerTime`/`elapsedDistance`; compute average pace as `1000.0 / averageSpeed` when speed is positive and return null otherwise. Metrics are read-only and never drive recording transitions.

- [ ] **Step 5: Implement lifecycle safety**

`shutdown()` stops an active session and attempts to save it. It returns success/failure for diagnostics but never discards. This covers forced app lifecycle shutdowns where no confirmation view can be shown.

- [ ] **Step 6: Run contract, full tests, and compiler**

Run: `make test && make build DEVICE=fr265s`

Expected: all tests PASS and `BUILD SUCCESSFUL` with no missing Fit permission error.

- [ ] **Step 7: Commit FIT recording**

```bash
git add source/RunController.mc tools/mappack/tests/contract/test_run_controller.py manifest.xml
git commit -m "feat: record EUR runs as FIT activities"
```

---

### Task 8: Wire running controls, compact metrics, and save confirmation

**Files:**
- Create: `source/RunDelegate.mc`
- Create: `source/RunConfirmation.mc`
- Modify: `source/RunMapView.mc`
- Modify: `source/OfflineMapsApp.mc`
- Modify: `source/LocationTracker.mc`
- Modify: `resources/strings/strings.xml`
- Create: `resources-ita/strings/strings.xml`
- Modify: `manifest.xml`
- Modify: `monkey.jungle`
- Create: `tools/mappack/tests/contract/test_run_ui.py`

**Interfaces:**
- Consumes: `RunController`, `RunTrail`, `RasterTileStore`, `LocationTracker`.
- Produces: complete app flow and physical-key behavior.

- [ ] **Step 1: Write a UI contract for keys, localized copy, and app wiring**

Assert that `KEY_ENTER` invokes controller toggle, `KEY_UP` selects detail, `KEY_DOWN` selects overview, and `KEY_ESC` pushes a `WatchUi.Confirmation` when a session exists. Assert both string files define identical IDs and Italian includes `Avvia`, `Pausa`, `Salva attività?`, `Fuori mappa`, and `Ricerca GPS`.

- [ ] **Step 2: Run the UI contract and verify failure**

Run: `cd tools/mappack && python3 -m unittest tests.contract.test_run_ui -v`

Expected: FAIL because delegate, confirmation flow, and localized strings are absent.

- [ ] **Step 3: Wire GPS to map and trail**

`OfflineMapsApp.onFix` always updates `RunMapView` with a usable fix. While `RunController.state() == :recording`, add that fix to `RunTrail`; paused fixes move the centred map but do not extend the visible trail. Expose GPS accuracy from `LocationTracker` so the app only enters `:ready` for `QUALITY_USABLE` or `QUALITY_GOOD`.

- [ ] **Step 4: Implement physical controls**

```monkeyc
function onKey(event) {
    var key = event.getKey();
    if (key == WatchUi.KEY_ENTER) { _controller.toggle(); refresh(); return true; }
    if (key == WatchUi.KEY_UP) { _view.setZoom(RasterPack.DETAIL); return true; }
    if (key == WatchUi.KEY_DOWN) { _view.setZoom(RasterPack.OVERVIEW); return true; }
    if (key == WatchUi.KEY_ESC && _controller.hasSession()) {
        WatchUi.pushView(new WatchUi.Confirmation(Rez.Strings.SaveActivity),
                         new RunConfirmation(_controller, _trail),
                         WatchUi.SLIDE_IMMEDIATE);
        return true;
    }
    return false;
}
```

`RunConfirmation.onResponse(CONFIRM_YES)` saves; `CONFIRM_NO` discards. Both clear the visible trail only after the session operation succeeds.

If save returns false, push a second confirmation labelled `Riprova salvataggio?`; Yes invokes `save()` again and No invokes `discard()`. This is the only path that offers discard after a failed save, and the controller retains the session until one operation succeeds.

- [ ] **Step 5: Draw the compact data band and status**

Reserve the top 52 px. Draw timer `h:mm:ss`, distance with two decimals in km, and average pace `m:ss/km`. Use green for ready, cyan for recording, amber for paused, and red for save/map/GPS failures. Draw `Fuori mappa` without hiding metrics; draw `Ricerca GPS` and disable Start until the fix is usable.

`RunDelegate` implements key handling only; it has no `onTap` or `onDrag`, so accidental screen contact cannot move the map or change recording state.

- [ ] **Step 6: Add English and Italian resources**

Keep labels short enough for 360 px. Add `eng` and `ita` to the manifest and `resources-ita` to the resource path. English remains the fallback; an Italian watch receives Italian copy.

Replace the manifest product list with exactly `<iq:product id="fr265s"/>` for this first release, matching the global device constraint.

- [ ] **Step 7: Replace the initial app wiring and lifecycle**

`OfflineMapsApp.onStart` creates store, tracker, trail, controller, and view references. `getInitialView` returns `[RunMapView, RunDelegate]`. `onStop` disables GPS, calls `RunController.shutdown()`, clears bitmap references, and disarms diagnostics. Remove heading polling because raster is always north-up.

- [ ] **Step 8: Run UI contract and build**

Run: `cd tools/mappack && python3 -m unittest tests.contract.test_run_ui -v && cd ../.. && make build DEVICE=fr265s`

Expected: PASS and `BUILD SUCCESSFUL`.

- [ ] **Step 9: Commit the complete running flow**

```bash
git add source/RunDelegate.mc source/RunConfirmation.mc source/RunMapView.mc source/OfflineMapsApp.mc source/LocationTracker.mc resources resources-ita manifest.xml monkey.jungle tools/mappack/tests/contract/test_run_ui.py
git commit -m "feat: add the raster running experience"
```

---

### Task 9: Remove vector-only runtime, generate the private EUR pack, and build the device artifact

**Files:**
- Delete after reference scan: `source/Camera.mc`, `source/MapDelegate.mc`, `source/MapMenu.mc`, `source/MapRenderer.mc`, `source/Onboarding.mc`, `source/Pack.mc`, `source/Palette.mc`, `source/Settings.mc`, `source/TileReader.mc`, `source/TileStore.mc`, `source/Ui.mc`, `source/Waypoints.mc`
- Delete or rewrite: `tools/mappack/tests/contract/test_palette.py`, `tools/mappack/tests/contract/test_tile_format.py`, `tools/mappack/tests/integration/test_preview.py`
- Modify: `README.md`, `docs/DEVELOPMENT.md`, `docs/DEVICES.md`, `docs/RENDERING.md`, `docs/PACKER.md`, `CHANGELOG.md`
- Generate locally only: `mapdata/raster/**`, `source/generated/RasterMapIndex.mc`, `bin/offline-maps.prg`

**Interfaces:**
- Consumes: all previous tasks.
- Produces: a smaller raster-only codebase and installable private `fr265s` PRG.

- [ ] **Step 1: Prove every legacy file is unreachable**

Run:

```bash
rg -n "Camera|MapDelegate|MapMenu|MapRenderer|Onboarding|Pack\.|Palette|Settings|TileReader|TileStore|Ui\.|Waypoints" source resources tools/mappack/tests
```

For each hit, either migrate it to the raster equivalent or keep the defining file. Do not delete a file with a live reference.

- [ ] **Step 2: Remove vector-only files and obsolete tests**

Delete only files proven unreachable. Replace old preview tests with a raster-preview integration test that composes the visible 360 x 360 cells at overview and detail scales and asserts output dimensions, non-background pixel ratio, and centred marker position.

- [ ] **Step 3: Update documentation around the final product**

Document `make raster-pack`, the fixed Rome bounds, local-only map artifacts, FIT permission, key controls, two scales, OSM attribution, and the physical-device acceptance procedure. Remove claims about progressive vector rendering, touch panning, downloadable cities, and heading-up behavior from user-facing docs for this fr265s build.

- [ ] **Step 4: Run every repository gate on the synthetic pack**

Run: `make test && make lint && make regression`

Expected: every Python/contract gate passes; regression compiles `fr265s`. Simulator execution remains skipped because SDK 9.2.0 crashes on this macOS installation.

- [ ] **Step 5: Commit raster-only cleanup and docs**

```bash
git add -A source tools/mappack/tests README.md docs CHANGELOG.md resources mapdata/raster-demo
git commit -m "refactor: retire the vector map runtime"
```

- [ ] **Step 6: Generate the private EUR raster pack without staging it**

Run:

```bash
make raster-pack \
  RASTER_BBOX=12.4644720888,41.8094001206,12.5247529112,41.8543156794 \
  RASTER_ZOOMS=13,15
```

Inspect `mapdata/raster/pack.json`: `tileSize` is 120, zooms are `[13,15]`, bounds enclose the requested circle, resource count remains below 230, and every PNG has at most 32 colors. Render 360 x 360 overview/detail previews centred at 41.8318579,12.4946125 and inspect names, contrast, roads, parks, water, and attribution.

- [ ] **Step 7: Select private resources for the local build**

Change the local, unstaged `base.resourcePath` from `mapdata/raster-demo` to `mapdata/raster`. Keep the generated `RasterMapIndex.mc`, raster cells, metadata, and this path switch out of all commits and pushes because they identify the user's home-centred area.

- [ ] **Step 8: Build and report artifact evidence**

Run: `make build DEVICE=fr265s`

Expected: `BUILD SUCCESSFUL`; `bin/offline-maps.prg` exists. Record its byte size, compiler warning count, and SHA-256 checksum. Deliver that exact PRG to the user.

- [ ] **Step 9: Perform physical-device acceptance**

Install the PRG, acquire GPS outdoors, start a short run, switch both scales, pause, resume, save, and synchronize. Confirm the activity appears in Garmin Connect as a street run with route geometry. Walk/run across a raster-cell boundary and verify the map remains continuous and no blank tile persists. If graphics memory fails, capture the diagnostic and reduce residency before changing coverage or visual detail.

---

## Final verification checklist

- [ ] `make test` passes all host and cross-language contracts.
- [ ] `make lint` passes.
- [ ] `make regression` passes without simulator execution.
- [ ] Synthetic raster demo builds from a clean checkout.
- [ ] Personal EUR raster previews are legible at both scales.
- [ ] Personal raster artifacts are absent from `git diff --cached` and all commits.
- [ ] `make build DEVICE=fr265s` reports `BUILD SUCCESSFUL`.
- [ ] Installed app follows GPS, draws trail, and does not progressively reveal roads.
- [ ] Pause/resume preserves one FIT session.
- [ ] Save produces a running activity with route geometry in Garmin Connect.
- [ ] Leaving the map or losing a bitmap does not terminate FIT recording.
