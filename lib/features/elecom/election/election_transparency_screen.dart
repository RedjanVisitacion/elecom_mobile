import 'package:flutter/material.dart';

class ElectionTransparencyScreen extends StatelessWidget {
  const ElectionTransparencyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF171620) : const Color(0xFFF3F4F6);
    final card = isDark ? const Color(0xFF2A2A35) : Colors.white;
    final border = isDark ? Colors.white12 : const Color(0xFFDADCE0);
    final fg = isDark ? Colors.white : Colors.black;
    final sub = isDark ? Colors.white70 : const Color(0xFF4B5563);
    final gold = const Color(0xFFD4AF37);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text(
          'Election Transparency',
          style: TextStyle(color: fg, fontWeight: FontWeight.w900),
        ),
        iconTheme: IconThemeData(color: fg),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.26 : 0.10),
                      blurRadius: 26,
                      offset: const Offset(0, 14),
                    ),
                    BoxShadow(
                      color: gold.withValues(alpha: isDark ? 0.06 : 0.04),
                      blurRadius: 22,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : const Color(0xFFF5F1E3),
                          shape: BoxShape.circle,
                          border: Border.all(color: gold.withValues(alpha: 0.55), width: 1),
                        ),
                        child: Icon(Icons.hub_rounded, color: gold, size: 32),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Voting Ledger',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: fg, fontWeight: FontWeight.w900, fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This section is designed to provide transparency by showing that votes are recorded securely in the election ledger.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: sub, fontWeight: FontWeight.w700, height: 1.35),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'More ledger details will appear here when enabled by your institution.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: isDark ? Colors.white60 : Colors.black45, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

