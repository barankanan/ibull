import 'dart:html' as html;

/// HTML boot loader'ını ilk frame'de ANINDA DOM'dan siler.
///
/// Eskiden `fade-out` sınıfı eklenip 350ms'lik `Future.delayed` ile `remove()`
/// çağrılıyordu; yani beyaz splash katmanı Flutter ilk frame'i çizdikten sonra
/// 350ms daha ekranda kalıyordu — hızlı açılışta kullanıcının gördüğü tek
/// gecikme buydu. Artık fade yok, timer yok.
///
/// `addPostFrameCallback` içinden çağrılıyor (bkz. `ibul_app_boot.dart` →
/// `_scheduleWebBootLoaderDismiss`); o noktada ilk frame'in sahnesi zaten
/// submit edilmiş oluyor, dolayısıyla loader aynı JS task'ında kaldırılıyor.
void markFlutterFirstFrame() {
  html.window.performance.mark('ibul_flutter_first_frame');
}

void recordRouteRedirectDecision(String decision) {
  try {
    html.window.sessionStorage['ibul_route_redirect'] = decision;
  } catch (_) {}
}

void dismissWebBootLoader() {
  final loader = html.document.getElementById('ibul-loader');
  if (loader == null) return;
  html.window.performance.mark('ibul_flutter_interactive');
  loader.remove();
  html.window.performance.mark('ibul_shell_removed');
}
