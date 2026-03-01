import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:hume/models/book.dart';
import 'package:hume/models/book_chapter.dart';
import 'package:hume/models/text_highlight.dart';
import 'package:hume/services/book_service.dart';
import 'package:hume/services/highlight_provider.dart';
import 'package:hume/utils/platform_utils.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hume/widgets/chapter_navigation_drawer.dart';

class ReaderScreen extends StatefulWidget {
  final Book book;

  const ReaderScreen({super.key, required this.book});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen>
    with WidgetsBindingObserver {
  late Future<String> _contentFuture;
  final Completer<String> _contentCompleter = Completer<String>();
  late ScrollController _scrollController;
  late BookService _bookService;

  String _content = '';
  String _htmlContent = '';
  double _fontSize = 18;
  List<BookChapter>? _chapters;
  int _currentChapterIndex = 0;
  bool _isLoadingChapter = false;
  bool _isRestoringPosition = false;
  bool _isInitialLoading = true;
  bool _isBookServiceReady = false;

  // Reading time tracking
  Timer? _readingTimer;
  int _accumulatedMinutes = 0;
  bool _isTrackingTime = false;

  static const double _lineHeight = 1.8;

  bool get _canSwipeChapters {
    // Only enable swipe on mobile - desktop users prefer text selection
    return PlatformUtils.isMobile &&
        (widget.book.format == 'epub' ||
            ['mobi', 'azw', 'azw3'].contains(widget.book.format)) &&
        (_chapters?.length ?? 0) > 1;
  }

  bool get _isHtmlFormat {
    return widget.book.format == 'epub' ||
        ['mobi', 'azw', 'azw3'].contains(widget.book.format);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController = ScrollController();
    _currentChapterIndex = widget.book.currentChapterIndex;
    _scrollController.addListener(_onScrollChanged);
    _contentFuture = _contentCompleter.future;

    // Load highlights for this book
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final highlightProvider = Provider.of<HighlightProvider>(
        context,
        listen: false,
      );
      highlightProvider.loadHighlights(widget.book.id);
      highlightProvider.setCurrentChapter(_currentChapterIndex);
    });

