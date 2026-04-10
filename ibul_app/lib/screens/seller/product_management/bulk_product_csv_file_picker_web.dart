// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:typed_data';
import 'dart:html' as html;

import 'bulk_product_import_models.dart';

Future<BulkProductSelectedFile?> pickBulkProductCsvFile() {
  final Completer<BulkProductSelectedFile?> completer =
      Completer<BulkProductSelectedFile?>();
  final html.FileUploadInputElement input = html.FileUploadInputElement()
    ..accept = '.csv,text/csv'
    ..multiple = false;

  input.onChange.first.then((_) {
    final html.File? file = input.files?.isNotEmpty == true
        ? input.files!.first
        : null;
    if (file == null) {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
      return;
    }

    final html.FileReader reader = html.FileReader();
    reader.onLoadEnd.first.then((_) {
      if (completer.isCompleted) {
        return;
      }
      final Object? result = reader.result;
      if (result is ByteBuffer) {
        completer.complete(
          BulkProductSelectedFile(
            name: file.name,
            bytes: Uint8List.view(result),
          ),
        );
        return;
      }
      if (result is Uint8List) {
        completer.complete(
          BulkProductSelectedFile(name: file.name, bytes: result),
        );
        return;
      }
      completer.completeError(
        Exception('CSV dosyasi okunamadi. Lutfen tekrar deneyin.'),
      );
    });
    reader.onError.first.then((_) {
      if (!completer.isCompleted) {
        completer.completeError(
          Exception('CSV dosyasi okunurken hata olustu.'),
        );
      }
    });
    reader.readAsArrayBuffer(file);
  });

  html.window.onFocus.first.then((_) {
    Future<void>.delayed(const Duration(milliseconds: 300), () {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    });
  });

  input.click();
  return completer.future;
}
