// A print job goes back to `pending` (where the hub sends it again) only
// when the failure proves nothing reached the printer. Anything that may
// already be on paper stays failed and waits for the operator.
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/order_print_job_service.dart';

void main() {
  bool notSent(String text) =>
      OrderPrintJobService.printFailureIsCertainlyNotSent(text);

  test('bridge never reached: may be queued again', () {
    expect(notSent('SocketException: Connection refused (errno = 61)'), isTrue);
    expect(notSent('ClientException: Failed host lookup: printbridge'), isTrue);
  });

  test('timeouts are never proof that nothing was sent', () {
    expect(notSent('TimeoutException after 0:00:05.000000'), isFalse);
    expect(notSent('LocalPrintServiceException errorCode: client_timeout'), isFalse);
    expect(notSent('bridge 500 errorCode: tcp_timeout'), isFalse);
    expect(notSent('Connection refused then timed out'), isFalse);
  });

  test('a broken or reset connection may have carried the ticket', () {
    expect(notSent('SocketException: Connection reset by peer'), isFalse);
    expect(notSent('SocketException: Broken pipe'), isFalse);
    expect(notSent('Connection closed before full header was received'), isFalse);
    expect(notSent('SocketException: OS Error'), isFalse);
  });

  test('a bridge answer that names an uncertain write is never queued', () {
    expect(
      notSent('connection refused write_may_have_started=true'),
      isFalse,
    );
    expect(notSent('409 print_outcome_uncertain'), isFalse);
    expect(notSent('Gönderim belirsiz'), isFalse);
  });

  test('ordinary application errors are not connection errors', () {
    expect(notSent('HTTP 400 invalid payload'), isFalse);
    expect(notSent(''), isFalse);
  });
}
