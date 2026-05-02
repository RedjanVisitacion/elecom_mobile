import 'package:flutter/material.dart';

import '../../candidates/candidate_profile_screen.dart';

String homeCandidateFirstName(Map<String, dynamic> c) {
  final f = (c['first_name'] ?? '').toString().trim();
  if (f.isNotEmpty) return f;
  for (final k in ['middle_name', 'last_name']) {
    final s = (c[k] ?? '').toString().trim();
    if (s.isNotEmpty) return s;
  }
  return 'Candidate';
}

/// Messenger-style horizontal row: circular photo with first name below.
class HomeCandidatesStrip extends StatelessWidget {
  const HomeCandidatesStrip({
    super.key,
    required this.candidates,
    required this.isDarkMode,
  });

  final List<Map<String, dynamic>> candidates;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    if (candidates.isEmpty) return const SizedBox.shrink();

    final labelColor = isDarkMode ? Colors.white : Colors.black87;
    final ringColor = isDarkMode ? const Color(0xFFFEA501) : const Color(0xFF0C1E70);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Candidates',
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 122,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(2, 2, 2, 8),
            itemCount: candidates.length,
            separatorBuilder: (context, index) => const SizedBox(width: 14),
            itemBuilder: (context, i) {
              final c = candidates[i];
              final photo = resolvedCandidatePhotoUrl(c['photo_url']);
              final first = homeCandidateFirstName(c);
              return SizedBox(
                width: 76,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => CandidateProfileScreen(candidate: Map<String, dynamic>.from(c)),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: ringColor, width: 2.5),
                          ),
                          padding: const EdgeInsets.all(2.5),
                          child: CircleAvatar(
                            radius: 30,
                            backgroundColor: isDarkMode ? Colors.white12 : const Color(0xFFEAF1FF),
                            backgroundImage: photo != null ? NetworkImage(photo) : null,
                            child: photo == null
                                ? Icon(Icons.person, size: 28, color: isDarkMode ? Colors.white54 : Colors.blue)
                                : null,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          first,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: labelColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
