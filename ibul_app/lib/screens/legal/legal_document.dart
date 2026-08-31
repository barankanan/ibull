enum LegalDocumentId {
  privacy,
  terms,
  kvkk,
  about,
  contact,
  faq,
  returns,
  safeShopping,
}

class LegalDocument {
  const LegalDocument({
    required this.id,
    required this.title,
    required this.updatedLabel,
    required this.paragraphs,
  });

  final LegalDocumentId id;
  final String title;
  final String updatedLabel;
  final List<String> paragraphs;

  static LegalDocument byId(LegalDocumentId id) {
    switch (id) {
      case LegalDocumentId.privacy:
        return _privacy;
      case LegalDocumentId.terms:
        return _terms;
      case LegalDocumentId.kvkk:
        return _kvkk;
      case LegalDocumentId.about:
        return _about;
      case LegalDocumentId.contact:
        return _contact;
      case LegalDocumentId.faq:
        return _faq;
      case LegalDocumentId.returns:
        return _returns;
      case LegalDocumentId.safeShopping:
        return _safeShopping;
    }
  }
}

const _privacy = LegalDocument(
  id: LegalDocumentId.privacy,
  title: 'Gizlilik Politikası',
  updatedLabel: 'Son güncelleme: 30 Ağustos 2026',
  paragraphs: [
    'iBul, hesap, sipariş, teslimat ve destek süreçlerini yürütmek için kimlik, iletişim, adres ve işlem verilerini işler. Kart numarası ve CVV, ödeme sağlayıcısı bağlanana kadar toplanmaz ve saklanmaz.',
    'Veriler Supabase üzerinde, ilgili kullanıcının oturumu ve satıcı/işletme yetkileri kapsamında tutulur. Analitik ve hata ayıklama kayıtları kişisel veriyi mümkün olduğunca azaltır.',
    'Üçüncü taraflar (harita, bildirim, yazdırma köprüsü, kargo/kurye) yalnızca hizmetin işlemesi için gerekli ölçüde veri alır. Reklam ve analitik çerezleri varsayılan olarak zorunlu değildir.',
    'Hesap silme ve erişim talepleriniz için iletişim sayfasındaki destek kanalını kullanın. Politika metni yasal danışmanlık yerine geçmez; güncellemeler bu sayfada yayımlanır.',
  ],
);

const _terms = LegalDocument(
  id: LegalDocumentId.terms,
  title: 'Kullanım Koşulları',
  updatedLabel: 'Son güncelleme: 30 Ağustos 2026',
  paragraphs: [
    'iBul bir pazaryeri ve restoran/teslimat altyapısıdır. Tüketici, satıcı, garson, kurye ve admin yüzeyleri aynı ekosistemin parçasıdır; her yüzey kendi yetki sınırına tabidir.',
    'Ürün, stok, fiyat ve teslimat taahhütleri ilgili satıcıya aittir. Platform, siparişi iletir; ödeme sağlayıcısı bağlanmadan kartlı tahsilat tamamlanmış sayılmaz.',
    'Sahte ilan, yasaklı ürün, başkasının hesabını kullanma ve sisteme yetkisiz müdahale hesap kapatma sebebidir. Restoran içi sipariş ve yazdırma, mağaza operatörünün sorumluluğundadır.',
    'Uyuşmazlıklarda Türkiye Cumhuriyeti hukuku uygulanır. Koşulları kabul etmiyorsanız hizmeti kullanmayın.',
  ],
);

const _kvkk = LegalDocument(
  id: LegalDocumentId.kvkk,
  title: 'KVKK Aydınlatma Metni',
  updatedLabel: 'Son güncelleme: 30 Ağustos 2026',
  paragraphs: [
    'Veri sorumlusu: iBul E-Ticaret. 6698 sayılı KVKK kapsamında işlenen başlıca veriler: kimlik, iletişim, konum/adres, sipariş, destek kaydı ve yetki logları.',
    'Hukuki sebepler: sözleşmenin kurulması ve ifası, meşru menfaat (dolandırıcılık önleme, operasyon güvenliği) ve açık rıza (pazarlama iletileri).',
    'Haklarınız: KVKK m.11 uyarınca öğrenme, düzeltme, silme, itiraz ve şikayet. Talepler destek kanalından iletilir; kimlik doğrulaması istenebilir.',
    'Adres ve sipariş verileri başka kullanıcılarla paylaşılmaz. Restoran ve kurye operatörleri yalnızca kendi görevleri kapsamındaki kayıtlara erişir.',
  ],
);

