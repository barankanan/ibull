import 'web_page_reload_stub.dart'
    if (dart.library.html) 'web_page_reload_web.dart' as impl;

void reloadWebPage() => impl.reloadWebPage();
