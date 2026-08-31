import unittest

from local_print_bridge.print_layout import (
    PRINT_SIZE_SCALES,
    default_bottom_feed_lines,
    default_cut_feed_lines,
    default_policy_for_paper,
    default_raster_bottom_padding_px,
    receipt_length_ab_max_fields,
    receipt_length_ab_min_fields,
    resolve_bottom_feed_lines,
    resolve_cut_feed_lines,
    resolve_min_receipt_height_px,
    resolve_print_text_scale,
    resolve_raster_bottom_padding_px,
    resolve_tail_padding_policy,
)
from local_print_bridge.receipt import _cut, _feed, append_trailing_feed_and_cut


class PrintLayoutTests(unittest.TestCase):
    def test_default_bottom_feed_lines_by_paper_width(self) -> None:
        self.assertEqual(default_bottom_feed_lines(80), 5)
        self.assertEqual(default_bottom_feed_lines(58), 6)
        self.assertEqual(default_cut_feed_lines(80), 4)
        self.assertEqual(default_cut_feed_lines(58), 5)
        self.assertEqual(default_raster_bottom_padding_px(80), 100)
        self.assertEqual(default_raster_bottom_padding_px(58), 90)

    def test_default_policy_normal_presets(self) -> None:
        policy80 = default_policy_for_paper(80)
        policy58 = default_policy_for_paper(58)
        self.assertEqual(policy80.bottom_feed_lines, 5)
        self.assertEqual(policy80.min_receipt_height_px, 560)
        self.assertEqual(policy58.bottom_feed_lines, 6)
        self.assertEqual(policy58.min_receipt_height_px, 520)

    def test_resolve_short_normal_long_presets(self) -> None:
        short = resolve_tail_padding_policy(80, {"receipt_length": "short"})
        normal = resolve_tail_padding_policy(80, {"receipt_length": "normal"})
        long = resolve_tail_padding_policy(80, {"receipt_length": "long"})
        self.assertLess(short.bottom_feed_lines, normal.bottom_feed_lines)
        self.assertLess(normal.bottom_feed_lines, long.bottom_feed_lines)

    def test_resolve_custom_bottom_feed_lines(self) -> None:
        policy = resolve_tail_padding_policy(
            80,
            {
                "receipt_length": "custom",
                "bottom_feed_lines": 20,
                "cut_feed_lines": 12,
                "min_receipt_height_px": 1000,
            },
        )
        self.assertEqual(policy.receipt_length_preset, "custom")
        self.assertEqual(policy.bottom_feed_lines, 20)
        self.assertEqual(policy.min_receipt_height_px, 1000)

    def test_resolve_custom_min_receipt_height_px(self) -> None:
        policy = resolve_tail_padding_policy(
            58,
            {
                "receipt_length": "custom",
                "receipt_min_receipt_height_px": 880,
                "receipt_bottom_padding_px": 220,
            },
        )
        self.assertEqual(policy.min_receipt_height_px, 880)
        self.assertEqual(policy.bottom_padding_px, 220)
        self.assertEqual(policy.policy_source, "custom")

    def test_short_preset_policy_source(self) -> None:
        policy = resolve_tail_padding_policy(80, {"receipt_length": "short"})
        self.assertEqual(policy.receipt_length_preset, "short")
        self.assertEqual(policy.policy_source, "preset")

    def test_print_size_defaults_to_normal(self) -> None:
        preset, scale = resolve_print_text_scale({})
        self.assertEqual(preset, "normal")
        self.assertEqual(scale, 1.0)
        self.assertEqual(PRINT_SIZE_SCALES["normal"], 1.0)

    def test_print_size_presets(self) -> None:
        self.assertEqual(resolve_print_text_scale({"print_size": "small"}), ("small", 0.85))
        self.assertEqual(resolve_print_text_scale({"print_size": "large"}), ("large", 1.20))
        self.assertEqual(resolve_print_text_scale({"print_size": "xlarge"}), ("xlarge", 1.40))

    def test_print_size_from_nested_printer(self) -> None:
        preset, scale = resolve_print_text_scale(
            {"printer": {"print_size": "large", "print_text_scale": 1.20}}
        )
        self.assertEqual(preset, "large")
        self.assertEqual(scale, 1.20)

    def test_append_trailing_feed_before_cut(self) -> None:
        chunks: list[bytes] = [b"CONTENT"]
        append_trailing_feed_and_cut(
            chunks,
            cut_mode="partial",
            bottom_feed_lines=8,
            cut_feed_lines=6,
        )
        self.assertEqual(chunks[0], b"CONTENT")
        self.assertEqual(chunks[1], _feed(8))
        self.assertEqual(chunks[2], _feed(6))
        self.assertEqual(chunks[3], _cut("partial"))

    def test_custom_zero_values_not_overridden(self) -> None:
        policy = resolve_tail_padding_policy(
            80,
            {
                "receipt_length": "custom",
                "bottom_feed_lines": 0,
                "cut_feed_lines": 0,
                "min_trailing_blank_lines": 0,
                "bottom_padding_px": 0,
                "min_receipt_height_px": 0,
            },
        )
        self.assertEqual(policy.bottom_feed_lines, 0)
        self.assertEqual(policy.min_receipt_height_px, 0)
        self.assertEqual(policy.bottom_padding_px, 0)

    def test_ab_min_and_max_policies_differ(self) -> None:
        ab_min = resolve_tail_padding_policy(80, receipt_length_ab_min_fields())
        ab_max = resolve_tail_padding_policy(80, receipt_length_ab_max_fields())
        self.assertEqual(ab_min.min_receipt_height_px, 0)
        self.assertEqual(ab_max.min_receipt_height_px, 1400)
        self.assertLess(ab_min.bottom_padding_px, ab_max.bottom_padding_px)

    def test_short_preset_is_shorter_than_normal(self) -> None:
        short = resolve_tail_padding_policy(80, {"receipt_length": "short"})
        normal = resolve_tail_padding_policy(80, {"receipt_length": "normal"})
        self.assertEqual(short.bottom_feed_lines, 2)
        self.assertEqual(normal.bottom_feed_lines, 5)
        self.assertLess(short.min_receipt_height_px, normal.min_receipt_height_px)


if __name__ == "__main__":
    unittest.main()