const _about = LegalDocument(
  id: LegalDocumentId.about,
  title: 'Hakkımızda',
  updatedLabel: 'iBul platform metni',
  paragraphs: [
    'iBul, yerel ticaret için pazaryeri, restoran operasyonu ve İHIZ teslimatını aynı altyapıda birleştirir. Yakın lokasyon siparişi, mağazadan teslim alma ve mutfak yazdırma bu ailenin parçasıdır.',
    'Amaç, semt esnafı ve restoranların dijital siparişi kendi tezgâhlarından yönetebilmesidir. Kurye ağı İHIZ markası altında büyür; yatırımcı yüzeyi ayrı bir kurumsal sayfadır.',
    'Ürün hâlâ gelişmektedir. Kartlı ödeme sağlayıcısı bağlanmadan pazaryeri tahsilatı canlı kabul edilmez. Restoran masa/QR döngüsü üretimde kullanılır.',
  ],
);

const _contact = LegalDocument(
  id: LegalDocumentId.contact,
  title: 'İletişim',
  updatedLabel: 'Destek kanalları',
  paragraphs: [
    'Müşteri destek talepleri hesap içi Destek sayfasından biletle açılır. Giriş yapmış kullanıcılar sipariş ve iade konularını oradan takip eder.',
    'Satıcı ve restoran operasyonu için satıcı paneli içindeki destek/şikayet akışını kullanın. İHIZ kurye başvuruları İHIZ landing üzerinden alınır.',
    'Kurumsal ve yatırımcı görüşmeleri Yatırımcı İlişkileri sayfasındaki form ile iletilir. Acil mutfak/yazıcı arızalarında mağaza içi yazıcı merkezini kontrol edin.',
  ],
);

const _faq = LegalDocument(
  id: LegalDocumentId.faq,
  title: 'Sıkça Sorulan Sorular',
  updatedLabel: 'SSS',
  paragraphs: [
    'Siparişimi nasıl takip ederim? Hesabım > Siparişlerim üzerinden pazar yeri siparişlerinizi, İHIZ kodunuz varsa Kargo Takibi veya /ihiz/track sayfasından gönderinizi izlersiniz.',
    'Kart bilgilerim kaydediliyor mu? Hayır. Ödeme sağlayıcısı bağlanana kadar kart numarası toplanmaz; sipariş kartlı tahsilat olarak tamamlanmaz.',
    'İade nasıl işler? İade ve Değişim sayfasındaki süreler satıcıya göre değişir. Talep, sipariş detayı veya Destek bileti ile açılır.',
    'Satıcı veya kurye olmak istiyorum? Footer’daki Satıcı Ol ve İhız başvurularını kullanın. Onay admin panelinden yürür.',
    'Restoran masasında neden QR var? QR, garson/mutfak siparişini açar; pazaryeri kargo siparişinden ayrı bir döngüdür.',
  ],
);

const _returns = LegalDocument(
  id: LegalDocumentId.returns,
  title: 'İade ve Değişim',
  updatedLabel: 'Son güncelleme: 30 Ağustos 2026',
  paragraphs: [
    'Cayma ve iade, mesafeli satış kuralları ile satıcının kendi iade politikasına tabidir. Bozulabilir gıda ve kişiye özel ürünlerde iade sınırlı olabilir.',
    'Talep, teslimattan sonra makul sürede sipariş detayından veya Destek üzerinden açılır. Ürün kullanılmamış ve orijinal ambalajında olmalıdır; aksi halde satıcı reddedebilir.',
    'İade kargo ücreti, ayıplı üründe satıcıya aittir. İHIZ ile giden gönderilerde iade, yeni bir teslimat kaydı veya satıcı talimatı ile yürür.',
    'Restoran masa siparişleri bu iade metninin dışındadır; iptal ve düzeltme garson/mutfak akışından yapılır.',
  ],
);

const _safeShopping = LegalDocument(
  id: LegalDocumentId.safeShopping,
  title: 'Güvenli Alışveriş',
  updatedLabel: 'Alıcı koruması',
  paragraphs: [
    'iBul üzerinden alışverişte satıcı mağaza bilgisi, sipariş kaydı ve destek bileti tutulur. Kartlı ödeme, sağlayıcı bağlanıp 3D Secure devreye girene kadar açılmaz.',
    'Şüpheli satıcı, sahte ürün veya teslim edilmeyen sipariş için Destek kaydı açın. Admin, sipariş ve şikayet kayıtlarını inceleyebilir.',
    'Bağlantı HTTPS üzerindedir. Yazıcı köprüsü yalnızca mağaza yerel ağındadır; tarayıcıya kart verisi yazdırmayın.',
    'Hesabınızı paylaşmayın. Garson ve kurye rolleri ayrı yetkilendirilir.',
  ],
);
