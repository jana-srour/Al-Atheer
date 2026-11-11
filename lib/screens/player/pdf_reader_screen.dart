import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:share_plus/share_plus.dart';

class PdfReaderScreen extends StatefulWidget {
  final File pdfFile;
  final String title;

  const PdfReaderScreen({
    super.key,
    required this.pdfFile,
    required this.title,
  });

  @override
  State<PdfReaderScreen> createState() => _PdfReaderScreenState();
}

class _PdfReaderScreenState extends State<PdfReaderScreen> {
  int? _totalPages = 0;
  int? _currentPage = 0;
  bool _isReady = false;
  PDFViewController? _pdfViewController;

  void _showJumpToPageDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('الانتقال إلى صفحة'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: 'أدخل رقم الصفحة (1 - ${_totalPages ?? 1})',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final pageNum = int.tryParse(controller.text.trim());
              if (pageNum != null &&
                  pageNum >= 1 &&
                  pageNum <= (_totalPages ?? 1)) {
                _pdfViewController?.setPage(pageNum - 1);
                Navigator.pop(ctx);
              }
            },
            child: const Text('انتقال'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const radiantGold = Color(0xFFF59E0B);
    const deepNavy = Color(0xFF0F172A);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: deepNavy,
        foregroundColor: Colors.white,
        title: Text(
          widget.title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          // Jump to page button
          if (_isReady && (_totalPages ?? 0) > 0)
            InkWell(
              onTap: _showJumpToPageDialog,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: radiantGold.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: radiantGold.withValues(alpha: 0.6)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${(_currentPage ?? 0) + 1} / ${_totalPages ?? 0}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: radiantGold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_drop_down, color: radiantGold, size: 16),
                  ],
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.share_outlined, size: 20),
            tooltip: 'مشاركة الكتاب',
            onPressed: () {
              Share.shareXFiles([XFile(widget.pdfFile.path)], text: widget.title);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          PDFView(
            filePath: widget.pdfFile.path,
            enableSwipe: true,
            swipeHorizontal: false,
            autoSpacing: true,
            pageFling: true,
            pageSnap: true,
            onViewCreated: (ctrl) {
              _pdfViewController = ctrl;
            },
            onRender: (pages) {
              setState(() {
                _totalPages = pages;
                _isReady = true;
              });
            },
            onPageChanged: (page, total) {
              setState(() {
                _currentPage = page;
              });
            },
            onError: (error) {
              debugPrint('PDF Render Error: $error');
            },
          ),
          if (!_isReady)
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: radiantGold),
                  SizedBox(height: 12),
                  Text('جاري فتح الكتاب...'),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
