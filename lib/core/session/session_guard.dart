import 'dart:async';

import 'package:flutter/material.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../config/api_config.dart';
import '../network/api_client.dart';
import 'session_persistence.dart';
import 'user_session.dart';

final sessionNavigatorKey = GlobalKey<NavigatorState>();

/// End local access when the server revokes a session, including on other pages.
class SessionGuard extends StatefulWidget {
  const SessionGuard({super.key, required this.child});
  final Widget child;

  @override
  State<SessionGuard> createState() => _SessionGuardState();
}

class _SessionGuardState extends State<SessionGuard>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _ending = false;
  bool _checking = false;
  bool _resumed = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ApiClient.sessionEnded.addListener(_onEnded);
    _resumed =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _check());
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    if (_resumed) unawaited(_check());
  }

  Future<void> _check() async {
    final identity = UserSession.studentId;
    if (!_resumed ||
        _ending ||
        _checking ||
        identity == null ||
        identity.isEmpty) {
      return;
    }
    _checking = true;
    final cookie = ApiClient.exportCookies()['sessionid'];
    try {
      final response = await ApiClient.httpClient.get(
        Uri.parse('${ApiConfig.baseUrl}/api/mobile/account/session/'),
        headers: const {'Accept': 'application/json'},
      );
      if (!_ending &&
          response.statusCode == 401 &&
          UserSession.studentId == identity &&
          ApiClient.exportCookies()['sessionid'] == cookie) {
        ApiClient.endSession();
      }
    } catch (_) {
      // An offline device is checked again on resume or the next interval.
    } finally {
      _checking = false;
    }
  }

  void _onEnded() {
    if (_ending || UserSession.studentId == null) return;
    unawaited(_signOut());
  }

  Future<void> _signOut() async {
    setState(() => _ending = true);
    FocusManager.instance.primaryFocus?.unfocus();
    final message = ApiClient.sessionEndMessage;
    try {
      await SessionPersistence.clear();
      if (!mounted) return;
      final navigator = sessionNavigatorKey.currentState;
      if (navigator == null) return;
      navigator.pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
        (_) => false,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final context = sessionNavigatorKey.currentContext;
        if (context != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
        }
      });
    } finally {
      if (mounted) setState(() => _ending = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    ApiClient.sessionEnded.removeListener(_onEnded);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      widget.child,
      if (_ending)
        ColoredBox(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: const Center(child: CircularProgressIndicator()),
        ),
    ],
  );
}
