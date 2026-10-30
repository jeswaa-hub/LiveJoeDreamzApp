import 'package:flutter/material.dart';
import 'package:dream_community_app/shared/widgets/video_detail_screen.dart';

class PodcastDetailScreen extends StatelessWidget {
  final String title;
  final String guest;
  final String videoUrl;
  final String? thumbnailUrl;
  final List<Map<String, dynamic>>? moreVideos;
  final int videoId;

  const PodcastDetailScreen({
    super.key,
    required this.title,
    required this.guest,
    required this.videoUrl,
    this.thumbnailUrl,
    this.moreVideos,
    required this.videoId,
  });

  @override
  Widget build(BuildContext context) {
    return VideoDetailScreen(
      title: title,
      subtitle: guest.isNotEmpty ? 'with $guest' : 'D.R.E.A.M. Podcast',
      videoUrl: videoUrl,
      thumbnailUrl: thumbnailUrl,
      moreVideos: moreVideos,
      videoType: 'podcast',
      videoId: videoId,
    );
  }
}
