from dataclasses import replace
import unittest
from local_print_bridge.config import BridgeSettings
from local_print_bridge.print_station import PrintStationConsumer


class PrintStationSizeTests(unittest.TestCase):
    def test_queued_receipt_and_kitchen_use_size_without_mutating_global_settings(self):
        base = replace(BridgeSettings.from_env(), render_mode='text', print_text_scale=1.0)
        consumer = object.__new__(PrintStationConsumer)
        consumer._settings_provider = lambda: base
        consumer._submit_bytes = lambda **kwargs: kwargs
        body = {'store_name': 'Fixture', 'table_no': '1', 'order_no': '1',
                'items': [{'name': 'Soup', 'qty': 1, 'quantity': 1, 'price': 10}]}
        for method in [consumer._print_receipt_job, consumer._print_kitchen_job]:
            normal = method(payload={**body, 'print_size': 'normal'}, selected_printer={})
            large = method(payload={**body, 'print_size': 'large'}, selected_printer={})
            self.assertEqual(large['settings'].print_text_scale, 1.20)
            self.assertIn(bytes([0x1D, 0x21, 0x01]), large['raw_bytes'])
            self.assertNotEqual(normal['raw_bytes'], large['raw_bytes'])
            self.assertEqual(base.print_text_scale, 1.0)

    def test_mixed_service_children_use_large_body_size(self):
        from local_print_bridge.models import KitchenPayload
        from local_print_bridge.raster import KitchenBitmapRenderer

        settings = replace(BridgeSettings.from_env(), print_text_scale=1.2, render_mode='image')
        payload = KitchenPayload.from_dict({
            'job_type': 'new_order',
            'title': 'MUTFAK',
            'table_number': 1,
            'items': [{
                'name': 'Karisik',
                'quantity': 1,
                'service_children': [{'name': 'Corba', 'quantity': 1}, {'name': 'Salata', 'quantity': 1}],
            }],
        })
        renderer = KitchenBitmapRenderer(settings)
        blocks = renderer._item_blocks(payload.items[0])
        children = [block for block in blocks if block.text.startswith('- ')]
        self.assertEqual([block.size for block in children], [24, 24])
        self.assertEqual(renderer._scaled_size(24), 29)
        text_settings = replace(settings, render_mode='text', print_text_scale=1.2)
        from local_print_bridge.kitchen import KitchenRenderer
        raw = KitchenRenderer(text_settings).render(payload)
        self.assertIn(bytes([0x1D, 0x21, 0x01]), raw)

    def test_mixed_service_plates_keep_quantity_and_large_text(self):
        from local_print_bridge.models import KitchenPayload
        from local_print_bridge.raster import KitchenBitmapRenderer
        from local_print_bridge.kitchen import KitchenRenderer

        payload = KitchenPayload.from_dict({
            'job_type': 'new_order',
            'title': 'MUTFAK',
            'table_number': 4,
            'items': [{
                'name': 'Karışık Servis',
                'quantity': 1,
                'plates': [{
                    'label': 'Tabak 2',
                    'items': [
                        {'name': 'Ciğer Dürüm', 'quantity': 1, 'note': 'acı'},
                        {'name': 'Ciğer Servis', 'quantity': 1},
                    ],
                }, {
                    'label': 'Tabak 3',
                    'items': [
                        {'name': 'Beyti Kebap', 'quantity': 1},
                        {'name': 'Ciğer Dürüm', 'quantity': 2, 'note': 'soğansız'},
                    ],
                }],
            }],
        })
        settings = replace(BridgeSettings.from_env(), print_text_scale=1.2, render_mode='image')
        renderer = KitchenBitmapRenderer(settings)
        blocks = renderer._item_blocks(payload.items[0])
        labels = [block.text for block in blocks if block.kind == 'text']
        self.assertIn('1x  Karışık Servis', labels)
        self.assertIn('Tabak 2', labels)
        self.assertIn('- 1x Ciğer Dürüm', labels)
        self.assertIn('- 1x Ciğer Servis', labels)
        self.assertIn('Tabak 3', labels)
        self.assertIn('- 2x Ciğer Dürüm', labels)
        self.assertIn('  Not: acı', labels)
        plate_blocks = [block for block in blocks if block.text.startswith('Tabak') or block.text.startswith('- ')]
        self.assertTrue(all(block.size == 24 for block in plate_blocks))
        self.assertEqual(renderer._scaled_size(24), 29)
        raw = KitchenRenderer(replace(settings, render_mode='text')).render(payload)
        self.assertIn('Tabak 2'.encode('cp857'), raw)
        self.assertIn(bytes([0x1D, 0x21, 0x01]), raw)
