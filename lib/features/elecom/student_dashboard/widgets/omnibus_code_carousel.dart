import 'dart:async';

import 'package:flutter/material.dart';

/// Opens a full-screen omnibus reader (multi-page, PDF-style).
void showOmnibusFullScreen(
  BuildContext context, {
  required List<String> assetPaths,
  required int initialIndex,
}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (ctx) => _OmnibusFullscreenReader(
        assetPaths: assetPaths,
        initialIndex: initialIndex,
      ),
    ),
  );
}

class _OmnibusFullscreenReader extends StatefulWidget {
  const _OmnibusFullscreenReader({
    required this.assetPaths,
    required this.initialIndex,
  });

  final List<String> assetPaths;
  final int initialIndex;

  @override
  State<_OmnibusFullscreenReader> createState() => _OmnibusFullscreenReaderState();
}

class _OmnibusFullscreenReaderState extends State<_OmnibusFullscreenReader> {
  final ScrollController _scrollController = ScrollController();
  late final List<GlobalKey> _pageKeys;

  @override
  void initState() {
    super.initState();
    _pageKeys = List<GlobalKey>.generate(widget.assetPaths.length, (_) => GlobalKey());
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || widget.assetPaths.isEmpty) return;
      final idx = widget.initialIndex.clamp(0, widget.assetPaths.length - 1);
      final ctx = _pageKeys[idx].currentContext;
      if (ctx == null) return;
      await Scrollable.ensureVisible(
        ctx,
        alignment: 0.18,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : Colors.white;
    final fg = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        foregroundColor: fg,
        elevation: 0,
        iconTheme: IconThemeData(color: fg),
        title: Text(
          'Omnibus Code',
          style: TextStyle(color: fg, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: Scrollbar(
          controller: _scrollController,
          thumbVisibility: true,
          interactive: true,
          child: SingleChildScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 32),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxW = constraints.maxWidth;
                final pageW = maxW.clamp(320, 560).toDouble();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < widget.assetPaths.length; i++) ...[
                      Center(
                        key: _pageKeys[i],
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: pageW),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isDark ? Colors.white12 : Colors.black12,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(13),
                              child: Image.asset(
                                widget.assetPaths[i],
                                fit: BoxFit.fitWidth,
                                alignment: Alignment.topCenter,
                                filterQuality: FilterQuality.medium,
                                errorBuilder: (context, error, stackTrace) {
                                  return Padding(
                                    padding: const EdgeInsets.all(32),
                                    child: Icon(
                                      Icons.broken_image_outlined,
                                      size: 72,
                                      color: fg.withValues(alpha: 0.45),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Horizontal auto-advancing carousel: **two cards per page** (like ELECOM reference).
class OmnibusCodeCarousel extends StatefulWidget {
  const OmnibusCodeCarousel({
    super.key,
    this.assetPaths,
    this.interval = const Duration(seconds: 5),
    this.height = 200,
  });

  /// Defaults to [page01.jpg … page14.jpg] under `assets/omnibus/`.
  final List<String>? assetPaths;
  final Duration interval;
  final double height;

  static List<String> defaultAssetPaths() {
    return List<String>.generate(
      14,
      (i) => 'assets/omnibus/page${(i + 1).toString().padLeft(2, '0')}.jpg',
    );
  }

  @override
  State<OmnibusCodeCarousel> createState() => _OmnibusCodeCarouselState();
}

class _OmnibusCodeCarouselState extends State<OmnibusCodeCarousel> {
  late PageController _pageController;
  Timer? _timer;

  List<String> get _paths => widget.assetPaths ?? OmnibusCodeCarousel.defaultAssetPaths();

  int get _pageCount => _paths.isEmpty ? 0 : (_paths.length + 1) ~/ 2;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _timer = Timer.periodic(widget.interval, (_) {
      if (!mounted || _pageCount <= 1) return;
      if (!_pageController.hasClients) return;
      final cur = _pageController.page!.round();
      final next = (cur + 1) % _pageCount;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : Colors.black;
    final paths = _paths;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Omnibus Code',
          style: TextStyle(
            color: titleColor,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: widget.height,
          child: PageView.builder(
            controller: _pageController,
            itemCount: _pageCount,
            itemBuilder: (context, pageIndex) {
              final i = pageIndex * 2;
              final leftPath = paths[i];
              final rightPath = i + 1 < paths.length ? paths[i + 1] : null;
              final pad = const EdgeInsets.symmetric(horizontal: 2);
              if (rightPath == null) {
                return Padding(
                  padding: pad,
                  child: _OmnibusCard(
                    path: leftPath,
                    index: i,
                    allPaths: paths,
                    height: widget.height,
                    isDark: isDark,
                  ),
                );
              }
              return Padding(
                padding: pad,
                child: Row(
                  children: [
                    Expanded(
                      child: _OmnibusCard(
                        path: leftPath,
                        index: i,
                        allPaths: paths,
                        height: widget.height,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _OmnibusCard(
                        path: rightPath,
                        index: i + 1,
                        allPaths: paths,
                        height: widget.height,
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _OmnibusCard extends StatelessWidget {
  const _OmnibusCard({
    required this.path,
    required this.index,
    required this.allPaths,
    required this.height,
    required this.isDark,
  });

  final String path;
  final int index;
  final List<String> allPaths;
  final double height;
  final bool isDark;

  static const Color _frame = Color(0xFF0c1e70);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => showOmnibusFullScreen(
          context,
          assetPaths: allPaths,
          initialIndex: index,
        ),
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          height: height,
          decoration: BoxDecoration(
            color: isDark ? _frame.withValues(alpha: 0.35) : _frame.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _frame, width: 2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              path,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (context, error, stackTrace) => ColoredBox(
                color: isDark ? Colors.white10 : Colors.grey.shade300,
                child: Icon(
                  Icons.picture_as_pdf_outlined,
                  size: 40,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
