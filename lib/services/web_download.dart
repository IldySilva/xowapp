import 'web_download_stub.dart'
    if (dart.library.html) 'web_download_web.dart' as impl;

Future<void> downloadBytes(List<int> bytes, String filename) =>
    impl.downloadBytes(bytes, filename);

Future<void> downloadUrl(String url, String filename) =>
    impl.downloadUrl(url, filename);
