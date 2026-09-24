import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

class GzipService {
  static List<int> compress(String originalData) {
    List<int> original = utf8.encode(originalData);
    List<int> compressed = gzip.encode(original);

    debugPrint('🚀 Original ${original.length} bytes');
    debugPrint('🚀 Compressed ${compressed.length} bytes');

    return compressed;
  }

  /// Inverse of [compress] — used by E2E sync to restore a downloaded,
  /// decrypted backup archive. See ADR-009.
  static String decompressToString(List<int> compressed) {
    return utf8.decode(gzip.decode(compressed));
  }
}
