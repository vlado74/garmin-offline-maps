# EUR Raster Runner for Forerunner 265S

## Purpose

Replace the current progressive vector-map experience with a predictable,
high-contrast raster map built specifically for running near Via Alessio
Baldovinetti in Rome. The watch must show the runner's live position and
bread-crumb trail, record a native running activity, and save a FIT file that
Garmin can synchronize to Garmin Connect.

The app is offline at runtime. Map generation happens on the development Mac.

## Geographic scope

- Centre: Via Alessio Baldovinetti, Rome, at 41.8318579 N,
  12.4946125 E.
- Coverage requirement: every point inside a circle with a 5 km diameter
  (2.5 km radius). Generated resources cover the Web Mercator tile-aligned
  rectangle enclosing that circle, so the round display has no gaps at the
  boundary.
- Orientation: north is always at the top.
- The camera remains centred on the latest usable GPS position.
- Leaving the mapped area never stops activity recording. The unavailable map
  area uses a neutral background while the position, trail, and status remain
  visible.

## User experience

### Map

The map uses a restrained daylight style designed for a 360 x 360 AMOLED
display. It includes named roads, road hierarchy, parks, water, railways, and a
small number of useful landmarks. Decorative detail and dense points of
interest are omitted. OpenStreetMap attribution remains visible in a compact
form.

Two manually selected scales are available:

- Overview: approximately 5 km across the display, based around Web Mercator
  zoom 13 at Rome's latitude.
- Detail: approximately 1.3 km across the display, based around Web Mercator
  zoom 15.

The physical Up and Down keys switch scale. The map does not pan or rotate.
Touch input does not move the map.

### Position and trail

The current position is fixed at the centre of the screen and shown with a
high-contrast direction marker. GPS accuracy state is visible while acquiring
a fix or when quality degrades.

The completed portion of the run is drawn as an outlined, high-contrast line.
The display trail is sampled by distance and simplified to bound memory use;
this simplification affects only the screen. Garmin's activity recorder owns
the complete FIT recording.

### Compact data band

A compact band leaves most of the screen to the map and displays:

- elapsed recording time;
- distance;
- average pace;
- recording state through color and a small icon.

### Recording controls

- The app opens on the map and starts acquiring GPS.
- Start is available once the fix is usable.
- The Enter/Start key starts the running session.
- Pressing Enter while recording pauses; pressing it while paused resumes.
- Back while a session exists opens a Save/Discard confirmation instead of
  exiting silently.
- Saving closes the activity session as a running FIT file. Garmin's normal
  synchronization then uploads it to Garmin Connect.
- The app never creates more than one ActivityRecording session at a time.

## Architecture

### Build-time raster pipeline

A new host-side map builder obtains OpenStreetMap data for the fixed region,
renders the two scales with the approved style, clips the output to the pack
bounds, and emits compressed bitmap resources plus a generated index. Labels
are baked into the images, so the watch does no text placement or road
rendering.

The builder uses 120 x 120 independently loadable tiles and a 32-color palette,
packed as compressed PNG resources. A 360 x 360 viewport intersects at most
four tiles per axis, bounding the visible indexed image data at 230,400 pixels.
The custom tile grid is anchored in Web Mercator world pixels and recorded in
the generated index. The builder must emit bounds, centre, scale metadata, and
the required OpenStreetMap attribution.

Bulk use of the public OpenStreetMap tile servers is not part of the pipeline.
The builder renders locally from OpenStreetMap data downloaded through the
existing packer's data source and retains OpenStreetMap attribution.

### Raster map runtime

The runtime map component converts latitude/longitude to Web Mercator world
pixels, selects the visible tiles for the active scale, and computes their
screen offsets around the current GPS position. It keeps only the visible
bitmap references. Resource changes happen outside the draw callback; the draw
callback only paints already selected bitmaps.

Missing or unloadable tiles are recoverable. The component evicts unused
references, fills the affected area with the neutral map color, and reports a
compact map warning without interrupting recording.

### GPS and visible trail

The implementation reuses the existing `LocationTracker` for continuous
position updates and quality checks, and the existing `Mercator` projection.
A dedicated trail component accepts usable fixes, rejects implausible jumps,
samples points by travelled distance, and stores a bounded representation
suitable for redrawing at either scale.
Projection is done when drawing so switching scale does not lose the trail.

The current marker remains centred; the map and earlier trail points move under
it. A loss of GPS freezes the map at the last valid fix and clearly changes the
GPS status indicator.

### FIT recording

A recording controller wraps `Toybox.ActivityRecording.Session` in an explicit
state machine: waiting for GPS, ready, recording, paused, and finishing. It
creates a running activity, starts, pauses, resumes, saves, or discards through
one interface. Map and trail failures cannot transition or destroy the FIT
session.

Elapsed time, distance, and average speed come from `Activity.getActivityInfo()`.
The UI converts average speed to average pace; null fields display placeholders
until Garmin provides values. The controller handles failed save operations by
retaining the session and presenting a retry/discard choice.

## Resource and performance constraints

- Target device: Forerunner 265S, 360 x 360 AMOLED, Connect IQ API 5.2.
- The app must remain within the device's watch-app memory limit.
- Raster images are compressed in the PRG and loaded through bitmap resource
  references; the implementation must not decode the entire region at once.
- Normal GPS updates must not reload unchanged tile resources.
- Drawing a frame consists primarily of bitmap blits, one trail polyline, the
  centre marker, and the data band.
- If physical-device testing shows graphics-pool pressure, reduce palette size
  or visible-tile residency before reducing geographic coverage.

## Error behavior

- No usable GPS: show map at the pack centre, display acquisition status, and
  keep Start disabled.
- GPS lost during a run: keep recording state, retain the last map view, and
  show a warning until fixes resume.
- Outside map bounds: continue the FIT session and draw position/trail over the
  neutral background.
- Tile load failure: continue recording, evict cache entries, and retry only
  when tile selection changes or the user changes scale.
- Exit with an active or paused session: require Save or Discard.
- FIT save failure: preserve the session and offer Retry or Discard.

## Verification

Host-side tests cover geographic bounds, coordinate-to-tile conversion, tile
selection at edges, both scales, trail sampling and jump rejection, and the
recording state machine through an injectable session adapter.

Build verification compiles the app for `fr265s` and reports PRG size and
bitmap resource counts. Generated overview/detail preview images verify labels,
contrast, attribution, and exact geographic coverage.

Physical-device acceptance requires:

1. acquisition of a usable outdoor GPS fix;
2. immediate map display at both scales without progressive line drawing;
3. stable north-up centring while moving;
4. visible trail growth during a run;
5. working pause and resume;
6. successful FIT save and appearance in Garmin Connect after synchronization;
7. continued FIT recording when the map edge or a missing-tile path is reached.

## Out of scope

- turn-by-turn navigation or a preplanned route;
- online map downloads on the watch;
- map rotation or automatic zoom;
- touch panning;
- coverage outside the 5 km diameter pack;
- support for devices other than the Forerunner 265S in the first release.
