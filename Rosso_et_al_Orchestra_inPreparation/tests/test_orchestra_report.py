"""Verify that explorer selections route to actual independent estimates."""
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

MODULE = Path(__file__).resolve().parents[1] / 'build_orchestra_report.py'
spec = importlib.util.spec_from_file_location('orchestra_report', MODULE)
report = importlib.util.module_from_spec(spec)
spec.loader.exec_module(report)


class ReportTest(unittest.TestCase):
    def make_catalog(self, root, calibration):
        path = root / calibration / '03_Visualization' / 'magnitude'
        stage = path / 'segment_piece'
        stage.mkdir(parents=True)
        files = []
        for name in ['matrix', 'activation', 'xy_norm', 'leading', 'h2']:
            p = stage / (name + '.png')
            p.write_bytes(b'fixture')
            files.append(str(p))
        settings = {'filter_width_calibration': calibration, 'color_first': [1, 0, 0],
                    'color_last': [0, 0.5, 1], 'color_concert': [0.5, 0, 1]}
        observation = {'piece': 'carmen', 'recording': 'carmenD2-full-R1',
            'recording_label': 'D2 / R1', 'segment_index': 1, 'segment_label': 'Start',
            'ntracks': 2, 'npnts': 500, 'srate': 25, 'srate_confirmed': True,
            'timing_provenance': {'srate_confirmation_source': 'user'},
            'filter_width_calibration': calibration, 'peak_frequency': 2,
            'peak_value': 30, 'boundary_peak': False, 'peak_tie_count': 1,
            'figure_files': files[:3], 'figure_roles': ['matrix', 'activation', 'xy_norm']}
        overlay = {'piece': 'carmen', 'recording': observation['recording'],
            'title': 'Carmen', 'labels': 'Start', 'ncurves': 1, 'figure_files': files[3:]}
        (stage / 'figure_catalog.json').write_text(json.dumps({'settings': settings,
            'observations': observation, 'overlays': overlay}))
        return path

    def test_independent_calibrations_and_magnitude_roles(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            legacy = self.make_catalog(root, 'legacy')
            physical = self.make_catalog(root, 'physical')
            output = root / 'report'
            result = report.build_report([legacy, physical], output)
            self.assertEqual(result['default_calibration'], 'physical')
            self.assertEqual(result['original_figures'], 10)
            catalog = json.loads((output / 'figure_catalog.json').read_text())
            for calibration in ['legacy', 'physical']:
                observed = catalog['datasets'][calibration+':hz']['segment_piece']['observations'][0]
                self.assertEqual(observed['filter_width_calibration'], calibration)
                self.assertEqual(set(observed['figures']), {'matrix', 'activation', 'xy_norm'})
                self.assertIn('/'+calibration+'/', observed['figures']['xy_norm'])
            page = (output / 'segments.html').read_text()
            self.assertLess(page.index('id="calibration"'), page.index('<nav>'))
            self.assertIn('data-kind="xy_norm"', page)
            self.assertIn('history.replaceState', page)
            self.assertIn('disabled>Frequency / beat', page)

    def test_reject_duplicate_calibration_catalog(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            physical = self.make_catalog(root, 'physical')
            with self.assertRaisesRegex(ValueError, 'Duplicate catalog'):
                report.build_report([physical, physical], root / 'report')

    def test_reject_mislabeled_results(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            physical = self.make_catalog(root, 'physical')
            file = physical / 'segment_piece' / 'figure_catalog.json'
            catalog = json.loads(file.read_text())
            catalog['observations']['filter_width_calibration'] = 'legacy'
            file.write_text(json.dumps(catalog))
            with self.assertRaisesRegex(ValueError, 'disagrees'):
                report.build_report(physical, root / 'report')

    def test_beat_reference_is_separate_and_requires_matching_metadata(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            hz = self.make_catalog(root / 'hz', 'physical')
            beat = self.make_catalog(root / 'beat', 'physical')
            file = beat / 'segment_piece' / 'figure_catalog.json'
            catalog = json.loads(file.read_text())
            catalog['settings']['frequency_reference'] = 'beat'
            catalog['observations'].update(frequency_reference='beat', beat_frex=2,
                peak_frequency_normalized=1, spatial_display={'signed_weights': [-4, 5]})
            file.write_text(json.dumps(catalog))
            result = report.build_report([hz, beat], root / 'report')
            self.assertEqual(result['frequency_references'], ['hz', 'beat'])
            page = (root / 'report' / 'segments.html').read_text()
            self.assertNotIn('disabled>Frequency / beat', page)
            self.assertNotIn('signed_weights', page)
            full_catalog = json.loads((root / 'report' / 'figure_catalog.json').read_text())
            self.assertIn('spatial_display', full_catalog['datasets']['physical:beat']['segment_piece']['observations'][0])
            catalog['observations']['frequency_reference'] = 'hz'
            file.write_text(json.dumps(catalog))
            with self.assertRaisesRegex(ValueError, 'frequency reference disagrees'):
                report.build_report([hz, beat], root / 'report')


if __name__ == '__main__':
    unittest.main()
