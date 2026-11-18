import 'package:flutter/material.dart';

class PhotoViewerScreen extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const PhotoViewerScreen({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
  });

  static Future<void> open(
    BuildContext context, {
    required List<String> imageUrls,
    int initialIndex = 0,
  }) {
    final validUrls = imageUrls
        .map((url) => url.trim())
        .where((url) => url.isNotEmpty)
        .toList();
    if (validUrls.isEmpty) return Future<void>.value();

    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PhotoViewerScreen(
          imageUrls: validUrls,
          initialIndex: initialIndex.clamp(0, validUrls.length - 1).toInt(),
        ),
      ),
    );
  }

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.imageUrls.isEmpty
        ? 0
        : widget.initialIndex
              .clamp(0, widget.imageUrls.length - 1)
              .toInt();
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF030712),
    appBar: AppBar(
      backgroundColor: const Color(0xFF030712),
      foregroundColor: Colors.white,
      automaticallyImplyLeading: false,
      title: Text(
        widget.imageUrls.length > 1
            ? '${_currentIndex + 1} / ${widget.imageUrls.length}'
            : 'عرض الصورة',
      ),
      actions: [
        IconButton(
          tooltip: 'إغلاق',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    ),
    body: PageView.builder(
      controller: _pageController,
      itemCount: widget.imageUrls.length,
      onPageChanged: (index) => setState(() => _currentIndex = index),
      itemBuilder: (context, index) => InteractiveViewer(
        minScale: 1,
        maxScale: 5,
        child: SizedBox.expand(
          child: Image.network(
            widget.imageUrls[index],
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFF59E0B),
                ),
              );
            },
            errorBuilder: (_, _, _) => const Center(
              child: Icon(
                Icons.broken_image_outlined,
                color: Colors.white70,
                size: 52,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
