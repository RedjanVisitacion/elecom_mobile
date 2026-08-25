import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

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
  State<_OmnibusFullscreenReader> createState() =>
      _OmnibusFullscreenReaderState();
}

class _OmnibusFullscreenReaderState extends State<_OmnibusFullscreenReader> {
  final ScrollController _scrollController = ScrollController();
  late final List<GlobalKey> _pageKeys;
  // One TransformationController per page for independent zoom state.
  late final List<TransformationController> _transformControllers;
  bool _zoomHintShown = false;

  @override
  void initState() {
    super.initState();
    _pageKeys = List<GlobalKey>.generate(
      widget.assetPaths.length,
      (_) => GlobalKey(),
    );
    _transformControllers = List<TransformationController>.generate(
      widget.assetPaths.length,
      (_) => TransformationController(),
    );
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
      // Show zoom hint briefly after navigating to the page.
      if (mounted) {
        setState(() => _zoomHintShown = true);
        await Future<void>.delayed(const Duration(seconds: 3));
        if (mounted) setState(() => _zoomHintShown = false);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    for (final c in _transformControllers) {
      c.dispose();
    }
    super.dispose();
  }

  /// Double-tap resets zoom on the tapped page.
  void _resetZoom(int index) {
    _transformControllers[index].value = Matrix4.identity();
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
        actions: [
          // Reset zoom button
          IconButton(
            tooltip: 'Reset zoom',
            icon: Icon(Icons.zoom_out_map_rounded, color: fg),
            onPressed: () {
              for (final c in _transformControllers) {
                c.value = Matrix4.identity();
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Scrollbar(
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
                                  color: isDark
                                      ? Colors.white10
                                      : Colors.black.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isDark
                                        ? Colors.white12
                                        : Colors.black12,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(13),
                                  child: GestureDetector(
                                    onDoubleTap: () => _resetZoom(i),
                                    child: InteractiveViewer(
                                      transformationController:
                                          _transformControllers[i],
                                      // Allow up to 5× zoom.
                                      maxScale: 5.0,
                                      minScale: 0.8,
                                      // Clip so the zoomed image stays within
                                      // the card boundary.
                                      clipBehavior: Clip.hardEdge,
                                      child: Image.asset(
                                        widget.assetPaths[i],
                                        fit: BoxFit.fitWidth,
                                        alignment: Alignment.topCenter,
                                        filterQuality: FilterQuality.high,
                                        errorBuilder:
                                            (context, error, stackTrace) {
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
            // Zoom hint overlay — fades in then out automatically.
            AnimatedOpacity(
              opacity: _zoomHintShown ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 400),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.70),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.pinch_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Pinch to zoom · Double-tap to reset',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Horizontally scrollable omnibus page previews (tap opens full-screen reader).
class OmnibusCodeCarousel extends StatefulWidget {
  const OmnibusCodeCarousel({
    super.key,
    this.assetPaths,
    this.height = 200,
    this.cardWidth = 168,
  });

  /// Defaults to [page01.jpg … page14.jpg] under `assets/omnibus/`.
  final List<String>? assetPaths;
  final double height;
  final double cardWidth;

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
  List<String> get _paths =>
      widget.assetPaths ?? OmnibusCodeCarousel.defaultAssetPaths();
  int _currentIndex = 0;

  List<List<int>> _groupedPageIndices(int total) {
    if (total <= 0) return const <List<int>>[];
    final groups = <List<int>>[];
    for (var i = 0; i < total; i += 2) {
      final pair = <int>[i];
      if (i + 1 < total) pair.add(i + 1);
      groups.add(pair);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : Colors.black;
    final paths = _paths;
    final groupedIndices = _groupedPageIndices(paths.length);

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
          child: paths.isEmpty
              ? const SizedBox.shrink()
              : CarouselSlider.builder(
                  itemCount: groupedIndices.length,
                  itemBuilder: (context, slideIndex, _) {
                    final group = groupedIndices[slideIndex];
                    if (group.length == 1) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Row(
                          children: [
                            const Spacer(),
                            Expanded(
                              flex: 2,
                              child: _OmnibusCard(
                                path: paths[group[0]],
                                index: group[0],
                                allPaths: paths,
                                height: widget.height,
                                isDark: isDark,
                              ),
                            ),
                            const Spacer(),
                          ],
                        ),
                      );
                    }
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Row(
                        children: [
                          Expanded(
                            child: _OmnibusCard(
                              path: paths[group[0]],
                              index: group[0],
                              allPaths: paths,
                              height: widget.height,
                              isDark: isDark,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _OmnibusCard(
                              path: paths[group[1]],
                              index: group[1],
                              allPaths: paths,
                              height: widget.height,
                              isDark: isDark,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  options: CarouselOptions(
                    height: widget.height,
                    viewportFraction: 1.0,
                    enlargeCenterPage: false,
                    autoPlay: groupedIndices.length > 1,
                    autoPlayInterval: const Duration(seconds: 4),
                    autoPlayAnimationDuration: const Duration(
                      milliseconds: 650,
                    ),
                    autoPlayCurve: Curves.easeInOut,
                    enableInfiniteScroll: groupedIndices.length > 1,
                    pauseAutoPlayOnManualNavigate: true,
                    pauseAutoPlayOnTouch: true,
                    onPageChanged: (index, _) {
                      if (!mounted) return;
                      setState(() => _currentIndex = index);
                    },
                  ),
                ),
        ),
        if (groupedIndices.length > 1) ...[
          const SizedBox(height: 8),
          Center(
            child: AnimatedSmoothIndicator(
              activeIndex: _currentIndex.clamp(0, groupedIndices.length - 1),
              count: groupedIndices.length,
              effect: ExpandingDotsEffect(
                dotWidth: 5.5,
                dotHeight: 5.5,
                spacing: 4.5,
                expansionFactor: 2.1,
                dotColor: isDark ? Colors.white24 : const Color(0xFFCCCCCC),
                activeDotColor: isDark ? Colors.white : const Color(0xFF4A4A4A),
              ),
            ),
          ),
        ],
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
            color: isDark
                ? _frame.withValues(alpha: 0.35)
                : _frame.withValues(alpha: 0.08),
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
