import 'dart:io';

import 'package:flutter/services.dart';

import 'print_agent_policy.dart';

class PrintAgentStatus {
  const PrintAgentStatus({
    required this.ok,
    required this.status,
    required this.message,
    this.code,
    this.domain,
    this.detail,
  });

  final bool ok;
  final String status;
  final String message;
  final int? code;
  final String? domain;
  final String? detail;

  bool get isEnabled => status == 'enabled';
  bool get needsUserApproval =>
      status == 'requiresApproval' || status == 'launch_denied';
}

/// Flutter side of the macOS SMAppService channel.
class PrintAgentMac {
  static const MethodChannel _channel = MethodChannel(
    'com.ibul.sellerdesktop/print_agent',
  );

  static String? plistForEnvironment([Map<String, String>? env]) {
    return PrintAgentPolicy.plistForEnvironment(env ?? Platform.environment);
  }

  static Future<PrintAgentStatus> status(String plistName) {
    return _invoke('status', plistName);
  }

  static Future<PrintAgentStatus> register(String plistName) {
    return _invoke('register', plistName);
  }

  static Future<PrintAgentStatus> unregister(String plistName) {
    return _invoke('unregister', plistName);
  }

  static Future<void> openLoginItems() async {
    await _channel.invokeMethod<Object>('openLoginItems');
  }

  static Future<PrintAgentStatus> _invoke(
    String method,
    String plistName,
  ) async {
    try {
      final raw = await _channel.invokeMethod<Object>(method, {
        'plistName': plistName,
      });
      final map = raw is Map
          ? Map<String, dynamic>.from(raw)
          : const <String, dynamic>{};
      final rawMessage = map['message']?.toString() ?? '';
      final status = map['status']?.toString() ?? 'unknown';
      final code = map['code'] is int ? map['code'] as int : null;
      return PrintAgentStatus(
        ok: map['ok'] == true,
        status: status,
        message: PrintAgentPolicy.userMessage(status: status, code: code),
        code: code,
        domain: map['domain']?.toString(),
        detail: rawMessage,
      );
    } on PlatformException catch (error) {
      return PrintAgentStatus(
        ok: false,
        status: 'channel_error',
        message: 'Yazıcı servisi kaydı tamamlanamadı.',
        code: int.tryParse(error.code),
        domain: error.code,
      );
    }
  }
}
