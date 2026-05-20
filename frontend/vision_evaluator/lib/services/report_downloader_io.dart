import 'dart:io';

Future<String> saveReport(String fileName, String content) async {
  final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '_');
  final file = File('${Directory.systemTemp.path}/$safeName');
  await file.writeAsString(content);
  return file.path;
}
