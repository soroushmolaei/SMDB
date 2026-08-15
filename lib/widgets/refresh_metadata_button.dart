import 'package:flutter/material.dart';

import '../utils/metadata_refresh_mode.dart';

/// A [HeroIconButton]-styled refresh control that opens a menu of the
/// three metadata-refresh modes instead of refreshing immediately, for
/// use in a [DetailTopBar]'s actions.
class RefreshMetadataButton extends StatelessWidget {
  final bool busy;
  final ValueChanged<MetadataRefreshMode> onSelected;
  final String imageLabel;

  const RefreshMetadataButton({
    super.key,
    required this.busy,
    required this.onSelected,
    this.imageLabel = 'poster & backdrop',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: const BoxDecoration(
        color: Colors.black45,
        shape: BoxShape.circle,
      ),
      child: PopupMenuButton<MetadataRefreshMode>(
        enabled: !busy,
        tooltip: 'Update metadata',
        onSelected: onSelected,
        itemBuilder: (context) => MetadataRefreshMode.values
            .map(
              (m) => PopupMenuItem(
                value: m,
                child: Text(
                  m.label(imageLabel: imageLabel),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            )
            .toList(),
        icon: busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : const Icon(Icons.refresh, color: Colors.white),
      ),
    );
  }
}
