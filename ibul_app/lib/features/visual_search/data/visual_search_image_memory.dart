import 'dart:typed_data';

/// Session cache so result screens can redraw the photo after upload.
class VisualSearchImageMemory {
  VisualSearchImageMemory._();

  static final Map<String, Uint8List> _bytes = {};

  static void put(String jobId, Uint8List bytes) {
    _bytes[jobId] = bytes;
  }

  static Uint8List? get(String jobId) => _bytes[jobId];

  static void remove(String jobId) => _bytes.remove(jobId);

  static void clear() => _bytes.clear();
}
