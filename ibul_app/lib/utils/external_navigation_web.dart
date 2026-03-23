// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;

class ExternalNavigation {
  static bool openIhizSite() {
    final host = html.window.location.host;
    final isLocalHost =
        host.contains('localhost') || host.contains('127.0.0.1');
    final targetUrl = isLocalHost
        ? 'http://localhost:8081'
        : 'https://ihiz.com';
    html.window.open(targetUrl, '_blank');
    return true;
  }
}
