import 'package:flutter/material.dart';
import '../config/app_config.dart';

class ProductImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double placeholderIconSize;
  final Widget? placeholder;

  const ProductImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.placeholderIconSize = 48,
    this.placeholder,
  });

  Widget _defaultPlaceholder() {
    return placeholder ??
        Center(
          child: Icon(
            Icons.image_outlined,
            size: placeholderIconSize,
            color: Colors.grey.shade400,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final clean = (imageUrl ?? '').trim();
    if (clean.isEmpty) {
      return _defaultPlaceholder();
    }

    // 1. Seed catalog images bundled locally in app assets
    if (clean.startsWith('/seeds/')) {
      final filename = clean.substring('/seeds/'.length);
      return Image.asset(
        'assets/images/seeds/$filename',
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (ctx, err, stack) => _defaultPlaceholder(),
      );
    }

    if (clean.startsWith('seeds/')) {
      final filename = clean.substring('seeds/'.length);
      return Image.asset(
        'assets/images/seeds/$filename',
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (ctx, err, stack) => _defaultPlaceholder(),
      );
    }

    // 2. Absolute remote URLs
    if (clean.startsWith('http://') || clean.startsWith('https://')) {
      return Image.network(
        clean,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (ctx, err, stack) => _defaultPlaceholder(),
        loadingBuilder: (ctx, child, progress) {
          if (progress == null) return child;
          return Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.green,
                value: progress.expectedTotalBytes != null
                    ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                    : null,
              ),
            ),
          );
        },
      );
    }

    // 3. Server relative URLs (e.g. uploaded images like /public/products/...)
    String resolvedUrl = clean;
    if (clean.startsWith('/')) {
      resolvedUrl = '${AppConfig.apiBaseUrl}$clean';
    } else {
      resolvedUrl = '${AppConfig.apiBaseUrl}/$clean';
    }

    return Image.network(
      resolvedUrl,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (ctx, err, stack) => _defaultPlaceholder(),
      loadingBuilder: (ctx, child, progress) {
        if (progress == null) return child;
        return Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.green,
              value: progress.expectedTotalBytes != null
                  ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                  : null,
            ),
          ),
        );
      },
    );
  }
}
