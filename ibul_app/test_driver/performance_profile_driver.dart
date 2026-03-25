import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  await integrationDriver(
    responseDataCallback: (data) async {
      await writeResponseData(
        data,
        testOutputFilename: 'performance_profile_response',
        destinationDirectory: 'build/perf_reports',
      );
    },
    writeResponseOnFailure: true,
  );
}
