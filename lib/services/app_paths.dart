import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app_paths_stub.dart'
    if (dart.library.io) 'app_paths_io.dart' as impl;

class AppPaths {
  AppPaths._();

  /// Writable directory for temp files and exports (desktop).
  /// On web returns an in-memory pseudo path prefix (not used for Process I/O).
  static Future<String> workDir() async {
    if (kIsWeb) return 'web-temp';
    try {
      final downloads = await getDownloadsDirectory();
      if (downloads != null) return downloads.path;
    } catch (_) {}
    final docs = await getApplicationDocumentsDirectory();
    return docs.path;
  }

  static Future<String> uniqueName(String prefix, String ext) async {
    final dir = await workDir();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    if (kIsWeb) return '$prefix$stamp.$ext';
    return p.join(dir, '$prefix$stamp.$ext');
  }

  static Future<void> writeBytes(String path, List<int> bytes) =>
      impl.writeBytes(path, bytes);

  static Future<List<int>> readBytes(String path) => impl.readBytes(path);

  static Future<bool> exists(String path) => impl.exists(path);

  static Future<String?> findLatestXowcaseVideo() =>
      impl.findLatestXowcaseVideo();
}
