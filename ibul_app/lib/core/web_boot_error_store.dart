import 'web_boot_error_store_stub.dart'
    if (dart.library.html) 'web_boot_error_store_web.dart' as impl;

void saveWebBootError({
  required String module,
  required String message,
  String? detail,
}) =>
    impl.saveWebBootError(module: module, message: message, detail: detail);

String? readLastWebBootError() => impl.readLastWebBootError();

void clearWebBootError() => impl.clearWebBootError();
