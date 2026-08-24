import 'package:flutter/material.dart';

import '../data/elecom_mobile_api.dart';
import '../student_dashboard/utils/theme_notifier.dart';
import 'candidate_profile_screen.dart';

// ── colour tokens (mirrors the rest of the feature) ──────────────────────────
const _blue = Color(0xFF2563EB);
const _gold = Color(0xFFFACC15);
const _ink = Color(0xFF0F172A);
const _sub = Color(0xFF475569);

/// Full-screen, Facebook-style candidate list.
/// Pass [preloaded] to skip the initial network call when the dashboard already
/// has fresh data; leave it null to trigger a fresh fetch.
class AllCandidatesScreen extends StatefulWidget {
  const AllCandidatesScreen({super.key, this.preloaded});

  final List<Map<String, dynamic>>? preloaded;

  @override
  State<AllCandidatesScreen> createState() => _AllCandidatesScreenState();
}

class _AllCandidatesScreenState extends State<AllCandidatesScreen> {
  final ElecomMobileApi _api = ElecomMobileApi();

  List<Map<String, dynamic>> _all = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  String? _error;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.preloaded != null && widget.preloaded!.isNotEmpty) {
      _all = List.of(widget.preloaded!);
      _filtered = _all;
      _loading = false;
    } else {
      _fetch();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _api.listAllCandidates();
      if (!mounted) return;
      setState(() {
        _all = list;
        _filtered = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _onSearch(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filtered = _all;
      } else {
        _filtered = _all.where((c) {
          final name = _fullName(c).toLowerCase();
          final pos = (c['position'] ?? '').toString().toLowerCase();
          final party = (c['party_name'] ?? '').toString().toLowerCase();
          final org = (c['organization'] ?? '').toString().toLowerCase();
          return name.contains(q) ||
              pos.contains(q) ||
              party.contains(q) ||
              org.contains(q);
        }).toList();
      }
    });
  }

  // ── helpers ────────────────────────────────────────────────────────────────

  static String _fullName(Map<String, dynamic> c) {
    final parts = [
      (c['first_name'] ?? '').toString().trim(),
      (c['middle_name'] ?? '').toString().trim(),
      (c['last_name'] ?? '').toString().trim(),
    ].where((x) => x.isNotEmpty).toList();
    return parts.isEmpty ? 'Candidate' : parts.join(' ');
  }

  static String _t(dynamic v) => (v ?? '').toString().trim();

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeNotifier,
      builder: (context, _) {
        final isPremium = themeNotifier.isPremiumMode;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        final pageBg = isPremium
            ? const Color(0xFFF0F2F5)
            : isDark
            ? const Color(0xFF18191A)
            : const Color(0xFFF0F2F5);

        final appBarBg = isPremium
            ? Colors.white
            : isDark
            ? const Color(0xFF242526)
            : Colors.white;

        final primaryText = isPremium
            ? _ink
            : isDark
            ? Colors.white
            : const Color(0xFF050505);

        final hintText = isPremium
            ? _sub
            : isDark
            ? const Color(0xFFB0B3B8)
            : const Color(0xFF65676B);

        final searchBg = isPremium
            ? const Color(0xFFE4E6EB)
            : isDark
            ? const Color(0xFF3A3B3C)
            : const Color(0xFFE4E6EB);

        return Scaffold(
          backgroundColor: pageBg,
          appBar: AppBar(
            backgroundColor: appBarBg,
            elevation: 0,
            scrolledUnderElevation: 1,
            surfaceTintColor: Colors.transparent,
            iconTheme: IconThemeData(color: primaryText),
            title: Text(
              'Candidates',
              style: TextStyle(
                color: primaryText,
                fontWeight: FontWeight.w900,
                fontSize: 20,
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(56),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: _SearchBar(
                  controller: _searchCtrl,
                  onChanged: _onSearch,
                  bg: searchBg,
                  hint: 'Search candidates…',
                  hintColor: hintText,
                  iconColor: hintText,
                  textColor: primaryText,
                  isPremium: isPremium,
                ),
              ),
            ),
          ),
          body: _buildBody(
            isPremium: isPremium,
            isDark: isDark,
            primaryText: primaryText,
            hintText: hintText,
          ),
        );
      },
    );
  }

  Widget _buildBody({
    required bool isPremium,
    required bool isDark,
    required Color primaryText,
    required Color hintText,
  }) {
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(
          color: isPremium ? _blue : null,
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_rounded, size: 48, color: hintText),
              const SizedBox(height: 12),
              Text(
                'Could not load candidates.',
                style: TextStyle(
                  color: primaryText,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _fetch,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
                style: FilledButton.styleFrom(
                  backgroundColor: isPremium ? _blue : Colors.black,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_filtered.isEmpty) {
      return Center(
        child: Text(
          _searchCtrl.text.trim().isEmpty
              ? 'No candidates available.'
              : 'No results for "${_searchCtrl.text.trim()}"',
          style: TextStyle(color: hintText, fontSize: 14),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetch,
      color: isPremium ? _blue : null,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _filtered.length,
        separatorBuilder: (_, __) => const SizedBox(height: 1),
        itemBuilder: (context, i) => _CandidateCard(
          candidate: _filtered[i],
          isPremium: isPremium,
          isDark: isDark,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => CandidateProfileScreen(
                candidate: Map<String, dynamic>.from(_filtered[i]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Candidate card ─────────────────────────────────────────────────────────

class _CandidateCard extends StatelessWidget {
  const _CandidateCard({
    required this.candidate,
    required this.isPremium,
    required this.isDark,
    required this.onTap,
  });

  final Map<String, dynamic> candidate;
  final bool isPremium;
  final bool isDark;
  final VoidCallback onTap;

  static String _fullName(Map<String, dynamic> c) {
    final parts = [
      (c['first_name'] ?? '').toString().trim(),
      (c['middle_name'] ?? '').toString().trim(),
      (c['last_name'] ?? '').toString().trim(),
    ].where((x) => x.isNotEmpty).toList();
    return parts.isEmpty ? 'Candidate' : parts.join(' ');
  }

  static String _t(dynamic v) => (v ?? '').toString().trim();

  @override
  Widget build(BuildContext context) {
    final cardBg = isPremium
        ? Colors.white
        : isDark
        ? const Color(0xFF242526)
        : Colors.white;

    final primaryText = isPremium
        ? _ink
        : isDark
        ? Colors.white
        : const Color(0xFF050505);

    final secondaryText = isPremium
        ? _sub
        : isDark
        ? const Color(0xFFB0B3B8)
        : const Color(0xFF65676B);

    final dividerColor = isPremium
        ? const Color(0xFFE4E6EB)
        : isDark
        ? const Color(0xFF3A3B3C)
        : const Color(0xFFE4E6EB);

    final name = _fullName(candidate);
    final position = _t(candidate['position']);
    final party = _t(candidate['party_name']);
    final org = _t(candidate['organization']);
    final photo = resolvedCandidatePhotoUrl(candidate['photo_url']);

    // Build the "sub-line" just like Facebook: position · party or org
    final subParts = <String>[
      if (position.isNotEmpty) position,
      if (party.isNotEmpty) party else if (org.isNotEmpty) org,
    ];
    final subLine = subParts.join(' · ');

    final mutualLine = _t(candidate['program']);

    return Container(
      color: cardBg,
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── avatar ──────────────────────────────────────────────
                  _Avatar(photo: photo, isPremium: isPremium, isDark: isDark),
                  const SizedBox(width: 12),
                  // ── text block ──────────────────────────────────────────
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            color: primaryText,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            height: 1.25,
                          ),
                        ),
                        if (subLine.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            subLine,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: secondaryText,
                              fontSize: 13,
                              height: 1.3,
                            ),
                          ),
                        ],
                        if (mutualLine.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                Icons.school_outlined,
                                size: 13,
                                color: secondaryText,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  mutualLine,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: secondaryText,
                                    fontSize: 12.5,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 10),
                        // ── action button (like Facebook's "Add friend") ──
                        SizedBox(
                          width: double.infinity,
                          height: 34,
                          child: isPremium
                              ? OutlinedButton(
                                  onPressed: onTap,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: _blue,
                                    side: const BorderSide(
                                      color: _blue,
                                      width: 1.4,
                                    ),
                                    padding: EdgeInsets.zero,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    textStyle: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                  child: const Text('View profile'),
                                )
                              : FilledButton(
                                  onPressed: onTap,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: isDark
                                        ? const Color(0xFF3A3B3C)
                                        : const Color(0xFFE4E6EB),
                                    foregroundColor: isDark
                                        ? Colors.white
                                        : const Color(0xFF050505),
                                    padding: EdgeInsets.zero,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    textStyle: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                  child: const Text('View profile'),
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, thickness: 1, color: dividerColor),
          ],
        ),
      ),
    );
  }
}

// ── Avatar widget ───────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.photo,
    required this.isPremium,
    required this.isDark,
  });

  final String? photo;
  final bool isPremium;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final ringColor = isPremium
        ? _blue
        : isDark
        ? _gold
        : const Color(0xFF0C1E70);

    final bgColor =
        isDark ? Colors.white12 : const Color(0xFFEAF1FF);

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ringColor, width: 2.5),
        boxShadow: isPremium
            ? [
                BoxShadow(
                  color: _blue.withValues(alpha: 0.16),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      padding: const EdgeInsets.all(2),
      child: CircleAvatar(
        radius: 32,
        backgroundColor: bgColor,
        backgroundImage: photo != null ? NetworkImage(photo!) : null,
        onBackgroundImageError:
            photo != null ? (_, __) {} : null,
        child: photo == null
            ? Icon(
                Icons.person,
                size: 30,
                color: isDark ? Colors.white54 : _blue,
              )
            : null,
      ),
    );
  }
}

// ── Search bar ─────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.bg,
    required this.hint,
    required this.hintColor,
    required this.iconColor,
    required this.textColor,
    required this.isPremium,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final Color bg;
  final String hint;
  final Color hintColor;
  final Color iconColor;
  final Color textColor;
  final bool isPremium;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 20, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: TextStyle(color: textColor, fontSize: 14),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: hintColor, fontSize: 14),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, val, __) => val.text.isNotEmpty
                ? GestureDetector(
                    onTap: () {
                      controller.clear();
                      onChanged('');
                    },
                    child: Icon(
                      Icons.cancel_rounded,
                      size: 18,
                      color: iconColor,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
