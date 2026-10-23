import 'package:flutter/widgets.dart';
import 'package:sm_design/sm_design.dart';

/// A brief message that rises above the bar.
///
/// Only one is ever on screen. When [message] changes while one is showing,
/// the old one leaves first, quickly but not abruptly, and only then does
/// the new one come in. Its owner decides when it goes by setting [message]
/// back to null.
class Toast extends StatefulWidget {
  final String? message;

  /// How long a toast takes to step aside for something that needs its
  /// place: another toast, or a picker opening in the lower panel.
  static const makeWay = Duration(milliseconds: 110);

  /// When [message] is null: leave at the [makeWay] pace, not the
  /// unhurried one of a toast that has simply run its time.
  final bool hurried;

  const Toast({super.key, required this.message, this.hurried = false});

  @override
  State<Toast> createState() => _ToastState();
}

class _ToastState extends State<Toast> with SingleTickerProviderStateMixin {
  String? _shown;

  // 0 = gone, 1 = fully in.
  late final AnimationController _presence;

  @override
  void initState() {
    super.initState();
    // Set here, not lazily: a lazy field would first be read during an
    // update and start out already holding the new message.
    _shown = widget.message;
    _presence = AnimationController(
      vsync: this,
      value: widget.message == null ? 0 : 1,
    )..addStatusListener(_onStatus);
  }

  @override
  void didUpdateWidget(Toast oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.message == _shown) {
      // Asked for again while on its way out: stay.
      if (_shown != null) _comeIn();
      return;
    }
    if (_presence.value == 0) {
      _shown = widget.message;
      if (_shown != null) _comeIn();
      return;
    }
    final motion = SmTheme.of(context).motion;
    _presence.animateBack(
      0,
      duration:
          (widget.message == null && !widget.hurried
              ? motion.medium
              : Toast.makeWay) *
          _presence.value,
      curve: Curves.easeIn,
    );
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.dismissed || widget.message == _shown) return;
    // The old toast has gone; the newest request takes its place.
    setState(() => _shown = widget.message);
    if (_shown != null) _comeIn();
  }

  void _comeIn() {
    if (_presence.value == 1) return;
    final motion = SmTheme.of(context).motion;
    _presence.animateTo(
      1,
      duration: motion.medium * (1 - _presence.value),
      curve: motion.curve,
    );
  }

  @override
  void dispose() {
    _presence.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final message = _shown;
    if (message == null) return const SizedBox.shrink();

    return IgnorePointer(
      child: FadeTransition(
        opacity: _presence,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.3),
            end: Offset.zero,
          ).animate(_presence),
          child: Container(
            margin: EdgeInsets.all(theme.spacing.md),
            padding: EdgeInsets.symmetric(
              horizontal: theme.spacing.md,
              vertical: theme.spacing.sm + theme.spacing.xs,
            ),
            decoration: BoxDecoration(
              color: theme.colors.surfaceRaised,
              border: Border.all(color: theme.colors.outline),
              borderRadius: BorderRadius.circular(theme.radii.md),
            ),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: theme.type.label.copyWith(color: theme.colors.textPrimary),
            ),
          ),
        ),
      ),
    );
  }
}
