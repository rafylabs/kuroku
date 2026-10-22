import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:extended_image/extended_image.dart';
import '../../../core/parser/parser_registry.dart';
import '../providers/reader_provider.dart';

class MangaReaderScreen extends ConsumerStatefulWidget {
  final ReaderArgs args;

  const MangaReaderScreen({super.key, required this.args});

  @override
  ConsumerState<MangaReaderScreen> createState() => _MangaReaderScreenState();
}

class _MangaReaderScreenState extends ConsumerState<MangaReaderScreen> {
  bool _showHud = true;
  late ExtendedPageController _pageController;
  final ScrollController _webtoonScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _pageController = ExtendedPageController(initialPage: widget.args.initialPage);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _pageController.dispose();
    _webtoonScrollController.dispose();
    super.dispose();
  }

  void _toggleHud() {
    setState(() {
      _showHud = !_showHud;
    });
  }

  @override
  Widget build(BuildContext context) {
    final readerState = ref.watch(readerProvider(widget.args));
    final readerNotifier = ref.read(readerProvider(widget.args).notifier);
    final readerMode = ref.watch(readerModeProvider);
    final parser = ParserRegistry.instance.getParser(widget.args.manga.sourceId);

    if (readerState.isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Color(0xFF00F0FF)),
              const SizedBox(height: 16),
              Text(
                'Loading ${widget.args.chapter.title}...',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    if (readerState.error != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.transparent),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                const SizedBox(height: 12),
                const Text(
                  'Failed to load chapter pages',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  readerState.error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => readerNotifier.loadPages(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final pages = readerState.pages;
    final totalPages = pages.length;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. READER VIEW CANVAS
          GestureDetector(
            onTap: _toggleHud,
            behavior: HitTestBehavior.opaque,
            child: readerMode == ReaderMode.webtoon
                ? _buildWebtoonView(pages, parser?.headers, readerNotifier)
                : _buildPagedView(pages, parser?.headers, readerMode, readerNotifier),
          ),

          // 2. TOP HUD (App Bar)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            top: _showHud ? 0 : -100,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                bottom: 12,
                left: 8,
                right: 16,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.85),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.args.manga.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.args.chapter.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  // Reader Mode Switcher Popup
                  PopupMenuButton<ReaderMode>(
                    icon: const Icon(Icons.chrome_reader_mode, color: Colors.white),
                    tooltip: 'Reader Mode',
                    onSelected: (mode) {
                      ref.read(readerModeProvider.notifier).state = mode;
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: ReaderMode.webtoon,
                        child: Text('Webtoon (Vertical Continuous)'),
                      ),
                      const PopupMenuItem(
                        value: ReaderMode.pagedRtl,
                        child: Text('Paged RTL (Manga Standard)'),
                      ),
                      const PopupMenuItem(
                        value: ReaderMode.pagedLtr,
                        child: Text('Paged LTR (Western Comic)'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 3. BOTTOM HUD (Scrubber & Page info)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            bottom: _showHud ? 0 : -120,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + 12,
                top: 16,
                left: 16,
                right: 16,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.85),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Page ${readerState.currentPage + 1} / $totalPages',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        readerMode == ReaderMode.webtoon
                            ? 'Webtoon'
                            : readerMode == ReaderMode.pagedRtl
                                ? 'Manga RTL'
                                : 'Comic LTR',
                        style: const TextStyle(color: Color(0xFF00F0FF), fontSize: 11),
                      ),
                    ],
                  ),
                  if (totalPages > 1 && readerMode != ReaderMode.webtoon)
                    Slider(
                      value: readerState.currentPage.toDouble().clamp(0, (totalPages - 1).toDouble()),
                      min: 0,
                      max: (totalPages - 1).toDouble(),
                      divisions: totalPages > 1 ? totalPages - 1 : 1,
                      activeColor: const Color(0xFF00F0FF),
                      inactiveColor: Colors.white24,
                      onChanged: (val) {
                        final target = val.round();
                        _pageController.jumpToPage(target);
                        readerNotifier.onPageChanged(target);
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Webtoon (Continuous vertical list)
  Widget _buildWebtoonView(
    List pages,
    Map<String, String>? headers,
    ReaderNotifier notifier,
  ) {
    return ListView.builder(
      controller: _webtoonScrollController,
      padding: EdgeInsets.zero,
      itemCount: pages.length,
      itemBuilder: (context, index) {
        final page = pages[index];
        return ExtendedImage.network(
          page.url,
          fit: BoxFit.contain,
          headers: headers,
          cache: true,
          mode: ExtendedImageMode.gesture,
          initGestureConfigHandler: (state) {
            return GestureConfig(
              minScale: 1.0,
              animationMinScale: 0.8,
              maxScale: 3.0,
              animationMaxScale: 3.5,
              speed: 1.0,
              inertialSpeed: 100.0,
              initialScale: 1.0,
              inPageView: false,
            );
          },
          loadStateChanged: (state) {
            if (state.extendedImageLoadState == LoadState.loading) {
              return Container(
                height: 350,
                color: Colors.black,
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white24, strokeWidth: 2),
                ),
              );
            }
            if (state.extendedImageLoadState == LoadState.completed) {
              // Track scrolling progress
              WidgetsBinding.instance.addPostFrameCallback((_) {
                notifier.onPageChanged(index);
              });
            }
            return null;
          },
        );
      },
    );
  }

  // Paged Horizontal Viewer (RTL or LTR)
  Widget _buildPagedView(
    List pages,
    Map<String, String>? headers,
    ReaderMode mode,
    ReaderNotifier notifier,
  ) {
    final isRtl = mode == ReaderMode.pagedRtl;

    return ExtendedImageGesturePageView.builder(
      controller: _pageController,
      reverse: isRtl,
      itemCount: pages.length,
      onPageChanged: (index) {
        notifier.onPageChanged(index);
      },
      itemBuilder: (context, index) {
        final page = pages[index];
        return ExtendedImage.network(
          page.url,
          fit: BoxFit.contain,
          headers: headers,
          cache: true,
          mode: ExtendedImageMode.gesture,
          initGestureConfigHandler: (state) {
            return GestureConfig(
              minScale: 1.0,
              animationMinScale: 0.8,
              maxScale: 3.0,
              animationMaxScale: 3.5,
              speed: 1.0,
              inertialSpeed: 100.0,
              initialScale: 1.0,
              inPageView: true,
            );
          },
          loadStateChanged: (state) {
            if (state.extendedImageLoadState == LoadState.loading) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.white24, strokeWidth: 2),
              );
            }
            return null;
          },
        );
      },
    );
  }
}
