import 'package:flutter/material.dart';

import '../data/elecom_mobile_api.dart';
import '../student_dashboard/utils/theme_notifier.dart';
import 'candidate_profile_screen.dart';

// ── colour tokens ─────────────────────────────────────────────────────────────
const _blue = Color(0xFF2563EB);
const _gold = Color(0xFFFACC15);
const _ink = Color(0xFF0F172A);
const _sub = Color(0xFF475569);

/// Full-screen, Facebook-style candidate list showing ALL candidates from every
/// department/org for transparency.  Voters cannot vote for all of them but can
/// browse and read every candidate's profile.
class AllCandidatesScreen extends StatefulWidget {
  const AllCandidatesScreen({super.key, this.preloaded});

  /// Optional pre-fetched list (eligibility-filtered home strip).  The screen
  /// will always re-fetch from the /candidates/all/ endpoint on open so that
  /// cross-department candidates are visible.
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

  // ── active filters ──────────────────────────────────────────────────────────
  String? _filterOrg;
  String? _filterPosition;
  String? _filterParty;

  // ── derived option lists (populated after data loads) ───────────────────────
  List<String> _orgs = [];
  List<String> _positions = [];
  List<String> _parties = [];

  @override
  void initState() {
    super.initState();
    // Always fetch from the all-candidates endpoint for full cross-dept list.
    _fetch();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── data ───────────────────────────────────────────────────────────────────

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _api.listAllCandidatesTransparency();
      if (!mounted) return;
      setState(() {
        _all = list;
        _orgs = _distinctSorted(list, 'organization');
        _positions = _distinctSorted(list, 'position');
        _parties = _distinctSorted(list, 'party_name');
        _loading = false;
      });
      _applyFilters();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  static List<String> _distinctSorted(
    List<Map<String, dynamic>> list,
    String key,
  ) {
    final seen = <String>{};
    for (final c in list) {
      final v = (c[key] ?? '').toString().trim();
      if (v.isNotEmpty) seen.add(v);
    }
    return seen.toList()..sort();
  }

  void _applyFilters() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = _all.where((c) {
        // text search
        if (q.isNotEmpty) {
          final name = _fullName(c).toLowerCase();
          final pos = (c['position'] ?? '').toString().toLowerCase();
          final party = (c['party_name'] ?? '').toString().toLowerCase();
          final org = (c['organization'] ?? '').toString().toLowerCase();
          final prog = (c['program'] ?? '').toString().toLowerCase();
          final hit = name.contains(q) ||
              pos.contains(q) ||
              party.contains(q) ||
              org.contains(q) ||
              prog.contains(q);
          if (!hit) return false;
        }
        // chip filters
        if (_filterOrg != null &&
            (c['organization'] ?? '').toString().trim() != _filterOrg) {
          return false;
        }
        if (_filterPosition != null &&
            (c['position'] ?? '').toString().trim() != _filterPosition) {
          return false;
        }
        if (_filterParty != null &&
            (c['party_name'] ?? '').toString().trim() != _filterParty) {
          return false;
        }
        return true;
      }).toList();
    });
  }

  void _clearFilters() {
    setState(() {
      _filterOrg = null;
      _filterPosition = null;
      _filterParty = null;
      _searchCtrl.clear();
    });
    _applyFilters();
  }

  bool get _hasActiveFilters =>
      _filterOrg != null ||
      _filterPosition != null ||
      _filterParty != null ||
      _searchCtrl.text.trim().isNotEmpty;

  // ── helpers ─────────────────────────────────────────────────────────────────

  static String _fullName(Map<String, dynamic> c) {
    final parts = [
      (c['first_name'] ?? '').toString().trim(),
      (c['middle_name'] ?? '').toString().trim(),
      (c['last_name'] ?? '').toString().trim(),
    ].where((x) => x.isNotEmpty).toList();
    return parts.isEmpty ? 'Candidate' : parts.join(' ');
  }

  // ── build ───────────────────────────────────────────────────────────────────

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

        final filterBg = isPremium
            ? Colors.white
            : isDark
            ? const Color(0xFF242526)
            : Colors.white;

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
            // ── search bar in appbar bottom ───────────────────────────────────
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(56),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: _SearchBar(
                  controller: _searchCtrl,
                  onChanged: (_) => _applyFilters(),
                  bg: searchBg,
                  hint: 'Search candidates…',
                  hintColor: hintText,
                  iconColor: hintText,
                  textColor: primaryText,
                ),
              ),
            ),
          ),
          body: Column(
            children: [
              // ── filter chip row ─────────────────────────────────────────────
              if (!_loading && _error == null) ...[
                _FilterRow(
                  bg: filterBg,
                  isPremium: isPremium,
                  isDark: isDark,
                  primaryText: primaryText,
                  hintText: hintText,
                  orgs: _orgs,
                  positions: _positions,
                  parties: _parties,
                  filterOrg: _filterOrg,
                  filterPosition: _filterPosition,
                  filterParty: _filterParty,
                  hasActive: _hasActiveFilters,
                  onOrgSelected: (v) {
                    setState(() => _filterOrg = v);
                    _applyFilters();
                  },
                  onPositionSelected: (v) {
                    setState(() => _filterPosition = v);
                    _applyFilters();
                  },
                  onPartySelected: (v) {
                    setState(() => _filterParty = v);
                    _applyFilters();
                  },
                  onClear: _clearFilters,
                ),
              ],
              // ── result count label ─────────────────────────────────────────
              if (!_loading && _error == null && _hasActiveFilters) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${_filtered.length} result${_filtered.length == 1 ? '' : 's'}',
                      style: TextStyle(
                        color: hintText,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
              // ── list ───────────────────────────────────────────────────────
              Expanded(
                child: _buildBody(
                  isPremium: isPremium,
                  isDark: isDark,
                  primaryText: primaryText,
                  hintText: hintText,
                ),
              ),
            ],
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
        child: CircularProgressIndicator(color: isPremium ? _blue : null),
      );
    }

    if (_error != null) {
      // Strip the internal class prefix for a cleaner message.
      final displayError = _error!
          .replaceFirst('ElecomApiException(message: ', '')
          .replaceFirst(RegExp(r', code: .*\)$'), '')
          .trim();
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
              const SizedBox(height: 8),
              Text(
                displayError,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: hintText,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
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
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_search_rounded, size: 48, color: hintText),
              const SizedBox(height: 12),
              Text(
                _hasActiveFilters
                    ? 'No candidates match your filters.'
                    : 'No candidates available.',
                textAlign: TextAlign.center,
                style: TextStyle(color: hintText, fontSize: 14),
              ),
              if (_hasActiveFilters) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _clearFilters,
                  child: Text(
                    'Clear filters',
                    style: TextStyle(color: isPremium ? _blue : primaryText),
                  ),
                ),
              ],
            ],
          ),
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

