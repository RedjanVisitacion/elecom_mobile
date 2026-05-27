import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../data/elecom_mobile_api.dart';
import '../student_dashboard/utils/theme_notifier.dart';
import 'candidate_profile_screen.dart';

const _premiumBlue = Color(0xFF2563EB);
const _premiumGold = Color(0xFFFACC15);
const _premiumInk = Color(0xFF0F172A);
const _premiumSub = Color(0xFF475569);
const _premiumBg = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    Color(0xFFFFFFFF),
    Color(0xFFF4F8FF),
    Color(0xFFEAF2FF),
    Color(0xFFFDFEFF),
  ],
);

class CandidateSearchScreen extends StatefulWidget {
  const CandidateSearchScreen({super.key});

  @override
  State<CandidateSearchScreen> createState() => _CandidateSearchScreenState();
}

class _CandidateSearchScreenState extends State<CandidateSearchScreen> {
  final ElecomMobileApi _api = ElecomMobileApi();
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  Timer? _debounce;
  bool _loading = false;
  String _query = '';
  String? _error;
  List<Map<String, dynamic>> _results = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 260), () async {
      final next = v.trim();
      setState(() => _query = next);
      await _search(next);
    });
  }

  Future<void> _search(String q) async {
    if (!mounted) return;
    if (q.trim().isEmpty) {
      setState(() {
        _loading = false;
        _error = null;
        _results = <Map<String, dynamic>>[];
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await _api.searchCandidates(q);
      if (!mounted) return;
      setState(() => _results = res);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _fullName(Map<String, dynamic> c) {
    final first = (c['first_name'] ?? '').toString().trim();
    final middle = (c['middle_name'] ?? '').toString().trim();
    final last = (c['last_name'] ?? '').toString().trim();
    final parts = [first, middle, last].where((x) => x.isNotEmpty).toList();
    return parts.isEmpty ? 'Candidate' : parts.join(' ');
  }

  void _applyPremiumHint(String value) {
    _debounce?.cancel();
    _controller.text = value;
    _controller.selection = TextSelection.collapsed(offset: value.length);
    setState(() => _query = value);
    _search(value);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeNotifier,
      builder: (context, _) {
        final isPremiumMode = themeNotifier.isPremiumMode;
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        final titleColor = isPremiumMode
            ? _premiumInk
            : isDarkMode
            ? Colors.white
            : Colors.black;
        final cardColor = isPremiumMode
            ? Colors.white.withValues(alpha: 0.86)
            : isDarkMode
            ? const Color(0xFF2A2A35)
            : Colors.white;
        final borderColor = isPremiumMode
            ? Colors.white.withValues(alpha: 0.74)
            : isDarkMode
            ? Colors.white12
            : Colors.black12;
        final subtitleColor = isPremiumMode
            ? _premiumSub
            : isDarkMode
            ? Colors.white70
            : Colors.black54;

        return Scaffold(
          backgroundColor: isPremiumMode ? const Color(0xFFFDFEFF) : null,
          appBar: AppBar(
            backgroundColor: isPremiumMode ? const Color(0xFFFDFEFF) : null,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            title: Text(
              'Search',
              style: TextStyle(fontWeight: FontWeight.w900, color: titleColor),
            ),
          ),
          body: Container(
            decoration: isPremiumMode
                ? const BoxDecoration(gradient: _premiumBg)
                : null,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                      boxShadow: isPremiumMode
                          ? [
                              BoxShadow(
                                color: _premiumBlue.withValues(alpha: 0.14),
                                blurRadius: 22,
                                offset: const Offset(0, 12),
                              ),
                            ]
                          : null,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        isPremiumMode
                            ? const HugeIcon(
                                icon: HugeIcons.strokeRoundedUserSearch01,
                                color: _premiumBlue,
                                size: 22,
                                strokeWidth: 1.8,
                              )
                            : Icon(Icons.search, color: subtitleColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            focusNode: _focusNode,
                            onChanged: _onQueryChanged,
                            textInputAction: TextInputAction.search,
                            onSubmitted: (v) => _search(v),
                            style: TextStyle(
                              color: titleColor,
                              fontWeight: FontWeight.w700,
                            ),
                            cursorColor: isPremiumMode ? _premiumBlue : null,
                            decoration: InputDecoration(
                              hintText: 'Search candidates...',
                              hintStyle: TextStyle(
                                color: subtitleColor,
                                fontWeight: FontWeight.w600,
                              ),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        if (_controller.text.isNotEmpty)
                          IconButton(
                            tooltip: 'Clear search',
                            onPressed: () {
                              _controller.clear();
                              _onQueryChanged('');
                            },
                            icon: isPremiumMode
                                ? const HugeIcon(
                                    icon: HugeIcons.strokeRoundedCancel01,
                                    color: _premiumSub,
                                    size: 20,
                                    strokeWidth: 1.8,
                                  )
                                : Icon(Icons.close, color: subtitleColor),
                          ),
                      ],
                    ),
                  ),
                ),
                if (isPremiumMode && _query.isEmpty)
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      clipBehavior: Clip.none,
                      padding: const EdgeInsets.fromLTRB(22, 0, 22, 8),
                      children: [
                        _PremiumSearchHint(
                          label: 'President',
                          onTap: () => _applyPremiumHint('President'),
                        ),
                        _PremiumSearchHint(
                          label: 'Vice President',
                          onTap: () => _applyPremiumHint('Vice President'),
                        ),
                        _PremiumSearchHint(
                          label: 'USG',
                          onTap: () => _applyPremiumHint('USG'),
                        ),
                        _PremiumSearchHint(
                          label: 'Party',
                          onTap: () => _applyPremiumHint('Party'),
                        ),
                      ],
                    ),
                  ),
                if (_loading)
                  LinearProgressIndicator(
                    minHeight: 2,
                    color: isPremiumMode ? _premiumBlue : null,
                    backgroundColor: isPremiumMode
                        ? _premiumBlue.withValues(alpha: 0.08)
                        : null,
                  ),
                Expanded(
                  child: Builder(
                    builder: (context) {
                      if (_error != null && _error!.isNotEmpty) {
                        return _SearchStateMessage(
                          isPremiumMode: isPremiumMode,
                          icon: HugeIcons.strokeRoundedSearchRemove,
                          fallback: Icons.error_outline,
                          message: 'Search failed.\n\n$_error',
                          color: subtitleColor,
                        );
                      }

                      if (_query.isEmpty) {
                        return _SearchStateMessage(
                          isPremiumMode: isPremiumMode,
                          icon: HugeIcons.strokeRoundedSearchFocus,
                          fallback: Icons.search,
                          message: 'Type a name, position, or party.',
                          color: subtitleColor,
                        );
                      }

                      if (_results.isEmpty) {
                        return _SearchStateMessage(
                          isPremiumMode: isPremiumMode,
                          icon: HugeIcons.strokeRoundedUserQuestion01,
                          fallback: Icons.person_search_outlined,
                          message: 'No results for "$_query".',
                          color: subtitleColor,
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
                        itemBuilder: (context, index) {
                          final c = _results[index];
                          final name = _fullName(c);
                          final org = (c['organization'] ?? '')
                              .toString()
                              .trim();
                          final pos = (c['position'] ?? '').toString().trim();
                          final party = (c['party_name'] ?? '')
                              .toString()
                              .trim();
                          final photoUrl = (c['photo_url'] ?? '')
                              .toString()
                              .trim();
                          final resolvedPhoto = resolvedCandidatePhotoUrl(
                            photoUrl,
                          );

                          return Container(
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: borderColor),
                              boxShadow: isPremiumMode
                                  ? [
                                      BoxShadow(
                                        color: _premiumBlue.withValues(
                                          alpha: 0.12,
                                        ),
                                        blurRadius: 18,
                                        offset: const Offset(0, 10),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: ListTile(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        CandidateProfileScreen(candidate: c),
                                  ),
                                );
                              },
                              leading: Container(
                                decoration: isPremiumMode
                                    ? BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: _premiumGold.withValues(
                                            alpha: 0.72,
                                          ),
                                          width: 1.4,
                                        ),
                                      )
                                    : null,
                                padding: EdgeInsets.all(isPremiumMode ? 2 : 0),
                                child: CircleAvatar(
                                  backgroundColor: isDarkMode
                                      ? Colors.white12
                                      : const Color(0xFFEAF1FF),
                                  backgroundImage: resolvedPhoto != null
                                      ? NetworkImage(resolvedPhoto)
                                      : null,
                                  child: resolvedPhoto != null
                                      ? null
                                      : isPremiumMode
                                      ? const HugeIcon(
                                          icon:
                                              HugeIcons.strokeRoundedUserCircle,
                                          color: _premiumBlue,
                                          size: 24,
                                          strokeWidth: 1.8,
                                        )
                                      : Icon(
                                          Icons.person,
                                          color: isDarkMode
                                              ? Colors.white70
                                              : Colors.blue,
                                        ),
                                ),
                              ),
                              title: Text(
                                name,
                                style: TextStyle(
                                  color: titleColor,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              subtitle: Text(
                                [
                                  if (org.isNotEmpty) org,
                                  if (pos.isNotEmpty) pos,
                                  if (party.isNotEmpty) party,
                                ].join(' • '),
                                style: TextStyle(
                                  color: subtitleColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              trailing: isPremiumMode
                                  ? const HugeIcon(
                                      icon: HugeIcons.strokeRoundedArrowRight01,
                                      color: _premiumSub,
                                      size: 18,
                                      strokeWidth: 1.8,
                                    )
                                  : null,
                            ),
                          );
                        },
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemCount: _results.length,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PremiumSearchHint extends StatelessWidget {
  const _PremiumSearchHint({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.76),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.92)),
            boxShadow: [
              BoxShadow(
                color: _premiumBlue.withValues(alpha: 0.10),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: const TextStyle(
              color: _premiumSub,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchStateMessage extends StatelessWidget {
  const _SearchStateMessage({
    required this.isPremiumMode,
    required this.icon,
    required this.fallback,
    required this.message,
    required this.color,
  });

  final bool isPremiumMode;
  final List<List<dynamic>> icon;
  final IconData fallback;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isPremiumMode) ...[
              HugeIcon(
                icon: icon,
                color: _premiumBlue,
                size: 48,
                strokeWidth: 1.7,
              ),
              const SizedBox(height: 12),
            ] else ...[
              Icon(fallback, color: color, size: 42),
              const SizedBox(height: 12),
            ],
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
