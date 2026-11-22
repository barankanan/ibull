import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'lan_center_discovery.dart';

const lanCenterChannelName = 'com.ibul.app/lan_center';

List<LanCenterRecord> recordsFromDiscoveryMaps(Object? raw) {
  if (raw is! List) return const <LanCenterRecord>[];
  final records = <LanCenterRecord>[];
  for (final item in raw) {
    if (item is! Map) continue;
    final host = item['host']?.toString().trim() ?? '';
    final port = int.tryParse(item['port']?.toString() ?? '');
    final restaurant = item['restaurant_id']?.toString().trim() ?? '';
    final machine = item['machine_id']?.toString().trim() ?? '';
    final fingerprint = item['fingerprint']?.toString().trim() ?? '';
    final service = item['service']?.toString().trim() ?? '';
    if (port == null || service != 'ibul-lan') continue;
    records.add(
      LanCenterRecord(
        host: host,
        port: port,
        restaurantId: restaurant,
        machineId: machine,
        fingerprint: fingerprint,
        service: service,
      ),
    );
  }
  return records;
}

List<String> instanceNamesFromBrowse(String text) {
  final names = <String>[];
  for (final line in text.split('\n')) {
    final match = RegExp(
      r'Add\s+\S+\s+\S+\s+\S+\s+_ibul-lan\._tcp\.?\s+(.+)$',
    ).firstMatch(line.trim());
    final name = match?.group(1)?.trim() ?? '';
    if (name.isNotEmpty && !names.contains(name)) names.add(name);
  }
  return names;
}

class LanCenterBrowser {
  LanCenterBrowser({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(lanCenterChannelName);

  final MethodChannel _channel;

  Future<List<LanCenterRecord>> browse() async {
    if (kIsWeb) return const <LanCenterRecord>[];
    if (Platform.isMacOS) return browseWithDnsSd();
    if (!Platform.isIOS && !Platform.isAndroid) return const <LanCenterRecord>[];
    try {
      final raw = await _channel.invokeMethod<dynamic>('browse');
      return recordsFromDiscoveryMaps(raw);
    } on MissingPluginException {
      debugPrint('[LanCenterBrowser] this build has no local network search');
      return const <LanCenterRecord>[];
    } on PlatformException catch (error) {
      debugPrint('[LanCenterBrowser] search failed: ${error.code}');
      return const <LanCenterRecord>[];
    }
  }
}

Future<List<LanCenterRecord>> browseWithDnsSd({
  Duration budget = const Duration(seconds: 2),
}) async {
  final browse = await Process.start('dns-sd', <String>[
    '-B',
    '_ibul-lan._tcp',
    'local.',
  ]);
  final text = StringBuffer();
  final subscription = browse.stdout
      .transform(utf8.decoder)
      .listen(text.write);
  await Future<void>.delayed(budget);
  browse.kill();
  await subscription.cancel();
  final records = <LanCenterRecord>[];
  for (final name in instanceNamesFromBrowse(text.toString())) {
    final lookup = await Process.start('dns-sd', <String>[
      '-L',
      name,
      '_ibul-lan._tcp',
      'local.',
    ]);
    final found = StringBuffer();
    final listen = lookup.stdout.transform(utf8.decoder).listen(found.write);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    lookup.kill();
    await listen.cancel();
    final parsed = parseLanLookup(found.toString());
    if (parsed != null) records.add(parsed);
  }
  return records;
}
