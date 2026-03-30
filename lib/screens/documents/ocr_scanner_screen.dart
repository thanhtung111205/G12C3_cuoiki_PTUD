// ignore_for_file: avoid_print

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/ocr_service.dart';
import '../../utils/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// OCR SCANNER SCREEN
// ─────────────────────────────────────────────────────────────────────────────

/// Màn hình quét tài liệu gồm 2 giai đoạn:
///  • Chưa có ảnh  – placeholder camera, nhấn để mở Camera hệ thống.
///  • Đã có ảnh    – hiển thị ảnh + OCR text + action toolbar.
class OcrScannerScreen extends StatefulWidget {
  const OcrScannerScreen({super.key});

  @override
  State<OcrScannerScreen> createState() => _OcrScannerScreenState();
}

class _OcrScannerScreenState extends State<OcrScannerScreen> {
  // ── Services ──────────────────────────────────────────────────────────────
  final OcrService _ocr = OcrService();
  final ImagePicker _picker = ImagePicker();

  // ── State ─────────────────────────────────────────────────────────────────
  String? _imagePath;       // null = belum ada foto
  bool _isExtracting = false;

  // ── Data ──────────────────────────────────────────────────────────────────
  late final TextEditingController _textController;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  /// Mở Camera hệ thống, chờ user chụp & xác nhận, rồi tự động chạy OCR.
  Future<void> _openCamera() async {
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.camera,
      // Không nén ảnh — giữ full resolution để ML Kit nhận diện chính xác nhất.
      // imageQuality mặc định = 100 (không nén).
      preferredCameraDevice: CameraDevice.rear,
    );

    if (photo == null) return; // user bấm huỷ

    setState(() {
      _imagePath = photo.path;
      _textController.clear();
    });

