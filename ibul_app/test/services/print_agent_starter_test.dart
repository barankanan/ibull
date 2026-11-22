import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/print_agent_macos.dart';
import 'package:ibul_app/services/print_agent_policy.dart';
import 'package:ibul_app/services/print_agent_starter.dart';

PrintAgentStatus _s(String status) =>
    PrintAgentStatus(ok: status == 'enabled', status: status, message: status);

void main() {
  test('a build without its own agent leaves the older path in charge', () async {
    var asked = 0;
    final result = await MacPrintAgentStarter(
      plistName: null,
      isAlive: () async => true,
      status: (_) async {
        asked++;
        return _s('enabled');
      },
    ).ensure();
    expect(result.outcome, MacPrintAgentOutcome.notConfigured);
    expect(asked, 0);
  });

  test('an enabled agent is not registered again; first request wakes it', () async {
    var registers = 0;
    var probes = 0;
    final result = await MacPrintAgentStarter(
      plistName: PrintAgentPolicy.isolatedPlistName,
      pollInterval: Duration.zero,
      isAlive: () async => ++probes >= 3,
      status: (_) async => _s('enabled'),
      register: (_) async {
        registers++;
        return _s('enabled');
      },
    ).ensure();
    expect(result.ok, isTrue);
    expect(registers, 0);
    expect(probes, 3);
  });

  test('an unregistered agent is registered once, then started', () async {
    var registers = 0;
    final result = await MacPrintAgentStarter(
      plistName: PrintAgentPolicy.isolatedPlistName,
      pollInterval: Duration.zero,
      isAlive: () async => true,
      status: (_) async => _s('notRegistered'),
      register: (_) async {
        registers++;
        return _s('enabled');
      },
    ).ensure();
    expect(result.ok, isTrue);
    expect(registers, 1);
  });

  test('waiting for the operator approval starts nothing', () async {
    var registers = 0;
    var probes = 0;
    final result = await MacPrintAgentStarter(
      plistName: PrintAgentPolicy.isolatedPlistName,
      isAlive: () async {
        probes++;
        return false;
      },
      status: (_) async => _s('requiresApproval'),
      register: (_) async {
        registers++;
        return _s('enabled');
      },
    ).ensure();
    expect(result.outcome, MacPrintAgentOutcome.needsApproval);
    expect(registers, 0);
    expect(probes, 0);
  });

  test('first-time approval is awaited; the start continues once allowed', () async {
    var statuses = 0;
    var opened = 0;
    final result = await MacPrintAgentStarter(
      plistName: PrintAgentPolicy.livePlistName,
      pollInterval: Duration.zero,
      approvalWait: const Duration(seconds: 5),
      approvalPoll: Duration.zero,
      openSettings: () async => opened++,
      isAlive: () async => true,
      status: (_) async => _s(++statuses >= 4 ? 'enabled' : 'requiresApproval'),
    ).ensure();
    expect(result.ok, isTrue);
    expect(opened, 1);
  });

  test('approval never given: reported, nothing registered or started', () async {
    var probes = 0;
    final result = await MacPrintAgentStarter(
      plistName: PrintAgentPolicy.livePlistName,
      approvalWait: const Duration(milliseconds: 30),
      approvalPoll: const Duration(milliseconds: 5),
      openSettings: () async {},
      isAlive: () async {
        probes++;
        return false;
      },
      status: (_) async => _s('requiresApproval'),
    ).ensure();
    expect(result.outcome, MacPrintAgentOutcome.needsApproval);
    expect(probes, 0);
  });

  test('a registered agent that never answers is a failure, not a hang', () async {
    final result = await MacPrintAgentStarter(
      plistName: PrintAgentPolicy.isolatedPlistName,
      pollInterval: Duration.zero,
      attempts: 4,
      isAlive: () async => false,
      status: (_) async => _s('enabled'),
    ).ensure();
    expect(result.outcome, MacPrintAgentOutcome.failed);
  });

  test('the live agent is chosen only by a build that opts in', () {
    expect(PrintAgentPolicy.plistForEnvironment(const {}, liveBuild: false), isNull);
    expect(
      PrintAgentPolicy.plistForEnvironment(const {}, liveBuild: true),
      PrintAgentPolicy.livePlistName,
    );
    expect(
      PrintAgentPolicy.plistForEnvironment(
        const {'IBUL_ISOLATED_PRINT_TEST': '1'},
        liveBuild: true,
      ),
      PrintAgentPolicy.isolatedPlistName,
    );
  });
}
