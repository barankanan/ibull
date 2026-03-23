import '../core/config/app_feature_flags.dart';

class AiAssistantService {
  const AiAssistantService._();

  static String buildResponse(String text) {
    if (!AppFeatureFlags.enableDemoAiAssistant) {
      return 'Yapay zeka asistanı şu anda yapılandırılmadı. Lütfen daha sonra tekrar deneyin.';
    }

    final lowerText = text.toLowerCase();
    if (lowerText.contains('merhaba') || lowerText.contains('selam')) {
      return 'Merhaba! Size nasıl yardımcı olabilirim?';
    }
    if (lowerText.contains('telefon')) {
      return "Telefon modellerimiz için 'Ürün Karşılaştır' menüsünü kullanabilir veya ana sayfadaki Elektronik kategorisine göz atabilirsiniz.";
    }
    if (lowerText.contains('indirim')) {
      return "Şu anda 'Yaz Fırsatları' kapsamında %20'ye varan indirimlerimiz mevcut. Kuponlarım sayfasından detayları görebilirsiniz.";
    }
    if (lowerText.contains('saç') || lowerText.contains('şampuan')) {
      return 'Saç bakım ürünleri için Kozmetik kategorisine bakmanızı öneririm. Sizin için popüler ürünleri listeleyebilirim.';
    }
    return 'Bu mod şu anda demo yanıtlar ile çalışıyor. Gerçek yapay zeka entegrasyonu etkinleştiğinde daha kapsamlı cevaplar dönecek.';
  }
}
