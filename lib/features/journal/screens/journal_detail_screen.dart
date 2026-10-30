import 'package:flutter/material.dart';
import 'package:dream_community_app/shared/widgets/video_detail_screen.dart';

class JournalDetailScreen extends StatelessWidget {
  final String title;
  final String videoUrl;
  final String? thumbnailUrl;
  final List<Map<String, dynamic>>? moreVideos;
  final int videoId;

  const JournalDetailScreen({
    super.key,
    required this.title,
    required this.videoUrl,
    this.thumbnailUrl,
    this.moreVideos,
    required this.videoId,
  });

  @override
  Widget build(BuildContext context) {
    return VideoDetailScreen(
      title: title,
      subtitle: 'D.R.E.A.M Journal',
      videoUrl: videoUrl,
      thumbnailUrl: thumbnailUrl,
      moreVideos: moreVideos,
      videoType: 'journal',
      videoId: videoId,
    );
  }
}
