import 'package:flutter/widgets.dart';

import 'theme.dart';

/// A tappable area that dims while pressed.
class SmPressable extends StatefulWidget {
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget child;

  const SmPressable({
    super.key,
    this.onTap,
    this.onLongPress,
    required this.child,
  });

  @override
  State<SmPressable> createState() => _SmPressableState();
}

class _SmPressableState extends State<SmPressable> {
  bool _pressed = false;

  void _setPressed(bool pressed) => setState(() => _pressed = pressed);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      child: AnimatedOpacity(
        opacity: _pressed ? 0.55 : 1,
        duration: SmTheme.of(context).motion.fast,
        child: widget.child,
      ),
    );
  }
}
