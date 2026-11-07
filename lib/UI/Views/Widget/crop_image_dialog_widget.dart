import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'image_crop_compress_helper.dart';

/// CropImageDialogWidget: Widget cắt và căn chỉnh ảnh (PRM393 MVVM Pattern)
class CropImageDialogWidget extends StatelessWidget {
  final Uint8List imageBytes;
  final double aspectRatio;

  const CropImageDialogWidget({
    super.key,
    required this.imageBytes,
    this.aspectRatio = 3 / 4,
  });

  static Future<Uint8List?> show(
    BuildContext context, {
    required Uint8List imageBytes,
    String? sourcePath,
    double aspectRatio = 3 / 4,
  }) {
    return ImageCropCompressHelper.cropImage(
      context: context,
      sourcePath: sourcePath,
      imageBytes: imageBytes,
      aspectRatio: aspectRatio,
    );
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox();
  }
}

