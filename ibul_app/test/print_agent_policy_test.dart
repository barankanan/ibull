import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/print_agent_policy.dart';

void main() {
  test('isolated test selects only the isolated plist', () {
    expect(
      PrintAgentPolicy.plistForEnvironment({
        'IBUL_ISOLATED_PRINT_TEST': '1',
      }),
      PrintAgentPolicy.isolatedPlistName,
    );
  });

  test('normal launch does not select the live plist', () {
    expect(PrintAgentPolicy.plistForEnvironment({}), isNull);
  });

  test('isolated test wins over the live approval flag', () {
    expect(
      PrintAgentPolicy.plistForEnvironment({
        'IBUL_ALLOW_LIVE_PRINT_AGENT': '1',
        'IBUL_ISOLATED_PRINT_TEST': '1',
      }),
      PrintAgentPolicy.isolatedPlistName,
    );
  });

  test('permission and signature messages stay distinct', () {
    expect(
      PrintAgentPolicy.userMessage(status: 'requiresApproval'),
      contains('Sistem Ayarları'),
    );
    expect(
      PrintAgentPolicy.userMessage(status: 'notFound', code: 1),
      contains('İzin penceresi açılmadı'),
    );
  });
}
