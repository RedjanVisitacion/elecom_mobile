import 'package:flutter/material.dart';

import '../../../core/session/user_session.dart';
import '../profile/profile_screen.dart';
import '../data/elecom_mobile_api.dart';
import 'utils/theme_notifier.dart';
import 'widgets/student_dashboard_appbar.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({
    super.key,
    required this.orgName,
    required this.assetPath,
  });

  final String orgName;
  final String assetPath;

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _PlaceholderTab extends StatelessWidget {
  const _PlaceholderTab({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _StudentDashboardState extends State<StudentDashboard> {
  final ElecomMobileApi _api = ElecomMobileApi();
  bool _loadingName = false;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _ensureFullName();
  }

  Future<void> _ensureFullName() async {
    final existing = (UserSession.fullName ?? '').trim();
    if (existing.isNotEmpty) return;

    if (mounted) {
      setState(() {
        _loadingName = true;
      });
    }

    try {
      final res = await _api.getProfile();
      final root = res;
      final data = root['data'] is Map<String, dynamic> ? (root['data'] as Map<String, dynamic>) : const <String, dynamic>{};

      // Apply both shapes: some APIs return {ok:true, data:{...}} while others return fields at root.
      if (data.isNotEmpty) {
        UserSession.setFromResponse(data);
      }
      UserSession.setFromResponse(root);

      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() {});
    } finally {
      if (mounted) {
        setState(() {
          _loadingName = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isElecom = widget.orgName.toUpperCase().contains('ELECOM');

    return ListenableBuilder(
      listenable: themeNotifier,
      builder: (context, child) {
        final shouldUseDarkMode = isElecom && themeNotifier.isDarkMode;
        final dashboardTheme = shouldUseDarkMode
            ? ThemeData(
                colorScheme: ColorScheme.fromSeed(
                  seedColor: Colors.deepPurple,
                  brightness: Brightness.dark,
                ),
                useMaterial3: true,
              )
            : Theme.of(context);

        return Theme(
          data: dashboardTheme,
          child: Scaffold(
            appBar: StudentDashboardAppBar.build(context: context, isElecom: isElecom),
            body: IndexedStack(
              index: _currentIndex,
              children: [
                _homeTab(context),
                const _PlaceholderTab(title: 'Election'),
                const _PlaceholderTab(title: 'Results'),
                const _PlaceholderTab(title: 'Receipt'),
                const ProfileBody(),
              ],
            ),
            bottomNavigationBar: BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              currentIndex: _currentIndex,
              onTap: (i) {
                setState(() {
                  _currentIndex = i;
                });
              },
              selectedItemColor: Colors.black,
              unselectedItemColor: Colors.black54,
              backgroundColor: Colors.white,
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Home'),
                BottomNavigationBarItem(icon: Icon(Icons.how_to_vote_outlined), label: 'Election'),
                BottomNavigationBarItem(icon: Icon(Icons.bar_chart_outlined), label: 'Results'),
                BottomNavigationBarItem(icon: Icon(Icons.receipt_long_outlined), label: 'Receipt'),
                BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Me'),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _homeTab(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                widget.assetPath,
                height: 72,
                fit: BoxFit.contain,
                errorBuilder: (c, e, s) => const Icon(Icons.how_to_vote, size: 64),
              ),
              const SizedBox(height: 12),
              Text(
                widget.orgName,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Text(
                _displayName(),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Elecom module UI is being reused. Next step is wiring voting + candidates + admin features to your Django API.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _displayName() {
    final name = (UserSession.fullName ?? '').trim();
    if (name.isNotEmpty) return name;

    if (_loadingName) return 'Loading...';

    // If profile API still didn't give a name, keep a safe fallback.
    return 'Student';
  }
}
