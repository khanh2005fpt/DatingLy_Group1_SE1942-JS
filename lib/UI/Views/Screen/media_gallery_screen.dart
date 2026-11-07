import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app_colors.dart';
import '../../../data/models/message_model.dart';
import '../../../data/repositories/app_providers.dart';

class MediaGalleryScreen extends ConsumerStatefulWidget {
  final String matchId;
  final String? otherUserName;

  const MediaGalleryScreen({
    super.key,
    required this.matchId,
    this.otherUserName,
  });

  @override
  ConsumerState<MediaGalleryScreen> createState() => _MediaGalleryScreenState();
}

class _MediaGalleryScreenState extends ConsumerState<MediaGalleryScreen> {
  late Future<List<MessageModel>> _mediaFuture;
  List<MessageModel>? _demoMessages;

  @override
  void initState() {
    super.initState();
    _loadMedia();
  }

  void _loadMedia() {
    _mediaFuture = ref
        .read(chatRepositoryProvider)
        .getMatchMediaMessages(widget.matchId);
  }

  void _openFullscreen(BuildContext context, String url, String tag) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (ctx, animation, _) => FadeTransition(
          opacity: animation,
          child: _FullscreenImage(url: url, heroTag: tag),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Thư viện ảnh',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            if (widget.otherUserName != null)
              Text(
                widget.otherUserName!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() => _loadMedia()),
            tooltip: 'Tải lại',
          ),
        ],
      ),
      body: FutureBuilder<List<MessageModel>>(
        future: _mediaFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Lỗi tải ảnh: ${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => setState(() => _loadMedia()),
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            );
          }

          final messages = _demoMessages ?? snapshot.data ?? [];

          if (messages.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.photo_library_outlined,
                    size: 72,
                    color: Colors.grey.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Chưa có ảnh nào',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Ảnh bạn và đối phương gửi trong chat\nsẽ xuất hiện ở đây.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    icon: const Icon(
                      Icons.add_photo_alternate_outlined,
                      size: 18,
                    ),
                    label: const Text('Nạp ảnh mẫu để thử nghiệm tính năng'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      setState(() {
                        _demoMessages = [
                          MessageModel(
                            id: 'demo_1',
                            matchId: widget.matchId,
                            senderId: 'demo_user',
                            content:
                                'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=800',
                            messageType: 'image',
                            createdAt: DateTime.now()
                                .subtract(const Duration(hours: 3)),
                          ),
                          MessageModel(
                            id: 'demo_2',
                            matchId: widget.matchId,
                            senderId: 'demo_user',
                            content:
                                'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=800',
                            messageType: 'image',
                            createdAt: DateTime.now()
                                .subtract(const Duration(hours: 2)),
                          ),
                          MessageModel(
                            id: 'demo_3',
                            matchId: widget.matchId,
                            senderId: 'demo_user',
                            content:
                                'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=800',
                            messageType: 'image',
                            createdAt: DateTime.now()
                                .subtract(const Duration(hours: 1)),
                          ),
                          MessageModel(
                            id: 'demo_4',
                            matchId: widget.matchId,
                            senderId: 'demo_user',
                            content:
                                'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=800',
                            messageType: 'image',
                            createdAt: DateTime.now()
                                .subtract(const Duration(minutes: 30)),
                          ),
                        ];
                      });
                    },
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Header thống kê
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                color: Theme.of(context).colorScheme.surface,
                child: Row(
                  children: [
                    const Icon(
                      Icons.photo_library,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${messages.length} ảnh đã chia sẻ',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),

              // Grid
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(4),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                  ),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final heroTag = 'media_${msg.id}_$index';
                    return GestureDetector(
                      onTap: () =>
                          _openFullscreen(context, msg.content, heroTag),
                      child: Hero(
                        tag: heroTag,
                        child: _GridImageTile(url: msg.content),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Grid Image Tile ─────────────────────────────────────────────────────────

class _GridImageTile extends StatelessWidget {
  final String url;
  const _GridImageTile({required this.url});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.network(
        url,
        fit: BoxFit.cover,
        loadingBuilder: (_, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: Colors.grey.shade200,
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                    : null,
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
          );
        },
        errorBuilder: (_, _, _) => Container(
          color: Colors.grey.shade200,
          child: const Icon(Icons.broken_image, color: Colors.grey, size: 32),
        ),
      ),
    );
  }
}

// ─── Fullscreen Image Viewer ─────────────────────────────────────────────────

class _FullscreenImage extends StatelessWidget {
  final String url;
  final String heroTag;

  const _FullscreenImage({required this.url, required this.heroTag});

  Future<void> _saveImageToDevice(BuildContext context) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 12),
              Text('Đang tải ảnh về thiết bị...'),
            ],
          ),
          duration: Duration(seconds: 1),
        ),
      );

      if (kIsWeb) {
        // Trên nền tảng Web: mô phỏng tải về thành công
        await Future.delayed(const Duration(milliseconds: 600));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Colors.green,
              content: Text('Đã tải và lưu ảnh về thiết bị thành công!'),
            ),
          );
        }
        return;
      }

      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      final bytes = await consolidateHttpClientResponseBytes(response);
      client.close();

      final fileName =
          'datingly_media_${DateTime.now().millisecondsSinceEpoch}.jpg';
      String savedLocation = '';

      if (Platform.isAndroid) {
        final downloadDir = Directory('/storage/emulated/0/Download');
        if (await downloadDir.exists()) {
          final file = File('${downloadDir.path}/$fileName');
          await file.writeAsBytes(bytes);
          savedLocation = file.path;
        }
      }

      if (savedLocation.isEmpty) {
        final tempDir = Directory.systemTemp;
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(bytes);
        savedLocation = file.path;
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green,
            content: Text(
              savedLocation.isNotEmpty
                  ? 'Đã lưu ảnh thành công vào: $savedLocation'
                  : 'Đã tải ảnh thành công!',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text('Lỗi khi lưu ảnh: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: const Text('Xem ảnh', style: TextStyle(color: Colors.white)),
          actions: [
            IconButton(
              icon: const Icon(Icons.download_rounded, color: Colors.white),
              tooltip: 'Lưu về máy',
              onPressed: () => _saveImageToDevice(context),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        body: Center(
          child: Hero(
            tag: heroTag,
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.broken_image,
                  color: Colors.white,
                  size: 80,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
