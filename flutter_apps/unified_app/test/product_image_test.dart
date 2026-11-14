import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unified_app/core/config/app_config.dart';
import 'package:unified_app/core/widgets/product_image.dart';

void main() {
  group('ProductImage Widget Tests', () {
    testWidgets('Renders AssetImage for seed URL path beginning with /seeds/',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProductImage(
              imageUrl: '/seeds/seed_01.jpeg',
              width: 100,
              height: 100,
            ),
          ),
        ),
      );

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);

      final Image imageWidget = tester.widget(imageFinder);
      expect(imageWidget.image, isA<AssetImage>());
      final AssetImage assetImage = imageWidget.image as AssetImage;
      expect(assetImage.assetName, equals('assets/images/seeds/seed_01.jpeg'));
    });

    testWidgets('Renders AssetImage for seed URL path seeds/seed_40.jpeg without leading slash',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProductImage(
              imageUrl: 'seeds/seed_40.jpeg',
              width: 100,
              height: 100,
            ),
          ),
        ),
      );

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);

      final Image imageWidget = tester.widget(imageFinder);
      expect(imageWidget.image, isA<AssetImage>());
      final AssetImage assetImage = imageWidget.image as AssetImage;
      expect(assetImage.assetName, equals('assets/images/seeds/seed_40.jpeg'));
    });

    testWidgets('Renders NetworkImage for absolute remote URLs',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProductImage(
              imageUrl: 'https://storage.googleapis.com/test-bucket/sample.jpg',
              width: 100,
              height: 100,
            ),
          ),
        ),
      );

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);

      final Image imageWidget = tester.widget(imageFinder);
      expect(imageWidget.image, isA<NetworkImage>());
      final NetworkImage networkImage = imageWidget.image as NetworkImage;
      expect(networkImage.url, equals('https://storage.googleapis.com/test-bucket/sample.jpg'));
    });

    testWidgets('Renders NetworkImage prepending apiBaseUrl for uploaded product paths',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProductImage(
              imageUrl: '/public/products/c8b9ece0f647431bb5dfa10f53c3e1f8.png',
              width: 100,
              height: 100,
            ),
          ),
        ),
      );

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);

      final Image imageWidget = tester.widget(imageFinder);
      expect(imageWidget.image, isA<NetworkImage>());
      final NetworkImage networkImage = imageWidget.image as NetworkImage;
      final expectedUrl = '${AppConfig.apiBaseUrl}/public/products/c8b9ece0f647431bb5dfa10f53c3e1f8.png';
      expect(networkImage.url, equals(expectedUrl));
    });

    testWidgets('Renders fallback placeholder when imageUrl is null or empty',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProductImage(
              imageUrl: null,
              width: 100,
              height: 100,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    });
  });
}
