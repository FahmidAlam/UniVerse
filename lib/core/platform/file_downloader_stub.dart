import 'dart:typed_data';
import 'file_downloader_interface.dart';

class StubFileDownloader implements FileDownloader {
  @override
  Future<String?> downloadBytes({
    required Uint8List bytes,
    required String filename,
    bool openAfterDownload = true,
  }) async {
    throw UnsupportedError('Platform not supported for file download.');
  }

  @override
  Future<String?> downloadString({
    required String content,
    required String filename,
  }) async {
    throw UnsupportedError('Platform not supported for file download.');
  }
}

FileDownloader getPlatformFileDownloader() => StubFileDownloader();

