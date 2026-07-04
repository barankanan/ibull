import 'web_boot_loader_stub.dart'
    if (dart.library.html) 'web_boot_loader_web.dart' as impl;

/// Hides the static HTML boot loader after Flutter paints its first frame.
void dismissWebBootLoader() => impl.dismissWebBootLoader();
