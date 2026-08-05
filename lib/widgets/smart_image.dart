import 'dart:io';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

bool isRemoteImagePath(String path) =>
    path.startsWith('http://') || path.startsWith('https://');

/// Displays an image from either a remote URL or a local file path,
/// depending on the string format. Movie/show posters and backdrops can be
/// either (auto-fetched posters are URLs; user-picked posters may be local
/// files sitting next to the video, e.g. "Movie (2020) Poster.jpg").
///
/// If [thumbnailBytes] is provided and the primary [path] fails to load —
/// most commonly because there's no internet connection — the locally
/// stored thumbnail is shown instead of a blank placeholder.
class SmartImage extends StatelessWidget {
  final String path;
  final BoxFit fit;
  final Uint8List? thumbnailBytes;
  final Widget Function(BuildContext context)? errorBuilder;

  const SmartImage({
    super.key,
    required this.path,
    this.fit = BoxFit.cover,
    this.thumbnailBytes,
    this.errorBuilder,
  });

  Widget _fallback(BuildContext context) {
    final bytes = thumbnailBytes;
    if (bytes != null) {
      return Image.memory(bytes, fit: fit);
    }
    return errorBuilder?.call(context) ?? Container(color: Colors.white10);
  }

  @override
  Widget build(BuildContext context) {
    if (isRemoteImagePath(path)) {
      return CachedNetworkImage(
        imageUrl: path,
        fit: fit,
        errorWidget: (c, u, e) => _fallback(context),
      );
    }
    return Image.file(
      File(path),
      fit: fit,
      errorBuilder: (c, e, st) => _fallback(context),
    );
  }
}

/// Same as [SmartImage] but returns an [ImageProvider], for widgets like
/// CircleAvatar that need a provider rather than a child widget.
ImageProvider smartImageProvider(String path) {
  return isRemoteImagePath(path)
      ? CachedNetworkImageProvider(path) as ImageProvider
      : FileImage(File(path));
}
