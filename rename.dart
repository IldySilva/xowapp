import 'dart:io';

void main() {
  final filesToProcess = <File>[];
  final macosDir = Directory('macos');
  
  if (macosDir.existsSync()) {
    filesToProcess.addAll(macosDir.listSync(recursive: true).whereType<File>().where((f) {
      return f.path.endsWith('.pbxproj') || 
             f.path.endsWith('.xcscheme') || 
             f.path.endsWith('.swift') || 
             f.path.endsWith('.plist');
    }));
  }
  
  final pigeonDart = File('lib/src/messages.g.dart');
  if (pigeonDart.existsSync()) {
    filesToProcess.add(pigeonDart);
  }

  for (final file in filesToProcess) {
    var content = file.readAsStringSync();
    final newContent = content
        .replaceAll('reckerly', 'xowcase')
        .replaceAll('Reckerly', 'XowCase')
        .replaceAll('reelbrick', 'xowcase')
        .replaceAll('ReelBrick', 'XowCase');
    
    if (content != newContent) {
      file.writeAsStringSync(newContent);
      print('Updated ${file.path}');
    }
  }
}
