import 'package:candra/keyboard_lift.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('follows the reported height, and starts down as soon as the '
      'focus leaves the text', (tester) async {
    addTearDown(tester.view.resetViewInsets);
    final focus = FocusNode();
    final controller = TextEditingController();
    addTearDown(focus.dispose);
    addTearDown(controller.dispose);
    late double inset;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery.fromView(
          view: tester.view,
          child: KeyboardLift(
            child: Builder(
              builder: (context) {
                inset = MediaQuery.viewInsetsOf(context).bottom;
                return EditableText(
                  controller: controller,
                  focusNode: focus,
                  style: const TextStyle(fontSize: 14),
                  cursorColor: const Color(0xFFFFFFFF),
                  backgroundCursorColor: const Color(0xFF000000),
                );
              },
            ),
          ),
        ),
      ),
    );
    expect(inset, 0);

    // The keyboard comes up: each report is passed on as it is.
    focus.requestFocus();
    await tester.pump();
    final ratio = tester.view.devicePixelRatio;
    for (final height in [80.0, 200.0, 244.0]) {
      tester.view.viewInsets = FakeViewPadding(bottom: height * ratio);
      await tester.pump();
      expect(inset, moreOrLessEquals(height));
    }
    await tester.pumpAndSettle();
    expect(inset, moreOrLessEquals(244));

    // The focus leaves: down at once, though nothing has been reported.
    focus.unfocus();
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(inset, lessThan(200));
    await tester.pump(const Duration(milliseconds: 120));
    expect(inset, 0);

    // The keyboard stayed after all: back to what is reported.
    await tester.pumpAndSettle();
    expect(inset, moreOrLessEquals(244));
  });
}
