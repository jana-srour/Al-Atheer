import 'package:flutter/material.dart';
import '../screens/photo_viewer_screen.dart';

class CoverImage extends StatelessWidget {
  final String? imageUrl;
  final double width;
  final double height;
  final BorderRadius borderRadius;
  final IconData fallbackIcon;

  const CoverImage({
    super.key,
    required this.imageUrl,
    required this.width,
    required this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.fallbackIcon = Icons.auto_stories_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    return Material(
      color: Colors.transparent,
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: url != null && url.isNotEmpty
            ? () => PhotoViewerScreen.open(context, imageUrls: [url])
            : null,
        child: SizedBox(
          width: width,
          height: height,
          child: url == null || url.isEmpty
              ? _placeholder(context)
              : Image.network(
                  url,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return _placeholder(
                      context,
                      child: const CircularProgressIndicator(),
                    );
                  },
                  errorBuilder: (_, _, _) => _placeholder(context),
                ),
        ),
      ),
    );
  }

  Widget _placeholder(BuildContext context, {Widget? child}) => Container(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    alignment: Alignment.center,
    child:
        child ??
        Icon(
          fallbackIcon,
          size: 30,
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
        ),
  );
}
