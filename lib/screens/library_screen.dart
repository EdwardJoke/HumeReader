import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hume/models/book.dart';
import 'package:hume/models/shelf.dart';
import 'package:hume/screens/reader_screen.dart';
import 'package:hume/services/book_service.dart';
import 'package:hume/utils/platform_utils.dart';
import 'package:hume/widgets/book_card.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  static const List<String> _supportedExtensions = [
    'txt',
    'epub',
    'mobi',
    'azw',
    'azw3',
  ];

  late Future<BookService> _bookServiceFuture;
  List<Book> _books = [];
  List<Shelf> _shelves = [];
  Shelf? _selectedShelf;
  bool _isLoading = false;
  bool _sidebarExtended = true;
  bool _isDragActive = false;

  @override
  void initState() {
    super.initState();
    _bookServiceFuture = BookService.create();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final service = await _bookServiceFuture;
    final books = await service.getBooks();
    final shelves = await service.getShelves();
    setState(() {
      _books = books;
      _shelves = shelves;
      _isLoading = false;
    });
  }

  List<Book> get _displayedBooks {
    if (_selectedShelf == null) return _books;
    return _books.where((b) => _selectedShelf!.bookIds.contains(b.id)).toList();
  }

  Future<void> _importBook() async {
    try {
      final useAndroidAnyPicker = PlatformUtils.isAndroid;
      final result = await FilePicker.platform.pickFiles(
        type: useAndroidAnyPicker ? FileType.any : FileType.custom,
        allowedExtensions: useAndroidAnyPicker ? null : _supportedExtensions,
        withData: PlatformUtils.isWeb,
      );

      if (result != null) {
        final pickedFile = result.files.single;
        if (!_isSupportedFileName(pickedFile.name)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Unsupported file type. Please pick a txt, epub, mobi, azw, or azw3 file.',
                ),
              ),
            );
          }
          return;
        }

        final service = await _bookServiceFuture;
        Book? book;

        if (PlatformUtils.isWeb) {
          if (pickedFile.bytes == null) {
            throw Exception('Web import failed: no file bytes available.');
          }
          book = await service.importBookBytes(
            pickedFile.bytes!,
            pickedFile.name,
          );
        } else if (pickedFile.bytes != null) {
          book = await service.importBookBytes(
            pickedFile.bytes!,
            pickedFile.name,
          );
        } else if (pickedFile.path != null) {
          final file = File(pickedFile.path!);
          book = await service.importBook(file);
        } else {
          throw Exception('Import failed: file path is unavailable.');
        }

        await _loadData();

        // Show permission tip on macOS if import failed
        if (book == null && mounted && PlatformUtils.isMacOS) {
          PlatformUtils.showMacOSPermissionSnackbar(context);
        }
      }
    } catch (e) {
      if (mounted) {
        await PlatformUtils.handleFileError(
          context,
          e,
          operation: 'import book',
        );
      }
    }
  }

  bool get _supportsDragAndDrop =>
      PlatformUtils.isWeb || PlatformUtils.isDesktop;

  bool _isSupportedFileName(String fileName) {
    final lastDot = fileName.lastIndexOf('.');
    if (lastDot <= 0 || lastDot >= fileName.length - 1) {
      return false;
    }
    final extension = fileName.substring(lastDot + 1).toLowerCase();
    return _supportedExtensions.contains(extension);
  }

  Future<void> _handleDroppedFiles(List<DropItem> files) async {
    if (files.isEmpty) return;

    final service = await _bookServiceFuture;
    var importedCount = 0;
    var skippedCount = 0;

    for (final file in files) {
      if (!_isSupportedFileName(file.name)) {
        skippedCount++;
        continue;
      }

      try {
        final bytes = await file.readAsBytes();
        final book = await service.importBookBytes(bytes, file.name);
        if (book != null) {
          importedCount++;
        } else {
          skippedCount++;
        }
      } catch (_) {
        skippedCount++;
      }
    }

    if (importedCount > 0) {
      await _loadData();
    }

    if (!mounted) return;

    final message = importedCount > 0
        ? skippedCount > 0
              ? 'Imported $importedCount file(s). Skipped $skippedCount unsupported/failed file(s).'
              : 'Imported $importedCount file(s).'
        : 'No supported books were imported.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildDropTarget(Widget child) {
    if (!_supportsDragAndDrop) return child;

    final colorScheme = Theme.of(context).colorScheme;
    return DropTarget(
      onDragEntered: (_) => setState(() => _isDragActive = true),
      onDragExited: (_) => setState(() => _isDragActive = false),
      onDragDone: (detail) async {
        if (_isDragActive) {
          setState(() => _isDragActive = false);
        }
        await _handleDroppedFiles(detail.files);
      },
      child: Stack(
        children: [
          Positioned.fill(child: child),
          if (_isDragActive)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.10),
                    border: Border.all(color: colorScheme.primary, width: 2),
                  ),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Drop ebook files to import',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _createShelf() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Shelf'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Shelf Name',
            hintText: 'Enter shelf name',
          ),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      final service = await _bookServiceFuture;
      await service.createShelf(result);
      await _loadData();
    }
  }

  Future<void> _deleteShelf(Shelf shelf) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Shelf'),
        content: Text('Are you sure you want to delete "${shelf.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final service = await _bookServiceFuture;
      await service.deleteShelf(shelf.id);
      setState(() {
        if (_selectedShelf?.id == shelf.id) {
          _selectedShelf = null;
        }
      });
      await _loadData();
    }
  }

  Future<void> _deleteBook(Book book) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Book'),
        content: Text('Are you sure you want to delete "${book.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final service = await _bookServiceFuture;
      await service.deleteBook(book.id);
      await _loadData();
    }
  }

  Future<void> _addToShelf(Book book) async {
    if (_shelves.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No shelves available. Create one first.'),
        ),
      );
      return;
    }

    final shelfId = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add to Shelf'),
        content: SizedBox(
          width: 200,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _shelves.length,
            itemBuilder: (context, index) {
              final shelf = _shelves[index];
              return ListTile(
                leading: const Icon(Icons.shelves),
                title: Text(shelf.name),
                onTap: () => Navigator.pop(context, shelf.id),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (shelfId != null) {
      final service = await _bookServiceFuture;
      await service.addBookToShelf(shelfId, book.id);
      await _loadData();
    }
  }

  void _openBook(Book book) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ReaderScreen(book: book)),
    ).then((_) => _loadData());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Left Sidebar
          _buildSidebar(),
          // Main Content
          Expanded(child: _buildMainContent()),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    final width = _sidebarExtended ? 240.0 : 72.0;
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: width,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(
          right: BorderSide(color: colorScheme.outlineVariant, width: 1),
        ),
      ),
      child: ClipRect(
        child: Column(
          children: [
            // Header
            _buildSidebarHeader(),

            // Import Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _SidebarButton(
                icon: Icons.add_rounded,
                label: 'Import',
                onPressed: _importBook,
                isExtended: _sidebarExtended,
                isPrimary: true,
              ),
            ),

            const SizedBox(height: 8),

            // Shelves Section
            Expanded(
              child: _sidebarExtended
                  ? _buildExtendedShelvesList()
                  : _buildCollapsedShelvesList(),
            ),

            // New Shelf Button
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: _SidebarButton(
                icon: Icons.create_new_folder_outlined,
                label: 'New Shelf',
                onPressed: _createShelf,
                isExtended: _sidebarExtended,
                isPrimary: false,
              ),
            ),

            // Expand/Collapse Button on mobile (positioned under New Shelf)
            if (PlatformUtils.isMobile)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                child: _SidebarButton(
                  icon: _sidebarExtended
                      ? Icons.chevron_left_rounded
                      : Icons.chevron_right_rounded,
                  label: _sidebarExtended ? 'Collapse' : 'Expand',
                  onPressed: () => setState(() {
                    _sidebarExtended = !_sidebarExtended;
                  }),
                  isExtended: _sidebarExtended,
                  isPrimary: false,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarHeader() {
    final colorScheme = Theme.of(context).colorScheme;
    final isExtended = _sidebarExtended;
    final isMobile = PlatformUtils.isMobile;

    return SizedBox(
      height: 64,
      child: isExtended
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Library',
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  // Hide expand/collapse button in header on mobile (moved to bottom)
                  if (!isMobile)
                    IconButton(
                      onPressed: () => setState(() {
                        _sidebarExtended = !_sidebarExtended;
                      }),
                      icon: const Icon(Icons.chevron_left_rounded, size: 22),
                      tooltip: 'Collapse',
                      style: IconButton.styleFrom(
                        foregroundColor: colorScheme.onSurfaceVariant,
                        minimumSize: const Size(36, 36),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                ],
              ),
            )
          // On mobile in collapsed state, show nothing (button is at bottom)
          : isMobile
          ? const SizedBox.shrink()
          : Center(
              child: IconButton(
                onPressed: () => setState(() {
                  _sidebarExtended = !_sidebarExtended;
                }),
                icon: const Icon(Icons.chevron_right_rounded, size: 22),
                tooltip: 'Expand',
                style: IconButton.styleFrom(
                  foregroundColor: colorScheme.onSurfaceVariant,
                  minimumSize: const Size(36, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
    );
  }

  Widget _buildExtendedShelvesList() {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
          child: Text(
            'SHELVES',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.outline,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
            children: [
              // All Books
              _SidebarTile(
                icon: Icons.menu_book_outlined,
                selectedIcon: Icons.menu_book_rounded,
                label: 'All Books',
                count: _books.length,
                isSelected: _selectedShelf == null,
                onTap: () => setState(() => _selectedShelf = null),
                isExtended: true,
              ),
              if (_shelves.isNotEmpty) ...[
                const SizedBox(height: 4),
                _buildSectionDivider(),
                const SizedBox(height: 4),
              ],
              // User Shelves with keys for efficient updates
              for (final shelf in _shelves)
                _SidebarTile(
                  key: ValueKey(shelf.id),
                  icon: Icons.folder_outlined,
                  selectedIcon: Icons.folder_rounded,
                  label: shelf.name,
                  count: shelf.bookIds.length,
                  isSelected: _selectedShelf?.id == shelf.id,
                  onTap: () => setState(() => _selectedShelf = shelf),
                  onDelete: () => _deleteShelf(shelf),
                  isExtended: true,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCollapsedShelvesList() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      children: [
        _SidebarTile(
          icon: Icons.menu_book_outlined,
          selectedIcon: Icons.menu_book_rounded,
          label: 'All Books',
          isSelected: _selectedShelf == null,
          onTap: () => setState(() => _selectedShelf = null),
          isExtended: false,
        ),
        for (final shelf in _shelves)
          _SidebarTile(
            key: ValueKey(shelf.id),
            icon: Icons.folder_outlined,
            selectedIcon: Icons.folder_rounded,
            label: shelf.name,
            isSelected: _selectedShelf?.id == shelf.id,
            onTap: () => setState(() => _selectedShelf = shelf),
            isExtended: false,
          ),
      ],
    );
  }

  Widget _buildSectionDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Divider(
        height: 1,
        thickness: 1,
        color: Theme.of(
          context,
        ).colorScheme.outlineVariant.withValues(alpha: 0.5),
      ),
    );
  }

  Widget _buildMainContent() {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedShelf?.name ?? 'My Library'),
        actions: [
          if (_selectedShelf != null)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() => _selectedShelf = null),
              tooltip: 'Show all books',
            ),
        ],
      ),
      body: _buildDropTarget(_buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final displayedBooks = _displayedBooks;

    if (displayedBooks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _selectedShelf != null ? Icons.shelves : Icons.menu_book_outlined,
              size: 80,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              _selectedShelf != null ? 'This shelf is empty' : 'No books yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _selectedShelf != null
                  ? 'Add books to this shelf'
                  : 'Import a TXT file to get started',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
      );
    }

    // Estimate item height for performance optimization
    // BookCard has ~120px height (padding + content)
    const estimatedItemExtent = 128.0;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: displayedBooks.length,
      itemExtent: estimatedItemExtent,
      itemBuilder: (context, index) {
        final book = displayedBooks[index];
        return BookCard(
          key: ValueKey(book.id),
          book: book,
          onTap: () => _openBook(book),
          onDelete: () => _deleteBook(book),
          onAddToShelf: _addToShelf,
        );
      },
    );
  }
}

