import 'dart:io';
import 'dart:typed_data';

import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import 'file_downloader_interface.dart';

class PlatformFileDownloader implements FileDownloader {
  final Future<Directory> Function()? _temporaryDirectory;
  final Future<Directory> Function()? _documentsDirectory;
  final Future<void> Function(String)? _openFile;

  PlatformFileDownloader({
    Future<Directory> Function()? temporaryDirectory,
    Future<Directory> Function()? documentsDirectory,
    Future<void> Function(String)? openFile,
  })  : _temporaryDirectory = temporaryDirectory,
        _documentsDirectory = documentsDirectory,
        _openFile = openFile;

  @override
  Future<String?> downloadBytes({
    required Uint8List bytes,
    required String filename,
    bool openAfterDownload = true,
  }) async {
    final tempGetter = _temporaryDirectory;
    final dir =
        tempGetter != null ? await tempGetter() : await getTemporaryDirectory();
    final path = '${dir.path}/$filename';
    await File(path).writeAsBytes(bytes, flush: true);
    if (openAfterDownload) {
      final opener = _openFile;
      if (opener != null) {
        await opener(path);
      } else {
        await OpenFilex.open(path);
      }
    }
    return path;
  }

  @override
  Future<String?> downloadString({
    required String content,
    required String filename,
  }) async {
    final docGetter = _documentsDirectory;
    final dir = docGetter != null
        ? await docGetter()
        : await getApplicationDocumentsDirectory();
    final path = '${dir.path}/$filename';
    await File(path).writeAsString(content, flush: true);
    return path;
  }
}

FileDownloader getPlatformFileDownloader() => PlatformFileDownloader();
