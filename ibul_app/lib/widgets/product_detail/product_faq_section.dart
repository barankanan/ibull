import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/product_detail_viewmodel.dart';

class ProductFaqSection extends StatefulWidget {
  const ProductFaqSection({super.key});

  @override
  State<ProductFaqSection> createState() => _ProductFaqSectionState();
}

class _ProductFaqSectionState extends State<ProductFaqSection> {
  final Set<int> _expandedIndexes = {};

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<ProductDetailViewModel>(context);
    final product = viewModel.initialProduct;
    final productName = product.name;
    final brand = product.brand;
    final fullName = '$brand $productName';

    final faqs = _generateFaqs(product);

    if (faqs.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            '$fullName ile İlgili Sıkça Sorulan Sorular',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),

          // FAQ items
          ...faqs.asMap().entries.map((entry) {
            final index = entry.key;
            final faq = entry.value;
            final isExpanded = _expandedIndexes.contains(index);
            final number = (index + 1).toString().padLeft(2, '0');

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[200]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    // Question row
                    InkWell(
                      onTap: () {
                        setState(() {
                          if (isExpanded) {
                            _expandedIndexes.remove(index);
                          } else {
                            _expandedIndexes.add(index);
                          }
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            // Number
                            Text(
                              number,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[400],
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Question text
                            Expanded(
                              child: Text(
                                faq['question']!,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            // Arrow icon
                            Icon(
                              isExpanded
                                  ? Icons.keyboard_arrow_up
                                  : Icons.keyboard_arrow_down,
                              color: Colors.grey[600],
                              size: 22,
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Answer (expanded)
                    AnimatedCrossFade(
                      firstChild: const SizedBox.shrink(),
                      secondChild: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(44, 0, 16, 14),
                        child: Text(
                          faq['answer']!,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                            height: 1.5,
                          ),
                        ),
                      ),
                      crossFadeState: isExpanded
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      duration: const Duration(milliseconds: 200),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  List<Map<String, String>> _generateFaqs(dynamic product) {
    final name = product.name.toString().toLowerCase();
    final brand = product.brand.toString();
    final fullName = '$brand ${product.name}';

    if (name.contains('iphone') || (brand.contains('Apple') && name.contains('phone'))) {
      return [
        {
          'question': '$fullName suya dayanıklı mı?',
          'answer':
              'Evet, $fullName IP68 sertifikasına sahiptir. 6 metreye kadar derinlikte 30 dakikaya kadar suya dayanıklıdır. Ancak su hasarı garanti kapsamında değildir.',
        },
        {
          'question': '$fullName kaç inç ekrana sahip?',
          'answer':
              '$fullName, Super Retina XDR OLED ekrana sahiptir. ${name.contains('pro max') || name.contains('plus') ? '6,7 inç' : '6,1 inç'} ekran boyutu ile geniş bir görüntüleme alanı sunar.',
        },
        {
          'question': '$fullName\'ın kamerası kaç megapiksel?',
          'answer':
              '$fullName, ${name.contains('15') || name.contains('16') || name.contains('17') ? '48 MP ana kamera' : '12 MP çift kamera'} sistemine sahiptir. Gece modu, portre modu ve sinematik video gibi gelişmiş fotoğrafçılık özellikleri sunar.',
        },
        {
          'question': '$fullName\'ın pil ömrü ne kadar?',
          'answer':
              '$fullName, normal kullanımda yaklaşık ${name.contains('pro max') ? '29 saate' : name.contains('13') ? '19 saate' : '22 saate'} kadar pil ömrü sunar. MagSafe ve Qi kablosuz şarj desteği bulunmaktadır.',
        },
      ];
    } else if (name.contains('galaxy') || brand.contains('Samsung')) {
      return [
        {
          'question': '$fullName suya dayanıklı mı?',
          'answer':
              'Evet, $fullName IP68 sertifikasına sahiptir. 1,5 metre derinlikte 30 dakikaya kadar suya ve toza karşı dayanıklıdır.',
        },
        {
          'question': '$fullName\'ın ekran boyutu nedir?',
          'answer':
              '$fullName, Dynamic AMOLED 2X ekrana sahiptir. ${name.contains('ultra') ? '6,8 inç' : '6,2 inç'} ekran boyutu ile yüksek çözünürlüklü görüntü sunar.',
        },
        {
          'question': '$fullName kaç megapiksel kameraya sahip?',
          'answer':
              '$fullName, ${name.contains('ultra') ? '200 MP ana kamera' : '50 MP ana kamera'} ile dikkat çekici fotoğraflar çekmenizi sağlar. Gece modu ve yapay zeka destekli fotoğraf düzenleme özellikleri mevcuttur.',
        },
        {
          'question': '$fullName\'ın pil kapasitesi ne kadar?',
          'answer':
              '$fullName, ${name.contains('ultra') ? '5000 mAh' : '4000 mAh'} pil kapasitesine sahiptir. 25W hızlı şarj ve kablosuz şarj desteği sunar.',
        },
      ];
    } else if (name.contains('macbook') || name.contains('laptop')) {
      return [
        {
          'question': '$fullName\'ın pil ömrü ne kadar?',
          'answer':
              '$fullName, tek şarjla 18 saate kadar pil ömrü sunar. Enerji verimli çip teknolojisi sayesinde uzun süreli kullanım imkanı sağlar.',
        },
        {
          'question': '$fullName kaç GB RAM\'e sahip?',
          'answer':
              '$fullName, birleşik bellek mimarisi ile 8 GB RAM sunmaktadır. Bu sayede çoklu uygulama kullanımında yüksek performans sağlar.',
        },
        {
          'question': '$fullName\'ın ekran boyutu nedir?',
          'answer':
              '$fullName, 13,6 inç Liquid Retina ekrana sahiptir. 500 nit parlaklık ve P3 geniş renk gamı ile profesyonel düzeyde görüntü kalitesi sunar.',
        },
        {
          'question': '$fullName ağırlığı ne kadar?',
          'answer':
              '$fullName yalnızca 1,24 kg ağırlığındadır. İnce ve hafif tasarımı sayesinde her yere kolayca taşınabilir.',
        },
      ];
    } else if (name.contains('airpods') || name.contains('kulaklık')) {
      return [
        {
          'question': '$fullName suya dayanıklı mı?',
          'answer':
              '$fullName, IPX4 ter ve suya dayanıklılık sertifikasına sahiptir. Spor yaparken veya hafif yağmurda güvenle kullanabilirsiniz.',
        },
        {
          'question': '$fullName\'ın pil ömrü ne kadar?',
          'answer':
              '$fullName, tek şarjla 6 saate kadar dinleme süresi sunar. Şarj kutusu ile birlikte toplam 30 saate kadar kullanım imkanı sağlar.',
        },
        {
          'question': '$fullName aktif gürültü engelleme özelliğine sahip mi?',
          'answer':
              'Evet, $fullName gelişmiş Aktif Gürültü Engelleme (ANC) teknolojisine sahiptir. Şeffaflık modu ile çevrenizden haberdar olabilirsiniz.',
        },
        {
          'question': '$fullName hangi cihazlarla uyumlu?',
          'answer':
              '$fullName, tüm Apple cihazları ile sorunsuz çalışır. Ayrıca Bluetooth 5.3 desteği sayesinde Android ve Windows cihazlarla da kullanılabilir.',
        },
      ];
    } else {
      // Generic FAQs
      return [
        {
          'question': '$fullName garanti kapsamında mı?',
          'answer':
              'Evet, $fullName 2 yıl üretici garantisi kapsamındadır. Garanti süresince ücretsiz teknik destek ve onarım hizmeti sunulmaktadır.',
        },
        {
          'question': '$fullName için kargo ücretsiz mi?',
          'answer':
              'Evet, $fullName siparişlerinizde kargo ücretsizdir. Siparişiniz 1-3 iş günü içerisinde adresinize teslim edilir.',
        },
        {
          'question': '$fullName iade edilebilir mi?',
          'answer':
              'Evet, $fullName teslim tarihinden itibaren 15 gün içerisinde ücretsiz iade edilebilir. Ürünün kullanılmamış ve orijinal ambalajında olması gerekmektedir.',
        },
        {
          'question': '$fullName orijinal ürün mü?',
          'answer':
              'Evet, platformumuzda satılan tüm ürünler %100 orijinaldir. $fullName yetkili distribütör garantisi ile satılmaktadır.',
        },
      ];
    }
  }
}
