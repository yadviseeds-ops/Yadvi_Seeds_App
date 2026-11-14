import 'package:flutter/material.dart';

bool _isExitDialogShowing = false;

/// Prompts the user with an exit confirmation dialog.
///
/// Returns `true` if the user selected 'Exit', `false` otherwise.
Future<bool> showExitConfirmationDialog(BuildContext context) async {
  if (_isExitDialogShowing) return false;
  _isExitDialogShowing = true;
  try {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: const Text('Exit App?'),
        content: const Text('Are you sure you want to exit the application?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Stay'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
    return result ?? false;
  } finally {
    _isExitDialogShowing = false;
  }
}
