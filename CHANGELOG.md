# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.11] - 2026-03-01

### Added

- GitHub Actions release workflow for automated multi-platform builds with versioned artifacts
- Multi-select shelf dialog with checkboxes (replaces single-select dropdown)
- Methods to get shelves containing a book and batch update book-shelf relationships

### Fixed

- MOBI chapter extraction now properly parses TOC with `filepos` attributes to extract real chapter names
- Fixed "No Material widget found" error in chapter navigation drawer search field
- Invalidates old chapter cache entries that used "Full Text" fallback

### Changed

- Improved MOBI chapter extraction with fallback chain: NCX → Guide → TOC filepos → Pagebreaks → HTML headings
- Merged consecutive duplicate chapter entries from MOBI TOC

## [0.1.10] - 2026-02-25

### Performance

- Moved EPUB/MOBI chapter extraction to isolate workers to reduce main-thread blocking.
- Added session-level chapter caching and a compact disk cache format that stores metadata plus nearby chapter content.
- Deferred initial reader loading until route transition completion so the loading UI renders immediately.

### Changed

- Updated reader startup flow to gate controls while initial content is loading.
- Added on-demand chapter hydration when navigating to chapters without preloaded content.
- Bumped app version to `0.1.10+1` in `pubspec.yaml`.

## [0.1.9] - 2026-02-24

### Added

- Added a dedicated settings screen with update channel selector and about link.
- Added a foreground import/loading experience for large book parsing.

### Changed

- Standardized the User screen around Material design patterns.
- Improved large-book reading flow with asynchronous loading in library/reader pipelines.

## [0.1.7] - 2026-02-22

### Added

- Web-native file import using in-memory bytes path
- Drag-and-drop ebook import support on web and desktop platforms

### Changed

- Standardized app/build output naming to `Hume` across Android, iOS, macOS, Windows, and Linux targets
- Updated Android release artifact naming to generate `Hume.apk` in release output directory
- Removed completed `FEAT-001` from `MILESTONE.toml`

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


## [0.1.6-beta1] - 2026-02-21

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

## [0.1.5-pre2] - 2026-02-19

### Added

- Android 14 fullscreen mode integration with native platform channel
- External link confirmation dialog before opening URLs in browser
- Link navigation support in EPUB reader (tap links to navigate between chapters)

### Fixed

- Platform stub files for web compilation compatibility
- Expand/collapse button repositioned for better mobile UX

### Changed

- Full-screen mode enabled by default on mobile devices

## [0.1.5-pre1] - 2026-02-15

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
[0.1.11]: https://github.com/EdwardJoke/HumeReader/compare/v0.1.10...v0.1.11
[0.1.10]: https://github.com/EdwardJoke/HumeReader/compare/v0.1.9...v0.1.10
[0.1.9]: https://github.com/EdwardJoke/HumeReader/compare/v0.1.7...v0.1.9
[0.1.7]: https://github.com/EdwardJoke/HumeReader/compare/v0.1.6-beta2...v0.1.7
[0.1.6-beta1]: https://github.com/EdwardJoke/HumeReader/compare/v0.1.5-pre2...v0.1.6-beta1
[0.1.5-pre2]: https://github.com/EdwardJoke/HumeReader/compare/v0.1.5-pre1...v0.1.5-pre2
[0.1.5-pre1]: https://github.com/EdwardJoke/HumeReader/releases/tag/v0.1.5-pre1
[0.1.0]: https://github.com/EdwardJoke/HumeReader/releases/tag/v0.1.0
