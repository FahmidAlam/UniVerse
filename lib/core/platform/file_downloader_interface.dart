import 'dart:typed_data';

abstract class FileDownloader {
  Future<String?> downloadBytes({
    required Uint8List bytes,
    required String filename,
    bool openAfterDownload = true,
  });

  Future<String?> downloadString({
    required String content,
    required String filename,
  });
}

