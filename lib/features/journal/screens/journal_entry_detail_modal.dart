import 'package:flutter/material.dart';
import 'package:dream_community_app/core/theme/app_theme.dart';
import 'package:dream_community_app/core/models/journal_entry_model.dart';
import 'package:dream_community_app/features/journal/screens/journal_entry_form_modal.dart';
import 'package:dream_community_app/features/journal/widgets/journal_media_gallery_viewer.dart';

class JournalEntryDetailModal extends StatelessWidget {
  final JournalEntryModel entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const JournalEntryDetailModal({
    super.key,
    required this.entry,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final parsedDate = DateTime.tryParse(entry.entryDate);
    final monthStr = parsedDate != null ? parsedDate.month.toString().padLeft(2, '0') : '--';
    final dayStr = parsedDate != null ? parsedDate.day.toString().padLeft(2, '0') : '--';
    final yearStr = parsedDate != null ? parsedDate.year.toString() : '----';
    final formattedDate = '$monthStr / $dayStr / $yearStr';

    final hasDream = entry.dream != null && entry.dream!.trim().isNotEmpty;
    final hasDestination = entry.destination != null && entry.destination!.trim().isNotEmpty;
    final hasReason = entry.reason != null && entry.reason!.trim().isNotEmpty;
    final hasEnergy = entry.energy != null && entry.energy!.trim().isNotEmpty;
    final hasAmigos = entry.amigos != null && entry.amigos!.trim().isNotEmpty;
    final hasMindset = entry.mindset != null && entry.mindset!.trim().isNotEmpty;

    final hasAnyContent = hasDream || hasDestination || hasReason || hasEnergy || hasAmigos || hasMindset;

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
      margin: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFDFDFB), // Authentic off-white paper page matching form modal
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            // Top Dark Cosmic Header Banner matching Reference & Form Modal
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF070B19), Color(0xFF140D2B), Color(0xFF0C172E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                children: [
                  // Top Bar: Center Handle Bar & Top-Right Close Button
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close_rounded, color: Colors.white70, size: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Main Title & Date Row matching JournalEntryFormModal exactly
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Header Title (Wrapped in Expanded to prevent overflow)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'DREAM',
                                  style: AppColors.soraBold(20).copyWith(
                                    color: AppColors.pink,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'JOURNAL',
                                  style: AppColors.soraBold(20).copyWith(
                                    color: Colors.white,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'A DAILY WRITING EXPERIENCE',
                              style: AppColors.geistBold(9).copyWith(
                                color: AppColors.cyan,
                                letterSpacing: 1.8,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Date Display Box matching Form Modal
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.cyan, width: 1.5),
                          boxShadow: [
                            BoxShadow(color: AppColors.cyan.withOpacity(0.3), blurRadius: 6),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'DATE:',
                              style: AppColors.geistBold(8).copyWith(color: Colors.black87),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              formattedDate,
                              style: AppColors.soraBold(11).copyWith(color: const Color(0xFF0F172A)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Paper Body with Ruled Paper Prompt Cards
            Expanded(
              child: Container(
                color: const Color(0xFFFDFDFB),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Render Prompts Matching Form Modal Structure
                      if (hasDream)
                        _buildPaperPromptBox(
                          letter: 'D',
                          title: 'DREAM',
                          question: 'WHAT IS MY DREAM?',
                          content: entry.dream!,
                          accentColor: const Color(0xFFEAB308), // Gold/Yellow
                          badgeColor: const Color(0xFFFEF08A),
                        ),

                      if (hasDestination)
                        _buildPaperPromptBox(
                          letter: 'D',
                          title: 'DESTINATION',
                          question: 'WHAT DID I DO TODAY THAT MOVED ME CLOSER TO MY DESTINATION?',
                          content: entry.destination!,
                          accentColor: const Color(0xFFCA8A04), // Darker Yellow
                          badgeColor: const Color(0xFFFEF08A),
                        ),

                      if (hasReason)
                        _buildPaperPromptBox(
                          letter: 'R',
                          title: 'REASON',
                          question: "WHAT REMINDED ME OF THE REASON WHY I'M DOING THIS?",
                          content: entry.reason!,
                          accentColor: const Color(0xFFEC4899), // Pink
                          badgeColor: const Color(0xFFFCE7F3),
                        ),

                      if (hasEnergy)
                        _buildPaperPromptBox(
                          letter: 'E',
                          title: 'ENERGY',
                          question: 'WHAT DID I DO TO CONTRIBUTE TO MY ENERGY TODAY?',
                          content: entry.energy!,
                          accentColor: const Color(0xFF06B6D4), // Cyan
                          badgeColor: const Color(0xFFCFFAFE),
                        ),

                      if (hasAmigos)
                        _buildPaperPromptBox(
                          letter: 'A',
                          title: 'AMIGOS',
                          question: 'WHO WERE THE AMIGOS I ASSOCIATED WITH TODAY?',
                          content: entry.amigos!,
                          accentColor: const Color(0xFFEAB308), // Gold
                          badgeColor: const Color(0xFFFEF08A),
                        ),

                      if (hasMindset)
                        _buildPaperPromptBox(
                          letter: 'M',
                          title: 'MINDSET',
                          question: 'WHAT DID I DO TO IMPROVE MY MINDSET TODAY?',
                          content: entry.mindset!,
                          accentColor: const Color(0xFF3B82F6), // Ice Blue
                          badgeColor: const Color(0xFFDBEAFE),
                        ),

                      if (!hasAnyContent)
                        _buildPaperPromptBox(
                          letter: 'D',
                          title: 'DREAM',
                          question: 'WHAT IS MY DREAM?',
                          content: '(No text recorded for this entry)',
                          accentColor: const Color(0xFFEAB308),
                          badgeColor: const Color(0xFFFEF08A),
                        ),

                      const SizedBox(height: 8),

                      // Media Attachments Section
                      if (entry.media.isNotEmpty) ...[
                        _buildMediaAttachmentSection(context),
                        const SizedBox(height: 20),
                      ],

                      // Bottom Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                Navigator.pop(context);
                                onEdit();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF070B19), Color(0xFF140D2B)],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.edit_rounded, color: AppColors.cyan, size: 16),
                                      const SizedBox(width: 8),
                                      Text(
                                        'EDIT JOURNAL ENTRY ✨',
                                        style: AppColors.soraBold(13).copyWith(
                                          color: Colors.white,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                              onDelete();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFFCA5A5)),
                              ),
                              child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 20),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Ruled Notebook Paper Prompt Box matching Reference & Form Modal
  Widget _buildPaperPromptBox({
    required String letter,
    required String title,
    required String question,
    required String content,
    required Color accentColor,
    required Color badgeColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withOpacity(0.6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title & Question Row matching Reference Image
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: accentColor.withOpacity(0.5)),
                ),
                child: Center(
                  child: Text(
                    letter,
                    style: AppColors.soraBold(12).copyWith(color: accentColor),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '$title : ',
                        style: AppColors.soraBold(12).copyWith(color: accentColor),
                      ),
                      TextSpan(
                        text: question,
                        style: AppColors.geistBold(10).copyWith(
                          color: const Color(0xFF1E293B),
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Ruled Notebook Paper Writing Area with Horizontal Lines
          Stack(
            children: [
              // Notebook Horizontal Ruled Lines Background
              Positioned.fill(
                child: CustomPaint(
                  painter: NotebookLinesPainter(
                    lineColor: const Color(0xFFCBD5E1),
                    lineHeight: 24.0,
                  ),
                ),
              ),

              // Text sitting perfectly on 24px notebook lines
              Container(
                constraints: const BoxConstraints(minHeight: 48),
                width: double.infinity,
                padding: const EdgeInsets.only(top: 2, bottom: 4),
                child: SelectableText(
                  content,
                  style: AppColors.hankenMedium(13).copyWith(
                    color: const Color(0xFF0F172A),
                    height: 1.85, // Aligns text cleanly with 24px notebook lines
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Media Attachment Section with gallery swiping
  Widget _buildMediaAttachmentSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'UNLIMITED MEDIA ATTACHMENTS',
                  style: AppColors.geistBold(11).copyWith(color: const Color(0xFF475569), letterSpacing: 0.8),
                ),
                const SizedBox(height: 2),
                Text(
                  'Tap any item to swipe in gallery mode ↔️',
                  style: AppColors.geistMedium(9).copyWith(color: AppColors.cyan, letterSpacing: 0.3),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.cyan.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.cyan.withValues(alpha: 0.3)),
              ),
              child: Text(
                '${entry.media.length} file${entry.media.length > 1 ? 's' : ''}',
                style: AppColors.geistBold(10).copyWith(color: AppColors.cyan),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        SizedBox(
          height: 94,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: entry.media.length,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (context, idx) {
              final m = entry.media[idx];
              final isVideo = m.fileType == 'video' ||
                  m.fileUrl.endsWith('.mp4') ||
                  m.fileUrl.endsWith('.mov') ||
                  m.fileUrl.endsWith('.webm') ||
                  m.fileUrl.endsWith('.mkv');

              return GestureDetector(
                onTap: () {
                  JournalMediaGalleryViewer.show(
                    context,
                    mediaList: entry.media,
                    initialIndex: idx,
                  );
                },
                child: Container(
                  width: 94,
                  height: 94,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isVideo ? const Color(0xFFEC4899) : AppColors.cyan.withValues(alpha: 0.45),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (isVideo ? const Color(0xFFEC4899) : AppColors.cyan).withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: isVideo
                      ? Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(color: const Color(0xFF0F172A)),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.play_circle_fill_rounded, color: AppColors.cyan, size: 30),
                                const SizedBox(height: 4),
                                Text('PLAY VIDEO', style: AppColors.geistBold(8).copyWith(color: Colors.white)),
                              ],
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEC4899),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'VIDEO',
                                  style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Image.network(
                          m.fileUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Center(
                            child: Icon(Icons.broken_image_rounded, color: Colors.white54, size: 28),
                          ),
                        ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
