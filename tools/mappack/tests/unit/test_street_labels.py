import os
import sys
import unittest

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
sys.path.insert(0, ROOT)

from mappack.osmread import Way
from mappack.raster import grid_for
from mappack.street_labels import abbreviate_street_name, street_label_cells


class TestStreetLabels(unittest.TestCase):
    def test_abbreviates_given_name_but_keeps_street_and_surname(self):
        self.assertEqual("Via A. Rossi", abbreviate_street_name("Via Andrea Rossi"))
        self.assertEqual("Via M. Bianchi", abbreviate_street_name("Via Mario Bianchi"))
        self.assertEqual("Via dei Georgofili", abbreviate_street_name("Via dei Georgofili"))

    def test_keeps_only_named_vehicle_roads(self):
        ways = [
            Way({"highway": "residential", "name": "Via Mario Bianchi"}, [(-0.001, 0.0), (0.001, 0.001)]),
            Way({"highway": "cycleway", "name": "Ciclabile Demo"}, [(-0.001, 0.0), (0.001, 0.001)]),
            Way({"highway": "footway", "name": "Passaggio Verde"}, [(-0.001, 0.0), (0.001, 0.001)]),
            Way({"highway": "path", "name": "Sentiero"}, [(-0.001, 0.0), (0.001, 0.001)]),
            Way({"highway": "residential"}, [(-0.001, 0.0), (0.001, 0.001)]),
        ]
        grid = grid_for((-0.01, -0.01, 0.01, 0.01), 15)
        labels = [label for cell in street_label_cells(ways, grid).values() for label in cell]
        self.assertEqual(["Via M. Bianchi"], [label.text for label in labels])

    def test_limits_each_cell_to_four_prioritized_names(self):
        kinds = ["residential", "service", "tertiary", "primary", "secondary"]
        ways = [
            Way({"highway": kind, "name": f"Via Nome {index}"}, [(-0.001, 0.0), (0.001, 0.001)])
            for index, kind in enumerate(kinds)
        ]
        grid = grid_for((-0.01, -0.01, 0.01, 0.01), 15)
        cells = street_label_cells(ways, grid)
        labels = next(iter(cells.values()))
        self.assertEqual(4, len(labels))
        self.assertNotIn("Via N. 1", [label.text for label in labels])


if __name__ == "__main__":
    unittest.main()
