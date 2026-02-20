# Hume

A cross-platform ebook reader built with Flutter. Read EPUB and TXT files with a beautiful reading experience, track your reading habits, and organize your library.

## Features

### Library Management
- Import and organize your ebook collection
- Support for **EPUB** and **TXT** formats
- Create custom shelves to organize books
- Book cover display
- Search and filter your library

### Reader
- Clean, distraction-free reading experience
- **Adjustable font size** (12-32px)
- **Chapter navigation** for EPUB files
- **Reading position persistence** - always resume where you left off
- Swipe gestures for chapter navigation
- Scroll-to-top/bottom quick navigation
- Selectable text for highlighting and copying

### Reading Statistics
- Track total books and reading progress
- Monitor **pages read** and **total reading time**
- **Reading streaks** - current and longest consecutive reading days
- Average progress per book

### Customization
- **Light and dark theme** support
- **Custom accent colors** - choose your preferred color scheme
- Smooth theme transitions

### Platform Support
- Android
- iOS
- macOS
- Windows
- Linux
- Web

## Getting Started

### Prerequisites
- Flutter SDK 3.12.0 or later
- Dart SDK 3.12.0 or later

### Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd hume
```

2. Install dependencies:
```bash
flutter pub get
```

3. Run the app:
```bash
flutter run
```

### Building

```bash
# Build for Android
flutter build apk

# Build for iOS (macOS only)
flutter build ios

# Build for web
flutter build web

# Build for macOS
flutter build macos

# Build for Windows
flutter build windows

# Build for Linux
flutter build linux
```

## Project Structure

```
lib/
  main.dart              # App entry point
  providers.dart         # State management
  models/                # Data models
    book.dart            # Book model
    book_chapter.dart    # Chapter model
    reading_stats.dart   # Statistics model
    shelf.dart           # Shelf/collection model
  screens/               # App screens
    home_screen.dart     # Main navigation container
    library_screen.dart # Book library view
    reader_screen.dart   # Ebook reader
    stats_screen.dart   # Reading statistics
    user_screen.dart    # User profile/settings
  services/              # Business logic
    book_service.dart    # Book operations
    theme_provider.dart  # Theme management
  theme/                 # App theming
    app_theme.dart       # Theme definitions
  widgets/               # Reusable components
    book_card.dart       # Book display card
  utils/                 # Utilities
    platform_utils.dart  # Platform-specific helpers
```

## Tech Stack

- **Flutter** - Cross-platform UI framework
- **Provider** - State management
- **flutter_html** - HTML rendering for EPUB files

## License

MIT License
