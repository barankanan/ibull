// `dart:html` olmayan platformlar (VM testleri) için işlevsiz karşılık.
// API, `ihiz_web_location_web.dart` ile birebir aynı kalmalıdır.

class IhizWebLocation {
  const IhizWebLocation._();

  static const String adminLoginPath = '/admin/login';

  static bool get isAdminLogin => false;

  static void push(String path) {}

  static void onPopState(void Function(bool isAdminNow) handler) {}
}
