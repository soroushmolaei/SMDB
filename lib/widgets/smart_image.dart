import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

bool isRemoteImagePath(String path) =>
    path.startsWith('http://') || path.startsWith('https://');

/// Displays an image from either a remote URL or a local file path,
/// depending on the string format. Movie/show posters and backdrops can be
/// either (auto-fetched posters are URLs; user-picked posters may be local
/// files sitting next to the video, e.g. "Movie (2020) Poster.jpg").
class SmartImage extends StatelessWidget {
  final String path;
  final BoxFit fit;
  final Widget Function(BuildContext context)? errorBuilder;

  const SmartImage({
    super.key,
    required this.path,
    this.fit = BoxFit.cover,
    this.errorBuilder,
  });

  @override
  Widget build(BuildContext context) {
    if (isRemoteImagePath(path)) {
      return CachedNetworkImage(
        imageUrl: path,
        fit: fit,
        errorWidget: (c, u, e) =>
            errorBuilder?.call(context) ?? Container(color: Colors.white10),
      );
    }
    return Image.file(
      File(path),
      fit: fit,
      errorBuilder: (c, e, st) =>
          errorBuilder?.call(context) ?? Container(color: Colors.white10),
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
