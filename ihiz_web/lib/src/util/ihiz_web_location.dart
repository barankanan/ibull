// İHIZ URL rotası yardımcısı.
//
// Gerçek uygulama (web) `dart:html` tabanlı sürümü kullanır. VM'de (flutter
// test) `dart:html` derlenmediği için işlevsiz bir karşılık seçilir.
export 'ihiz_web_location_stub.dart'
    if (dart.library.js_interop) 'ihiz_web_location_web.dart';
