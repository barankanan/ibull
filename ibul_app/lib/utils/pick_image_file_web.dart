// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:typed_data';
import 'dart:html' as html;

import 'pick_image_file_models.dart';

/// Web: gizli `<input type="file">` — diyalog içinde image_picker/file_picker güvenilir değil.
Future<List<PickedImageFile>> pickImageFiles({
  bool allowMultiple = false,
}) async {
  final Completer<List<PickedImageFile>> completer =
      Completer<List<PickedImageFile>>();
  final html.FileUploadInputElement input = html.FileUploadInputElement()
    ..accept = 'image/jpeg,image/png,image/webp,image/gif,image/*'
    ..multiple = allowMultiple
    ..style.display = 'none';

  void cleanup() {
    input.remove();
  }

  input.onChange.first.then((_) {
    final files = input.files;
    if (files == null || files.isEmpty) {
      if (!completer.isCompleted) {
        completer.complete(const <PickedImageFile>[]);
      }
      cleanup();
      return;
    }
    Future.wait(files.map(_readPickedImageFile)).then((pickedFiles) {
      if (!completer.isCompleted) {
        completer.complete(pickedFiles);
      }
      cleanup();
    }).catchError((_) {
      if (!completer.isCompleted) {
        completer.completeError(
          Exception('Görsel okunurken hata oluştu.'),
        );
      }
      cleanup();
    });
  });

  html.window.onFocus.first.then((_) {
    // Some browsers restore window focus before the input change event fires.
    // Give the picker enough time to populate `input.files` before treating it
    // as a cancellation.
    Future<void>.delayed(const Duration(milliseconds: 1500), () {
      if (!completer.isCompleted) {
        final files = input.files;
        if (files == null || files.isEmpty) {
          completer.complete(const <PickedImageFile>[]);
        }
        cleanup();
      }
    });
  });

  html.document.body?.append(input);
  input.click();
  return completer.future;
}

Future<PickedImageFile?> pickImageFile() async {
  final files = await pickImageFiles();
  if (files.isEmpty) return null;
  return files.first;
}

Future<PickedImageFile> _readPickedImageFile(html.File file) async {
  final html.FileReader reader = html.FileReader();
  final completer = Completer<PickedImageFile>();

  reader.onLoadEnd.first.then((_) {
    final Object? result = reader.result;
    Uint8List? bytes;
    if (result is ByteBuffer) {
      bytes = Uint8List.view(result);
    } else if (result is Uint8List) {
      bytes = result;
    }
    if (bytes == null || bytes.isEmpty) {
      completer.completeError(
        Exception('Görsel okunamadı. Lütfen tekrar deneyin.'),
      );
      return;
    }
    completer.complete(
      PickedImageFile(
        name: file.name.trim().isNotEmpty ? file.name : 'image.jpg',
        bytes: bytes,
      ),
    );
  });
  reader.onError.first.then((_) {
    completer.completeError(
      Exception('Görsel okunurken hata oluştu.'),
    );
  });
  reader.readAsArrayBuffer(file);
  return completer.future;
}