    // Ensure loader frame is rendered and route transition is complete first.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final route = ModalRoute.of(context);
      await _startInitialLoadWhenRouteVisible(route);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _pauseReadingTimer();
      _saveReadingPosition();
    } else if (state == AppLifecycleState.resumed) {
      _resumeReadingTimer();
    }
  }



  @override
  void dispose() {
    _stopReadingTimer();
    _saveReadingPosition();
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.removeListener(_onScrollChanged);
    _scrollController.dispose();
    super.dispose();
  }

  // ==================== Reading Time Tracking ====================

  void _startReadingTimer() {
    if (_isTrackingTime) return;
    _isTrackingTime = true;

    // Timer fires every 1 minute - efficient, minimal CPU usage
    _readingTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _accumulatedMinutes++;
      _saveAccumulatedTime();
    });
  }

  void _pauseReadingTimer() {
    _readingTimer?.cancel();
    _readingTimer = null;
    _isTrackingTime = false;
    // Save any remaining accumulated time
    if (_accumulatedMinutes > 0) {
      _saveAccumulatedTime();
    }
  }

  void _resumeReadingTimer() {
    _startReadingTimer();
  }

  void _stopReadingTimer() {
    _readingTimer?.cancel();
    _readingTimer = null;
    _isTrackingTime = false;
    // Save remaining time on exit
    _saveAccumulatedTime();
  }

  Future<void> _saveAccumulatedTime() async {
    if (!_isBookServiceReady) return;
    if (_accumulatedMinutes <= 0) return;

    final minutesToSave = _accumulatedMinutes;
    _accumulatedMinutes = 0;

    try {
      await _bookService.addReadingTime(minutesToSave);
    } catch (e) {
      debugPrint('Error saving reading time: $e');
      // Restore accumulated time if save failed
      _accumulatedMinutes += minutesToSave;
    }
  }

  void _onScrollChanged() {
    // Throttled save - only save every 500 pixels of scroll to reduce I/O
    if (_scrollController.offset % 500 < 10) {
      _saveReadingPosition();
    }
  }

  Future<void> _saveReadingPosition() async {
    if (!_isBookServiceReady) return;
    if (_isRestoringPosition) return;

    try {
      await _bookService.saveReadingPosition(
        book: widget.book,
        chapterIndex: _currentChapterIndex,
        scrollPosition: _scrollController.hasClients
            ? _scrollController.offset
            : 0,
      );
    } catch (e) {
      debugPrint('Error saving reading position: $e');
    }
  }

  Future<String> _loadContent() async {
    try {
      _bookService = await BookService.create();
      _isBookServiceReady = true;

      if (widget.book.format == 'epub') {
        _chapters = await _bookService.getEpubChapters(widget.book);
        if (_chapters != null && _chapters!.isNotEmpty) {
          // Clamp chapter index to valid range
          final validIndex = _currentChapterIndex.clamp(
            0,
            _chapters!.length - 1,
          );
          await _ensureChapterLoaded(validIndex);
          setState(() {
            _currentChapterIndex = validIndex;
            _content = _chapters![validIndex].content;
            _htmlContent = _chapters![validIndex].htmlContent ?? _content;
          });

          // Restore scroll position after content loads
          _restoreScrollPosition();
          // Start tracking reading time
          _startReadingTimer();
          return _content;
        }
      }

      if (['mobi', 'azw', 'azw3'].contains(widget.book.format)) {
        _chapters = await _bookService.getMobiChapters(widget.book);
        if (_chapters != null && _chapters!.isNotEmpty) {
          // Clamp chapter index to valid range
          final validIndex = _currentChapterIndex.clamp(
            0,
            _chapters!.length - 1,
          );
          await _ensureMobiChapterLoaded(validIndex);
          setState(() {
            _currentChapterIndex = validIndex;
            _content = _chapters![validIndex].content;
            _htmlContent = _chapters![validIndex].htmlContent ?? _content;
          });

          // Restore scroll position after content loads
          _restoreScrollPosition();
          // Start tracking reading time
          _startReadingTimer();
          return _content;
        }
      }

      final content = await _bookService.getBookContent(widget.book);
      setState(() => _content = content);

      // Restore scroll position for TXT files
      _restoreScrollPosition();
      // Start tracking reading time
      _startReadingTimer();
      return content;
    } finally {
      if (mounted) {
        setState(() => _isInitialLoading = false);
      }
    }
  }

  Future<void> _startInitialLoad() async {
    try {
      final content = await _loadContent();
      if (!_contentCompleter.isCompleted) {
        _contentCompleter.complete(content);
      }
    } catch (e, s) {
      if (!_contentCompleter.isCompleted) {
        _contentCompleter.completeError(e, s);
      }
    }
  }

  Future<void> _startInitialLoadWhenRouteVisible(
    ModalRoute<dynamic>? route,
  ) async {
    while (mounted) {
      final animation = route?.animation;
      final isCurrentRoute = route?.isCurrent ?? true;
      final isTransitionDone =
          animation == null || animation.status == AnimationStatus.completed;

      if (isCurrentRoute && isTransitionDone) {
        await _startInitialLoad();
        return;
      }

      await Future<void>.delayed(const Duration(milliseconds: 16));
    }
  }

  Future<void> _ensureChapterLoaded(int index) async {
    if (_chapters == null || index < 0 || index >= _chapters!.length) return;

    final chapter = _chapters![index];
    final hasContent =
        chapter.content.isNotEmpty ||
        (chapter.htmlContent?.isNotEmpty ?? false);
    if (hasContent) return;

    final loaded = await _bookService.getEpubChapterByIndex(widget.book, index);
    if (loaded != null && mounted) {
      _chapters![index] = loaded;
    }
  }

  Future<void> _ensureMobiChapterLoaded(int index) async {
    if (_chapters == null || index < 0 || index >= _chapters!.length) return;

    final chapter = _chapters![index];
    final hasContent =
        chapter.content.isNotEmpty ||
        (chapter.htmlContent?.isNotEmpty ?? false);
    if (hasContent) return;

    final loaded = await _bookService.getMobiChapterByIndex(widget.book, index);
    if (loaded != null && mounted) {
      _chapters![index] = loaded;
    }
  }

  void _restoreScrollPosition() {
    if (widget.book.scrollPosition > 0) {
      _isRestoringPosition = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(widget.book.scrollPosition);
        }
        _isRestoringPosition = false;
      });
    }
  }

  Future<void> _loadChapter(int index) async {
    if (_chapters == null || index < 0 || index >= _chapters!.length) return;

    // Save position before changing chapter
    _saveReadingPosition();

    setState(() {
      _isLoadingChapter = true;
      _currentChapterIndex = index;
    });

    // Update highlight provider for new chapter
    if (mounted) {
      final highlightProvider = Provider.of<HighlightProvider>(
        context,
        listen: false,
      );
      highlightProvider.setCurrentChapter(index);
    }

    // Let Flutter render the loading indicator before heavy chapter work starts.
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;

    if (widget.book.format == 'epub') {
      await _ensureChapterLoaded(index);
    } else if (['mobi', 'azw', 'azw3'].contains(widget.book.format)) {
      await _ensureMobiChapterLoaded(index);
    }

    if (!mounted) return;

    setState(() {
      _content = _chapters![index].content;
      _htmlContent = _chapters![index].htmlContent ?? _content;
      _isLoadingChapter = false;
    });

    _scrollController.jumpTo(0);

    // Preload adjacent chapters for faster navigation
    _preloadAdjacentChapters(index);

    // Save position after chapter change
    _saveReadingPosition();
  }

  /// Preload adjacent chapters for faster swipe navigation
  Future<void> _preloadAdjacentChapters(int currentIndex) async {
    if (_chapters == null) return;

    final ensureLoaded = widget.book.format == 'epub'
        ? _ensureChapterLoaded
        : (['mobi', 'azw', 'azw3'].contains(widget.book.format)
            ? _ensureMobiChapterLoaded
            : null);

    if (ensureLoaded == null) return;

    // Preload next chapter
    if (currentIndex + 1 < _chapters!.length) {
      ensureLoaded(currentIndex + 1);
    }
    // Preload previous chapter
    if (currentIndex - 1 >= 0) {
      ensureLoaded(currentIndex - 1);
    }
  }

  void _nextChapter() {
    if (_chapters != null && _currentChapterIndex < _chapters!.length - 1) {
      _loadChapter(_currentChapterIndex + 1);
    }
  }

  void _previousChapter() {
    if (_currentChapterIndex > 0) {
      _loadChapter(_currentChapterIndex - 1);
    }
  }

  void _increaseFontSize() {
    setState(() {
      _fontSize = (_fontSize + 2).clamp(12, 32);
    });
  }

  void _decreaseFontSize() {
    setState(() {
      _fontSize = (_fontSize - 2).clamp(12, 32);
    });
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _scrollToBottom() {
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  /// Handle link taps in EPUB content
  void _handleLinkTap(String? url, Map<String, String> attributes) {
    if (url == null || url.isEmpty) return;

    // Check if it's an external URL (http:// or https://)
    if (url.startsWith('http://') || url.startsWith('https://')) {
      _showExternalLinkDialog(url);
      return;
    }

    // Handle internal chapter navigation
    if (_chapters == null) return;

    String targetHref = url;

    // Remove anchor part (e.g., "#section" from "chapter1.html#section")
    final anchorIndex = targetHref.indexOf('#');
    if (anchorIndex > 0) {
      targetHref = targetHref.substring(0, anchorIndex);
    }

    // Handle relative paths - extract just the file name
    if (targetHref.contains('/')) {
      targetHref = targetHref.split('/').last;
    }

    // Find the chapter with matching href
    for (int i = 0; i < _chapters!.length; i++) {
      final chapter = _chapters![i];
      if (chapter.href != null) {
        String chapterHref = chapter.href!;
        if (chapterHref.contains('/')) {
          chapterHref = chapterHref.split('/').last;
        }

        if (chapterHref == targetHref) {
          _loadChapter(i);
          return;
        }
      }
    }
  }

  /// Show confirmation dialog for external links
  Future<void> _showExternalLinkDialog(String url) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Open External Link'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Open this link in your browser?'),
            const SizedBox(height: 8),
            Text(
              url,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Open'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _chapters != null && _chapters!.isNotEmpty
              ? _chapters![_currentChapterIndex].title
              : widget.book.title,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (!_isInitialLoading && _chapters != null && _chapters!.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.list),
              onPressed: () => _showChapterList(context),
              tooltip: 'Chapters',
            ),
          if (!_isInitialLoading)
            IconButton(
              icon: const Icon(Icons.text_decrease),
              onPressed: _decreaseFontSize,
            ),
          if (!_isInitialLoading)
            IconButton(
              icon: const Icon(Icons.text_increase),
              onPressed: _increaseFontSize,
            ),
        ],
      ),
      body: FutureBuilder<String>(
        future: _contentFuture,
        builder: (context, snapshot) {
          final isLoading =
              _isInitialLoading ||
              snapshot.connectionState != ConnectionState.done;

          if (isLoading) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      'Loading book in background...',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.book.title,
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
          }

          if (snapshot.hasError) {
            final isPermissionIssue =
                PlatformUtils.isMacOS &&
                PlatformUtils.isPermissionError(snapshot.error!);
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isPermissionIssue
                          ? Icons.lock_outline
                          : Icons.error_outline,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isPermissionIssue
                          ? 'File Access Permission Required'
                          : 'Error: ${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    if (isPermissionIssue) ...[
                      ElevatedButton.icon(
                        onPressed: () =>
                            PlatformUtils.showMacOSPermissionTip(context),
                        icon: const Icon(Icons.info_outline),
                        label: const Text('How to Grant Permission'),
                      ),
                      const SizedBox(height: 8),
                    ],
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Go Back'),
                    ),
                  ],
                ),
              ),
            );
          }

          final scrollableContent = RepaintBoundary(
            child: Scrollbar(
              controller: _scrollController,
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.all(24),
                child: RepaintBoundary(child: _buildContent()),
              ),
            ),
          );

          return Stack(
            children: [
              scrollableContent,
              if (_canSwipeChapters) ..._buildEdgeTapZones(),
              if (_isLoadingChapter)
                const Positioned.fill(
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          );
        },
      ),
      floatingActionButton: _isInitialLoading
          ? null
          : RepaintBoundary(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FloatingActionButton.small(
                    heroTag: 'top',
                    onPressed: _scrollToTop,
                    child: const Icon(Icons.arrow_upward),
                  ),
                  const SizedBox(height: 8),
                  FloatingActionButton.small(
                    heroTag: 'bottom',
                    onPressed: _scrollToBottom,
                    child: const Icon(Icons.arrow_downward),
                  ),
                ],
              ),
            ),
      bottomNavigationBar:
          !_isInitialLoading &&
              _chapters != null &&
              _chapters!.isNotEmpty &&
              _chapters!.length > 1
          ? _buildChapterNavigation()
          : null,
    );
  }

  // ==================== Highlight Methods ====================

  /// Build custom context menu for SelectionArea
  Widget _buildSelectionAreaContextMenu(
    BuildContext context,
    SelectableRegionState selectableRegionState,
  ) {
    final List<Widget> buttonItems = [];

    // Add highlight button
    buttonItems.add(
      TextSelectionToolbarTextButton(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        onPressed: () {
          ContextMenuController.removeAny();
          _handleSelectionAreaHighlight(selectableRegionState);
        },
        child: const Text('Highlight'),
      ),
    );

    return AdaptiveTextSelectionToolbar(
      anchors: selectableRegionState.contextMenuAnchors,
      children: buttonItems,
    );
  }

  /// Handle highlight for SelectionArea - simplified approach
  Future<void> _handleSelectionAreaHighlight(
    SelectableRegionState selectableRegionState,
  ) async {
    // Show info message for now - full selection handling is complex
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please select text first, then use Highlight'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// Build text with highlights applied
  TextSpan _buildHighlightedText(String text) {
    final highlightProvider = context.read<HighlightProvider>();
    final chapterHighlights = highlightProvider.getHighlightsForChapter(
      _currentChapterIndex,
    );

    if (chapterHighlights.isEmpty) {
      return TextSpan(text: text);
    }

    // Sort highlights by start position
    final sortedHighlights = List<TextHighlight>.from(chapterHighlights)
      ..sort((a, b) => a.startOffset.compareTo(b.startOffset));

    final List<TextSpan> spans = [];
    int currentPosition = 0;

    for (final highlight in sortedHighlights) {
      // Skip if highlight is out of bounds
      if (highlight.startOffset >= text.length) continue;

      // Add non-highlighted text before this highlight
      if (highlight.startOffset > currentPosition) {
        spans.add(
          TextSpan(
            text: text.substring(currentPosition, highlight.startOffset),
          ),
        );
      }

      // Calculate highlight end (cap at text length)
      final endOffset = highlight.endOffset.clamp(0, text.length);

      // Add highlighted text
      final highlightText = text.substring(
        highlight.startOffset.clamp(0, text.length),
        endOffset,
      );

      if (highlightText.isNotEmpty) {
        spans.add(
          TextSpan(
            text: highlightText,
            style: TextStyle(
              backgroundColor: highlight.style == HighlightStyle.markpen
                  ? highlight.color.withValues(alpha: 0.4)
                  : null,
              decoration: highlight.style == HighlightStyle.underline
                  ? TextDecoration.underline
                  : null,
              decorationColor: highlight.color,
              decorationThickness: 3,
            ),
          ),
        );
      }

      currentPosition = endOffset;
    }

    // Add remaining text after last highlight
    if (currentPosition < text.length) {
      spans.add(TextSpan(text: text.substring(currentPosition)));
    }

    return TextSpan(children: spans);
  }

  List<Widget> _buildEdgeTapZones() {
    const double tapZoneWidth = 60.0;
    final canGoPrevious = _currentChapterIndex > 0;
    final canGoNext = _chapters != null && _currentChapterIndex < _chapters!.length - 1;

    return [
      Positioned(
        left: 0,
        top: 0,
        bottom: 0,
        width: tapZoneWidth,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: canGoPrevious ? _previousChapter : null,
          child: IgnorePointer(
            ignoring: !canGoPrevious,
            child: Container(
              color: Colors.transparent,
            ),
          ),
        ),
      ),
      Positioned(
        right: 0,
        top: 0,
        bottom: 0,
        width: tapZoneWidth,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: canGoNext ? _nextChapter : null,
          child: IgnorePointer(
            ignoring: !canGoNext,
            child: Container(
              color: Colors.transparent,
            ),
          ),
        ),
      ),
    ];
  }

  Widget _buildContent() {
    final baseStyle = TextStyle(fontSize: _fontSize, height: _lineHeight);

    if (_isHtmlFormat && _htmlContent.isNotEmpty) {
      return SelectionArea(
        child: HtmlWidget(
          _htmlContent,
          onTapUrl: (url) {
            _handleLinkTap(url, {});
            return true;
          },
          textStyle: baseStyle,
          customStylesBuilder: (element) {
            final tagName = element.localName?.toLowerCase();
            switch (tagName) {
              case 'h1':
                return {
                  'font-size': '${(_fontSize * 1.8).toStringAsFixed(1)}px',
                  'font-weight': 'bold',
                  'line-height': '1.3',
                  'margin-bottom': '16px',
                  'margin-top': '24px',
                };
              case 'h2':
                return {
                  'font-size': '${(_fontSize * 1.5).toStringAsFixed(1)}px',
                  'font-weight': 'bold',
                  'line-height': '1.3',
                  'margin-bottom': '12px',
                  'margin-top': '20px',
                };
              case 'h3':
                return {
                  'font-size': '${(_fontSize * 1.3).toStringAsFixed(1)}px',
                  'font-weight': 'bold',
                  'line-height': '1.4',
                  'margin-bottom': '10px',
                  'margin-top': '16px',
                };
              case 'h4':
                return {
                  'font-size': '${(_fontSize * 1.15).toStringAsFixed(1)}px',
                  'font-weight': 'bold',
                  'line-height': '1.4',
                  'margin-bottom': '8px',
                  'margin-top': '12px',
                };
              case 'h5':
                return {
                  'font-size': '${(_fontSize * 1.0).toStringAsFixed(1)}px',
                  'font-weight': 'bold',
                  'line-height': '1.5',
                  'margin-bottom': '6px',
                  'margin-top': '10px',
                };
              case 'h6':
                return {
                  'font-size': '${(_fontSize * 0.9).toStringAsFixed(1)}px',
                  'font-weight': 'bold',
                  'line-height': '1.5',
                  'margin-bottom': '6px',
                  'margin-top': '10px',
                };
              case 'p':
                return {
                  'font-size': '${_fontSize.toStringAsFixed(1)}px',
                  'line-height': '$_lineHeight',
                  'margin-bottom': '12px',
                };
              case 'blockquote':
                return {
                  'font-size': '${(_fontSize * 0.95).toStringAsFixed(1)}px',
                  'font-style': 'italic',
                  'padding-left': '16px',
                  'margin-bottom': '12px',
                  'margin-top': '12px',
                  'border-left': '4px solid',
                };
              case 'li':
                return {
                  'font-size': '${_fontSize.toStringAsFixed(1)}px',
                  'line-height': '$_lineHeight',
                };
              case 'a':
                return {
                  'color': _colorToHex(Theme.of(context).colorScheme.primary),
                  'text-decoration': 'underline',
                };
              default:
                return null;
            }
          },
        ),
      );
    }

    return SelectionArea(
      contextMenuBuilder: (context, selectableRegionState) {
        return _buildSelectionAreaContextMenu(context, selectableRegionState);
      },
      child: SelectableText.rich(
        _buildHighlightedText(_content),
        style: baseStyle,
      ),
    );
  }

  String _colorToHex(Color color) {
    return '#${color.r.toInt().toRadixString(16).padLeft(2, '0')}${color.g.toInt().toRadixString(16).padLeft(2, '0')}${color.b.toInt().toRadixString(16).padLeft(2, '0')}';
  }

  Widget _buildChapterNavigation() {
    final canGoPrevious = _currentChapterIndex > 0;
    final canGoNext = _currentChapterIndex < _chapters!.length - 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: canGoPrevious ? _previousChapter : null,
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Previous Chapter',
          ),
          Text(
            'Chapter ${_currentChapterIndex + 1} of ${_chapters!.length}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          IconButton(
            onPressed: canGoNext ? _nextChapter : null,
            icon: const Icon(Icons.arrow_forward),
            tooltip: 'Next Chapter',
          ),
        ],
      ),
    );
  }

  void _showChapterList(BuildContext context) {
    if (_chapters == null || _chapters!.isEmpty) return;

    // Use Navigator to push a new route with the drawer overlay
    Navigator.of(context).push(
      _ChapterDrawerRoute(
        chapters: _chapters!,
        currentChapterIndex: _currentChapterIndex,
        onChapterSelected: (index) {
          _loadChapter(index);
          Navigator.of(context).pop();
        },
      ),
    );
  }
}

