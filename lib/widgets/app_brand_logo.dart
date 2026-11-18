import 'package:flutter/material.dart';

class AppBrandLogo extends StatelessWidget {
  final String? imageUrl;
  final double size;
  final Color fallbackColor;

  const AppBrandLogo({
    super.key,
    required this.imageUrl,
    required this.size,
    required this.fallbackColor,
  });

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    final fallback = Icon(
      Icons.auto_stories,
      size: size * 0.56,
      color: fallbackColor,
    );

    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(shape: BoxShape.circle),
      clipBehavior: Clip.antiAlias,
      child: url == null || url.isEmpty
          ? fallback
          : Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => fallback,
            ),
    );
  }
}
