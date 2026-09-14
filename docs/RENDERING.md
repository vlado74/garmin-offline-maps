# Rendering

Map cells are rendered at twice their final resolution and reduced to 120×120
pixels. This gives smoother road edges and labels while keeping each Connect IQ
bitmap small. The fixed palette separates water, green space, rail, paths,
minor roads, tertiary roads, primary roads, and motorways with strong contrast.
Only named roads receive labels.

The watch draws in this order:

1. raster cells;
2. `(c) OSM` attribution;
3. dark outline and cyan breadcrumb;
4. centred cyan GPS marker;
5. state text;
6. a 52 px metric band positioned inside the safe width of the round display.

Zoom 13 gives context across the packed region. Zoom 15 shows local streets.
The map stays north-up and cannot be dragged, so the marker always represents
the viewport centre. Missing cells or a position outside the pack produce a red
status without stopping FIT recording.
