import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_scanner/widgets/scan_progress.dart';

void main() {
  group('ScanProgress Widget', () {
    testWidgets('displays progress indicator and percentage text',
        (WidgetTester tester) async {
      // Arrange
      const progress = 45.5;

      // Act
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ScanProgress(progress: progress),
          ),
        ),
      );

      // Assert
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('45.5% complete'), findsOneWidget);

      // Verify progress indicator value
      final progressIndicator =
          tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
      expect(progressIndicator.value, closeTo(0.455, 0.001));
    });

    testWidgets('displays 0% progress correctly', (WidgetTester tester) async {
      // Arrange
      const progress = 0.0;

      // Act
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ScanProgress(progress: progress),
          ),
        ),
      );

      // Assert
      expect(find.text('0.0% complete'), findsOneWidget);
      final progressIndicator =
          tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
      expect(progressIndicator.value, 0.0);
    });

    testWidgets('displays 100% progress correctly', (WidgetTester tester) async {
      // Arrange
      const progress = 100.0;

      // Act
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ScanProgress(progress: progress),
          ),
        ),
      );

      // Assert
      expect(find.text('100.0% complete'), findsOneWidget);
      final progressIndicator =
          tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
      expect(progressIndicator.value, 1.0);
    });

    testWidgets('handles decimal progress values', (WidgetTester tester) async {
      // Arrange
      const progress = 33.333;

      // Act
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ScanProgress(progress: progress),
          ),
        ),
      );

      // Assert
      expect(find.text('33.3% complete'), findsOneWidget);
    });
  });
}