/// Standardized sidebar button widget.
class _SidebarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool isExtended;
  final bool isPrimary;

  const _SidebarButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.isExtended,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (isExtended) {
      return Material(
        color: isPrimary
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 44,
            child: Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isPrimary
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isPrimary
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Collapsed state
    return Tooltip(
      message: label,
      preferBelow: false,
      child: Material(
        color: isPrimary
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 48,
            height: 44,
            child: Center(
              child: Icon(
                icon,
                size: 20,
                color: isPrimary
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Standardized sidebar tile widget for shelf items.
class _SidebarTile extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final int? count;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final bool isExtended;

  const _SidebarTile({
    super.key,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.count,
    required this.isSelected,
    required this.onTap,
    this.onDelete,
    required this.isExtended,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (!isExtended) {
      return Tooltip(
        message: label,
        preferBelow: false,
        child: Material(
          color: isSelected
              ? colorScheme.secondaryContainer
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 48,
              height: 44,
              child: Center(
                child: Icon(
                  isSelected ? selectedIcon : icon,
                  size: 22,
                  color: isSelected
                      ? colorScheme.onSecondaryContainer
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Extended state
    return Material(
      color: isSelected ? colorScheme.secondaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 44,
          child: Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              const SizedBox(width: 12),
              Icon(
                isSelected ? selectedIcon : icon,
                size: 20,
                color: isSelected
                    ? colorScheme.onSecondaryContainer
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: isSelected
                        ? colorScheme.onSecondaryContainer
                        : colorScheme.onSurface,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ),
              if (count != null && count! > 0) ...[
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colorScheme.onSecondaryContainer.withValues(
                            alpha: 0.2,
                          )
                        : colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isSelected
                          ? colorScheme.onSecondaryContainer
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (onDelete != null) const SizedBox(width: 4),
              ],
              if (onDelete != null)
                SizedBox(
                  width: 28,
                  height: 28,
                  child: IconButton(
                    onPressed: onDelete,
                    icon: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: isSelected
                          ? colorScheme.onSecondaryContainer.withValues(
                              alpha: 0.7,
                            )
                          : colorScheme.onSurfaceVariant,
                    ),
                    padding: EdgeInsets.zero,
                    tooltip: 'Delete shelf',
                    style: IconButton.styleFrom(
                      minimumSize: const Size(28, 28),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ),
              const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }
}
