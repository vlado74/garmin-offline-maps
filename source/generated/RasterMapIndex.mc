//
// GENERATED FILE -- DO NOT EDIT.
// Produced by tools/mappack. Regenerate with `make raster-demo` or
// `make raster-pack`, according to the pack selected for this build.
//

module RasterMapIndex {
    const TILE_SIZE = 120;
    const ZOOMS = [13, 15];
    const PACK_NAME = "Synthetic Raster Demo";
    const ATTRIBUTION = "(c) OpenStreetMap contributors";
    const WEST = 13.3267000d;
    const SOUTH = 52.4950000d;
    const EAST = 13.3997000d;
    const NORTH = 52.5317988d;
    const CENTER_LON = 13.3632000d;
    const CENTER_LAT = 52.5133994d;
    const HOME_LON = 13.3632000d;
    const HOME_LAT = 52.5133994d;

    function originX(zoom) {
        if (zoom == 13) { return 1126200; }
        if (zoom == 15) { return 4504800; }
        return null;
    }

    function originY(zoom) {
        if (zoom == 13) { return 687600; }
        if (zoom == 15) { return 2750520; }
        return null;
    }

    function cols(zoom) {
        if (zoom == 13) { return 4; }
        if (zoom == 15) { return 15; }
        return null;
    }

    function rows(zoom) {
        if (zoom == 13) { return 4; }
        if (zoom == 15) { return 13; }
        return null;
    }

    function resourceAt(zoom, col, row) {
        if (zoom == 13) { return resourceAt13(col, row); }
        if (zoom == 15) { return resourceAt15(col, row); }
        return null;
    }

    function resourceAt13(col, row) {
        if (col < 0 || row < 0 || col >= 4 || row >= 4) { return null; }
        var key = col * 4 + row;
        switch (key) {
            case 0: return Rez.Drawables.r13_0_0;
            case 1: return Rez.Drawables.r13_0_1;
            case 2: return Rez.Drawables.r13_0_2;
            case 3: return Rez.Drawables.r13_0_3;
            case 4: return Rez.Drawables.r13_1_0;
            case 5: return Rez.Drawables.r13_1_1;
            case 6: return Rez.Drawables.r13_1_2;
            case 7: return Rez.Drawables.r13_1_3;
            case 8: return Rez.Drawables.r13_2_0;
            case 9: return Rez.Drawables.r13_2_1;
            case 10: return Rez.Drawables.r13_2_2;
            case 11: return Rez.Drawables.r13_2_3;
            case 12: return Rez.Drawables.r13_3_0;
            case 13: return Rez.Drawables.r13_3_1;
            case 14: return Rez.Drawables.r13_3_2;
            case 15: return Rez.Drawables.r13_3_3;
        }
        return null;
    }

