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
    const MAX_KM_MARKERS = 50;
    const MAX_DRAWN_KM_MARKERS = 12;

    hidden var _lats as Array<Number>;
    hidden var _lons as Array<Number>;
    hidden var _sampleMetres;
    hidden var _lastFixLat;
    hidden var _lastFixLon;
    hidden var _lapStartIndex;
    hidden var _kmLats as Array<Number>;
    hidden var _kmLons as Array<Number>;
    hidden var _kmNumbers as Array<Number>;
    hidden var _lastDistance;

    function initialize() {
        _lats = [] as Array<Number>;
        _lons = [] as Array<Number>;
        _sampleMetres = INITIAL_SAMPLE_METRES;
        _lastFixLat = null;
        _lastFixLon = null;
        _lapStartIndex = 0;
        _kmLats = [] as Array<Number>;
        _kmLons = [] as Array<Number>;
        _kmNumbers = [] as Array<Number>;
        _lastDistance = null;
    }

    //! Add a plausible fix far enough from the latest displayed point.
    function add(lat, lon, totalDistance) {
        var count = _lats.size();
        if (count > 0) {
            var jump = distance(_lastFixLat, _lastFixLon, lat, lon);
            if (jump > MAX_JUMP_METRES) { return false; }
            recordKilometres(_lastFixLat, _lastFixLon, lat, lon,
                             _lastDistance, totalDistance);
            _lastFixLat = lat;
            _lastFixLon = lon;
            _lastDistance = totalDistance;
            var moved = distance(_lats[count - 1], _lons[count - 1], lat, lon);
            if (moved < _sampleMetres) { return false; }
        } else {
            _lastFixLat = lat;
            _lastFixLon = lon;
            _lastDistance = totalDistance;
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
        _lastFixLat = null;
        _lastFixLon = null;
        _lapStartIndex = 0;
        _kmLats = [] as Array<Number>;
        _kmLons = [] as Array<Number>;
        _kmNumbers = [] as Array<Number>;
        _lastDistance = null;
    }

    function size() { return _lats.size(); }
    function latAt(index) { return _lats[index]; }
    function lonAt(index) { return _lons[index]; }

    function markLap() {
        if (_lats.size() > 0) { _lapStartIndex = _lats.size() - 1; }
    }

    //! Project retained geographic coordinates at the current display scale.
    function draw(dc, centreLat, centreLon, zoom, width, height) {
        if (_lats.size() < 2) { return; }

        var centreX = Mercator.lonToWorldX(centreLon, zoom);
        var centreY = Mercator.latToWorldY(centreLat, zoom);
        if (_lapStartIndex > 0) {
            drawPass(dc, 5, Graphics.COLOR_BLACK, centreX, centreY, zoom,
                     width, height, 0, _lapStartIndex + 1);
            drawPass(dc, 3, 0x0066CC, centreX, centreY, zoom,
                     width, height, 0, _lapStartIndex + 1);
        }
        drawPass(dc, 5, Graphics.COLOR_BLACK, centreX, centreY, zoom,
                 width, height, _lapStartIndex, _lats.size());
        drawPass(dc, 3, 0x00D7FF, centreX, centreY, zoom,
                 width, height, _lapStartIndex, _lats.size());
        drawKilometreMarkers(dc, centreX, centreY, zoom, width, height);
    }

    //! Place every crossed whole kilometre between the surrounding GPS fixes.
    hidden function recordKilometres(fromLat, fromLon, toLat, toLon,
                                     fromDistance, toDistance) {
        if (fromDistance == null || toDistance == null || toDistance <= fromDistance) {
            return;
        }
        var nextKm = _kmNumbers.size() == 0
                     ? 1 : _kmNumbers[_kmNumbers.size() - 1] + 1;
        while (nextKm * 1000.0d <= toDistance) {
            var fraction = (nextKm * 1000.0d - fromDistance)
                           / (toDistance - fromDistance);
            if (fraction < 0.0d) { fraction = 0.0d; }
            if (fraction > 1.0d) { fraction = 1.0d; }
            if (_kmNumbers.size() >= MAX_KM_MARKERS) {
                _kmLats.remove(0);
                _kmLons.remove(0);
                _kmNumbers.remove(0);
            }
            _kmLats.add(fromLat + (toLat - fromLat) * fraction);
            _kmLons.add(fromLon + (toLon - fromLon) * fraction);
            _kmNumbers.add(nextKm);
            nextKm += 1;
        }
    }

    hidden function drawKilometreMarkers(dc, centreX, centreY, zoom,
                                         width, height) {
        var start = _kmNumbers.size() - MAX_DRAWN_KM_MARKERS;
        if (start < 0) { start = 0; }
        for (var i = start; i < _kmNumbers.size(); i += 1) {
            var x = width / 2.0d + Mercator.lonToWorldX(_kmLons[i], zoom) - centreX;
            var y = height / 2.0d + Mercator.latToWorldY(_kmLats[i], zoom) - centreY;
            if (x < -12 || x > width + 12 || y < -12 || y > height + 12) {
                continue;
            }
            var px = x.toNumber();
            var py = y.toNumber();
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(px, py, 10);
            dc.setColor(0xFFFF00, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(px, py, 8);
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            dc.drawText(px, py - 7, Graphics.FONT_XTINY,
                        _kmNumbers[i].format("%d"), Graphics.TEXT_JUSTIFY_CENTER);
        }
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
        _lapStartIndex = _lapStartIndex / 2;
    }

    hidden function drawPass(dc, penWidth, colour, centreX, centreY, zoom,
                             width, height, startIndex, endIndex) {
        if (endIndex - startIndex < 2) { return; }
        dc.setColor(colour, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(penWidth);
        var x1 = width / 2.0d + Mercator.lonToWorldX(_lons[startIndex], zoom) - centreX;
        var y1 = height / 2.0d + Mercator.latToWorldY(_lats[startIndex], zoom) - centreY;
        for (var i = startIndex + 1; i < endIndex; i += 1) {
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
