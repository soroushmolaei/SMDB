import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'global_search_box.dart';

/// Replaces the native Windows title bar (hidden via WindowOptions in
/// main.dart) with a slim, dark bar that matches the rest of the app —
/// no more bright OS chrome sitting on top of a dark UI. Left side is
/// draggable and double-tap toggles maximize, same as a native caption.
class CustomTitleBar extends StatefulWidget {
  const CustomTitleBar({super.key});

  @override
  State<CustomTitleBar> createState() => _CustomTitleBarState();
}

class _CustomTitleBarState extends State<CustomTitleBar> with WindowListener {
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    windowManager.isMaximized().then((maximized) {
      if (mounted) setState(() => _isMaximized = maximized);
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMaximize() => setState(() => _isMaximized = true);

  @override
  void onWindowUnmaximize() => setState(() => _isMaximized = false);

  Future<void> _toggleMaximize() =>
      _isMaximized ? windowManager.unmaximize() : windowManager.maximize();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      color: const Color(0xFF17171C),
      child: Row(
        children: [
          Expanded(
            child: DragToMoveArea(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onDoubleTap: _toggleMaximize,
                child: const Row(
                  children: [
                    SizedBox(width: 12),
                    Text(
                      'SMDB',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const GlobalSearchBox(),
          Expanded(
            child: DragToMoveArea(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onDoubleTap: _toggleMaximize,
                child: const SizedBox.expand(),
              ),
            ),
          ),
          _TitleBarButton(
            icon: Icons.minimize,
            tooltip: 'Minimize',
            onPressed: () => windowManager.minimize(),
          ),
          _TitleBarButton(
            icon: _isMaximized ? Icons.filter_none : Icons.crop_square,
            iconSize: _isMaximized ? 13 : 15,
            tooltip: _isMaximized ? 'Restore' : 'Maximize',
            onPressed: _toggleMaximize,
          ),
          _TitleBarButton(
            icon: Icons.close,
            tooltip: 'Close',
            hoverColor: const Color(0xFFE81123),
            onPressed: () => windowManager.close(),
          ),
        ],
      ),
    );
  }
}

class _TitleBarButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? hoverColor;
  final double iconSize;

  const _TitleBarButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.hoverColor,
    this.iconSize = 15,
  });

  @override
  State<_TitleBarButton> createState() => _TitleBarButtonState();
}

class _TitleBarButtonState extends State<_TitleBarButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Tooltip(
          message: widget.tooltip,
          waitDuration: const Duration(milliseconds: 600),
          child: Container(
            width: 46,
            height: 36,
            alignment: Alignment.center,
            color: _hovering
                ? (widget.hoverColor ?? Colors.white.withValues(alpha: 0.08))
                : Colors.transparent,
            child: Icon(
              widget.icon,
              size: widget.iconSize,
              color: _hovering ? Colors.white : Colors.white70,
            ),
          ),
        ),
      ),
    );
  }
}
