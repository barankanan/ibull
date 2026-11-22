import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:ibul_app/services/restaurant_offline/print_evidence.dart';

const seller = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
const waiter = 'cccccccc-cccc-cccc-cccc-cccccccccccc';
const ocak = '11111111-1111-1111-1111-111111111111';
const jwtSecret = 'isolated-jwt-secret-not-production';

Future<void> main(List<String> args) async {
  final base = args.isEmpty ? 'http://127.0.0.1:54321' : args.first;
  final failures = <String>[];
  Future<Map<String, dynamic>> rpc(
    String subject,
    Map<String, dynamic> body,
  ) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(
        Uri.parse('$base/rpc/create_table_order_with_print_jobs'),
      );
      request.headers.set('authorization', 'Bearer ${_jwt(subject)}');
      request.headers.contentType = ContentType.json;
      request.add(utf8.encode(jsonEncode(body)));
      final response = await request.close();
      final text = await utf8.decoder.bind(response).join();
      return <String, dynamic>{
        'status': response.statusCode,
        'text': text,
      };
    } finally {
      client.close(force: true);
    }
  }

  void check(String name, bool ok, String detail) {
    stdout.writeln('${ok ? 'PASS' : 'FAIL'} $name $detail');
    if (!ok) failures.add(name);
  }

  final legacy = createTableOrderRpcParams(
    restaurantId: seller,
    tableNumber: 1,
    items: <Map<String, dynamic>>[
      <String, dynamic>{
        'product_id': 'a',
        'name': 'Çorba',
        'quantity': 1,
        'price': 40,
        'station_id': ocak,
      },
    ],
    waiterName: 'Garson',
    jobType: 'new_order',
  );
  final legacyResult = await rpc(seller, legacy);
  check(
    'legacy-9',
    legacyResult['status'] == 200 &&
        legacyResult['text'].toString().contains('"print_disposition": "online"'),
    '${legacyResult['status']} ${legacyResult['text']}',
  );

  final synced = createTableOrderRpcParams(
    restaurantId: seller,
    tableNumber: 1,
    items: <Map<String, dynamic>>[
      <String, dynamic>{
        'product_id': 'a',
        'name': 'Çorba',
        'quantity': 1,
        'price': 40,
        'station_id': ocak,
      },
    ],
    waiterName: 'Garson',
    jobType: 'new_order',
    localOrderId: 'sync-1',
  );
  final first = await rpc(seller, synced);
  final replay = await rpc(seller, synced);
  check(
    'sync-and-replay',
    first['status'] == 200 &&
        replay['status'] == 200 &&
        replay['text'].toString().contains('"idempotent_replay": true'),
    'first=${first['status']} replay=${replay['text']}',
  );

  final changed = Map<String, dynamic>.from(synced);
  changed['p_items'] = <Map<String, dynamic>>[
    <String, dynamic>{
      'product_id': 'a',
      'name': 'Çorba',
      'quantity': 2,
      'price': 40,
      'station_id': ocak,
    },
  ];
  final conflict = await rpc(seller, changed);
  check(
    'content-conflict',
    conflict['status'] != 200 &&
        conflict['text'].toString().contains('farklı içerik'),
    '${conflict['status']} ${conflict['text']}',
  );

  final signed = await rpc(
    seller,
    createTableOrderRpcParams(
      restaurantId: seller,
      tableNumber: 1,
      items: <Map<String, dynamic>>[
        <String, dynamic>{
          'product_id': 'a',
          'name': 'Çorba',
          'quantity': 1,
          'price': 40,
          'station_id': ocak,
        },
      ],
      waiterName: 'Garson',
      jobType: 'new_order',
      localOrderId: 'signed-1',
      localPrintEvidence: 'v1.forwarded.not-a-server-signature',
    ),
  );
  check(
    'shared-secret-rejected',
    signed['status'] == 200 &&
        signed['text'].toString().contains(
          '"print_disposition": "unverified"',
        ),
    '${signed['status']} ${signed['text']}',
  );

  final plain = await rpc(
    seller,
    createTableOrderRpcParams(
      restaurantId: seller,
      tableNumber: 1,
      items: <Map<String, dynamic>>[
        <String, dynamic>{
          'product_id': 'a',
          'name': 'Çorba',
          'quantity': 1,
          'price': 40,
          'station_id': ocak,
        },
      ],
      waiterName: 'Garson',
      jobType: 'new_order',
      localOrderId: 'plain-1',
      localPrintEvidence: 'forwarded',
    ),
  );
  check(
    'plain-owner-rejected',
    plain['status'] == 200 &&
        plain['text'].toString().contains('"print_disposition": "unverified"'),
    '${plain['status']} ${plain['text']}',
  );

  final waiterCall = await rpc(
    waiter,
    createTableOrderRpcParams(
      restaurantId: seller,
      tableNumber: 1,
      items: <Map<String, dynamic>>[
        <String, dynamic>{
          'product_id': 'a',
          'name': 'Çorba',
          'quantity': 1,
          'price': 40,
          'station_id': ocak,
        },
      ],
      waiterId: waiter,
      waiterName: 'Garson',
      jobType: 'new_order',
      localOrderId: 'waiter-1',
      localPrintEvidence: 'forwarded',
    ),
  );
  check(
    'waiter-token-not-proof',
    waiterCall['status'] == 200 &&
        waiterCall['text'].toString().contains('"print_disposition": "unverified"'),
    '${waiterCall['status']} ${waiterCall['text']}',
  );

  final raceBodies = <Map<String, dynamic>>[
    createTableOrderRpcParams(
      restaurantId: seller,
      tableNumber: 1,
      items: <Map<String, dynamic>>[
        <String, dynamic>{
          'product_id': 'a',
          'name': 'Çorba',
          'quantity': 1,
          'price': 40,
          'station_id': ocak,
        },
      ],
      waiterName: 'Garson',
      jobType: 'new_order',
      localOrderId: 'race-http',
    ),
  ];
  final raced = await Future.wait(<Future<Map<String, dynamic>>>[
    rpc(seller, raceBodies.first),
    rpc(seller, raceBodies.first),
  ]);
  check(
    'concurrent-replay',
    raced.every((row) => row['status'] == 200) &&
        raced.any((row) => row['text'].toString().contains('idempotent_replay')),
    raced.map((row) => row['status']).join(','),
  );

  if (failures.isEmpty) {
    stdout.writeln('POSTGREST_PROBE_OK');
  } else {
    stderr.writeln('POSTGREST_PROBE_FAIL ${failures.join(',')}');
    exitCode = 1;
  }
}

String _jwt(String subject) {
  String part(Object value) => base64Url
      .encode(utf8.encode(jsonEncode(value)))
      .replaceAll('=', '');
  final header = part(<String, String>{'alg': 'HS256', 'typ': 'JWT'});
  final payload = part(<String, String>{
    'role': 'authenticated',
    'sub': subject,
  });
  final mac = Hmac(sha256, utf8.encode(jwtSecret)).convert(
    utf8.encode('$header.$payload'),
  );
  final signature = base64Url.encode(mac.bytes).replaceAll('=', '');
  return '$header.$payload.$signature';
}
