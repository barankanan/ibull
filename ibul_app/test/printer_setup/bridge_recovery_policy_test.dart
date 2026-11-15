import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/bridge_manager.dart';
import 'package:ibul_app/services/bridge_recovery_policy.dart';

void main() {
  test('open port is not a healthy bridge', () {
    final decision = decideBridgeRecovery(
      healthOk: false,
      portOpen: true,
      processState: 'stopped',
    );
    expect(decision.action, BridgeRecoveryAction.sigcont);
    expect(decision.portOpenIsHealth, isFalse);
    expect(decision.replayUncertainJobs, isFalse);
    expect(decision.rewriteJobStatus, isFalse);
  });

  test('health response is the ready signal', () {
    final decision = decideBridgeRecovery(
      healthOk: true,
      portOpen: true,
      processState: 'running',
    );
    expect(decision.action, BridgeRecoveryAction.healthy);
  });

  test('restart budget stops a loop', () {
    final decision = decideBridgeRecovery(
      healthOk: false,
      portOpen: true,
      processState: 'stopped',
      sigcontAttempted: true,
      restartsInWindow: bridgeRecoveryMaxRestarts,
      secondsSinceRestart: 30,
    );
    expect(decision.action, BridgeRecoveryAction.giveUp);
    expect(decision.replayUncertainJobs, isFalse);
  });

  test('macOS T state is stopped and does not signal pid 0', () async {
    expect(classifyProcessStat('T'), 'stopped');
    expect(classifyProcessStat('TN'), 'stopped');
    expect(classifyProcessStat('S'), 'running');
    expect(await BridgeManager.resumeStoppedPid(0, stat: 'T'), isFalse);
    expect(await BridgeManager.resumeStoppedPid(1, stat: 'S'), isFalse);
  });
}
