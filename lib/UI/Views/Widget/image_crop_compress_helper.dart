import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_cropper/image_cropper.dart';
import '../../app_colors.dart';

class ImageCropCompressHelper {
  /// Nén dữ liệu ảnh đa tầng bằng flutter_image_compress và tái mã hóa hạ kích thước
  static Future<Uint8List> compressImageBytes(
    Uint8List rawBytes, {
    int targetWidth = 1080,
    int quality = 80,
  }) async {
    // Tầng 1: Nén bằng flutter_image_compress (Native plugin hiệu năng cao)
    try {
      final compressed = await FlutterImageCompress.compressWithList(
        rawBytes,
        minWidth: targetWidth,
        quality: quality,
        format: CompressFormat.jpeg,
      );
      if (compressed.isNotEmpty && compressed.length < rawBytes.length) {
        debugPrint(
            'Nén ảnh thành công bằng flutter_image_compress: ${rawBytes.length} -> ${compressed.length} bytes');
        return compressed;
      }
    } catch (e) {
      debugPrint('flutter_image_compress fallback to instantiateImageCodec: $e');
    }

    // Tầng 2: Nén bằng ui.instantiateImageCodec (hoạt động 100% trên mọi nền tảng bao gồm Desktop & Web)
    try {
      final codec = await ui.instantiateImageCodec(
        rawBytes,
        targetWidth: targetWidth,
      );
      final frame = await codec.getNextFrame();
      final byteData =
          await frame.image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        return byteData.buffer.asUint8List();
      }
    } catch (e) {
      debugPrint('Lỗi nén ảnh qua ui codec: $e');
    }
    return rawBytes;
  }

  /// Cắt và căn chỉnh ảnh: Hỗ trợ cả image_cropper (native Android/iOS)
  /// và Custom Interactive Crop Dialog (hỗ trợ Desktop/Web và linh hoạt trong ứng dụng)
  static Future<Uint8List?> cropImage({
    required BuildContext context,
    required String? sourcePath,
    required Uint8List imageBytes,
    double aspectRatio = 3 / 4,
  }) async {
    // 1. Thử dùng image_cropper trên Android hoặc iOS nếu có đường dẫn file gốc
    if (sourcePath != null &&
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      try {
        final croppedFile = await ImageCropper().cropImage(
          sourcePath: sourcePath,
          compressFormat: ImageCompressFormat.jpg,
          compressQuality: 85,
          maxHeight: 1440,
          maxWidth: 1080,
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Cắt ảnh hồ sơ DatingLy',
              toolbarColor: AppColors.primary,
              toolbarWidgetColor: Colors.white,
              activeControlsWidgetColor: AppColors.primary,
              initAspectRatio: CropAspectRatioPreset.ratio4x3,
              lockAspectRatio: false,
              aspectRatioPresets: [
                CropAspectRatioPreset.ratio4x3,
                CropAspectRatioPreset.square,
                CropAspectRatioPreset.original,
              ],
            ),
            IOSUiSettings(
              title: 'Cắt ảnh hồ sơ DatingLy',
              aspectRatioLockEnabled: false,
              aspectRatioPresets: [
                CropAspectRatioPreset.ratio4x3,
                CropAspectRatioPreset.square,
                CropAspectRatioPreset.original,
              ],
            ),
          ],
        );

        if (croppedFile != null) {
          final bytes = await croppedFile.readAsBytes();
          // Tiếp tục nén ảnh bằng bộ nén cao cấp
          return await compressImageBytes(bytes);
        } else {
          // Người dùng chủ động bấm Hủy trong image_cropper
          return null;
        }
      } catch (e) {
        debugPrint('image_cropper fallback sang in-app dialog: $e');
      }
    }

    // 2. Fallback sang Hộp thoại Cắt ảnh trực quan tích hợp sẵn (tương thích mọi môi trường)
    if (!context.mounted) return null;
    return showCropDialog(
      context,
      imageBytes: imageBytes,
      aspectRatio: aspectRatio,
    );
  }

  /// Mở màn hình / hộp thoại Interactive Crop cho người dùng căn chỉnh ảnh
  static Future<Uint8List?> showCropDialog(
    BuildContext context, {
    required Uint8List imageBytes,
    double aspectRatio = 3 / 4, // Chuẩn tỷ lệ ảnh thẻ Dating
  }) async {
    return showDialog<Uint8List?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _CropDialog(
        imageBytes: imageBytes,
        aspectRatio: aspectRatio,
      ),
    );
  }
}

class _CropDialog extends StatefulWidget {
  final Uint8List imageBytes;
  final double aspectRatio;

  const _CropDialog({
    required this.imageBytes,
    required this.aspectRatio,
  });

