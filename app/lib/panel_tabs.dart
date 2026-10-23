import 'package:flutter/widgets.dart';
import 'package:sm_design/sm_design.dart';

import 'bar_button.dart';

/// The row of tabs at the top of a utility's lower panel, scrolled
/// sideways when they do not fit. The tabs are small and stand at the top
/// of the row, so the scroll bar under them has room of its own.
class PanelTabs<T> extends StatelessWidget {
  final List<T> tabs;
  final T shown;
  final String Function(T) label;
  final String Function(T) keyOf;
  final ValueChanged<T> onChoose;
  final Key? listKey;

  const PanelTabs({
    super.key,
    this.listKey,
    required this.tabs,
    required this.shown,
    required this.label,
    required this.keyOf,
    required this.onChoose,
  });

  @override
  Widget build(BuildContext context) {
    return PillRow(
      listKey: listKey,
      children: [
        for (final tab in tabs)
          BarButton(
            key: ValueKey(keyOf(tab)),
            label: label(tab),
            compact: true,
            small: true,
            filled: tab == shown,
            onTap: () => onChoose(tab),
          ),
      ],
    );
  }
}

/// A sideways row of pills in a lower panel: each [pill] high at the top
/// of the row, so the scroll bar drawn under them has room of its own
/// and never lies across them (owner, 16 October 2026).
class PillRow extends StatelessWidget {
  static const pill = 34.0;
  static const height = 46.0;

  final Key? listKey;
  final List<Widget> children;

  /// Room at either end; the panel's own margin unless given.
  final double? inset;

  const PillRow({super.key, this.listKey, required this.children, this.inset});

  @override
  Widget build(BuildContext context) {
    final spacing = SmTheme.of(context).spacing;
    return SizedBox(
      height: height,
      child: ListView(
        key: listKey,
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: inset ?? spacing.md),
        children: [
          for (final child in children)
            Padding(
              padding: EdgeInsets.only(right: spacing.sm),
              child: Align(
                alignment: Alignment.topCenter,
                child: SizedBox(height: pill, child: child),
              ),
            ),
        ],
      ),
    );
  }
}
