class UploadProgressDetails {
  const UploadProgressDetails({
    required this.progress,
    required this.bytesSent,
    required this.totalBytes,
    required this.bytesPerSecond,
    required this.eta,
    required this.isServerProcessing,
  });

  final double progress;
  final int bytesSent;
  final int totalBytes;
  final double bytesPerSecond;
  final Duration? eta;
  final bool isServerProcessing;
}