  @override
  State<_CropDialog> createState() => _CropDialogState();
}

class _CropDialogState extends State<_CropDialog> {
  final GlobalKey _cropAreaKey = GlobalKey();
  final TransformationController _transformController =
      TransformationController();
  bool _isProcessing = false;

  Future<void> _captureCrop() async {
    setState(() => _isProcessing = true);
    try {
      final boundary = _cropAreaKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        if (mounted) Navigator.pop(context, widget.imageBytes);
        return;
      }

      // Capture at device pixel ratio 2.0 for sharp portrait quality
      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData != null) {
        final croppedBytes = byteData.buffer.asUint8List();
        // Tiếp tục nén ảnh sau khi crop
        final compressed =
            await ImageCropCompressHelper.compressImageBytes(croppedBytes);
        if (mounted) {
          Navigator.pop(context, compressed);
        }
        return;
      }
    } catch (e) {
      debugPrint('Lỗi khi crop ảnh: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }

    if (mounted) Navigator.pop(context, widget.imageBytes);
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final viewWidth = media.size.width * 0.88;
    final viewHeight = viewWidth / widget.aspectRatio;

    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.crop_rotate_rounded,
                        color: AppColors.primary, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Cắt & Căn chỉnh ảnh',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.pop(context, null),
                ),
              ],
            ),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Chụm 2 ngón tay để phóng to/thu nhỏ và kéo để chọn góc chụp đẹp nhất',
              style: TextStyle(color: Colors.white60, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),

          // Crop Viewport with RepaintBoundary
          RepaintBoundary(
            key: _cropAreaKey,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: viewWidth,
                height: viewHeight.clamp(200.0, media.size.height * 0.55),
                color: Colors.black,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    InteractiveViewer(
                      transformationController: _transformController,
                      minScale: 0.8,
                      maxScale: 3.5,
                      boundaryMargin: const EdgeInsets.all(80),
                      child: Image.memory(
                        widget.imageBytes,
                        fit: BoxFit.contain,
                      ),
                    ),

                    // Grid overlay guides
                    IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.4),
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                    Expanded(
                                        child: Container(
                                            decoration: BoxDecoration(
                                                border: Border(
                                                    right: BorderSide(
                                                        color: Colors.white
                                                            .withValues(alpha: 0.2)),
                                                    bottom: BorderSide(
                                                        color: Colors.white
                                                            .withValues(
                                                                alpha: 0.2)))))),
                                    Expanded(
                                        child: Container(
                                            decoration: BoxDecoration(
                                                border: Border(
                                                    right: BorderSide(
                                                        color: Colors.white
                                                            .withValues(alpha: 0.2)),
                                                    bottom: BorderSide(
                                                        color: Colors.white
                                                            .withValues(
                                                                alpha: 0.2)))))),
                                    Expanded(
                                        child: Container(
                                            decoration: BoxDecoration(
                                                border: Border(
                                                    bottom: BorderSide(
                                                        color: Colors.white
                                                            .withValues(
                                                                alpha: 0.2)))))),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Row(
                                children: [
                                    Expanded(
                                        child: Container(
                                            decoration: BoxDecoration(
                                                border: Border(
                                                    right: BorderSide(
                                                        color: Colors.white
                                                            .withValues(alpha: 0.2)),
                                                    bottom: BorderSide(
                                                        color: Colors.white
                                                            .withValues(
                                                                alpha: 0.2)))))),
                                    Expanded(
                                        child: Container(
                                            decoration: BoxDecoration(
                                                border: Border(
                                                    right: BorderSide(
                                                        color: Colors.white
                                                            .withValues(alpha: 0.2)),
                                                    bottom: BorderSide(
                                                        color: Colors.white
                                                            .withValues(
                                                                alpha: 0.2)))))),
                                    Expanded(
                                        child: Container(
                                            decoration: BoxDecoration(
                                                border: Border(
                                                    bottom: BorderSide(
                                                        color: Colors.white
                                                            .withValues(
                                                                alpha: 0.2)))))),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Row(
                                children: [
                                    Expanded(
                                        child: Container(
                                            decoration: BoxDecoration(
                                                border: Border(
                                                    right: BorderSide(
                                                        color: Colors.white
                                                            .withValues(
                                                                alpha: 0.2)))))),
                                    Expanded(
                                        child: Container(
                                            decoration: BoxDecoration(
                                                border: Border(
                                                    right: BorderSide(
                                                        color: Colors.white
                                                            .withValues(
                                                                alpha: 0.2)))))),
                                    const Expanded(child: SizedBox()),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Actions
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white30),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context, widget.imageBytes),
                    child: const Text('Giữ gốc'),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _isProcessing ? null : _captureCrop,
                    child: _isProcessing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Cắt & Lưu',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

