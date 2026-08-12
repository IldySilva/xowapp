import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<void> writeBytes(String path, List<int> bytes) async {
  await File(path).writeAsBytes(bytes, flush: true);
}

Future<List<int>> readBytes(String path) async {
  return File(path).readAsBytes();
}

Future<bool> exists(String path) async => File(path).exists();

Future<String?> findLatestXowcaseVideo() async {
  Directory? dir;
  try {
    dir = await getDownloadsDirectory();
  } catch (_) {}
  dir ??= await getApplicationDocumentsDirectory();
  if (!dir.existsSync()) return null;

  final files = dir
      .listSync()
      .whereType<File>()
      .where((f) {
        final name = p.basename(f.path);
        return name.startsWith('xowcase_') && name.endsWith('.mp4');
      })
      .toList();
  if (files.isEmpty) return null;
  files.sort(
    (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
  );
  return files.first.path;
}
