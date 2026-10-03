// Real macOS runtime check for AVM login, form input/focus, draft and
// document upload. Run:
//   flutter test integration_test/mall_runtime_test.dart -d macos \
//     --dart-define-from-file=.env \
//     --dart-define=MALL_RT_EMAIL=... --dart-define=MALL_RT_PASSWORD=...
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:ibul_app/app/app_bootstrap.dart';
import 'package:ibul_app/app/ibul_app_boot.dart';
import 'package:ibul_app/app/ibul_material_app.dart';
import 'package:ibul_app/app/ibul_router.dart';
import 'package:ibul_app/app/shared_app_widgets.dart';
import 'package:ibul_app/core/route_observer.dart';
import 'package:ibul_app/features/mall/auth/mall_auth_session.dart';
import 'package:ibul_app/features/mall/services/mall_application_repository.dart';
import 'package:ibul_app/features/mall/widgets/mall_application_form.dart';
import 'package:provider/provider.dart';

const _email = String.fromEnvironment('MALL_RT_EMAIL');
const _password = String.fromEnvironment('MALL_RT_PASSWORD');
const _wide = bool.fromEnvironment('MALL_RT_WIDE', defaultValue: true);

final _report = <String, String>{};
var _shot = 0;

void _log(String line) => debugPrint('[MALL_RT] $line');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('business step validation', (tester) async {
    tester.view.physicalSize = const Size(1440, 1400) * tester.view.devicePixelRatio;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MallApplicationWizard(
              repository: MallApplicationRepository(),
              forceSignedIn: true,
              initialStep: 1,
              onFinished: () {},
            ),
          ),
        ),
      ),
    );
    await _pumpFor(tester, const Duration(seconds: 1));
    bool shown(String message) => find.textContaining(message).evaluate().isNotEmpty;

    await _typeCheck(tester, 'v.tax_bad', 'Vergi numarası *', '21231232');
    await _typeCheck(tester, 'v.mersis_bad', 'MERSİS numarası *', '1231334');
    await _typeCheck(tester, 'v.kep_bad', 'KEP adresi', 'hatay iskenderun numune mahallesi');
    _report['v.tax_error_under_field'] = '${shown('Vergi numarası 10 veya 11 haneli olmalıdır.')}';
    _report['v.mersis_error_under_field'] = '${shown('MERSİS numarası 16 haneli olmalıdır.')}';
    _report['v.kep_error_under_field'] = '${shown('KEP adresi e-posta biçiminde')}';
    await _shotNow(tester, 'V_bad_values');

    final taxEditable = find.descendant(
      of: _textField('Vergi numarası *'),
      matching: find.byType(EditableText),
    );
    await tester.tapAt(tester.getCenter(taxEditable));
    await tester.pump();
    tester.state<EditableTextState>(taxEditable).updateEditingValue(
          const TextEditingValue(
            text: '12a34b567890123',
            selection: TextSelection.collapsed(offset: 15),
          ),
        );
    await tester.pump();
    _report['v.tax_mask'] = _fieldText(tester, 'Vergi numarası *');
    final mersisEditable = find.descendant(
      of: _textField('MERSİS numarası *'),
      matching: find.byType(EditableText),
    );
    await tester.tapAt(tester.getCenter(mersisEditable));
    await tester.pump();
    tester.state<EditableTextState>(mersisEditable).updateEditingValue(
          const TextEditingValue(
            text: 'x0123456789012345678',
            selection: TextSelection.collapsed(offset: 20),
          ),
        );
    await tester.pump();
    _report['v.mersis_mask'] = _fieldText(tester, 'MERSİS numarası *');

    await _tapReal(tester, find.widgetWithText(FilledButton, 'Devam Et'));
    await _pumpFor(tester, const Duration(milliseconds: 500));
    final legalState = tester.state<EditableTextState>(find.descendant(
      of: _textField('Şirket / ticari unvan *'),
      matching: find.byType(EditableText),
    ));
    _report['v.devam_blocked'] = '${find.text('İşletme Bilgileri').evaluate().isNotEmpty}';
    _report['v.focus_first_invalid'] = '${legalState.widget.focusNode.hasFocus}';
    _report['v.required_errors_shown'] =
        '${shown('Unvan zorunlu') && shown('Vergi dairesi zorunlu') && shown('Ticaret sicil numarası zorunlu')}';
    await _shotNow(tester, 'V_devam_blocked');

    await _typeCheck(tester, 'v.legal', 'Şirket / ticari unvan *', 'Prime AVM A.Ş.');
    await _typeCheck(tester, 'v.tax_ok', 'Vergi numarası *', _validVkn('123456789'));
    await _typeCheck(tester, 'v.office', 'Vergi dairesi *', 'İskenderun');
    await _typeCheck(tester, 'v.mersis_ok', 'MERSİS numarası *', '0123456789012345');
    await _typeCheck(tester, 'v.registry', 'Ticaret sicil numarası *', '12345');
    await _typeCheck(tester, 'v.kep_ok', 'KEP adresi', 'ornek@hs01.kep.tr');
    _report['v.errors_cleared'] =
        '${!shown('haneli olmalıdır') && !shown('zorunlu') && !shown('KEP adresi e-posta')}';
    await _tapReal(tester, find.widgetWithText(FilledButton, 'Devam Et'));
    await _pumpFor(tester, const Duration(milliseconds: 500));
    _report['v.advanced_to_avm'] = '${find.text('AVM Bilgileri').evaluate().isNotEmpty}';
    _report['v.isletme_check'] = '${find.text('✓').evaluate().length == 1}';
    await _typeCheck(tester, 'v.website', 'Web sitesi', 'primall.com');
    _report['v.website_no_error'] = '${!shown('Geçerli bir web sitesi')}';
    await _shotNow(tester, 'V_isletme_done');
    _dump();
  });

  testWidgets('mall runtime', (tester) async {
    // Same tree as the root lib/main.dart MyApp used by `flutter run -d macos`.
    await runIbulAppBootstrap(
      bootWatch: Stopwatch()..start(),
      initServicesBackground: initIbulServicesBackground,
      runAppWidget: () => runApp(
        MultiProvider(
          providers: buildAppProviders(),
          child: IbulMaterialApp(
            navigatorKey: GlobalKey<NavigatorState>(),
            includeAuthRoutes: true,
            navigatorObservers: [routeObserver, SeoRouteObserver()],
          ),
        ),
      ),
    );
    await _waitFor(tester, () => IbulGoRouterBinding.instance != null,
        label: 'router', seconds: 60);
    await _pumpFor(tester, const Duration(seconds: 3));
    if (_wide) {
      tester.view.physicalSize = const Size(1440, 1000) * tester.view.devicePixelRatio;
      addTearDown(tester.view.resetPhysicalSize);
    }
    _log('surface=${tester.view.physicalSize / tester.view.devicePixelRatio}');

    final mallSession = MallAuthSession.instance;
    await mallSession.restore();
    if (mallSession.isSignedIn) {
      await mallSession.signOut();
      await _pumpFor(tester, const Duration(seconds: 1));
    }
    final client = mallSession.client;

    // A — hub -> AVM Girişi -> /avm/giris (logged out)
    await _go(tester, '/avm');
    await _waitForFinder(tester, find.text('AVM Girişi'), label: 'hub');
    await _shotNow(tester, 'hub');
    await _tapReal(tester, find.text('AVM Girişi'));
    await _pumpFor(tester, const Duration(seconds: 1));
    _report['hub_entry_route'] = _path();
    final loginRendered = find.text('AVM Yönetici Girişi').evaluate().isNotEmpty;
    _report['login_page_rendered'] = '$loginRendered';

    // F — login inputs
    if (loginRendered) {
      await _typeCheck(tester, 'login.identifier', 'E-posta', 'mall.rt@example.com');
      await _typeCheck(tester, 'login.password', 'Şifre', 'abcdef12');
      await _shotNow(tester, 'login_typed');
    }

    // B/E — application wizard logged out
    await _go(tester, '/avm/basvuru');
    await _waitForFinder(tester, find.text('Hesap ve Yetkili'), label: 'wizard');
    await _shotNow(tester, 'wizard_logged_out');
    await _typeCheck(tester, 'account.given', 'Ad *', 'Runtime');
    await _typeCheck(tester, 'account.surname', 'Soyad *', 'Tester');
    await _typeCheck(tester, 'account.email', 'E-posta *',
        _email.isEmpty ? 'mall.rt@example.com' : _email);
    await _typeCheck(tester, 'account.phone', 'Telefon *', '5551112233');
    await _typeCheck(tester, 'account.password', 'Şifre *', 'abcdef12',
        secret: true, replaceWith: _password);
    await _typeCheck(tester, 'account.confirm', 'Şifre tekrar *', 'abcdef12',
        secret: true, replaceWith: _password);
    await _typeCheck(tester, 'account.title', 'Yetkili görevi / ünvanı *', 'Genel Müdür');
    await _shotNow(tester, 'wizard_account_typed');

    if (_email.isEmpty || _password.isEmpty) {
      _report['auth'] = 'SKIPPED (no MALL_RT_EMAIL/MALL_RT_PASSWORD)';
      _dump();
      return;
    }

    // E — inline auth keeps the wizard
    await _tapReal(tester, find.widgetWithText(FilledButton, 'Devam Et'));
    await _waitFor(tester, () {
      return find.text('İşletme Bilgileri').evaluate().isNotEmpty ||
          find.text('Giriş Yap ve Devam Et').evaluate().isNotEmpty;
    }, label: 'signup_or_signin', seconds: 30);
    if (find.text('Giriş Yap ve Devam Et').evaluate().isNotEmpty) {
      _log('existing account -> inline sign-in');
      await _tapReal(tester, find.text('Giriş Yap ve Devam Et'));
    }
    await _waitForFinder(tester, find.text('İşletme Bilgileri'),
        label: 'step1', seconds: 30);
    _report['inline_auth_route'] = _path();
    _report['inline_auth_session'] = '${client.auth.currentUser != null}';
    final uid = client.auth.currentUser!.id;

    final tax = _validVkn('123456789');
    final devam = find.widgetWithText(FilledButton, 'Devam Et');
    final taslak = find.widgetWithText(OutlinedButton, 'Taslak Kaydet');

    // A — half form: steps 1-3 filled, no documents yet
    await _typeCheck(tester, 'business.legal', 'Şirket / ticari unvan *', 'Runtime AVM A.Ş.');
    await _typeCheck(tester, 'business.tax', 'Vergi numarası *', tax, secret: true);
    await _typeCheck(tester, 'business.taxOffice', 'Vergi dairesi *', 'Çankaya');
    await _typeCheck(tester, 'business.mersis', 'MERSİS numarası *', '0123456789012345',
        secret: true);
    await _typeCheck(tester, 'business.registry', 'Ticaret sicil numarası *', '123456');
    await _tapReal(tester, devam);
    await _waitForFinder(tester, find.text('AVM Bilgileri'), label: 'step2');
    await _typeCheck(tester, 'mall.name', 'AVM adı *', 'Runtime Test AVM');
    await _typeCheck(tester, 'mall.floors', 'Kat sayısı', '4');
    await _tapReal(tester, devam);
    await _waitForFinder(tester, find.text('AVM Konumu'), label: 'step3');
    await _typeCheck(tester, 'location.city', 'Şehir *', 'Ankara');
    await _pickOption(tester, 'Ankara');
    await _pumpFor(tester, const Duration(seconds: 2));
    await _typeCheck(tester, 'location.district', 'İlçe *', 'Çankaya');
    await _pickOption(tester, 'Çankaya');
    await _pumpFor(tester, const Duration(seconds: 2));
    await _typeCheck(tester, 'location.address', 'Açık adres *',
        'Kızılırmak Mah. 1443 Cad. No:5');
    final map = find.byType(FlutterMap);
    await tester.ensureVisible(map.first);
    await _pumpFor(tester, const Duration(milliseconds: 500));
    await _tapReal(tester, map.first);
    await _pumpFor(tester, const Duration(seconds: 1));

    final editableBefore = await _editableDrafts(client, uid);
    _report['A_taslak_button_visible'] = '${taslak.evaluate().isNotEmpty}';
    await _tapReal(tester, taslak);
    await _waitFor(tester, () {
      return find.text('Başvuru taslağı kaydedildi.').evaluate().isNotEmpty ||
          find.textContaining('Taslak için zorunlu').evaluate().isNotEmpty ||
          find.textContaining('yazılamadı').evaluate().isNotEmpty;
    }, label: 'draft_save', seconds: 30);
    await _shotNow(tester, 'A_draft_saved');
    final editableAfter = await _editableDrafts(client, uid);
    _report['A_snackbar'] =
        '${find.text('Başvuru taslağı kaydedildi.').evaluate().isNotEmpty}';
    _report['A_editable_drafts_before_after'] =
        '${editableBefore.length} -> ${editableAfter.length}';
    final appId = editableAfter.isEmpty ? '' : '${editableAfter.first['id']}';
    _report['A_application_id'] = appId;
    // second save must update, not duplicate
    await _pumpFor(tester, const Duration(seconds: 4));
    await _tapReal(tester, taslak);
    await _pumpFor(tester, const Duration(seconds: 4));
    final editableAgain = await _editableDrafts(client, uid);
    _report['A_second_save_same_id'] =
        '${editableAgain.length == editableAfter.length && '${editableAgain.first['id']}' == appId}';

    // B — leave and come back
    await _go(tester, '/');
    await _pumpFor(tester, const Duration(seconds: 2));
    await _go(tester, '/avm/basvuru');
    await _waitForFinder(tester, find.text('Hesap ve Yetkili'), label: 'reentry', seconds: 30);
    final restoredTitle = _fieldText(tester, 'Yetkili görevi / ünvanı *');
    await _tapReal(tester, devam);
    await _waitForFinder(tester, find.text('İşletme Bilgileri'), label: 'reentry1', seconds: 20);
    final restoredLegal = _fieldText(tester, 'Şirket / ticari unvan *');
    final restoredOffice = _fieldText(tester, 'Vergi dairesi *');
    await _tapReal(tester, devam);
    await _waitForFinder(tester, find.text('AVM Bilgileri'), label: 'reentry2');
    final restoredName = _fieldText(tester, 'AVM adı *');
    final restoredFloors = _fieldText(tester, 'Kat sayısı');
    await _tapReal(tester, devam);
    await _waitForFinder(tester, find.text('AVM Konumu'), label: 'reentry3');
    final restoredAddress = _fieldText(tester, 'Açık adres *');
    final restoredCity = _fieldText(tester, 'Şehir *');
    _report['B_restore'] = [
      'title=${restoredTitle == 'Genel Müdür'}',
      'legal=${restoredLegal == 'Runtime AVM A.Ş.'}',
      'taxOffice=${restoredOffice == 'Çankaya'}',
      'name=${restoredName == 'Runtime Test AVM'}',
      'floors=${restoredFloors == '4'}',
      'city=${restoredCity == 'Ankara'}',
      'address=${restoredAddress.startsWith('Kızılırmak')}',
    ].join(' ');
    await _shotNow(tester, 'B_restored_location');

    // C — complete the form: all six documents
    await _tapReal(tester, devam);
    await _waitForFinder(tester, find.text('AVM Yetki Doğrulama'), label: 'forward docs');
    final pdf = await _writeRealPdf();
    FilePicker.platform = _DiskFilePicker(pdf);
    for (var i = 0; i < 6; i++) {
      final cards = find.text('Görüntüle').evaluate().length;
      final button = i == 0
          ? find.widgetWithText(FilledButton, 'Yetki Belgesi Yükle')
          : find.widgetWithText(FilledButton, 'Yükle');
      if (button.evaluate().isEmpty) break;
      await _tapReal(tester, button);
      await _waitFor(tester, () {
        return find.text('Görüntüle').evaluate().length > cards ||
            find.textContaining('yüklenemedi').evaluate().isNotEmpty ||
            find.textContaining('yazılamadı').evaluate().isNotEmpty;
      }, label: 'upload_$i', seconds: 45);
      await _pumpFor(tester, const Duration(milliseconds: 600));
    }
    _report['C_document_cards'] = '${find.text('Görüntüle').evaluate().length}';
    await _tapReal(tester, devam);
    await _waitForFinder(tester, find.text('Önizleme'), label: 'preview');
    await _pumpFor(tester, const Duration(milliseconds: 500));
    await _shotNow(tester, 'C_preview');
    final send = find.widgetWithText(FilledButton, 'Başvuruyu Gönder');
    final enabled = send.evaluate().isNotEmpty &&
        tester.widget<FilledButton>(send).onPressed != null;
    _report['C_submit_enabled'] = '$enabled';
    _report['C_ready_text'] = '${find.text('Gönderilmeye hazır').evaluate().isNotEmpty}';
    final missing = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .where((t) => t.startsWith('• '))
        .toList();
    _report['C_missing_list'] = missing.join(' ');

    // D — submit through the RPC
    if (enabled) {
      await _tapReal(tester, send);
      await _waitFor(tester, () {
        return find.text('Başvurunuz inceleniyor.').evaluate().isNotEmpty ||
            find.textContaining('gönderilemedi').evaluate().isNotEmpty ||
            find.textContaining('Başvuru eksik').evaluate().isNotEmpty ||
            find.textContaining('Belgeler başvuru').evaluate().isNotEmpty;
      }, label: 'submit', seconds: 40);
      await _shotNow(tester, 'D_submitted');
      final row = await client
          .from('mall_applications')
          .select('status,submitted_at,document_paths')
          .eq('id', appId)
          .maybeSingle();
      _report['D_status'] = '${row?['status']}';
      _report['D_submitted_at_set'] = '${row?['submitted_at'] != null}';
      _report['D_document_paths'] = '${(row?['document_paths'] as List?)?.length}';
      final docs = await client
          .from('mall_application_documents')
          .select('document_type')
          .eq('application_id', appId);
      _report['D_document_types'] =
          (docs as List).map((d) => (d as Map)['document_type']).toSet().join(',');
    }
    _dump();
  }, timeout: const Timeout(Duration(minutes: 8)));
}

