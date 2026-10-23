import 'package:flutter/widgets.dart';
import 'package:sm_design/sm_design.dart';

import 'bar_button.dart';
import 'glyph_button.dart';

/// What a bar becomes while a question is up: the answer in the middle,
/// and a cross on the right that takes the question back.
class ConfirmBar extends StatelessWidget {
  final String label;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  /// The colour of the answer; [dangerColor] when it destroys something.
  final Color? tint;

  /// The key of the answer button.
  final Key confirmKey;

  const ConfirmBar({
    super.key,
    required this.label,
    required this.onConfirm,
    required this.onCancel,
    this.tint = dangerColor,
    this.confirmKey = const ValueKey('confirm-delete'),
  });

  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.center,
    children: [
      Align(
        alignment: Alignment.centerRight,
        child: GlyphButton(
          key: const ValueKey('confirm-cancel'),
          glyph: Glyph.close,
          onTap: onCancel,
        ),
      ),
      BarButton(
        key: confirmKey,
        label: label,
        onTap: onConfirm,
        primary: true,
        tint: tint,
      ),
    ],
  );
}

/// The foot of a lower panel: its [toast], and under it, while a question
/// is up, the [answer] to it (a [ConfirmBar]). The bar is the house's and
/// never changes for a question (owner, 20 October 2026), so the question
/// is answered where it is asked.
class PanelFoot extends StatelessWidget {
  final Widget toast;
  final Widget? answer;

  const PanelFoot({super.key, required this.toast, this.answer});

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final spacing = theme.spacing;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        toast,
        AnimatedSize(
          duration: theme.motion.medium,
          curve: theme.motion.curve,
          alignment: Alignment.bottomCenter,
          child: answer == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: EdgeInsets.fromLTRB(
                    spacing.md,
                    spacing.sm,
                    spacing.md,
                    spacing.md,
                  ),
                  child: answer,
                ),
        ),
      ],
    );
  }
}
