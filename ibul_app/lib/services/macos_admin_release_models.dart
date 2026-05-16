class AdminCupsReleaseResult {
  const AdminCupsReleaseResult({
    required this.ok,
    required this.message,
    this.output,
    this.error,
  });

  final bool ok;
  final String message;
  final String? output;
  final String? error;
}
