import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sm_design/sm_design.dart';

import 'strings.dart';

/// The EN | ID pill. A raised thumb slides under the chosen language and
/// its code lights up; tapping a side chooses it.
class LanguageToggle extends StatelessWidget {
  const LanguageToggle({super.key});

  static const _segmentWidth = 38.0;
  static const _height = 30.0;

  @override
  Widget build(BuildContext context) {
    final theme = SmTheme.of(context);
    final colors = theme.colors;
    final motion = theme.motion;
    final controller = LanguageScope.of(context);
    final radius = BorderRadius.circular(_height / 2);

    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        border: Border.all(color: colors.outline),
        borderRadius: radius,
      ),
      child: SizedBox(
        width: _segmentWidth * AppLanguage.values.length,
        height: _height,
        child: Stack(
          children: [
            AnimatedAlign(
              alignment: controller.value == AppLanguage.en
                  ? Alignment.centerLeft
                  : Alignment.centerRight,
              duration: motion.medium,
              curve: motion.transitionCurve,
              child: Container(
                width: _segmentWidth,
                height: _height,
                decoration: BoxDecoration(
                  color: colors.surfaceRaised,
                  borderRadius: radius,
                ),
              ),
            ),
            Row(
              children: [
                for (final language in AppLanguage.values)
                  GestureDetector(
                    key: ValueKey('language-${language.name}'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (language == controller.value) return;
                      HapticFeedback.selectionClick();
                      controller.select(language);
                    },
                    child: SizedBox(
                      width: _segmentWidth,
                      height: _height,
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: motion.medium,
                          curve: motion.curve,
                          style: theme.type.caption.copyWith(
                            letterSpacing: 1,
                            fontSize: 11,
                            color: language == controller.value
                                ? colors.accent
                                : colors.textFaint,
                          ),
                          child: Text(language.code),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
