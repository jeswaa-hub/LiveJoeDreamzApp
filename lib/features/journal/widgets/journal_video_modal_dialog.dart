import 'dart:async';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class JournalVideoModalDialog extends StatefulWidget {
  final String title;
  final String videoUrl;

  const JournalVideoModalDialog({
    super.key,
    required this.title,
    required this.videoUrl,
  });

  @override
  State<JournalVideoModalDialog> createState() => _JournalVideoModalDialogState();
}

class _JournalVideoModalDialogState extends State<JournalVideoModalDialog> {
  late final Player _player;
  late final VideoController _controller;
  double _aspectRatio = 16 / 9;
  StreamSubscription<int?>? _widthSub;
  StreamSubscription<int?>? _heightSub;
  int _videoW = 0;
  int _videoH = 0;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(
      _player,
      configuration: const VideoControllerConfiguration(
        enableHardwareAcceleration: true,
      ),
    );

    _widthSub = _player.stream.width.listen((w) {
      if (w != null && w > 0) {
        _videoW = w;
        _updateAspectRatio();
      }
    });
    _heightSub = _player.stream.height.listen((h) {
      if (h != null && h > 0) {
        _videoH = h;
        _updateAspectRatio();
      }
    });

    _player.stream.completed.listen((completed) {
      if (completed && mounted) {
        Navigator.pop(context);
      }
    });

    _player.open(Media(widget.videoUrl), play: true);
  }

  void _updateAspectRatio() {
    if (_videoW > 0 && _videoH > 0 && mounted) {
      setState(() => _aspectRatio = _videoW / _videoH);
    }
  }

  @override
  void dispose() {
    _widthSub?.cancel();
    _heightSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: _aspectRatio,
          child: Stack(
            children: [
              Video(
                controller: _controller,
                controls: MaterialVideoControls,
              ),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
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
