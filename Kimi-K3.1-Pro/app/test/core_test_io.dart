import 'dart:io';

String appRoot() {
  final directory = Directory.current.absolute;
  if (!File('${directory.path}/pubspec.yaml').existsSync()) {
    throw StateError('Tests must run from the app directory');
  }
  return directory.path;
}

String projectRoot() =>
    Directory.fromUri(Uri.directory(appRoot()).resolve('..')).absolute.path;

Directory createAgentTestDirectory(String prefix) {
  final parent = Directory('${projectRoot()}/.tmp/agent-tests');
  parent.createSync(recursive: true);
  return parent.createTempSync(prefix).absolute;
}

void deleteAgentTestDirectory(Directory directory) {
  final allowedPrefix = '${projectRoot()}/.tmp/agent-tests/';
  if (!directory.absolute.path.startsWith(allowedPrefix)) {
    throw StateError('Refusing to delete a directory outside agent-tests');
  }
  if (directory.existsSync()) directory.deleteSync(recursive: true);
}
