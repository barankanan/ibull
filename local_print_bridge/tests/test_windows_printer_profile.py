import unittest

from local_print_bridge.windows_printer_profile import classify_windows_printer


class WindowsPrinterProfileTest(unittest.TestCase):
    def test_fax_is_not_recommended(self) -> None:
        profile = classify_windows_printer(name="Fax")
        self.assertEqual(profile.operator_tier, "not_recommended")
        self.assertEqual(profile.status_level, "warning")

    def test_generic_text_only_warning(self) -> None:
        profile = classify_windows_printer(name="Generic / Text Only")
        self.assertEqual(profile.warning_code, "generic_text_only")
        self.assertIn("ESC/POS", profile.status_message)

    def test_pos58_candidate_is_recommended(self) -> None:
        profile = classify_windows_printer(name="pos-58")
        self.assertEqual(profile.operator_tier, "pos_candidate")
        self.assertTrue(profile.recommended)

    def test_canon_office_printer_requires_test(self) -> None:
        profile = classify_windows_printer(name="Canon E410 series")
        self.assertEqual(profile.operator_tier, "normal")
        self.assertEqual(profile.status_level, "warning")


if __name__ == "__main__":
    unittest.main()
