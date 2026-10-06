import 'dart:async';

import 'package:elecom_mobile/app/app.dart';
import 'package:elecom_mobile/features/elecom/candidates/candidate_filing_screen.dart';
import 'package:elecom_mobile/features/elecom/data/elecom_mobile_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _StatusApi extends ElecomMobileApi {
  String status = 'pending';
  int requests = 0;
  bool fail = false;
  Completer<Map<String, dynamic>>? pending;

  @override
  Future<Map<String, dynamic>> getProfile() async => {};

  @override
  Future<List<String>> getCandidateApplicationParties() async => [];

  @override
  Future<Map<String, dynamic>> getCandidateApplicationStatus() async {
    requests++;
    if (pending != null) return pending!.future;
    if (fail) throw Exception('Temporary network failure');
    return {
      'application': {'id': 1, 'status': status},
    };
  }
}

Future<void> _open(
  WidgetTester tester,
  _StatusApi api, {
  GlobalKey<NavigatorState>? navigatorKey,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigatorKey,
      navigatorObservers: [elecomRouteObserver],
      home: CandidateFilingScreen(api: api),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('initial and final approvals update without refreshing', (
    tester,
  ) async {
    final api = _StatusApi();
    await _open(tester, api);
    expect(find.text('Filing Under Review'), findsOneWidget);

    api.status = 'requirements_pending';
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(find.text('Initial Filing Approved'), findsOneWidget);

    api.status = 'requirements_review';
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(find.text('Requirements Under Review'), findsOneWidget);

    api.status = 'approved';
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(find.text('Congratulations!'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    final requests = api.requests;
    await tester.pump(const Duration(seconds: 6));
    expect(api.requests, requests);
  });

  testWidgets('failed polls retain status and slow requests never overlap', (
    tester,
  ) async {
    final api = _StatusApi();
    await _open(tester, api);
    api.fail = true;
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(find.text('Filing Under Review'), findsOneWidget);

    api.fail = false;
    api.pending = Completer<Map<String, dynamic>>();
    await tester.pump(const Duration(seconds: 3));
    final requests = api.requests;
    await tester.pump(const Duration(seconds: 9));
    expect(api.requests, requests);
    api.pending!.complete({
      'application': {'id': 1, 'status': 'approved'},
    });
    await tester.pump();
    await tester.pump();
    expect(find.text('Congratulations!'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('polls pause in background and behind another page', (
    tester,
  ) async {
    final api = _StatusApi();
    final navigator = GlobalKey<NavigatorState>();
    await _open(tester, api, navigatorKey: navigator);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    final requests = api.requests;
    await tester.pump(const Duration(seconds: 6));
    expect(api.requests, requests);

    api.status = 'requirements_pending';
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();
    expect(find.text('Initial Filing Approved'), findsOneWidget);

    unawaited(
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Another page')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final hiddenRequests = api.requests;
    await tester.pump(const Duration(seconds: 6));
    expect(api.requests, hiddenRequests);
    api.status = 'approved';
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('Congratulations!'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
