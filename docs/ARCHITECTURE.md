# Architecture

The Python packer converts an OSM extract or Overpass response into 120×120
indexed PNG cells at zoom 13 and 15. `raster_emit.py` writes the bitmap resource
XML, `pack.json`, and `source/generated/RasterMapIndex.mc`.

On the watch, `RasterTileStore` holds only cells intersecting the current
360×360 viewport, with a hard limit of 16 bitmap references. `RunMapView` draws
the cells north-up, then attribution, breadcrumb, GPS marker, status, and the
compact metric band. No geometry is decoded or progressively rendered on the
watch.

`LocationTracker` accepts Garmin `QUALITY_USABLE` and `QUALITY_GOOD` fixes.
`OfflineMapsApp` recentres the view for each accepted fix and adds it to
`RunTrail` only while `RunController` is recording. `RunController` owns one
`ActivityRecording.Session` and retains it after any failed stop, save, or
discard operation so the user can retry.
