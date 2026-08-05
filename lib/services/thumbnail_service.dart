import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

/// Downloads (or reads, for local files) a poster/backdrop and produces a
/// small JPEG thumbnail suitable for storing directly in the database as a
/// BLOB, so posters/backdrops keep showing up with no internet connection.
///
/// Every failure mode (offline, timed out, 404, corrupt image) is caught
/// and returns null rather than throwing — a missing thumbnail just means
/// the app falls back to today's behaviour (load live, show a placeholder
/// if that fails), so this must never be allowed to break a scan.
class ThumbnailService {
  static const _maxDimension = 320;
  static const _quality = 72;
  static const _timeout = Duration(seconds: 8);

  static bool _isRemote(String path) =>
      path.startsWith('http://') || path.startsWith('https://');

  static Future<Uint8List?> fetch(String? pathOrUrl) async {
    if (pathOrUrl == null || pathOrUrl.isEmpty) return null;
    try {
      final Uint8List bytes;
      if (_isRemote(pathOrUrl)) {
        final response =
            await http.get(Uri.parse(pathOrUrl)).timeout(_timeout);
        if (response.statusCode != 200) return null;
        bytes = response.bodyBytes;
      } else {
        final file = File(pathOrUrl);
        if (!await file.exists()) return null;
        bytes = await file.readAsBytes();
      }
      // Decoding + re-encoding is CPU-bound, not I/O-bound — run it on a
      // background isolate via compute() so a big batch (the Settings
      // backfill) doesn't stutter the UI thread.
      return await compute(_resize, bytes);
    } catch (_) {
      return null;
    }
  }

  static Uint8List? _resize(Uint8List bytes) {
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;
      final resized = decoded.width >= decoded.height
          ? img.copyResize(decoded, width: _maxDimension)
          : img.copyResize(decoded, height: _maxDimension);
      return Uint8List.fromList(img.encodeJpg(resized, quality: _quality));
    } catch (_) {
      return null;
    }
  }
}
