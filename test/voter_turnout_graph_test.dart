import 'package:elecom_mobile/features/elecom/student_dashboard/widgets/voter_turnout_graph.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('turnout graph fits the existing compact card content', (
    tester,
  ) async {
    for (final dark in [false, true]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 260,
                height: 115,
                child: VoterTurnoutGraph(
                  voters: 1647,
                  castVotes: 2,
                  isDark: dark,
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('0.1%'), findsOneWidget);
      expect(find.text('2 voted • 1,647 total voters'), findsOneWidget);
      expect(find.text('Turnout progress'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'missing turnout is not displayed as zero or a fabricated trend',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 260,
              height: 115,
              child: VoterTurnoutGraph(
                voters: 0,
                castVotes: null,
                isDark: false,
              ),
            ),
          ),
        ),
      );
      expect(find.text('Turnout unavailable'), findsOneWidget);
      expect(find.text('0.0%'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
