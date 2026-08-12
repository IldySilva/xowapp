Future<void> writeBytes(String path, List<int> bytes) async {
  throw UnsupportedError('File I/O is not available on this platform');
}

Future<List<int>> readBytes(String path) async {
  throw UnsupportedError('File I/O is not available on this platform');
}

Future<bool> exists(String path) async => false;

Future<String?> findLatestXowcaseVideo() async => null;
