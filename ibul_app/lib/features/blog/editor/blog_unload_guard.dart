import 'blog_unload_guard_stub.dart'
    if (dart.library.html) 'blog_unload_guard_web.dart'
    as impl;

/// Asks the browser to confirm closing/reloading the tab while [active].
void setBlogUnloadGuard(bool active) => impl.setBlogUnloadGuard(active);
