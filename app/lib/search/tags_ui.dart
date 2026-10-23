import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sm_design/sm_design.dart';

import '../bar_button.dart';
import '../glyph_button.dart';
import '../journal/journal_store.dart';
import '../reminders/reminder_store.dart';
import '../strings.dart';
import '../swipe_to_delete.dart';

/// The lower panel for an entry's or a reminder's tags: every tag there is,
/// each a row that a touch puts on or takes off, and at the foot a row that
/// makes a new one (named in the bar, see [TagNameBar]). With no tags yet,
/// that row alone.
///
/// A row drawn to the left shows its delete button. Deleting a tag takes
/// it off every entry and every reminder, so it asks first, here in the
/// panel, saying how many.
class TagPanel extends StatefulWidget {
  final Set<String> chosen;
  final ValueChanged<Set<String>> onChanged;
  final VoidCallback onNew;

  const TagPanel({
    super.key,
    required this.chosen,
    required this.onChanged,
    required this.onNew,
  });

  @override
  State<TagPanel> createState() => _TagPanelState();
}

class _TagPanelState extends State<TagPanel> {
  // The tag being asked about, while the delete question is up.
  String? _deleting;

  void _toggle(String id) {
    HapticFeedback.selectionClick();
    final next = {...widget.chosen};
    if (!next.remove(id)) next.add(id);
    widget.onChanged(next);
  }

  void _delete(String id) {
    HapticFeedback.mediumImpact();
    JournalScope.of(context).deleteTag(id);
    ReminderScope.of(context).untag(id);
    widget.onChanged({...widget.chosen}..remove(id));
    setState(() => _deleting = null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final colors = theme.colors;
    final spacing = theme.spacing;
    final strings = Strings.of(context);
    final journal = JournalScope.of(context);
    final tags = journal.tags;
    final deleting = _deleting == null ? null : journal.tag(_deleting!);

    if (deleting != null) {
      final entries = journal.countTagged(deleting.id);
      final reminders = ReminderScope.of(context).countTagged(deleting.id);
      return Padding(
        key: const ValueKey('tag-question'),
        padding: EdgeInsets.all(spacing.md),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              strings.deleteTagQuestion(deleting.name, entries, reminders),
              textAlign: TextAlign.center,
              style: theme.type.label.copyWith(
                color: colors.textPrimary,
                height: 1.4,
              ),
            ),
            SizedBox(height: spacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                BarButton(
                  key: const ValueKey('tag-delete-confirm'),
                  label: strings.delete,
                  compact: true,
                  primary: true,
                  tint: dangerColor,
                  onTap: () => _delete(deleting.id),
                ),
                SizedBox(width: spacing.sm),
                BarButton(
                  key: const ValueKey('tag-delete-cancel'),
                  label: strings.keep,
                  compact: true,
                  onTap: () => setState(() => _deleting = null),
                ),
              ],
            ),
          ],
        ),
      );
    }

    Widget row({
      required Key key,
      required Widget child,
      required VoidCallback onTap,
    }) => GestureDetector(
      key: key,
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: 40,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing.md),
          child: child,
        ),
      ),
    );

    return ListView(
      key: const ValueKey('tag-panel'),
      padding: EdgeInsets.only(top: spacing.xs, bottom: spacing.sm),
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            spacing.md,
            spacing.xs,
            spacing.md,
            spacing.xs,
          ),
          child: Text(
            strings.tagsNote,
            style: theme.type.caption.copyWith(color: colors.textFaint),
          ),
        ),
        for (final tag in tags)
          SwipeToDelete(
            key: ValueKey('tag-row-${tag.id}'),
            name: 'tag-${tag.id}',
            onDelete: () => setState(() => _deleting = tag.id),
            child: row(
              key: ValueKey('tag-${tag.id}'),
              onTap: () => _toggle(tag.id),
              child: TagMark(
                name: tag.name,
                on: widget.chosen.contains(tag.id),
              ),
            ),
          ),
        row(
          key: const ValueKey('tag-new'),
          onTap: () {
            HapticFeedback.selectionClick();
            widget.onNew();
          },
          child: Row(
            children: [
              GlyphMark(glyph: Glyph.add, size: 14, color: colors.accent),
              SizedBox(width: spacing.sm),
              Text(
                strings.tagNew,
                style: theme.type.body.copyWith(color: colors.accent),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A tag as the tag panel draws it: its name, and a ring at the far end,
/// filled and both in the accent when it is on.
class TagMark extends StatelessWidget {
  final String name;
  final bool on;

  const TagMark({super.key, required this.name, required this.on});

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final colors = theme.colors;
    return Row(
      children: [
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.type.body.copyWith(
              color: on ? colors.accent : colors.textPrimary,
            ),
          ),
        ),
        // On or off: a filled ring, or an empty one.
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: on ? colors.accent : null,
            border: Border.all(
              color: on ? colors.accent : colors.textFaint,
              width: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

/// The bar while a new tag is named: the cross that puts it away, the
/// name, and the tick that makes it.
class TagNameBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onDone;
  final VoidCallback onCancel;

  /// What the empty field says: "New tag" unless given.
  final String? placeholder;

  const TagNameBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onDone,
    required this.onCancel,
    this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final colors = theme.colors;
    final spacing = theme.spacing;
    final strings = Strings.of(context);
    return Row(
      key: const ValueKey('tag-name-bar'),
      children: [
        GlyphButton(
          key: const ValueKey('tag-name-cancel'),
          glyph: Glyph.close,
          square: true,
          onTap: onCancel,
        ),
        SizedBox(width: spacing.sm),
        Expanded(
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: spacing.md,
              vertical: spacing.sm + 1,
            ),
            decoration: BoxDecoration(
              border: Border.all(color: colors.outline),
              borderRadius: BorderRadius.circular(theme.radii.md),
            ),
            child: SmTextField(
              key: const ValueKey('tag-name'),
              controller: controller,
              focusNode: focusNode,
              labels: strings.textToolbar,
              placeholder: placeholder ?? strings.tagNew,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => onDone(),
              style: theme.type.body.copyWith(color: colors.textPrimary),
            ),
          ),
        ),
        SizedBox(width: spacing.sm),
        GlyphButton(
          key: const ValueKey('tag-name-done'),
          glyph: Glyph.save,
          square: true,
          lit: true,
          onTap: onDone,
        ),
      ],
    );
  }
}

/// A choice in a row of choices: its name, in its colour, filled when on.
/// Given the width, as the search's categories and tags are, it is a row
/// as wide as the panel; the reminder's leads and planets on a tablet take
/// the same look.
class SearchChip extends StatelessWidget {
  final String label;
  final Color hue;
  final bool on;
  final VoidCallback onTap;

  const SearchChip({
    super.key,
    required this.label,
    required this.hue,
    required this.on,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 32,
        padding: EdgeInsets.symmetric(horizontal: theme.spacing.md),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? hue.withValues(alpha: 0.22) : null,
          border: Border.all(color: hue.withValues(alpha: on ? 1 : 0.5)),
          borderRadius: BorderRadius.circular(theme.radii.lg),
        ),
        child: Text(
          label,
          style: theme.type.label.copyWith(
            color: on ? theme.colors.textPrimary : theme.colors.textSecondary,
          ),
        ),
      ),
    );
  }
}
