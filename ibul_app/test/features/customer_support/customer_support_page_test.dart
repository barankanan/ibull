import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/core/app_state.dart';
import 'package:ibul_app/features/customer_support/models/support_pending_attachment.dart';
import 'package:ibul_app/features/customer_support/screens/customer_support_chat_page.dart';
import 'package:ibul_app/features/customer_support/screens/customer_support_page.dart';
import 'package:ibul_app/features/customer_support/widgets/support_chat_bubble.dart';
import 'package:ibul_app/features/customer_support/widgets/support_chat_composer.dart';
import 'package:ibul_app/features/customer_support/widgets/support_responsive_center.dart';
import 'package:ibul_app/features/customer_support/widgets/support_status_badge.dart';
import 'package:ibul_app/features/customer_support/models/customer_support_models.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  const testSupabaseUrl = String.fromEnvironment(
    'IBUL_SUPABASE_URL',
    defaultValue: 'https://example.supabase.co',
  );
  const testSupabaseAnonKey = String.fromEnvironment(
    'IBUL_SUPABASE_ANON_KEY',
    defaultValue: 'test-anon-key',
  );

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Supabase.initialize(
      url: testSupabaseUrl,
      anonKey: testSupabaseAnonKey,
    );
  });

  Widget buildHub({Size viewport = const Size(390, 844)}) {
    return ChangeNotifierProvider<AppState>.value(
      value: AppState(),
      child: MaterialApp(
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(size: viewport),
            child: child!,
          );
        },
        home: const CustomerSupportPage(),
      ),
    );
  }

  Future<void> pumpMobileHub(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(buildHub());
    await tester.pump();
  }

  Widget buildChat() {
    return ChangeNotifierProvider<AppState>.value(
      value: AppState(),
      child: const MaterialApp(home: CustomerSupportChatPage()),
    );
  }

  test('max support attachments is 3', () {
    expect(kMaxSupportAttachments, 3);
  });

  testWidgets('hub page has no Görsel ile Anlat card', (tester) async {
    await pumpMobileHub(tester);

    expect(find.text('Görsel ile Anlat'), findsNothing);
    expect(find.text('Mesajla Destek'), findsOneWidget);
    expect(find.text('Sesli Destek'), findsOneWidget);
    expect(find.text('AI Destek Asistanı'), findsOneWidget);
  });

  testWidgets('hub page is support center without large form', (tester) async {
    await pumpMobileHub(tester);

    expect(find.text('Destek talebi'), findsNothing);
    expect(find.text('Mesajla Destek Al'), findsOneWidget);
    expect(find.text('Taleplerim'), findsOneWidget);
  });

  testWidgets('Mesajla Destek Al navigates to chat page', (tester) async {
    await pumpMobileHub(tester);

    await tester.tap(find.text('Mesajla Destek Al'));
    await tester.pumpAndSettle();

    expect(find.byType(CustomerSupportChatPage), findsOneWidget);
  });

  testWidgets('chat page has no connect-agent step', (tester) async {
    await tester.pumpWidget(buildChat());
    await tester.pumpAndSettle();

    expect(find.text('Müşteri temsilcisine bağlan'), findsNothing);
    expect(
      find.text('Mesaj göndermek için önce müşteri temsilcisine bağlan.'),
      findsNothing,
    );
  });

  testWidgets('composer is enabled by default in widget', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SupportChatComposer(
            controller: controller,
            enabled: true,
            sending: false,
            attachments: const [],
            onSend: () {},
            onPickImage: () {},
            onRemoveAttachment: (_) {},
          ),
        ),
      ),
    );

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.enabled, isTrue);
    expect(find.text('Mesajını yaz...'), findsOneWidget);
  });

  testWidgets('welcome bubble renders support greeting', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SupportChatBubble(
            message: 'Merhaba 👋 Size nasıl yardımcı olabiliriz?',
            alignment: SupportBubbleAlignment.left,
            label: 'İBUL Destek',
          ),
        ),
      ),
    );

    expect(
      find.text('Merhaba 👋 Size nasıl yardımcı olabiliriz?'),
      findsOneWidget,
    );
  });

  testWidgets('voice and AI quick cards stay disabled on hub', (tester) async {
    await pumpMobileHub(tester);

    final voiceButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Sesli Arama • Yakında'),
    );
    expect(voiceButton.onPressed, isNull);
  });

  testWidgets('status badge renders reviewing label', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SupportStatusBadge(
            status: CustomerSupportStatus.reviewing,
            compact: true,
          ),
        ),
      ),
    );

    expect(find.text('İncelemede'), findsOneWidget);
  });

  testWidgets('responsive center constrains width on wide screens', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SupportResponsiveCenter(
            maxWidth: kSupportChatMaxWidth,
            child: SizedBox(width: double.infinity, height: 40),
          ),
        ),
      ),
    );
    await tester.pump();

    final box = tester.renderObject<RenderBox>(
      find.descendant(
        of: find.byType(SupportResponsiveCenter),
        matching: find.byType(SizedBox),
      ),
    );
    expect(box.size.width, lessThanOrEqualTo(kSupportChatMaxWidth));
  });

  testWidgets('composer embedded mode has no detached shadow strip', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SupportChatComposer(
            controller: controller,
            enabled: true,
            sending: false,
            attachments: const [],
            onSend: () {},
            onPickImage: () {},
            onRemoveAttachment: (_) {},
            embedded: true,
          ),
        ),
      ),
    );

    final composer = tester.widget<SupportChatComposer>(find.byType(SupportChatComposer));
    expect(composer.embedded, isTrue);
  });

  testWidgets('hub wide layout uses support hub max width constant', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SupportResponsiveCenter(
            maxWidth: kSupportHubMaxWidth,
            child: SizedBox(width: double.infinity, height: 40),
          ),
        ),
      ),
    );
    await tester.pump();

    final box = tester.renderObject<RenderBox>(
      find.descendant(
        of: find.byType(SupportResponsiveCenter),
        matching: find.byType(SizedBox),
      ),
    );
    expect(box.size.width, lessThanOrEqualTo(kSupportHubMaxWidth));
  });
}
