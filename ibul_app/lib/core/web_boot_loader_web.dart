import 'dart:html' as html;

void dismissWebBootLoader() {
  final loader = html.document.getElementById('ibul-loader');
  if (loader != null) {
    loader.classes.add('fade-out');
    Future<void>.delayed(const Duration(milliseconds: 350), () {
      loader.remove();
    });
  }
}