    function resourceAt15(col, row) {
        if (col < 0 || row < 0 || col >= 15 || row >= 13) { return null; }
        var key = col * 13 + row;
        switch (key) {
            case 0: return Rez.Drawables.r15_0_0;
            case 1: return Rez.Drawables.r15_0_1;
            case 2: return Rez.Drawables.r15_0_2;
            case 3: return Rez.Drawables.r15_0_3;
            case 4: return Rez.Drawables.r15_0_4;
            case 5: return Rez.Drawables.r15_0_5;
            case 6: return Rez.Drawables.r15_0_6;
            case 7: return Rez.Drawables.r15_0_7;
            case 8: return Rez.Drawables.r15_0_8;
            case 9: return Rez.Drawables.r15_0_9;
            case 10: return Rez.Drawables.r15_0_10;
            case 11: return Rez.Drawables.r15_0_11;
            case 12: return Rez.Drawables.r15_0_12;
            case 13: return Rez.Drawables.r15_1_0;
            case 14: return Rez.Drawables.r15_1_1;
            case 15: return Rez.Drawables.r15_1_2;
            case 16: return Rez.Drawables.r15_1_3;
            case 17: return Rez.Drawables.r15_1_4;
            case 18: return Rez.Drawables.r15_1_5;
            case 19: return Rez.Drawables.r15_1_6;
            case 20: return Rez.Drawables.r15_1_7;
            case 21: return Rez.Drawables.r15_1_8;
            case 22: return Rez.Drawables.r15_1_9;
            case 23: return Rez.Drawables.r15_1_10;
            case 24: return Rez.Drawables.r15_1_11;
            case 25: return Rez.Drawables.r15_1_12;
            case 26: return Rez.Drawables.r15_2_0;
            case 27: return Rez.Drawables.r15_2_1;
            case 28: return Rez.Drawables.r15_2_2;
            case 29: return Rez.Drawables.r15_2_3;
            case 30: return Rez.Drawables.r15_2_4;
            case 31: return Rez.Drawables.r15_2_5;
            case 32: return Rez.Drawables.r15_2_6;
            case 33: return Rez.Drawables.r15_2_7;
            case 34: return Rez.Drawables.r15_2_8;
            case 35: return Rez.Drawables.r15_2_9;
            case 36: return Rez.Drawables.r15_2_10;
            case 37: return Rez.Drawables.r15_2_11;
            case 38: return Rez.Drawables.r15_2_12;
            case 39: return Rez.Drawables.r15_3_0;
            case 40: return Rez.Drawables.r15_3_1;
            case 41: return Rez.Drawables.r15_3_2;
            case 42: return Rez.Drawables.r15_3_3;
            case 43: return Rez.Drawables.r15_3_4;
            case 44: return Rez.Drawables.r15_3_5;
            case 45: return Rez.Drawables.r15_3_6;
            case 46: return Rez.Drawables.r15_3_7;
            case 47: return Rez.Drawables.r15_3_8;
            case 48: return Rez.Drawables.r15_3_9;
            case 49: return Rez.Drawables.r15_3_10;
            case 50: return Rez.Drawables.r15_3_11;
            case 51: return Rez.Drawables.r15_3_12;
            case 52: return Rez.Drawables.r15_4_0;
            case 53: return Rez.Drawables.r15_4_1;
            case 54: return Rez.Drawables.r15_4_2;
            case 55: return Rez.Drawables.r15_4_3;
            case 56: return Rez.Drawables.r15_4_4;
            case 57: return Rez.Drawables.r15_4_5;
            case 58: return Rez.Drawables.r15_4_6;
            case 59: return Rez.Drawables.r15_4_7;
            case 60: return Rez.Drawables.r15_4_8;
            case 61: return Rez.Drawables.r15_4_9;
            case 62: return Rez.Drawables.r15_4_10;
            case 63: return Rez.Drawables.r15_4_11;
            case 64: return Rez.Drawables.r15_4_12;
            case 65: return Rez.Drawables.r15_5_0;
            case 66: return Rez.Drawables.r15_5_1;
            case 67: return Rez.Drawables.r15_5_2;
            case 68: return Rez.Drawables.r15_5_3;
            case 69: return Rez.Drawables.r15_5_4;
            case 70: return Rez.Drawables.r15_5_5;
            case 71: return Rez.Drawables.r15_5_6;
            case 72: return Rez.Drawables.r15_5_7;
            case 73: return Rez.Drawables.r15_5_8;
            case 74: return Rez.Drawables.r15_5_9;
            case 75: return Rez.Drawables.r15_5_10;
            case 76: return Rez.Drawables.r15_5_11;
            case 77: return Rez.Drawables.r15_5_12;
            case 78: return Rez.Drawables.r15_6_0;
            case 79: return Rez.Drawables.r15_6_1;
            case 80: return Rez.Drawables.r15_6_2;
            case 81: return Rez.Drawables.r15_6_3;
            case 82: return Rez.Drawables.r15_6_4;
            case 83: return Rez.Drawables.r15_6_5;
            case 84: return Rez.Drawables.r15_6_6;
            case 85: return Rez.Drawables.r15_6_7;
            case 86: return Rez.Drawables.r15_6_8;
            case 87: return Rez.Drawables.r15_6_9;
            case 88: return Rez.Drawables.r15_6_10;
            case 89: return Rez.Drawables.r15_6_11;
            case 90: return Rez.Drawables.r15_6_12;
            case 91: return Rez.Drawables.r15_7_0;
            case 92: return Rez.Drawables.r15_7_1;
            case 93: return Rez.Drawables.r15_7_2;
            case 94: return Rez.Drawables.r15_7_3;
            case 95: return Rez.Drawables.r15_7_4;
            case 96: return Rez.Drawables.r15_7_5;
            case 97: return Rez.Drawables.r15_7_6;
            case 98: return Rez.Drawables.r15_7_7;
            case 99: return Rez.Drawables.r15_7_8;
            case 100: return Rez.Drawables.r15_7_9;
            case 101: return Rez.Drawables.r15_7_10;
            case 102: return Rez.Drawables.r15_7_11;
            case 103: return Rez.Drawables.r15_7_12;
            case 104: return Rez.Drawables.r15_8_0;
            case 105: return Rez.Drawables.r15_8_1;
            case 106: return Rez.Drawables.r15_8_2;
            case 107: return Rez.Drawables.r15_8_3;
            case 108: return Rez.Drawables.r15_8_4;
            case 109: return Rez.Drawables.r15_8_5;
            case 110: return Rez.Drawables.r15_8_6;
            case 111: return Rez.Drawables.r15_8_7;
            case 112: return Rez.Drawables.r15_8_8;
            case 113: return Rez.Drawables.r15_8_9;
            case 114: return Rez.Drawables.r15_8_10;
            case 115: return Rez.Drawables.r15_8_11;
            case 116: return Rez.Drawables.r15_8_12;
            case 117: return Rez.Drawables.r15_9_0;
            case 118: return Rez.Drawables.r15_9_1;
            case 119: return Rez.Drawables.r15_9_2;
            case 120: return Rez.Drawables.r15_9_3;
            case 121: return Rez.Drawables.r15_9_4;
            case 122: return Rez.Drawables.r15_9_5;
            case 123: return Rez.Drawables.r15_9_6;
            case 124: return Rez.Drawables.r15_9_7;
            case 125: return Rez.Drawables.r15_9_8;
            case 126: return Rez.Drawables.r15_9_9;
            case 127: return Rez.Drawables.r15_9_10;
            case 128: return Rez.Drawables.r15_9_11;
            case 129: return Rez.Drawables.r15_9_12;
            case 130: return Rez.Drawables.r15_10_0;
            case 131: return Rez.Drawables.r15_10_1;
            case 132: return Rez.Drawables.r15_10_2;
            case 133: return Rez.Drawables.r15_10_3;
            case 134: return Rez.Drawables.r15_10_4;
            case 135: return Rez.Drawables.r15_10_5;
            case 136: return Rez.Drawables.r15_10_6;
            case 137: return Rez.Drawables.r15_10_7;
            case 138: return Rez.Drawables.r15_10_8;
            case 139: return Rez.Drawables.r15_10_9;
            case 140: return Rez.Drawables.r15_10_10;
            case 141: return Rez.Drawables.r15_10_11;
            case 142: return Rez.Drawables.r15_10_12;
            case 143: return Rez.Drawables.r15_11_0;
            case 144: return Rez.Drawables.r15_11_1;
            case 145: return Rez.Drawables.r15_11_2;
            case 146: return Rez.Drawables.r15_11_3;
            case 147: return Rez.Drawables.r15_11_4;
            case 148: return Rez.Drawables.r15_11_5;
            case 149: return Rez.Drawables.r15_11_6;
            case 150: return Rez.Drawables.r15_11_7;
            case 151: return Rez.Drawables.r15_11_8;
            case 152: return Rez.Drawables.r15_11_9;
            case 153: return Rez.Drawables.r15_11_10;
            case 154: return Rez.Drawables.r15_11_11;
            case 155: return Rez.Drawables.r15_11_12;
            case 156: return Rez.Drawables.r15_12_0;
            case 157: return Rez.Drawables.r15_12_1;
            case 158: return Rez.Drawables.r15_12_2;
            case 159: return Rez.Drawables.r15_12_3;
            case 160: return Rez.Drawables.r15_12_4;
            case 161: return Rez.Drawables.r15_12_5;
            case 162: return Rez.Drawables.r15_12_6;
            case 163: return Rez.Drawables.r15_12_7;
            case 164: return Rez.Drawables.r15_12_8;
            case 165: return Rez.Drawables.r15_12_9;
            case 166: return Rez.Drawables.r15_12_10;
            case 167: return Rez.Drawables.r15_12_11;
            case 168: return Rez.Drawables.r15_12_12;
            case 169: return Rez.Drawables.r15_13_0;
            case 170: return Rez.Drawables.r15_13_1;
            case 171: return Rez.Drawables.r15_13_2;
            case 172: return Rez.Drawables.r15_13_3;
            case 173: return Rez.Drawables.r15_13_4;
            case 174: return Rez.Drawables.r15_13_5;
            case 175: return Rez.Drawables.r15_13_6;
            case 176: return Rez.Drawables.r15_13_7;
            case 177: return Rez.Drawables.r15_13_8;
            case 178: return Rez.Drawables.r15_13_9;
            case 179: return Rez.Drawables.r15_13_10;
            case 180: return Rez.Drawables.r15_13_11;
            case 181: return Rez.Drawables.r15_13_12;
            case 182: return Rez.Drawables.r15_14_0;
            case 183: return Rez.Drawables.r15_14_1;
            case 184: return Rez.Drawables.r15_14_2;
            case 185: return Rez.Drawables.r15_14_3;
            case 186: return Rez.Drawables.r15_14_4;
            case 187: return Rez.Drawables.r15_14_5;
            case 188: return Rez.Drawables.r15_14_6;
            case 189: return Rez.Drawables.r15_14_7;
            case 190: return Rez.Drawables.r15_14_8;
            case 191: return Rez.Drawables.r15_14_9;
            case 192: return Rez.Drawables.r15_14_10;
            case 193: return Rez.Drawables.r15_14_11;
            case 194: return Rez.Drawables.r15_14_12;
        }
        return null;
    }

}