String _path() => IbulGoRouterBinding.instance?.state.uri.path ?? '?';

Future<void> _go(WidgetTester tester, String path) async {
  IbulGoRouterBinding.instance!.go(path);
  await _pumpFor(tester, const Duration(milliseconds: 800));
}

Future<void> _pumpFor(WidgetTester tester, Duration total) async {
  final end = DateTime.now().add(total);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _waitFor(
  WidgetTester tester,
  bool Function() done, {
  required String label,
  int seconds = 15,
}) async {
  final end = DateTime.now().add(Duration(seconds: seconds));
  while (DateTime.now().isBefore(end)) {
    if (done()) return;
    await tester.pump(const Duration(milliseconds: 100));
  }
  await _shotNow(tester, 'timeout_$label');
  _dump();
  fail('timeout waiting for $label route=${_path()}');
}

Future<void> _waitForFinder(WidgetTester tester, Finder finder,
    {required String label, int seconds = 15}) {
  return _waitFor(tester, () => finder.evaluate().isNotEmpty,
      label: label, seconds: seconds);
}

Finder _textField(String label) {
  return find.byWidgetPredicate((widget) {
    return widget is TextField && widget.decoration?.labelText == label;
  }).last;
}

String _fieldText(WidgetTester tester, String label) {
  return tester.widget<TextField>(_textField(label)).controller?.text ?? '';
}

/// Real pointer tap through the binding hit-test (overlays included).
Future<void> _tapReal(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder.first);
  await tester.pump(const Duration(milliseconds: 100));
  await tester.tap(finder.first, warnIfMissed: true);
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _typeCheck(
  WidgetTester tester,
  String key,
  String label,
  String text, {
  bool secret = false,
  String? replaceWith,
  bool allowReadOnly = false,
}) async {
  final field = _textField(label);
  if (field.evaluate().isEmpty) {
    _report[key] = 'FIELD_NOT_FOUND';
    return;
  }
  await tester.ensureVisible(field);
  await _pumpFor(tester, const Duration(milliseconds: 200));
  final editableFinder =
      find.descendant(of: field, matching: find.byType(EditableText));
  final center = tester.getCenter(editableFinder);
  final hit = HitTestResult();
  WidgetsBinding.instance.hitTestInView(hit, center, tester.view.viewId);
  final editableRender = tester.renderObject(editableFinder);
  final reachesField = hit.path.any((entry) => entry.target == editableRender);
  final top = hit.path.isEmpty ? 'none' : hit.path.first.target.runtimeType.toString();
  final blockers = hit.path
      .map((entry) => entry.target.runtimeType.toString())
      .where((name) => name.contains('Absorb') || name.contains('Ignore') || name.contains('ModalBarrier'))
      .toSet();

  await tester.tapAt(center);
  var caret = false;
  for (var i = 0; i < 16; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    caret = caret ||
        tester.state<EditableTextState>(editableFinder).cursorCurrentlyVisible;
  }
  final state = tester.state<EditableTextState>(editableFinder);
  final focusAfterTap = state.widget.focusNode.hasFocus;
  if (!focusAfterTap) {
    _log('$key focus miss primary=${FocusManager.instance.primaryFocus} '
        'node=${state.widget.focusNode} canRequest=${state.widget.focusNode.canRequestFocus}');
  }
  final readOnly = state.widget.readOnly;

  var lostFocusAt = -1;
  final controller = state.widget.controller;
  final before = controller.text;
  final target = replaceWith ?? text;
  if (!readOnly && focusAfterTap) {
    var value = const TextEditingValue();
    state.updateEditingValue(value);
    for (var i = 0; i < target.length; i++) {
      final next = value.text + target[i];
      value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: next.length),
      );
      final live = tester.state<EditableTextState>(editableFinder);
      if (!live.widget.focusNode.hasFocus && lostFocusAt < 0) lostFocusAt = i;
      live.updateEditingValue(value);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await _pumpFor(tester, const Duration(milliseconds: 300));
  }
  final liveState = tester.state<EditableTextState>(editableFinder);
  final after = liveState.widget.controller.text;
  final sameController = identical(liveState.widget.controller, controller);
  final focusEnd = liveState.widget.focusNode.hasFocus;
  final textOk = after == target;
  final shown = secret ? 'len=${after.length}' : 'text="$after"';
  final result = [
    'hit=$reachesField',
    'top=$top',
    if (blockers.isNotEmpty) 'blockers=$blockers',
    'focusTap=$focusAfterTap',
    'caret=$caret',
    'readOnly=$readOnly',
    'lostFocusAt=$lostFocusAt',
    'focusEnd=$focusEnd',
    'sameCtrl=$sameController',
    'textOk=$textOk',
    shown,
    if (before.isNotEmpty && !secret) 'before="$before"',
  ].join(' ');
  final pass = reachesField &&
      focusAfterTap &&
      caret &&
      textOk &&
      focusEnd &&
      lostFocusAt < 0;
  _report[key] = '${pass ? 'PASS' : (readOnly && allowReadOnly ? 'READONLY' : 'FAIL')} $result';
  _log('$key $result');
}

