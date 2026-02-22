import 'package:flutter/material.dart';

/// Widget that displays error messages
/// Shows an error icon and message with red color scheme
/// Used to display scanning errors and validation messages
class ErrorMessage extends StatelessWidget {
  final String? message;

  const ErrorMessage({
    super.key,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.red.shade200,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.red.shade700,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message ?? 'An error occurred',
              style: TextStyle(
                color: Colors.red.shade900,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
