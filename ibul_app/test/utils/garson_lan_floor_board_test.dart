import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/utils/garson_area_sections.dart';
import 'package:ibul_app/utils/garson_board_state.dart';

void main() {
  const tables = <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 'table-3',
      'table_number': 3,
      'area_id': 'bahce',
      'display_label': 'Bahçe 3',
    },
  ];
  const areas = <Map<String, dynamic>>[
    <String, dynamic>{'id': 'bahce', 'name': 'Bahçe'},
  ];

  Map<String, dynamic> order({DateTime? updatedAt, String? name, String? id}) {
    final at = updatedAt ?? DateTime.utc(2026, 11, 13, 18);
    return lanFloorOrderFromRecord(
      localOrderId: 'floor-bahce-3',
      tableNumber: 3,
      tableName: 'Bahçe 3',
      items: <Map<String, dynamic>>[
        <String, dynamic>{'name': name ?? 'Çorba', 'quantity': 1, 'price': 40},
      ],
      total: 40,
      printStatus: 'queued',
      updatedAt: at,
    )..['id'] = id ?? 'floor-bahce-3';
  }

  GarsonTableSectionItem cardOf(GarsonBoardState board) {
    final sections = resolveGarsonAreaSections(
      areas: areas,
      tables: tables,
      activeOrders: board.uiOrders,
    );
    return sections.sections.single.tables.single;
  }

  test('Bahçe 3 card, counters and a second waiter share one order', () {
    final host = reconcileLanFloorOrders(
      current: const GarsonBoardState(
        tables: tables,
        areas: areas,
        lastGoodTables: tables,
        lastGoodAreas: areas,
      ),
      incoming: <Map<String, dynamic>>[order()],
    );
    final again = reconcileLanFloorOrders(
      current: host,
      incoming: <Map<String, dynamic>>[order()],
    );
    final card = cardOf(again);
    final sections = resolveGarsonAreaSections(
      areas: areas,
      tables: tables,
      activeOrders: again.uiOrders,
    );
    final bundle = resolveGarsonRenderBundle(
      currentSections: sections,
      fallbackAreas: areas,
      fallbackTables: tables,
      fallbackOrders: again.uiOrders,
      tableNumbers: const <int>{},
      areaFilterKey: 'all',
      uiTablesCount: tables.length,
      hasEverRenderedBoard: true,
      initialBootstrapFinished: true,
      isRefreshing: false,
      initialLoading: false,
      storeTablesReady: true,
    );
    expect(bundle.occupiedTableCount, 1);
    expect(bundle.willShowGrid, isTrue);
    expect(card.displayLabel, 'Bahçe 3');
    expect(card.isOccupied, isTrue);
    expect(card.activeOrder?['items'], isA<List>());
    expect((card.activeOrder?['items'] as List).single['name'], 'Çorba');
    expect(card.activeOrder?['total_amount'], 40);
    expect(card.activeOrder?['print_status'], 'queued');
    expect(sections.sections.single.occupiedCount, 1);
    expect(sections.sections.single.emptyCount, 0);
    expect(again.uiOrders, hasLength(1));

    final secondWaiter = reconcileLanFloorOrders(
      current: const GarsonBoardState(tables: tables, areas: areas),
      incoming: <Map<String, dynamic>>[
        Map<String, dynamic>.from(again.uiOrders.single),
      ],
    );
    expect(cardOf(secondWaiter).isOccupied, isTrue);
    expect(secondWaiter.uiOrders, hasLength(1));
  });

  test('an older snapshot and a cloud id do not duplicate the card', () {
    final current = reconcileLanFloorOrders(
      current: const GarsonBoardState(tables: tables, areas: areas),
      incoming: <Map<String, dynamic>>[
        order(updatedAt: DateTime.utc(2026, 11, 13, 18, 5), name: 'Pide'),
      ],
    );
    final kept = reconcileLanFloorOrders(
      current: current,
      incoming: <Map<String, dynamic>>[
        order(updatedAt: DateTime.utc(2026, 11, 13, 18), name: 'Çorba'),
        order(id: 'remote-uuid', name: 'Pide'),
      ],
    );
    expect(kept.uiOrders, hasLength(1));
    expect((kept.uiOrders.single['items'] as List).single['name'], 'Pide');
    expect(cardOf(kept).isOccupied, isTrue);
  });
}
