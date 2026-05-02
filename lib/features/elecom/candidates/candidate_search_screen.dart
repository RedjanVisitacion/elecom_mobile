import 'dart:async';

import 'package:flutter/material.dart';

import '../data/elecom_mobile_api.dart';
import 'candidate_profile_screen.dart';

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
      setState(() {
        _query = next;
      });
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
      setState(() {
        _results = res;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
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

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDarkMode ? Colors.white : Colors.black;
    final cardColor = isDarkMode ? const Color(0xFF2A2A35) : Colors.white;
    final borderColor = isDarkMode ? Colors.white12 : Colors.black12;
    final subtitleColor = isDarkMode ? Colors.white70 : Colors.black54;

    return Scaffold(
      appBar: AppBar(
        title: Text('Search', style: TextStyle(fontWeight: FontWeight.w900, color: titleColor)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(Icons.search, color: subtitleColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      onChanged: _onQueryChanged,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (v) => _search(v),
                      style: TextStyle(color: titleColor, fontWeight: FontWeight.w700),
                      decoration: InputDecoration(
                        hintText: 'Search candidates...',
                        hintStyle: TextStyle(color: subtitleColor, fontWeight: FontWeight.w600),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  if (_controller.text.isNotEmpty)
                    IconButton(
                      onPressed: () {
                        _controller.clear();
                        _onQueryChanged('');
                      },
                      icon: Icon(Icons.close, color: subtitleColor),
                    ),
                ],
              ),
            ),
          ),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: Builder(
              builder: (context) {
                if (_error != null && _error!.isNotEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Search failed.\n\n$_error',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: subtitleColor, fontWeight: FontWeight.w600),
                      ),
                    ),
                  );
                }

                if (_query.isEmpty) {
                  return Center(
                    child: Text(
                      'Type a name, position, or party.',
                      style: TextStyle(color: subtitleColor, fontWeight: FontWeight.w600),
                    ),
                  );
                }

                if (_results.isEmpty) {
                  return Center(
                    child: Text(
                      'No results for "$_query".',
                      style: TextStyle(color: subtitleColor, fontWeight: FontWeight.w600),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
                  itemBuilder: (context, index) {
                    final c = _results[index];
                    final name = _fullName(c);
                    final org = (c['organization'] ?? '').toString().trim();
                    final pos = (c['position'] ?? '').toString().trim();
                    final party = (c['party_name'] ?? '').toString().trim();
                    final photoUrl = (c['photo_url'] ?? '').toString().trim();

                    return Container(
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: borderColor),
                      ),
                      child: ListTile(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => CandidateProfileScreen(candidate: c)),
                          );
                        },
                        leading: CircleAvatar(
                          backgroundColor: isDarkMode ? Colors.white12 : const Color(0xFFEAF1FF),
                          backgroundImage: resolvedCandidatePhotoUrl(photoUrl) != null
                              ? NetworkImage(resolvedCandidatePhotoUrl(photoUrl)!)
                              : null,
                          child: resolvedCandidatePhotoUrl(photoUrl) != null
                              ? null
                              : Icon(Icons.person, color: isDarkMode ? Colors.white70 : Colors.blue),
                        ),
                        title: Text(name, style: TextStyle(color: titleColor, fontWeight: FontWeight.w900)),
                        subtitle: Text(
                          [
                            if (org.isNotEmpty) org,
                            if (pos.isNotEmpty) pos,
                            if (party.isNotEmpty) party,
                          ].join(' • '),
                          style: TextStyle(color: subtitleColor, fontWeight: FontWeight.w600),
                        ),
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
    );
  }
}

