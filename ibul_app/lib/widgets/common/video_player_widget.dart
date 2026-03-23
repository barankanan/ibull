import 'dart:io';

import 'package:chewie/chewie.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../../services/media/media_perf_logger.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String? videoUrl;
  final XFile? videoFile;
  final bool autoPlay;
  final Duration? trimStart;
  final Duration? trimEnd;
  final bool initializeOnTap;
  final String? thumbnailUrl;

  const VideoPlayerWidget({
    super.key,
    this.videoUrl,
    this.videoFile,
    this.autoPlay = false,
    this.trimStart,
    this.trimEnd,
    this.initializeOnTap = true,
    this.thumbnailUrl,
  }) : assert(videoUrl != null || videoFile != null);

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _error = false;
  bool _isInitializing = false;
  bool _isInitialized = false;
  VoidCallback? _trimListener;

  @override
  void initState() {
    super.initState();
    if (!widget.initializeOnTap) {
      _initializePlayer();
    }
  }

  Future<void> _initializePlayer() async {
    if (_isInitializing) return;
    setState(() {
      _error = false;
      _isInitializing = true;
    });

    final initWatch = Stopwatch()..start();
    try {
      await _disposeControllers();

      if (widget.videoFile != null) {
        if (kIsWeb) {
          _videoPlayerController = VideoPlayerController.networkUrl(
            Uri.parse(widget.videoFile!.path),
          );
        } else {
          _videoPlayerController = VideoPlayerController.file(
            File(widget.videoFile!.path),
          );
        }
      } else if (widget.videoUrl != null) {
        _videoPlayerController = VideoPlayerController.networkUrl(
          Uri.parse(widget.videoUrl!),
        );
      } else {
        throw Exception('No video source provided');
      }

      final controller = _videoPlayerController;
      if (controller == null) {
        throw Exception('Video controller oluşturulamadı');
      }

      await controller.initialize();

      final trimStart = widget.trimStart;
      if (trimStart != null &&
          trimStart > Duration.zero &&
          trimStart < controller.value.duration) {
        await controller.seekTo(trimStart);
      }

      final trimEnd = widget.trimEnd;
      final hasTrimRange =
          (trimStart != null && trimStart > Duration.zero) ||
          (trimEnd != null &&
              trimEnd > Duration.zero &&
              trimEnd < controller.value.duration);
      final trimBoundaryEnd =
          (trimEnd == null || trimEnd > controller.value.duration)
          ? controller.value.duration
          : trimEnd;

      if (hasTrimRange) {
        _trimListener = () {
          final activeController = _videoPlayerController;
          if (activeController == null ||
              !activeController.value.isInitialized) {
            return;
          }
          final position = activeController.value.position;
          if (position >= trimBoundaryEnd) {
            final wasPlaying = activeController.value.isPlaying;
            activeController.seekTo(trimStart ?? Duration.zero);
            if (wasPlaying) {
              activeController.play();
            }
          }
        };
        controller.addListener(_trimListener!);
      }

      _chewieController = ChewieController(
        videoPlayerController: controller,
        autoPlay: widget.autoPlay,
        looping: !hasTrimRange,
        aspectRatio: controller.value.aspectRatio,
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Text(
              'Video oynatılırken hata oluştu: $errorMessage',
              style: const TextStyle(color: Colors.white),
            ),
          );
        },
      );

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Error initializing video player: $e');
      if (mounted) {
        setState(() {
          _error = true;
          _isInitialized = false;
        });
      }
    } finally {
      initWatch.stop();
      MediaPerfLogger.logDuration(
        'detail_page_video_initialize_suresi',
        initWatch.elapsed,
        extra: {
          'hasUrl': widget.videoUrl != null,
          'hasFile': widget.videoFile != null,
        },
      );
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  Future<void> _disposeControllers() async {
    final controller = _videoPlayerController;
    if (controller != null && _trimListener != null) {
      controller.removeListener(_trimListener!);
    }
    _trimListener = null;
    _chewieController?.dispose();
    _videoPlayerController?.dispose();
    _chewieController = null;
    _videoPlayerController = null;
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error) {
      return _buildRetryState();
    }

    if (_chewieController != null &&
        (_videoPlayerController?.value.isInitialized ?? false)) {
      return Chewie(controller: _chewieController!);
    }

    if (widget.initializeOnTap && !_isInitializing && !_isInitialized) {
      return _buildIdleState();
    }

    return _buildLoadingState();
  }

  Widget _buildIdleState() {
    return GestureDetector(
      onTap: _initializePlayer,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildThumbnailBackground(),
          Container(color: Colors.black.withValues(alpha: 0.24)),
          const Center(
            child: CircleAvatar(
              radius: 28,
              backgroundColor: Colors.white,
              child: Icon(
                Icons.play_arrow_rounded,
                size: 34,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildThumbnailBackground(),
        Container(color: Colors.black.withValues(alpha: 0.24)),
        const Center(child: CircularProgressIndicator(color: Colors.white)),
      ],
    );
  }

  Widget _buildRetryState() {
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildThumbnailBackground(),
        Container(color: Colors.black.withValues(alpha: 0.5)),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Video yüklenemedi',
                style: TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _initializePlayer,
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: const Text(
                  'Tekrar dene',
                  style: TextStyle(color: Colors.white),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildThumbnailBackground() {
    final thumb = widget.thumbnailUrl?.trim();
    if (thumb != null && thumb.isNotEmpty) {
      return Image.network(
        thumb,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(color: Colors.black),
      );
    }
    return Container(color: Colors.black);
  }
}
