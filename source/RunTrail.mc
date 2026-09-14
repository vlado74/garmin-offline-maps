import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;

//! Distance-sampled GPS points for the visible running breadcrumb.
class RunTrail {
    const MAX_POINTS = 512;
    const INITIAL_SAMPLE_METRES = 5.0d;
    const MAX_JUMP_METRES = 200.0d;
    const EARTH_RADIUS_METRES = 6371000.0d;
    const DRAW_MARGIN = 10;

    hidden var _lats as Array<Number>;
    hidden var _lons as Array<Number>;
    hidden var _sampleMetres;

    function initialize() {
        _lats = [] as Array<Number>;
        _lons = [] as Array<Number>;
        _sampleMetres = INITIAL_SAMPLE_METRES;
    }

    //! Add a plausible fix far enough from the latest displayed point.
    function add(lat, lon) {
        var count = _lats.size();
        if (count > 0) {
            var moved = distance(_lats[count - 1], _lons[count - 1], lat, lon);
            if (moved < _sampleMetres || moved > MAX_JUMP_METRES) { return false; }
        }

        if (count >= MAX_POINTS) { compact(); }
        _lats.add(lat);
        _lons.add(lon);
        return true;
    }

    function clear() {
        _lats = [] as Array<Number>;
        _lons = [] as Array<Number>;
        _sampleMetres = INITIAL_SAMPLE_METRES;
    }

    function size() { return _lats.size(); }
    function latAt(index) { return _lats[index]; }
    function lonAt(index) { return _lons[index]; }

    //! Project retained geographic coordinates at the current display scale.
    function draw(dc, centreLat, centreLon, zoom, width, height) {
        if (_lats.size() < 2) { return; }

        var centreX = Mercator.lonToWorldX(centreLon, zoom);
        var centreY = Mercator.latToWorldY(centreLat, zoom);
        drawPass(dc, 4, Graphics.COLOR_DK_GRAY, centreX, centreY, zoom, width, height);
        drawPass(dc, 2, 0x00D7FF, centreX, centreY, zoom, width, height);
    }

    //! Equirectangular distance on a spherical earth; accurate at trail scale.
    hidden function distance(fromLat, fromLon, toLat, toLon) {
        var latRadians = fromLat * Math.PI / 180.0d;
        var dy = (toLat - fromLat) * Math.PI / 180.0d * EARTH_RADIUS_METRES;
        var dx = (toLon - fromLon) * Math.PI / 180.0d * EARTH_RADIUS_METRES
                 * Math.cos(latRadians);
        return Math.sqrt(dx * dx + dy * dy);
    }

    //! Keep the endpoints and every second interior point in lockstep arrays.
    hidden function compact() {
        var compactLats = [] as Array<Number>;
        var compactLons = [] as Array<Number>;
        compactLats.add(_lats[0]);
        compactLons.add(_lons[0]);
        for (var i = 2; i < _lats.size() - 1; i += 2) {
            compactLats.add(_lats[i]);
            compactLons.add(_lons[i]);
        }
        compactLats.add(_lats[_lats.size() - 1]);
        compactLons.add(_lons[_lons.size() - 1]);

        _lats = compactLats;
        _lons = compactLons;
        _sampleMetres *= 2.0d;
    }

    hidden function drawPass(dc, penWidth, colour, centreX, centreY, zoom, width, height) {
        dc.setColor(colour, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(penWidth);
        var x1 = width / 2.0d + Mercator.lonToWorldX(_lons[0], zoom) - centreX;
        var y1 = height / 2.0d + Mercator.latToWorldY(_lats[0], zoom) - centreY;
        for (var i = 1; i < _lats.size(); i += 1) {
            var x2 = width / 2.0d + Mercator.lonToWorldX(_lons[i], zoom) - centreX;
            var y2 = height / 2.0d + Mercator.latToWorldY(_lats[i], zoom) - centreY;
            if (segmentVisible(x1, y1, x2, y2, width, height)) {
                dc.drawLine(x1.toNumber(), y1.toNumber(), x2.toNumber(), y2.toNumber());
            }
            x1 = x2;
            y1 = y2;
        }
    }

    //! Reject only a segment wholly beyond the same side of the draw margin.
    hidden function segmentVisible(x1, y1, x2, y2, width, height) {
        var left = -DRAW_MARGIN;
        var top = -DRAW_MARGIN;
        var right = width + DRAW_MARGIN;
        var bottom = height + DRAW_MARGIN;
        if (x1 < left && x2 < left) { return false; }
        if (x1 > right && x2 > right) { return false; }
        if (y1 < top && y2 < top) { return false; }
        if (y1 > bottom && y2 > bottom) { return false; }
        return true;
    }
}
