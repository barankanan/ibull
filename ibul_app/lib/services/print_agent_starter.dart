import 'print_agent_macos.dart';

/// What happened when the seller app asked macOS for its printer service.
enum MacPrintAgentOutcome {
  /// This build has no agent of its own; the caller uses its older path.
  notConfigured,
  ready,
  needsApproval,
  failed,
}

class MacPrintAgentResult {
  const MacPrintAgentResult(this.outcome, [this.message = '']);
  final MacPrintAgentOutcome outcome;
  final String message;
  bool get ok => outcome == MacPrintAgentOutcome.ready;
}

/// Starts the bundled printer service on macOS without anything running at
/// login. The agent is registered once (SMAppService); launchd holds the
/// bridge port and starts the bridge when the first health request arrives.
/// launchd runs at most one copy, so a second bridge cannot appear.
class MacPrintAgentStarter {
  MacPrintAgentStarter({
    required this.plistName,
    required this.isAlive,
    Future<PrintAgentStatus> Function(String plist)? status,
    Future<PrintAgentStatus> Function(String plist)? register,
    this.pollInterval = const Duration(milliseconds: 500),
    this.attempts = 40,
    Future<void> Function()? openSettings,
    this.approvalWait = Duration.zero,
    this.approvalPoll = const Duration(seconds: 1),
    this.onProgress,
  })  : _status = status ?? PrintAgentMac.status,
        _register = register ?? PrintAgentMac.register,
        _openSettings = openSettings ?? PrintAgentMac.openLoginItems;

  final String? plistName;
  final Future<bool> Function() isAlive;
  final Future<PrintAgentStatus> Function(String plist) _status;
  final Future<PrintAgentStatus> Function(String plist) _register;
  final Duration pollInterval;
  final int attempts;
  final Future<void> Function() _openSettings;

  /// How long the first-time macOS approval is waited for. Zero: report it
  /// at once (tests). The seller app waits so that, once the operator allows
  /// the service in System Settings, the start simply continues.
  final Duration approvalWait;
  final Duration approvalPoll;
  final void Function(String message)? onProgress;

  Future<MacPrintAgentResult> ensure() async {
    final plist = (plistName ?? '').trim();
    if (plist.isEmpty) {
      return const MacPrintAgentResult(MacPrintAgentOutcome.notConfigured);
    }
    var agent = await _status(plist);
    if (!agent.isEnabled && !agent.needsUserApproval) {
      agent = await _register(plist);
    }
    if (agent.needsUserApproval) {
      agent = await _waitForApproval(agent);
    }
    if (agent.needsUserApproval) {
      return MacPrintAgentResult(
        MacPrintAgentOutcome.needsApproval,
        agent.message,
      );
    }
    if (!agent.isEnabled) {
      return MacPrintAgentResult(MacPrintAgentOutcome.failed, agent.message);
    }
    onProgress?.call('Yazıcı servisi başlatılıyor...');
    // The first request wakes the bridge; a packaged bridge needs a few
    // seconds before it answers.
    for (var i = 0; i < attempts; i++) {
      if (await isAlive()) {
        return const MacPrintAgentResult(MacPrintAgentOutcome.ready);
      }
      await Future<void>.delayed(pollInterval);
    }
    return const MacPrintAgentResult(
      MacPrintAgentOutcome.failed,
      'Yazıcı servisi kayıtlı ancak yanıt vermiyor.',
    );
  }

  /// macOS asks once for permission to run the service. The System Settings
  /// page is opened for the operator and the answer is awaited; nothing is
  /// started and nothing is approved on the operator's behalf.
  Future<PrintAgentStatus> _waitForApproval(PrintAgentStatus first) async {
    if (approvalWait <= Duration.zero) return first;
    onProgress?.call(
      'Sistem Ayarları > Oturum Açma Öğeleri sayfasında İBUL Satıcı için '
      'izin verin. Onaylanınca yazıcı servisi kendiliğinden başlar.',
    );
    try {
      await _openSettings();
    } catch (_) {}
    final deadline = DateTime.now().add(approvalWait);
    var agent = first;
    while (agent.needsUserApproval && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(approvalPoll);
      agent = await _status((plistName ?? '').trim());
    }
    return agent;
  }
}
