import 'dart:io';

void main() {
  final content = File('macos/Runner/Messages.g.swift').readAsStringSync();
  final windowFile = File('macos/Runner/MainFlutterWindow.swift');
  windowFile.writeAsStringSync('\n$content', mode: FileMode.append);
  print('Appended!');
}
