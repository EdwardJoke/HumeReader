# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.6-beta2] - 2026-02-22

### Performance

 Migrate cover images from SharedPreferences to file system storage (reduces memory usage by ~33%)
 Add lazy loading for book covers with in-memory cache
 Replace AnimatedBuilder with ListenableBuilder to avoid full app rebuilds on theme changes
 Remove unnecessary theme rebuild in HomeScreen (theme now handled by MaterialApp)
 Add itemExtent to ListView.builder for optimized list scrolling
 Add ValueKey to list items for efficient widget reconciliation
 Cache Theme.of(context) calls in local variables to reduce lookup overhead

### Fixed

 Correct PalmDoc LZ77 decompression algorithm in MOBI parsing (fix distance calculation in Type B commands)
 MOBI content extraction now properly handles fallback when parseOpt fails

### Added

 AZW and AZW3 format support for importing and reading ebooks
 Comprehensive test suite for MOBI parsing (26 tests)
 Minimum window size constraint (800x600) for desktop platforms (macOS, Windows, Linux)

### Changed

 Improved MOBI title extraction with better fallback chain (PDB header → MOBI header → EXTH)
 Enhanced MOBI content extraction with direct record parsing fallback


## [0.1.6-beta1] - 2025-02-21

### Fixed

- Correct PalmDoc LZ77 decompression algorithm in MOBI parsing (fix distance calculation in Type B commands)
- MOBI content extraction now properly handles fallback when parseOpt fails

### Added

- AZW and AZW3 format support for importing and reading ebooks
- Comprehensive test suite for MOBI parsing (26 tests)
- Minimum window size constraint (800x600) for desktop platforms (macOS, Windows, Linux)

### Changed

- Improved MOBI title extraction with better fallback chain (PDB header → MOBI header → EXTH)
- Enhanced MOBI content extraction with direct record parsing fallback

## [0.1.5-pre2] - 2025-02-19

### Added

- Android 14 fullscreen mode integration with native platform channel
- External link confirmation dialog before opening URLs in browser
- Link navigation support in EPUB reader (tap links to navigate between chapters)

### Fixed

- Platform stub files for web compilation compatibility
- Expand/collapse button repositioned for better mobile UX

### Changed

- Full-screen mode enabled by default on mobile devices

## [0.1.5-pre1] - 2025-02-15

### Added

- Reading position persistence (save/restore scroll position and chapter)
- Reading time tracking with efficient timer-based approach
- Reading streak tracking (current and longest consecutive days)
- Progress tracking with max progress percentage (never decreases)
- Current progress bar visualization on book cards
- EPUB format support with chapter navigation
- Custom shelf organization for books

### Changed

- License changed from MIT to Apache 2.0

### Fixed

- Stats no longer decrease when switching between books

## [0.1.0] - 2025-02-10

### Added

- Initial release of Hume ebook reader
- Cross-platform support: Android, iOS, macOS, Windows, Linux, Web
- TXT file support
- Beautiful library view with book covers
- Light and dark theme support with custom accent colors
- Adjustable font size in reader (12-32px)
- Book import from local files
- Reading statistics dashboard

[0.1.6-beta2]: https://github.com/EdwardJoke/HumeReader/compare/v0.1.6-beta1...v0.1.6-beta2
[0.1.6-beta1]: https://github.com/EdwardJoke/HumeReader/compare/v0.1.5-pre2...v0.1.6-beta1
[0.1.5-pre2]: https://github.com/EdwardJoke/HumeReader/compare/v0.1.5-pre1...v0.1.5-pre2
[0.1.5-pre1]: https://github.com/EdwardJoke/HumeReader/releases/tag/v0.1.5-pre1
[0.1.0]: https://github.com/EdwardJoke/HumeReader/releases/tag/v0.1.0
