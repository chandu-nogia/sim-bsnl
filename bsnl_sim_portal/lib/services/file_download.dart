import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

void triggerDownload(Uint8List bytes, String filename, String mime) {
  final href = 'data:$mime;base64,${base64Encode(bytes)}';
  final anchor = web.HTMLAnchorElement()
    ..href = href
    ..download = filename
    ..style.display = 'none';
  web.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
}

Future<bool> sharePdfFile(Uint8List bytes, String filename, String title) async {
  try {
    final file = web.File(
      [bytes.toJS].toJS,
      filename,
      web.FilePropertyBag(type: 'application/pdf'),
    );
    final data = web.ShareData(
      title: title,
      text: title,
      files: [file].toJS,
    );
    if (!web.window.navigator.canShare(data)) return false;
    await web.window.navigator.share(data).toDart;
    return true;
  } catch (_) {
    return false;
  }
}

void openWhatsApp(String text) {
  final href = 'https://wa.me/?text=${Uri.encodeComponent(text)}';
  web.window.open(href, '_blank');
}