module StreetLabelIndex {
    function labelsAt(zoom, col, row) {
        if (zoom == 13) { return labelsAt13(col, row); }
        if (zoom == 15) { return labelsAt15(col, row); }
        return null;
    }

    function labelsAt13(col, row) {
        if (col < 0 || row < 0 || col >= 4 || row >= 4) { return null; }
        var key = col * 4 + row;
        switch (key) {
            case 2: return [[1126291, 687848, "Ronda Oeste"], [1126304, 687846, "Calle 4"], [1126232, 687846, "Calle 1"], [1126280, 687846, "Calle 3"]];
            case 4: return [[1126422, 687659, "A-99"], [1126422, 687704, "Travesia 13"]];
            case 5: return [[1126422, 687727, "Travesia 12"], [1126422, 687823, "Travesia 8"], [1126422, 687798, "Travesia 9"], [1126422, 687750, "Travesia 11"]];
            case 6: return [[1126423, 687843, "Gran Via Demo"], [1126428, 687847, "Paseo Central"], [1126422, 687894, "Travesia 5"], [1126422, 687871, "Travesia 6"]];
            case 7: return [[1126422, 687966, "Travesia 2"], [1126422, 687991, "Travesia 1"]];
            case 10: return [[1126559, 687847, "Ronda Este"], [1126446, 687846, "Calle 10"], [1126517, 687846, "Calle 13"], [1126540, 687846, "Calle 14"]];
            case 14: return [[1126588, 687846, "Calle 16"], [1126612, 687846, "Calle 17"], [1126563, 687846, "Calle 15"]];
        }
        return null;
    }

