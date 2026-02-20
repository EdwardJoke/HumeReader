import 'dart:io' if (dart.library.html) 'dart:html';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Utility class for platform-specific operations, especially macOS permissions.
class PlatformUtils {
  /// Returns true if the app is running on the web.
  static bool get isWeb => kIsWeb;

  /// Returns true if the app is running on macOS.
  static bool get isMacOS => !kIsWeb && Platform.isMacOS;

  /// Returns true if the app is running on a desktop platform (macOS, Windows, Linux).
  static bool get isDesktop =>
      !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);

  /// Returns true if the app is running on a mobile platform (Android, iOS).
  static bool get isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Shows a dialog with instructions for granting file access permission on macOS.
  ///
  /// This should be called when a file operation fails due to permission issues.
  static Future<void> showMacOSPermissionTip(BuildContext context) async {
    if (!isMacOS) return;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lock_outline, size: 24),
            SizedBox(width: 8),
            Text('File Access Permission'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'macOS requires permission to access files.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text('To grant file access:'),
              SizedBox(height: 8),
              _NumberedStep(number: 1, text: 'Open System Settings'),
              _NumberedStep(number: 2, text: 'Go to Privacy & Security'),
              _NumberedStep(number: 3, text: 'Click on Files and Folders'),
              _NumberedStep(
                number: 4,
                text: 'Find this app and enable file access',
              ),
              SizedBox(height: 16),
              Text(
                'Alternatively, you can:',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
              SizedBox(height: 8),
              Text('• Right-click the file and select "Open With"'),
              Text('• Drag and drop the file onto the app'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Shows a snackbar with a quick tip for macOS file permission.
  ///
  /// Use this for less intrusive notifications.
  static void showMacOSPermissionSnackbar(BuildContext context) {
    if (!isMacOS) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.white),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'If file access fails, check System Settings > Privacy & Security > Files and Folders',
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Details',
          onPressed: () => showMacOSPermissionTip(context),
        ),
      ),
    );
  }

  /// Checks if an error is related to file permission issues.
  static bool isPermissionError(Object error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('permission') ||
        errorString.contains('access') ||
        errorString.contains('denied') ||
        errorString.contains('unauthorized') ||
        errorString.contains('not allowed') ||
        errorString.contains('operation not permitted');
  }

  /// Handles file operation errors and shows appropriate messages.
  ///
  /// Returns true if the error was handled (permission tip shown).
  static Future<bool> handleFileError(
    BuildContext context,
    Object error, {
    String? operation,
  }) async {
    if (isMacOS && isPermissionError(error)) {
      await showMacOSPermissionTip(context);
      return true;
    }

    // Show generic error if not a permission issue
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            operation != null
                ? 'Failed to $operation: $error'
                : 'Error: $error',
          ),
        ),
      );
    }
    return false;
  }
}

/// A numbered step widget for the permission dialog.
class _NumberedStep extends StatelessWidget {
  final int number;
  final String text;

  const _NumberedStep({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$number',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
