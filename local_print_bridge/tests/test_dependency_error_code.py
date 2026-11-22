"""A missing Pillow is a bridge setup failure, not a printer or network one."""
from __future__ import annotations

import unittest

from local_print_bridge import server
from local_print_bridge.raster import PillowMissingError


class DependencyErrorCodeTests(unittest.TestCase):
    def test_missing_pillow_is_reported_as_dependency_missing(self) -> None:
        payload = server._error_response(
            PillowMissingError("Bitmap baski icin Pillow gerekir."),
            errorCode="render_failed",
            render_mode="image",
        )
        self.assertFalse(payload["ok"])
        self.assertEqual(payload["errorCode"], "dependency_missing")
        self.assertEqual(payload["error_code"], "dependency_missing")
        self.assertEqual(payload["missing_dependency"], "Pillow")
        self.assertEqual(payload["render_mode"], "image")

    def test_other_render_errors_keep_the_callers_code(self) -> None:
        payload = server._error_response(
            RuntimeError("font bozuk"), errorCode="render_failed"
        )
        self.assertEqual(payload["errorCode"], "render_failed")
        self.assertNotIn("missing_dependency", payload)

    def test_an_exception_without_a_code_gets_none(self) -> None:
        payload = server._error_response(ValueError("x"))
        self.assertNotIn("errorCode", payload)

    def test_the_error_is_still_a_runtime_error_for_older_callers(self) -> None:
        self.assertTrue(issubclass(PillowMissingError, RuntimeError))


if __name__ == "__main__":
    unittest.main()
