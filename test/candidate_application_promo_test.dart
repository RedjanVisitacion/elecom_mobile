import 'package:elecom_mobile/features/elecom/student_dashboard/widgets/candidate_application_promo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget card({
    String? url,
    List<Map<String, dynamic>>? slides,
    VoidCallback? onApply,
  }) => MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 360,
        child: CandidateApplicationPromo(
          isDarkMode: false,
          backgroundImageUrl: url,
          slides: slides,
          onApplyNow: onApply ?? () {},
        ),
      ),
    ),
  );

  testWidgets(
    'custom slides auto-advance and identical refresh keeps the current slide',
    (tester) async {
      List<Map<String, dynamic>> configured() => [
        {
          'default_index': 0,
          'title': 'Student leaders wanted',
          'subtitle': 'File your application today.',
          'image_url': null,
        },
        {
          'default_index': 3,
          'title': 'Your next step',
          'subtitle': 'Prepare your documents.',
          'image_url': null,
        },
      ];
      await tester.pumpWidget(card(slides: configured()));
      expect(find.text('Student leaders wanted'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(milliseconds: 600));
      var page = tester
          .widget<PageView>(find.byType(PageView))
          .controller!
          .page!;
      expect(page, closeTo(1, 0.01));
      await tester.pumpWidget(card(slides: configured()));
      await tester.pump();
      page = tester.widget<PageView>(find.byType(PageView)).controller!.page!;
      expect(page, closeTo(1, 0.01));
      expect(find.text('Your next step'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('default carousel stays available and filing action works', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(card(onApply: () => taps++));
    expect(find.text('Lead the Change'), findsOneWidget);
    await tester.tap(find.text('File now').first);
    expect(taps, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'custom background uses ready-to-serve copy and reset restores carousel',
    (tester) async {
      await tester.pumpWidget(
        card(url: 'https://res.cloudinary.com/demo/image/upload/card.jpg'),
      );
      expect(find.text('Ready to Serve?'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Image && widget.image is NetworkImage,
        ),
        findsOneWidget,
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(card());
      await tester.pump();
      expect(find.text('Lead the Change'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('unsafe remote URL uses bundled defaults', (tester) async {
    await tester.pumpWidget(card(url: 'http://unknown.example/card.jpg'));
    expect(find.text('Lead the Change'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Image && widget.image is NetworkImage,
      ),
      findsNothing,
    );
    await tester.pumpWidget(const SizedBox());
  });
}
