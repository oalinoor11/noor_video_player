import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:shimmer/shimmer.dart';

class VideoThumbnailWidget extends StatefulWidget {
  final String videoUrl;

  const VideoThumbnailWidget({super.key, required this.videoUrl});

  @override
  State<VideoThumbnailWidget> createState() => _VideoThumbnailWidgetState();
}

class _VideoThumbnailWidgetState extends State<VideoThumbnailWidget> {
  Uint8List? _thumbnail;

  @override
  void initState() {
    super.initState();
    _generateThumbnail();
  }

  Future<void> _generateThumbnail() async {
    final uint8list = await VideoThumbnail.thumbnailData(
      video: widget.videoUrl,
      imageFormat: ImageFormat.JPEG,
      maxWidth: 1280,
      quality: 75,
    );

    if (mounted) {
      setState(() => _thumbnail = uint8list);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_thumbnail == null) {
      return Shimmer.fromColors(
        baseColor: Colors.black12,
        highlightColor: Colors.black26,
        child: Container(
          color: Colors.black,
          child: const Center(
            child: Icon(Icons.videocam_rounded, size: 64, color: Colors.white),
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.memory(_thumbnail!, fit: BoxFit.cover),
        const Center(child: Icon(Icons.play_circle_fill, size: 64, color: Colors.white)),
      ],
    );
  }
}

final ValueNotifier<bool> globalMuteNotifier = ValueNotifier<bool>(false);

class NoorPlayer extends StatefulWidget {
  final String videoUrl;

  const NoorPlayer({super.key, required this.videoUrl});

  @override
  State<NoorPlayer> createState() => _NoorPlayerState();
}

class _NoorPlayerState extends State<NoorPlayer> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _needsRotation = false;
  String? _localVideoPath;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;

  // To reduce too many setState calls from download progress
  int _lastProgressUpdateTime = 0;

  late bool _isMuted;

  @override
  void initState() {
    super.initState();
    _isMuted = globalMuteNotifier.value;

    globalMuteNotifier.addListener(() {
      if (mounted) {
        setState(() {
          _isMuted = globalMuteNotifier.value;
          if (_isInitialized) {
            _controller.setVolume(_isMuted ? 0.0 : 1.0);
          }
        });
      }
    });

    _prepareVideo();
  }

  Future<void> _prepareVideo() async {
    final localPath = await _getCachedVideoPath(widget.videoUrl);
    final fileExists = localPath != null && await File(localPath).exists();

    if (fileExists) {
      _localVideoPath = localPath;
      _initializeController(_localVideoPath!);
    } else {
      _downloadAndCacheVideo(widget.videoUrl);
    }
  }

  Future<String?> _getCachedVideoPath(String url) async {
    final cacheDir = await getTemporaryDirectory();
    final fileName = Uri.parse(url).pathSegments.last;
    final filePath = '${cacheDir.path}/$fileName';
    return filePath;
  }

  Future<void> _downloadAndCacheVideo(String url) async {
    try {
      setState(() {
        _isDownloading = true;
        _downloadProgress = 0.0;
      });

      final cacheDir = await getTemporaryDirectory();
      final fileName = Uri.parse(url).pathSegments.last;
      final savePath = '${cacheDir.path}/$fileName';

      await Dio().download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final now = DateTime.now().millisecondsSinceEpoch;
            // Throttle setState calls to max once per 100ms
            if (now - _lastProgressUpdateTime > 100) {
              final progress = (received / total).clamp(0.0, 1.0);
              setState(() {
                _downloadProgress = progress;
              });
              _lastProgressUpdateTime = now;
            }
          }
        },
      );

      setState(() {
        _isDownloading = false;
        _localVideoPath = savePath;
      });

      _initializeController(savePath);
    } catch (e) {
      // fallback to network video if download failed
      setState(() {
        _isDownloading = false;
      });
      _initializeController(widget.videoUrl);
    }
  }

  void _initializeController(String videoSource) {
    _controller = videoSource.startsWith('http')
        ? VideoPlayerController.network(videoSource)
        : VideoPlayerController.file(File(videoSource));

    _controller.initialize().then((_) {
      if (mounted) {
        setState(() {
          _isInitialized = true;
          final size = _controller.value.size;
          _needsRotation = size.width > size.height;
        });
        _controller.setVolume(_isMuted ? 0.0 : 1.0);
        _controller.setLooping(true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    globalMuteNotifier.removeListener(() {}); // Clean up listener
    super.dispose();
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      _controller.pause();
      setState(() {
        _isPlaying = false;
      });
    } else {
      _controller.play();
      setState(() {
        _isPlaying = true;
      });
    }
  }

  void _toggleMute() {
    globalMuteNotifier.value = !globalMuteNotifier.value;
    // No need to set volume here manually, listener handles it
  }

  void _handleVisibilityChanged(VisibilityInfo info) {
    if (!_isInitialized) return;

    if (info.visibleFraction > 0.5) {
      if (!_controller.value.isPlaying) {
        _controller.play();
        _controller.setVolume(_isMuted ? 0.0 : 1.0);
        setState(() {
          _isPlaying = true;
        });
      }
    } else {
      if (_controller.value.isPlaying) {
        _controller.pause();
        setState(() {
          _isPlaying = false;
          // Do NOT change mute state on scroll out
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isDownloading) {
      return Shimmer.fromColors(
        baseColor: Colors.grey.shade300,
        highlightColor: Colors.grey.shade100,
        child: Container(
          width: double.infinity,
          height: 200,
          color: Colors.grey,
          margin: const EdgeInsets.symmetric(horizontal: 16),
        ),
      );
    }

    if (!_isInitialized) {
      return VideoThumbnailWidget(videoUrl: widget.videoUrl);
    }

    Widget videoWidget = VideoPlayer(_controller);
    if (_needsRotation) {
      videoWidget = Transform.rotate(
        angle: -1.5708,
        child: videoWidget,
      );
    }

    return VisibilityDetector(
      key: Key(widget.videoUrl),
      onVisibilityChanged: _handleVisibilityChanged,
      child: GestureDetector(
        onTap: _togglePlayPause,
        child: AspectRatio(
          aspectRatio: _controller.value.aspectRatio,
          child: Stack(
            fit: StackFit.expand,
            children: [
              videoWidget,
              if (!_isPlaying)
                Center(
                  child: Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black,
                    ),
                    child: const Icon(Icons.play_circle_fill, size: 64, color: Colors.white),
                  ),
                ),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: _toggleMute,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: Tooltip(
                      message: _isMuted ? "Unmute" : "Mute",
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Icon(
                          _isMuted ? Icons.volume_off : Icons.volume_up,
                          key: ValueKey<bool>(_isMuted),
                          color: Colors.white,
                          size: 25,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
