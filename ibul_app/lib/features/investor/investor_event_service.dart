import '../../core/runtime_diagnostic_logger.dart';

class InvestorEventService {
  InvestorEventService._();

  static final InvestorEventService instance = InvestorEventService._();

  final Set<String> _seen = <String>{};

  void track(String event, {bool once = false}) {
    final key = event.trim();
    if (key.isEmpty) return;
    if (once && !_seen.add(key)) return;
    RuntimeDiagnosticLogger.investor('event=$key');
  }
}
