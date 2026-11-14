import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unified_app/features/splash/animated_splash_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AnimatedSplashScreen Widget Tests', () {
    testWidgets('Renders authentic logo image, company title, and exact tagline without ShaderMask',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AnimatedSplashScreen(
            isCheckingAuth: false,
            onSplashComplete: () {},
          ),
        ),
      );

      // Verify authentic logo asset image is referenced
      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);
      final imageWidget = tester.widget<Image>(imageFinder);
      expect((imageWidget.image as AssetImage).assetName, 'assets/images/yhs_logo.png');

      // Verify "YADVI SEEDS" text is present
      expect(find.text('YADVI SEEDS'), findsOneWidget);

      // Verify exact tagline is present
      expect(find.text('Sowing Seeds, Growing Futures.'), findsOneWidget);

      // Verify ShaderMask is completely absent
      expect(find.byType(ShaderMask), findsNothing);
    });

    testWidgets('Calls onSplashComplete once 3.5s animation completes and auth is ready',
        (WidgetTester tester) async {
      bool completed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: AnimatedSplashScreen(
            isCheckingAuth: false,
            onSplashComplete: () {
              completed = true;
            },
          ),
        ),
      );

      expect(completed, isFalse);

      // Advance through animation stages
      await tester.pump(const Duration(milliseconds: 1000));
      expect(completed, isFalse);

      await tester.pump(const Duration(milliseconds: 1500));
      expect(completed, isFalse);

      // Advance past 3500ms
      await tester.pump(const Duration(milliseconds: 1100));
      expect(completed, isTrue);
    });

    testWidgets('Waits for isCheckingAuth to become false before completing',
        (WidgetTester tester) async {
      bool completed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: AnimatedSplashScreen(
            isCheckingAuth: true, // auth still checking
            onSplashComplete: () {
              completed = true;
            },
          ),
        ),
      );

      // Advance 4 seconds (past controller completion, but before safety timeout)
      await tester.pump(const Duration(milliseconds: 4000));
      // Should still be false because auth was checking
      expect(completed, isFalse);

      // Now update widget with isCheckingAuth = false
      await tester.pumpWidget(
        MaterialApp(
          home: AnimatedSplashScreen(
            isCheckingAuth: false,
            onSplashComplete: () {
              completed = true;
            },
          ),
        ),
      );

      expect(completed, isTrue);
    });

    testWidgets('Triggers safety timeout fallback if isCheckingAuth remains true past 5.0s',
        (WidgetTester tester) async {
      bool completed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: AnimatedSplashScreen(
            isCheckingAuth: true, // auth is stuck
            onSplashComplete: () {
              completed = true;
            },
          ),
        ),
      );

      // Advance to 4.5 seconds
      await tester.pump(const Duration(milliseconds: 4500));
      expect(completed, isFalse);

      // Advance past 5.0 second safety timeout
      await tester.pump(const Duration(milliseconds: 600));
      expect(completed, isTrue);
    });
  });
}
