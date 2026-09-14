# EUR Run Map for Garmin Forerunner 265S

A small Connect IQ watch app that keeps an offline street map under your live
GPS position while recording a run. The map is pre-rendered on a computer and
compiled into the app, so drawing on the watch is immediate and needs no phone,
network connection, or subscription.

The public repository ships a synthetic Berlin fixture. Personal map packs,
coordinates, signing keys, previews, and `.prg` files are ignored by Git.

## What the watch shows

- north-up map, always centred on the latest usable GPS fix;
- overview at zoom 13, street detail at zoom 15, and a 2x close view;
- a cyan breadcrumb sampled every 5 m and bounded to 512 points;
- elapsed time, distance in kilometres, and average pace in min/km;
- clear GPS, map, recording, pause, and save-failure states;
- a FIT street-running activity that synchronizes through Garmin Connect.

Only physical keys change state:

| Key | Action |
|---|---|
| START/STOP | start, pause, or resume the same activity |
| UP | zoom in: overview → detail → close |
| DOWN | zoom out: close → detail → overview |
| hold UP/MENU | hide or show the time/distance/pace band |
| BACK | save/discard confirmation when a session exists |

## Build the demo

Install the [Connect IQ SDK](https://developer.garmin.com/connect-iq/sdk/) and
Python 3.9+ with Pillow, then:

```bash
make key
make test
make build
```

The result is `bin/offline-maps.prg`, built only for `fr265s`.

## Build a private map

Choose a bounding box as `west,south,east,north`. A 5 km diameter needs a 2.5 km
radius around the chosen centre.

```bash
make raster-pack RASTER_BBOX="west,south,east,north" RASTER_NAME="My running map"
make raster-preview PACK=mapdata/raster ZOOM=13 OUTPUT=overview.png
make raster-preview PACK=mapdata/raster ZOOM=15 OUTPUT=detail.png
```

After inspecting both previews, temporarily change `mapdata/raster-demo` to
`mapdata/raster` in `monkey.jungle` and run `make build`. Do not commit that path
change or `source/generated/RasterMapIndex.mc`: both reveal the personal map
extent. [docs/PACKER.md](docs/PACKER.md) describes the pack and checks.

## Map data and attribution

The renderer uses OpenStreetMap data. Generated maps are derivative databases
under the ODbL and the watch displays `(c) OSM`. See the
[OpenStreetMap copyright page](https://www.openstreetmap.org/copyright).

Code is MIT licensed; see [LICENSE](LICENSE).