/// Custom route for slide-out chapter navigation drawer
class _ChapterDrawerRoute extends PageRouteBuilder {
  final List<BookChapter> chapters;
  final int currentChapterIndex;
  final ValueChanged<int> onChapterSelected;

  _ChapterDrawerRoute({
    required this.chapters,
    required this.currentChapterIndex,
    required this.onChapterSelected,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) {
            return _ChapterDrawerOverlay(
              chapters: chapters,
              currentChapterIndex: currentChapterIndex,
              onChapterSelected: onChapterSelected,
            );
          },
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return Stack(
              children: [
                // Dimmed background
                FadeTransition(
                  opacity: animation,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      color: Colors.black54,
                    ),
                  ),
                ),
                // Slide-in drawer from right
                SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(1, 0),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  )),
                  child: child,
                ),
              ],
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 250),
        );
}

/// Overlay widget containing the chapter navigation drawer
class _ChapterDrawerOverlay extends StatelessWidget {
  final List<BookChapter> chapters;
  final int currentChapterIndex;
  final ValueChanged<int> onChapterSelected;

  const _ChapterDrawerOverlay({
    required this.chapters,
    required this.currentChapterIndex,
    required this.onChapterSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: ChapterNavigationDrawer(
        chapters: chapters,
        currentChapterIndex: currentChapterIndex,
        onChapterSelected: onChapterSelected,
        onClose: () => Navigator.of(context).pop(),
      ),
    );
  }
}