Future<void> _pickOption(WidgetTester tester, String option) async {
  await _pumpFor(tester, const Duration(milliseconds: 400));
  final options = find.byWidgetPredicate((w) => w is Text && w.data == option);
  final candidates = options.evaluate().where((element) {
    return element.findAncestorWidgetOfExactType<EditableText>() == null;
  }).toList();
  if (candidates.isEmpty) {
    _report['option_$option'] = 'NOT_SHOWN';
    return;
  }
  await tester.tapAt(tester.getCenter(find.byElementPredicate((e) => e == candidates.last)));
  await _pumpFor(tester, const Duration(milliseconds: 400));
  _report['option_$option'] = 'selected';
}

String _validVkn(String nine) {
  final d = nine.split('').map(int.parse).toList();
  var sum = 0;
  for (var i = 0; i < 9; i++) {
    final tmp = (d[i] + 9 - i) % 10;
    var v = (tmp * (1 << (9 - i))) % 9;
    if (tmp != 0 && v == 0) v = 9;
    sum += v;
  }
  return '$nine${(10 - sum % 10) % 10}';
}

Future<File> _writeRealPdf() async {
  const body = '%PDF-1.4\n'
      '1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj\n'
      '2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj\n'
      '3 0 obj<</Type/Page/Parent 2 0 R/MediaBox[0 0 595 842]/Contents 4 0 R/Resources<</Font<</F1 5 0 R>>>>>>endobj\n'
      '4 0 obj<</Length 58>>stream\nBT /F1 18 Tf 72 760 Td (AVM Yetki Belgesi - runtime) Tj ET\nendstream endobj\n'
      '5 0 obj<</Type/Font/Subtype/Type1/BaseFont/Helvetica>>endobj\n'
      'trailer<</Root 1 0 R>>\n%%EOF\n';
  final file = File('${Directory.systemTemp.path}/yetki_belgesi.pdf');
  await file.writeAsBytes(utf8.encode(body), flush: true);
  _log('pdf=${file.path} bytes=${await file.length()}');
  return file;
}

