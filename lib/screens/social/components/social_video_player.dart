import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../../models/social_models.dart';
import '../../../providers/auth_provider.dart';

class SocialVideoPlayer extends StatefulWidget {
  final SocialAttachment attachment;

  const SocialVideoPlayer({
    super.key,
    required this.attachment,
  });

  @override
  State<SocialVideoPlayer> createState() => _SocialVideoPlayerState();
}

class _SocialVideoPlayerState extends State<SocialVideoPlayer> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isLoading = false;
  bool _showControls = true;

  String _resolveUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.isEmpty) return '';
    if (rawUrl.startsWith('http://') || rawUrl.startsWith('https://')) return rawUrl;
    final base = AuthProvider.authBaseUrl;
    final clean = rawUrl.startsWith('/') ? rawUrl : '/$rawUrl';
    return '$base$clean';
  }

  Map<String, String> _getHeaders() {
    final cookies = AuthProvider.instance?.cookies;
    if (cookies != null && cookies.isNotEmpty) {
      return {'cookie': cookies};
    }
    return const {};
  }

  String _formatDuration(int? durationMs) {
    if (durationMs == null || durationMs <= 0) return '';
    final totalSeconds = (durationMs / 1000).round();
    final minutes = totalSeconds ~/ 60;
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _startPlayback() async {
    final videoUrl = _resolveUrl(widget.attachment.url);
    if (videoUrl.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final uri = Uri.parse(videoUrl);
      final controller = VideoPlayerController.networkUrl(
        uri,
        httpHeaders: _getHeaders(),
      );

      await controller.initialize();
      controller.addListener(_videoListener);
      await controller.play();

      if (mounted) {
        setState(() {
          _controller = controller;
          _isInitialized = true;
          _isPlaying = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[SocialVideoPlayer] Initialization error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể phát video này.')),
        );
      }
    }
  }

  void _videoListener() {
    if (_controller == null || !mounted) return;
    final isPlaying = _controller!.value.isPlaying;
    if (isPlaying != _isPlaying) {
      setState(() => _isPlaying = isPlaying);
    }
  }

  void _togglePlayPause() {
    if (_controller == null) return;
    if (_controller!.value.isPlaying) {
      _controller!.pause();
    } else {
      _controller!.play();
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_videoListener);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final posterUrl = _resolveUrl(widget.attachment.posterUrl);
    final durationText = _formatDuration(widget.attachment.durationMs);

    final double aspect = (widget.attachment.width != null &&
            widget.attachment.height != null &&
            widget.attachment.height! > 0)
        ? (widget.attachment.width! / widget.attachment.height!)
        : 16 / 9;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      constraints: const BoxConstraints(maxHeight: 380),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: aspect.clamp(0.6, 2.2),
          child: Container(
            color: Colors.black,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 1. Video Player or Poster Image
                if (_isInitialized && _controller != null)
                  GestureDetector(
                    onTap: () => setState(() => _showControls = !_showControls),
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: _controller!.value.aspectRatio,
                        child: VideoPlayer(_controller!),
                      ),
                    ),
                  )
                else if (posterUrl.isNotEmpty)
                  Image.network(
                    posterUrl,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    headers: _getHeaders(),
                    errorBuilder: (_, error, stackTrace) => Container(
                      color: const Color(0xFF1E293B),
                      child: const Center(
                        child: Icon(Icons.videocam_rounded, color: Color(0xFF94A3B8), size: 48),
                      ),
                    ),
                  )
                else
                  Container(
                    color: const Color(0xFF0F172A),
                    child: const Center(
                      child: Icon(Icons.play_circle_outline, color: Colors.white70, size: 54),
                    ),
                  ),

                // 2. Duration Badge (when not playing or controls visible)
                if ((!_isInitialized || _showControls) && durationText.isNotEmpty)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        durationText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                // 3. Play button or Loading Indicator
                if (_isLoading)
                  const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                else if (!_isInitialized)
                  Center(
                    child: GestureDetector(
                      onTap: _startPlayback,
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white70, width: 2),
                        ),
                        child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 36),
                      ),
                    ),
                  ),

                // 4. In-player Controls Overlay
                if (_isInitialized && _showControls && _controller != null) ...[
                  Center(
                    child: GestureDetector(
                      onTap: _togglePlayPause,
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.8),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: VideoProgressIndicator(
                        _controller!,
                        allowScrubbing: true,
                        colors: const VideoProgressColors(
                          playedColor: Color(0xFF2563EB),
                          bufferedColor: Colors.white30,
                          backgroundColor: Colors.white12,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
