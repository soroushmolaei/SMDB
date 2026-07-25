import 'package:flutter/material.dart';

/// A single circular, translucent-backed icon button — legible over any
/// backdrop image regardless of how bright or dark it is.
class HeroIconButton extends StatelessWidget {
  final Widget icon;
  final String? tooltip;
  final VoidCallback? onPressed;

  const HeroIconButton({
    super.key,
    required this.icon,
    this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final button = Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: const BoxDecoration(
        color: Colors.black45,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: icon,
        color: Colors.white,
        onPressed: onPressed,
      ),
    );
    return tooltip != null
        ? Tooltip(message: tooltip!, child: button)
        : button;
  }
}

/// Floats a back button on the left and arbitrary actions on the right,
/// on top of a scrolling detail page's backdrop hero. Meant to be placed
/// in a [Stack] above a [CustomScrollView].
class DetailTopBar extends StatelessWidget {
  final List<Widget> actions;

  const DetailTopBar({super.key, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              HeroIconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const Spacer(),
              ...actions,
            ],
          ),
        ),
      ),
    );
  }
}
