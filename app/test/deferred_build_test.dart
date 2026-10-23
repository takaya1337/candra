import 'package:candra/deferred_build.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host({required bool eager, ValueNotifier<bool>? busy}) =>
      Directionality(
        textDirection: TextDirection.ltr,
        child: DeferredBuild(
          eager: eager,
          busy: busy,
          child: const Text('content'),
        ),
      );

  testWidgets('an eager child is there on the first frame', (tester) async {
    await tester.pumpWidget(host(eager: true));
    expect(find.text('content'), findsOneWidget);
  });

  testWidgets('a deferred child arrives on the frame after', (tester) async {
    await tester.pumpWidget(host(eager: false));
    expect(find.text('content'), findsNothing);

    await tester.pump();
    expect(find.text('content'), findsOneWidget);
  });

  testWidgets('it waits while busy and arrives when that clears', (
    tester,
  ) async {
    final busy = ValueNotifier(true);
    addTearDown(busy.dispose);
    await tester.pumpWidget(host(eager: false, busy: busy));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('content'), findsNothing);

    busy.value = false;
    await tester.pump();
    expect(find.text('content'), findsOneWidget);
  });

  testWidgets('it waits out a running animation', (tester) async {
    final controller = AnimationController(
      vsync: tester,
      duration: const Duration(milliseconds: 300),
    );
    addTearDown(controller.dispose);
    controller.forward();
    await tester.pumpWidget(host(eager: false));

    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('content'), findsNothing);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('content'), findsNothing);

    await tester.pumpAndSettle();
    expect(find.text('content'), findsOneWidget);
  });

  testWidgets('becoming eager shows a waiting child at once', (tester) async {
    final busy = ValueNotifier(true);
    addTearDown(busy.dispose);
    await tester.pumpWidget(host(eager: false, busy: busy));
    await tester.pump();
    expect(find.text('content'), findsNothing);

    await tester.pumpWidget(host(eager: true, busy: busy));
    expect(find.text('content'), findsOneWidget);
  });
}
