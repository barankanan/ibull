/// Recovery decision for the local print bridge.
///
/// An open port is not health. A stopped process is continued before any
/// restart. Uncertain print jobs are never replayed by this decision.
enum BridgeRecoveryAction { healthy, start, sigcont, restart, wait, giveUp, blocked }

class BridgeRecoveryDecision {
  const BridgeRecoveryDecision({
    required this.action,
    required this.reason,
  });

  final BridgeRecoveryAction action;
  final String reason;

  bool get portOpenIsHealth => false;

  bool get replayUncertainJobs => false;

  bool get rewriteJobStatus => false;
}

const int bridgeRecoveryMaxRestarts = 3;
const int bridgeRecoveryMinGapSeconds = 15;

BridgeRecoveryDecision decideBridgeRecovery({
  required bool healthOk,
  required bool portOpen,
  required String processState,
  int restartsInWindow = 0,
  bool sigcontAttempted = false,
  int? secondsSinceRestart,
}) {
  final state = processState.trim().toLowerCase();
  if (healthOk) {
    return const BridgeRecoveryDecision(
      action: BridgeRecoveryAction.healthy,
      reason: 'health_responded',
    );
  }
  if (state == 'stopped' && !sigcontAttempted) {
    return const BridgeRecoveryDecision(
      action: BridgeRecoveryAction.sigcont,
      reason: 'process_stopped_port_is_not_health',
    );
  }
  final restartBlocked =
      restartsInWindow >= bridgeRecoveryMaxRestarts ||
      (secondsSinceRestart != null &&
          secondsSinceRestart < bridgeRecoveryMinGapSeconds);
  if (state == 'stopped' && sigcontAttempted) {
    if (restartBlocked) {
      return const BridgeRecoveryDecision(
        action: BridgeRecoveryAction.giveUp,
        reason: 'stopped_process_still_unresponsive_restart_budget_exhausted',
      );
    }
    return const BridgeRecoveryDecision(
      action: BridgeRecoveryAction.restart,
      reason: 'sigcont_did_not_restore_health',
    );
  }
  if (!portOpen &&
      (state == 'absent' || state == 'zombie' || state == 'unknown')) {
    return const BridgeRecoveryDecision(
      action: BridgeRecoveryAction.start,
      reason: 'no_listener',
    );
  }
  if (portOpen && state == 'absent') {
    return const BridgeRecoveryDecision(
      action: BridgeRecoveryAction.blocked,
      reason: 'port_held_by_unidentified_process',
    );
  }
  if (portOpen || state == 'running') {
    if (restartBlocked) {
      return const BridgeRecoveryDecision(
        action: BridgeRecoveryAction.giveUp,
        reason: 'unresponsive_restart_budget_exhausted',
      );
    }
    return const BridgeRecoveryDecision(
      action: BridgeRecoveryAction.restart,
      reason: 'health_timeout_while_process_or_port_present',
    );
  }
  return const BridgeRecoveryDecision(
    action: BridgeRecoveryAction.wait,
    reason: 'state_not_actionable',
  );
}

/// macOS ``ps`` STAT. Leading ``T`` is stopped, including ``TN`` or ``TXs``.
String classifyProcessStat(String? stat) {
  final text = (stat ?? '').trim().toUpperCase();
  if (text.isEmpty || text == '-' || text == 'NONE') return 'absent';
  if (text.startsWith('T') || text.contains('STOPPED')) return 'stopped';
  if (text.startsWith('Z')) return 'zombie';
  final first = text[0];
  if ('RSIUDW'.contains(first)) return 'running';
  return 'unknown';
}