// ── Filter row ─────────────────────────────────────────────────────────────

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.bg,
    required this.isPremium,
    required this.isDark,
    required this.primaryText,
    required this.hintText,
    required this.orgs,
    required this.positions,
    required this.parties,
    required this.filterOrg,
    required this.filterPosition,
    required this.filterParty,
    required this.hasActive,
    required this.onOrgSelected,
    required this.onPositionSelected,
    required this.onPartySelected,
    required this.onClear,
  });

  final Color bg;
  final bool isPremium;
  final bool isDark;
  final Color primaryText;
  final Color hintText;
  final List<String> orgs;
  final List<String> positions;
  final List<String> parties;
  final String? filterOrg;
  final String? filterPosition;
  final String? filterParty;
  final bool hasActive;
  final ValueChanged<String?> onOrgSelected;
  final ValueChanged<String?> onPositionSelected;
  final ValueChanged<String?> onPartySelected;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final borderColor = isPremium
        ? const Color(0xFFE4E6EB)
        : isDark
        ? const Color(0xFF3A3B3C)
        : const Color(0xFFE4E6EB);

    return Container(
      color: bg,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(
              children: [
                _FilterChipButton(
                  label: filterOrg ?? 'Organization',
                  isActive: filterOrg != null,
                  isPremium: isPremium,
                  isDark: isDark,
                  primaryText: primaryText,
                  onTap: () => _showPicker(
                    context,
                    title: 'Organization',
                    items: orgs,
                    selected: filterOrg,
                    onSelected: onOrgSelected,
                    isPremium: isPremium,
                    isDark: isDark,
                    primaryText: primaryText,
                    hintText: hintText,
                  ),
                ),
                const SizedBox(width: 8),
                _FilterChipButton(
                  label: filterPosition ?? 'Position',
                  isActive: filterPosition != null,
                  isPremium: isPremium,
                  isDark: isDark,
                  primaryText: primaryText,
                  onTap: () => _showPicker(
                    context,
                    title: 'Position',
                    items: positions,
                    selected: filterPosition,
                    onSelected: onPositionSelected,
                    isPremium: isPremium,
                    isDark: isDark,
                    primaryText: primaryText,
                    hintText: hintText,
                  ),
                ),
                const SizedBox(width: 8),
                _FilterChipButton(
                  label: filterParty ?? 'Party',
                  isActive: filterParty != null,
                  isPremium: isPremium,
                  isDark: isDark,
                  primaryText: primaryText,
                  onTap: () => _showPicker(
                    context,
                    title: 'Party',
                    items: parties,
                    selected: filterParty,
                    onSelected: onPartySelected,
                    isPremium: isPremium,
                    isDark: isDark,
                    primaryText: primaryText,
                    hintText: hintText,
                  ),
                ),
                if (hasActive) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: onClear,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isPremium
                            ? const Color(0xFFE4E6EB)
                            : isDark
                            ? const Color(0xFF3A3B3C)
                            : const Color(0xFFE4E6EB),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.close, size: 14, color: primaryText),
                          const SizedBox(width: 4),
                          Text(
                            'Clear',
                            style: TextStyle(
                              color: primaryText,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: borderColor),
        ],
      ),
    );
  }

  void _showPicker(
    BuildContext context, {
    required String title,
    required List<String> items,
    required String? selected,
    required ValueChanged<String?> onSelected,
    required bool isPremium,
    required bool isDark,
    required Color primaryText,
    required Color hintText,
  }) {
    final sheetBg = isPremium
        ? Colors.white
        : isDark
        ? const Color(0xFF242526)
        : Colors.white;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: sheetBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: hintText.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  color: primaryText,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    ListTile(
                      title: Text(
                        'All',
                        style: TextStyle(color: primaryText),
                      ),
                      trailing: selected == null
                          ? Icon(
                              Icons.check_circle_rounded,
                              color: isPremium ? _blue : primaryText,
                            )
                          : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        onSelected(null);
                      },
                    ),
                    ...items.map((item) {
                      final isSelected = selected == item;
                      return ListTile(
                        title: Text(
                          item,
                          style: TextStyle(
                            color: primaryText,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.normal,
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(
                                Icons.check_circle_rounded,
                                color: isPremium ? _blue : primaryText,
                              )
                            : null,
                        onTap: () {
                          Navigator.pop(ctx);
                          onSelected(item);
                        },
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
    required this.label,
    required this.isActive,
    required this.isPremium,
    required this.isDark,
    required this.primaryText,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final bool isPremium;
  final bool isDark;
  final Color primaryText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final activeBg = isPremium ? _blue : isDark ? Colors.white24 : Colors.black;
    final activeText = Colors.white;
    final inactiveBg = isPremium
        ? const Color(0xFFE4E6EB)
        : isDark
        ? const Color(0xFF3A3B3C)
        : const Color(0xFFE4E6EB);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? activeBg : inactiveBg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isActive ? activeText : primaryText,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.expand_more_rounded,
              size: 16,
              color: isActive ? activeText : primaryText,
            ),
          ],
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
    final org = _t(candidate['organization']);
    final party = _t(candidate['party_name']);
    final photo = resolvedCandidatePhotoUrl(candidate['photo_url']);

    // Facebook-style sub-line: position · party  (fallback to org)
    final subParts = <String>[
      if (position.isNotEmpty) position,
      if (party.isNotEmpty) party else if (org.isNotEmpty) org,
    ];
    final subLine = subParts.join(' · ');
    final programLine = _t(candidate['program']);

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
                  _Avatar(photo: photo, isPremium: isPremium, isDark: isDark),
                  const SizedBox(width: 12),
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
                        if (org.isNotEmpty) ...[
                          const SizedBox(height: 1),
                          _OrgBadge(
                            org: org,
                            isPremium: isPremium,
                            isDark: isDark,
                          ),
                        ],
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
                        if (programLine.isNotEmpty) ...[
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
                                  programLine,
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

// ── Org badge pill ─────────────────────────────────────────────────────────

class _OrgBadge extends StatelessWidget {
  const _OrgBadge({
    required this.org,
    required this.isPremium,
    required this.isDark,
  });

  final String org;
  final bool isPremium;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final bg = isPremium
        ? _blue.withValues(alpha: 0.10)
        : isDark
        ? Colors.white12
        : _blue.withValues(alpha: 0.09);
    final text = isPremium ? _blue : isDark ? Colors.white70 : _blue;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        org,
        style: TextStyle(
          color: text,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ── Avatar ─────────────────────────────────────────────────────────────────

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

    final bgColor = isDark ? Colors.white12 : const Color(0xFFEAF1FF);

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
        onBackgroundImageError: photo != null ? (_, __) {} : null,
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
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final Color bg;
  final String hint;
  final Color hintColor;
  final Color iconColor;
  final Color textColor;

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