    // Tự động chạy OCR ngay sau khi có ảnh
    await _runOcr(photo.path);
  }

  /// Gọi OcrService và cập nhật text field.
  Future<void> _runOcr(String path) async {
    setState(() => _isExtracting = true);
    try {
      final String result = await _ocr.extractText(path);
      if (mounted) {
        _textController.text = result.isEmpty ? '(Không nhận diện được chữ)' : result;
      }
    } catch (e) {
      debugPrint('[OcrScannerScreen] OCR error: $e');
      if (mounted) {
        _textController.text = '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi nhận diện chữ: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExtracting = false);
    }
  }

  /// Xoá ảnh, xoá text, quay về trạng thái ban đầu.
  void _retake() {
    setState(() {
      _imagePath = null;
      _textController.clear();
    });
  }

  void _saveDocument() {
    final String text = _textController.text.trim();
    print('[OcrScannerScreen] Navigate to document_viewer_screen.dart with text: $text');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Tính năng Lưu tài liệu sẽ sớm được cập nhật.'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bool hasImage = _imagePath != null;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: Column(
        children: <Widget>[
          // ── Flex 6 – Vùng ảnh / placeholder ───────────────────────────────
          Expanded(
            flex: 6,
            child: hasImage
                ? _ImagePreview(imagePath: _imagePath!)
                : _CameraPlaceholder(onTap: _openCamera),
          ),

          // ── Flex 4 – Vùng text + toolbar ──────────────────────────────────
          Expanded(
            flex: 4,
            child: _TextPanel(
              controller: _textController,
              isExtracting: _isExtracting,
              isPreviewMode: hasImage,
              onRetake: _retake,
              onReExtract: _imagePath == null
                  ? null
                  : () => _runOcr(_imagePath!),
              onSave: _saveDocument,
            ),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: const Text(
        'Quét tài liệu',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 18,
        ),
      ),
      centerTitle: true,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CAMERA PLACEHOLDER (trạng thái chưa có ảnh)
// ─────────────────────────────────────────────────────────────────────────────

class _CameraPlaceholder extends StatelessWidget {
  const _CameraPlaceholder({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: const Color(0xFFF0EEF8), // nền xám nhạt tím
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            // ── Icon camera ─────────────────────────────────────────────────
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.lavender,
                shape: BoxShape.circle,
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: AppColors.deepPurple.withValues(alpha: 0.18),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                size: 48,
                color: AppColors.deepPurple,
              ),
            ),
            const SizedBox(height: 20),
            // ── Label chính ──────────────────────────────────────────────────
            const Text(
              'Nhấn để chụp ảnh',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.deepPurple,
              ),
            ),
            const SizedBox(height: 8),
            // ── Label phụ ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Camera sẽ mở ra để bạn chụp tài liệu cần nhận diện chữ.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.lightTextSecondary.withValues(alpha: 0.9),
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 28),
            // ── Nút CTA ─────────────────────────────────────────────────────
            ElevatedButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.camera_alt_rounded, size: 18),
              label: const Text(
                'Mở Camera',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// IMAGE PREVIEW (trạng thái đã có ảnh)
// ─────────────────────────────────────────────────────────────────────────────

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({required this.imagePath});

  final String imagePath;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Image.file(
        File(imagePath),
        fit: BoxFit.cover,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TEXT PANEL (Flex 4 – phần dưới)
// ─────────────────────────────────────────────────────────────────────────────

class _TextPanel extends StatelessWidget {
  const _TextPanel({
    required this.controller,
    required this.isExtracting,
    required this.isPreviewMode,
    required this.onRetake,
    required this.onReExtract,
    required this.onSave,
  });

  final TextEditingController controller;
  final bool isExtracting;
  final bool isPreviewMode;
  final VoidCallback onRetake;
  final VoidCallback? onReExtract;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      child: Column(
        children: <Widget>[
          // ── Drag handle ───────────────────────────────────────────────────
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.30),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 10),

          // ── Section title ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.text_snippet_rounded,
                  size: 16,
                  color: AppColors.periwinkle,
                ),
                const SizedBox(width: 7),
                Text(
                  isPreviewMode
                      ? 'Văn bản nhận diện được'
                      : 'Chụp ảnh để nhận diện chữ',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.lightTextSecondary,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // ── TextField + loading overlay ───────────────────────────────────
          Expanded(
            child: Stack(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextField(
                    controller: controller,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.65,
                      color: Color(0xFF1A1A2E),
                      fontWeight: FontWeight.w400,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: isPreviewMode
                          ? 'Đang nhận diện...'
                          : 'Chữ sẽ xuất hiện sau khi chụp ảnh.',
                      hintStyle: TextStyle(
                        color: Colors.grey.withValues(alpha: 0.55),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),

                // Loading overlay
                if (isExtracting)
                  Positioned.fill(
                    child: Container(
                      color: Colors.white.withValues(alpha: 0.88),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            CircularProgressIndicator(
                              color: AppColors.deepPurple,
                              strokeWidth: 3,
                            ),
                            SizedBox(height: 14),
                            Text(
                              'Đang nhận diện chữ...',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.deepPurple,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Toolbar (chỉ hiện khi đã có ảnh) ─────────────────────────────
          if (isPreviewMode)
            _ActionToolbar(
              onRetake: onRetake,
              onReExtract: onReExtract,
              onSave: onSave,
              isExtracting: isExtracting,
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ACTION TOOLBAR (Preview Mode only)
// ─────────────────────────────────────────────────────────────────────────────

class _ActionToolbar extends StatelessWidget {
  const _ActionToolbar({
    required this.onRetake,
    required this.onReExtract,
    required this.onSave,
    required this.isExtracting,
  });

  final VoidCallback onRetake;
  final VoidCallback? onReExtract;
  final VoidCallback onSave;
  final bool isExtracting;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: AppColors.lavender,
            width: 1,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // ── Chụp lại + Lấy lại chữ ───────────────────────────────────────
          Row(
            children: <Widget>[
              Expanded(
                child: _OutlineButton(
                  icon: Icons.camera_alt_rounded,
                  label: 'Chụp lại',
                  onTap: onRetake,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _OutlineButton(
                  icon: Icons.refresh_rounded,
                  label: 'Lấy lại chữ',
                  onTap: isExtracting ? null : onReExtract,
                  loading: isExtracting,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── Lưu tài liệu ─────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isExtracting ? null : onSave,
              icon: const Icon(Icons.save_rounded, size: 20),
              label: const Text(
                'Lưu tài liệu',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.deepPurple,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    AppColors.deepPurple.withValues(alpha: 0.4),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// OUTLINE BUTTON (dùng trong toolbar)
// ─────────────────────────────────────────────────────────────────────────────

class _OutlineButton extends StatelessWidget {
  const _OutlineButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.loading = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.deepPurple,
        side: const BorderSide(color: AppColors.periwinkle, width: 1.5),
        padding: const EdgeInsets.symmetric(vertical: 13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      child: loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.deepPurple,
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(icon, size: 16),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
    );
  }
}