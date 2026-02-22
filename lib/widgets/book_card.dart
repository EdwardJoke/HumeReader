import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:hume/models/book.dart';
import 'package:hume/services/book_service.dart';

/// Global cache for book covers - survives across widget rebuilds
/// This prevents re-loading images from disk when scrolling back
final Map<String, Uint8List> _coverImageCache = {};

class BookCard extends StatefulWidget {
  final Book book;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final void Function(Book book)? onAddToShelf;

  const BookCard({
    super.key,
    required this.book,
    required this.onTap,
    required this.onDelete,
    this.onAddToShelf,
  });

  static String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  State<BookCard> createState() => _BookCardState();
}

class _BookCardState extends State<BookCard> {
  Uint8List? _coverImage;
  bool _isLoading = false;
  BookService? _bookService;

  @override
  void initState() {
    super.initState();
    _loadCoverImage();
  }

  @override
  void didUpdateWidget(BookCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload cover if book changed
    if (oldWidget.book.id != widget.book.id) {
      _coverImage = null;
      _loadCoverImage();
    }
  }

  Future<void> _loadCoverImage() async {
    // Check cache first - fastest path
    if (_coverImageCache.containsKey(widget.book.id)) {
      if (mounted) {
        setState(() => _coverImage = _coverImageCache[widget.book.id]);
      }
      return;
    }

    // Check if book has cover in memory (legacy base64 data during migration)
    if (widget.book.coverImage != null) {
      // Cache for future use
      _coverImageCache[widget.book.id] = widget.book.coverImage!;
      if (mounted) {
        setState(() => _coverImage = widget.book.coverImage);
      }
      return;
    }

    // Load from file path (new optimized storage)
    if (widget.book.coverImageFilePath != null) {
      if (mounted) {
        setState(() => _isLoading = true);
      }

      try {
        _bookService ??= await BookService.create();
        final image = await _bookService!.loadCoverImage(
          widget.book.coverImageFilePath,
        );

        if (mounted && image != null) {
          // Cache for future use
          _coverImageCache[widget.book.id] = image;
          setState(() {
            _coverImage = image;
            _isLoading = false;
          });
        } else if (mounted) {
          setState(() => _isLoading = false);
        }
      } catch (e) {
        debugPrint('Error loading cover image: $e');
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Widget _buildDefaultCover(ColorScheme colorScheme) {
    return Container(
      width: 56,
      height: 80,
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.menu_book,
        color: colorScheme.onPrimaryContainer,
        size: 28,
      ),
    );
  }

  Widget _buildCoverImage(ColorScheme colorScheme) {
    if (_isLoading) {
      return Container(
        width: 56,
        height: 80,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.memory(
        _coverImage!,
        width: 56,
        height: 80,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            _buildDefaultCover(colorScheme),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Cache colorScheme to avoid repeated Theme.of calls
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Cover image with lazy loading
              _coverImage != null || _isLoading
                  ? _buildCoverImage(colorScheme)
                  : _buildDefaultCover(colorScheme),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.book.title,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.book.format.toUpperCase()} • ${BookCard._formatFileSize(widget.book.fileSize)}',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.outline,
                      ),
                    ),
                    if (widget.book.maxReadingProgress > 0) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: widget.book.readingProgress / 100,
                                backgroundColor:
                                    colorScheme.surfaceContainerHighest,
                                valueColor: AlwaysStoppedAnimation(
                                  colorScheme.primary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${widget.book.maxReadingProgress}%',
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (widget.onAddToShelf != null)
                IconButton(
                  icon: const Icon(Icons.shelves),
                  onPressed: () => widget.onAddToShelf!(widget.book),
                  tooltip: 'Add to shelf',
                  color: colorScheme.primary,
                ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: widget.onDelete,
                color: colorScheme.error,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
