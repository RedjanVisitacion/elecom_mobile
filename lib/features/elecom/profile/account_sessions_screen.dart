import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_shape.dart';
import '../../../core/utils/toast_service.dart';
import '../data/elecom_mobile_api.dart';

class AccountSessionsScreen extends StatefulWidget {
  const AccountSessionsScreen({super.key, this.api});
  final ElecomMobileApi? api;

  @override
  State<AccountSessionsScreen> createState() => _AccountSessionsScreenState();
}

class _AccountSessionsScreenState extends State<AccountSessionsScreen> {
  late final ElecomMobileApi _api;
  List<Map<String, dynamic>> _sessions = [];
  bool _loading = true;
  bool _working = false;
  bool _leaving = false;
  String? _error;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? ElecomMobileApi();
    _load();
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    try {
      final response = await _api.getAccountSessions();
      if (!mounted || generation != _loadGeneration) return;
      final raw = response['sessions'];
      setState(() {
        _sessions = raw is List
            ? raw
                  .whereType<Map>()
                  .map((s) => Map<String, dynamic>.from(s))
                  .toList()
            : [];
        _error = null;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _loading = false;
        _error = 'Unable to load signed-in devices. Please try again.';
      });
    }
  }

  ThemeData _screenTheme(BuildContext context) {
    final base = Theme.of(context);
    final dark = base.brightness == Brightness.dark;
    final blue = dark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);
    final surface = dark ? const Color(0xFF1E293B) : Colors.white;
    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: blue,
        onPrimary: dark ? const Color(0xFF0F172A) : Colors.white,
        secondary: blue,
        surface: surface,
        surfaceTint: Colors.transparent,
      ),
      cardTheme: base.cardTheme.copyWith(
        color: surface,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: base.dialogTheme.copyWith(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }

  Future<void> _logout({Map<String, dynamic>? session}) async {
    if (_working) return;
    final all = session == null;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Theme(
        data: _screenTheme(context),
        child: AlertDialog(
          title: Text(all ? 'Log out all devices?' : 'Log out this device?'),
          content: Text(
            all
                ? 'Every device, including this one, will need to sign in again.'
                : session['is_current'] == true
                ? 'You will return to the login screen on this device.'
                : 'This device will need to sign in again to access your account.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Log out'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    _loadGeneration++;
    setState(() => _working = true);
    try {
      final response = await _api.revokeAccountSessions(
        all: all,
        sessionId: session?['id']?.toString(),
      );
      if (!mounted) return;
      if (response['current_session_ended'] == true) {
        _leaving = true;
        ApiClient.endSession(
          message: 'You have been logged out. Please sign in again.',
        );
        return;
      }
      await _load();
      if (mounted) AppToast.success(context, 'Device logged out.');
    } catch (_) {
      if (mounted) {
        AppToast.error(
          context,
          'Unable to log out this device. Please try again.',
        );
      }
    } finally {
      if (mounted && !_leaving) setState(() => _working = false);
    }
  }

  String _time(dynamic value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    return parsed == null
        ? 'Unavailable for this older session'
        : DateFormat('MMM d, yyyy · h:mm a').format(parsed.toLocal());
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: _screenTheme(context),
    child: Builder(builder: _buildContent),
  );

  Widget _buildContent(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text("Where you're logged in")),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'Manage the devices signed in to your account. Changing your password signs out all devices.',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Device labels come from the app or browser. IP addresses are network information, not an exact location.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  if (_error != null) ...[
                    Text(_error!, style: TextStyle(color: color.error)),
                    TextButton(
                      onPressed: _load,
                      child: const Text('Try again'),
                    ),
                  ],
                  for (final session in _sessions)
                    Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppShape.cardBorderRadius,
                        side: BorderSide(color: color.outlineVariant),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.devices_outlined,
                                  color: color.primary,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    session['device_name']?.toString() ??
                                        'Device',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (session['is_current'] == true) ...[
                              const SizedBox(height: 6),
                              Text(
                                'This device',
                                style: TextStyle(
                                  color: color.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                            const SizedBox(height: 10),
                            Text(
                              'IP address: ${(session['ip_address']?.toString().isNotEmpty ?? false) ? session['ip_address'] : 'Unavailable'}',
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Signed in: ${_time(session['signed_in_at'])}',
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Last active: ${_time(session['last_active_at'])}',
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: _working
                                    ? null
                                    : () => _logout(session: session),
                                icon: const Icon(Icons.logout, size: 18),
                                label: const Text('Log out'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_sessions.isEmpty && _error == null)
                    const Text(
                      'No active sessions found. Pull down to refresh.',
                    ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _working || _sessions.isEmpty
                        ? null
                        : () => _logout(),
                    icon: const Icon(Icons.logout),
                    label: Text(
                      _working ? 'Please wait…' : 'Log out all devices',
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
