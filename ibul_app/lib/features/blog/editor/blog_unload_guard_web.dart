// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;

StreamSubscription<html.Event>? _subscription;

void setBlogUnloadGuard(bool active) {
  if (!active) {
    _subscription?.cancel();
    _subscription = null;
    return;
  }
  _subscription ??= html.window.onBeforeUnload.listen((event) {
    if (event is html.BeforeUnloadEvent) {
      event.preventDefault();
      event.returnValue = '';
    }
  });
}