class _DiskFilePicker extends FilePicker {
  _DiskFilePicker(this.file);
  final File file;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    _log('picker ext=$allowedExtensions withData=$withData');
    return FilePickerResult([
      PlatformFile(
        name: file.uri.pathSegments.last,
        size: file.lengthSync(),
        path: file.path,
      ),
    ]);
  }
}

Future<void> _shotNow(WidgetTester tester, String name) async {
  try {
    final view = RendererBinding.instance.renderViews.first;
    final layer = view.debugLayer! as OffsetLayer;
    final size = view.size;
    final dpr = tester.view.devicePixelRatio;
    final image = await layer.toImage(
      Offset.zero & (size * dpr),
      pixelRatio: 1 / dpr,
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('${Directory.systemTemp.path}/mall_rt_${_shot++}_$name.png');
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    _log('shot ${file.path}');
  } catch (error) {
    _log('shot failed $name $error');
  }
}

void _dump() {
  _log('==== REPORT ====');
  for (final entry in _report.entries) {
    _log('${entry.key}: ${entry.value}');
  }
}

Future<List<Map<String, dynamic>>> _editableDrafts(SupabaseClient client, String uid) async {
  final rows = await client
      .from('mall_applications')
      .select('id,status')
      .eq('applicant_user_id', uid)
      .inFilter('status', ['draft', 'needs_info'])
      .order('updated_at', ascending: false);
  return [for (final row in rows as List) Map<String, dynamic>.from(row as Map)];
}
