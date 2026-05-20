// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

Future<String> saveReport(String fileName, String content) async {
  final bytes = html.Blob([content], 'text/csv;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(bytes);
  final anchor = html.AnchorElement(href: url)
    ..download = fileName
    ..style.display = 'none';

  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);

  return fileName;
}