    function labelsAt15(col, row) {
        if (col < 0 || row < 0 || col >= 15 || row >= 13) { return null; }
        var key = col * 13 + row;
        switch (key) {
            case 20: return [[4504930, 2751386, "Calle 1"], [4505022, 2751386, "Calle 2"]];
            case 33: return [[4505119, 2751386, "Calle 3"]];
            case 46: return [[4505164, 2751390, "Ronda Oeste"], [4505217, 2751386, "Calle 4"]];
            case 59: return [[4505315, 2751386, "Calle 5"]];
            case 72: return [[4505499, 2751386, "Calle 7"], [4505408, 2751386, "Calle 6"]];
            case 85: return [[4505591, 2751386, "Calle 8"]];
            case 91: return [[4505689, 2750635, "A-99"]];
            case 93: return [[4505689, 2750816, "Travesia 13"]];
            case 94: return [[4505689, 2750909, "Travesia 12"]];
            case 95: return [[4505689, 2751000, "Travesia 11"], [4505689, 2751094, "Travesia 10"]];
            case 96: return [[4505689, 2751192, "Travesia 9"]];
            case 97: return [[4505689, 2751292, "Travesia 8"]];
            case 98: return [[4505690, 2751371, "Gran Via Demo"], [4505710, 2751387, "Paseo Central"], [4505689, 2751391, "Travesia 7"], [4505686, 2751386, "Calle 9"]];
            case 99: return [[4505689, 2751576, "Travesia 5"], [4505689, 2751484, "Travesia 6"]];
            case 100: return [[4505689, 2751669, "Travesia 4"]];
            case 101: return [[4505689, 2751766, "Travesia 3"]];
            case 102: return [[4505689, 2751865, "Travesia 2"]];
            case 103: return [[4505689, 2751964, "Travesia 1"]];
            case 111: return [[4505784, 2751386, "Calle 10"]];
            case 124: return [[4505882, 2751386, "Calle 11"], [4505977, 2751386, "Calle 12"]];
            case 137: return [[4506068, 2751386, "Calle 13"]];
            case 150: return [[4506237, 2751388, "Ronda Este"], [4506159, 2751386, "Calle 14"]];
            case 163: return [[4506351, 2751386, "Calle 16"], [4506253, 2751386, "Calle 15"]];
            case 176: return [[4506449, 2751386, "Calle 17"]];
        }
        return null;
    }

}
