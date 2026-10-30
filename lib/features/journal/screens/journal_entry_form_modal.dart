import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dream_community_app/core/theme/app_theme.dart';
import 'package:dream_community_app/core/widgets/dream_toast.dart';
import 'package:dream_community_app/core/models/journal_entry_model.dart';
import 'package:dream_community_app/features/journal/services/journal_entry_service.dart';

class JournalEntryFormModal extends StatefulWidget {
  final VoidCallback onSaved;
  final JournalEntryModel? entry;

  const JournalEntryFormModal({
    super.key,
    required this.onSaved,
    this.entry,
  });

  @override
  State<JournalEntryFormModal> createState() => _JournalEntryFormModalState();
}

class _JournalEntryFormModalState extends State<JournalEntryFormModal> {
  final _dreamCtrl = TextEditingController();
  final _destinationCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  final _energyCtrl = TextEditingController();
  final _amigosCtrl = TextEditingController();
  final _mindsetCtrl = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;

  final List<PickedMediaFile> _pickedMediaList = [];
  final List<int> _deleteMediaIds = [];

  @override
  void initState() {
    super.initState();
    if (widget.entry != null) {
      final e = widget.entry!;
      _dreamCtrl.text = e.dream ?? '';
      _destinationCtrl.text = e.destination ?? '';
      _reasonCtrl.text = e.reason ?? '';
      _energyCtrl.text = e.energy ?? '';
      _amigosCtrl.text = e.amigos ?? '';
      _mindsetCtrl.text = e.mindset ?? '';
      _selectedDate = DateTime.tryParse(e.entryDate) ?? DateTime.now();
    }
  }

  @override
  void dispose() {
    _dreamCtrl.dispose();
    _destinationCtrl.dispose();
    _reasonCtrl.dispose();
    _energyCtrl.dispose();
    _amigosCtrl.dispose();
    _mindsetCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickMediaFromGallery() async {
    try {
      final picker = ImagePicker();
      final List<XFile> mediaFiles = await picker.pickMultipleMedia(imageQuality: 85);
      if (mediaFiles.isNotEmpty) {
        for (final file in mediaFiles) {
          final bytes = await file.readAsBytes();
          final ext = file.name.toLowerCase();
          final isVideo = ext.endsWith('.mp4') ||
              ext.endsWith('.mov') ||
              ext.endsWith('.avi') ||
              ext.endsWith('.webm') ||
              ext.endsWith('.mkv') ||
              file.mimeType?.contains('video') == true;
          setState(() {
            _pickedMediaList.add(PickedMediaFile(
              bytes: bytes,
              fileName: file.name,
              isVideo: isVideo,
            ));
          });
        }
      }
    } catch (e) {
      if (mounted) DreamToast.error(context, 'Failed to pick media');
    }
  }

  Future<void> _recordVideo() async {
    try {
      final picker = ImagePicker();
      final XFile? video = await picker.pickVideo(source: ImageSource.camera);
      if (video != null) {
        final bytes = await video.readAsBytes();
        setState(() {
          _pickedMediaList.add(PickedMediaFile(
            bytes: bytes,
            fileName: video.name,
            isVideo: true,
          ));
        });
      }
    } catch (e) {
      if (mounted) DreamToast.error(context, 'Failed to record video');
    }
  }

  Future<void> _takePhoto() async {
    try {
      final picker = ImagePicker();
      final XFile? photo = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
      if (photo != null) {
        final bytes = await photo.readAsBytes();
        setState(() {
          _pickedMediaList.add(PickedMediaFile(
            bytes: bytes,
            fileName: photo.name,
            isVideo: false,
          ));
        });
      }
    } catch (e) {
      if (mounted) DreamToast.error(context, 'Failed to take photo');
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.cyan,
              onPrimary: AppColors.background,
              surface: Color(0xFF0C1524),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _saveEntry() async {
    if (_dreamCtrl.text.trim().isEmpty) {
      DreamToast.error(context, 'Please write your dream title.');
      return;
    }

    setState(() => _isSaving = true);

    final dateStr =
        '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

    final isEditing = widget.entry != null;
    final result = isEditing
        ? await JournalEntryService().updateEntry(
            id: widget.entry!.id,
            entryDate: dateStr,
            dream: _dreamCtrl.text.trim(),
            destination: _destinationCtrl.text.trim().isNotEmpty ? _destinationCtrl.text.trim() : null,
            reason: _reasonCtrl.text.trim().isNotEmpty ? _reasonCtrl.text.trim() : null,
            energy: _energyCtrl.text.trim().isNotEmpty ? _energyCtrl.text.trim() : null,
            amigos: _amigosCtrl.text.trim().isNotEmpty ? _amigosCtrl.text.trim() : null,
            mindset: _mindsetCtrl.text.trim().isNotEmpty ? _mindsetCtrl.text.trim() : null,
            mediaFiles: _pickedMediaList,
            deleteMediaIds: _deleteMediaIds,
          )
        : await JournalEntryService().createEntry(
            entryDate: dateStr,
            dream: _dreamCtrl.text.trim(),
            destination: _destinationCtrl.text.trim().isNotEmpty ? _destinationCtrl.text.trim() : null,
            reason: _reasonCtrl.text.trim().isNotEmpty ? _reasonCtrl.text.trim() : null,
            energy: _energyCtrl.text.trim().isNotEmpty ? _energyCtrl.text.trim() : null,
            amigos: _amigosCtrl.text.trim().isNotEmpty ? _amigosCtrl.text.trim() : null,
            mindset: _mindsetCtrl.text.trim().isNotEmpty ? _mindsetCtrl.text.trim() : null,
            mediaFiles: _pickedMediaList,
          );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (result != null) {
      DreamToast.success(context, isEditing ? 'Journal Entry Updated! ✨' : 'Journal Entry Saved! ✨');
      widget.onSaved();
      Navigator.pop(context);
    } else {
      DreamToast.error(context, 'Failed to save entry. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final isEditing = widget.entry != null;

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
      margin: EdgeInsets.fromLTRB(10, 10, 10, 10 + bottomPadding),
      decoration: BoxDecoration(
        color: const Color(0xFFFDFDFB), // Authentic off-white paper page
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
            // Top Dark Cosmic Header Banner matching Reference Image
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF070B19), Color(0xFF140D2B), Color(0xFF0C172E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                children: [
                  // Handle Bar
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
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
                          ),
                        ],
                      ),

                      // Date Picker Box matching Reference Image
                      GestureDetector(
                        onTap: _selectDate,
                        child: Container(
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
                                '${_selectedDate.month.toString().padLeft(2, '0')} / ${_selectedDate.day.toString().padLeft(2, '0')} / ${_selectedDate.year}',
                                style: AppColors.soraBold(11).copyWith(color: const Color(0xFF0F172A)),
                              ),
                            ],
                          ),
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
                    children: [
                      // Exact Prompts & Questions from Reference Image
                      _buildPaperPromptBox(
                        letter: 'D',
                        title: 'DREAM',
                        question: 'WHAT IS MY DREAM?',
                        controller: _dreamCtrl,
                        accentColor: const Color(0xFFEAB308), // Gold/Yellow
                        badgeColor: const Color(0xFFFEF08A),
                      ),
                      _buildPaperPromptBox(
                        letter: 'D',
                        title: 'DESTINATION',
                        question: 'WHAT DID I DO TODAY THAT MOVED ME CLOSER TO MY DESTINATION?',
                        controller: _destinationCtrl,
                        accentColor: const Color(0xFFCA8A04), // Darker Yellow
                        badgeColor: const Color(0xFFFEF08A),
                      ),
                      _buildPaperPromptBox(
                        letter: 'R',
                        title: 'REASON',
                        question: "WHAT REMINDED ME OF THE REASON WHY I'M DOING THIS?",
                        controller: _reasonCtrl,
                        accentColor: const Color(0xFFEC4899), // Pink
                        badgeColor: const Color(0xFFFCE7F3),
                      ),
                      _buildPaperPromptBox(
                        letter: 'E',
                        title: 'ENERGY',
                        question: 'WHAT DID I DO TO CONTRIBUTE TO MY ENERGY TODAY?',
                        controller: _energyCtrl,
                        accentColor: const Color(0xFF06B6D4), // Cyan
                        badgeColor: const Color(0xFFCFFAFE),
                      ),
                      _buildPaperPromptBox(
                        letter: 'A',
                        title: 'AMIGOS',
                        question: 'WHO WERE THE AMIGOS I ASSOCIATED WITH TODAY?',
                        controller: _amigosCtrl,
                        accentColor: const Color(0xFFEAB308), // Gold
                        badgeColor: const Color(0xFFFEF08A),
                      ),
                      _buildPaperPromptBox(
                        letter: 'M',
                        title: 'MINDSET',
                        question: 'WHAT DID I DO TO IMPROVE MY MINDSET TODAY?',
                        controller: _mindsetCtrl,
                        accentColor: const Color(0xFF3B82F6), // Ice Blue
                        badgeColor: const Color(0xFFDBEAFE),
                      ),

                      const SizedBox(height: 8),

                      // Unlimited Media Attachment Section (Photos & Videos)
                      _buildMediaAttachmentSection(),

                      const SizedBox(height: 20),

                      // Save / Update Button inside Paper Page
                      GestureDetector(
                        onTap: _isSaving ? null : _saveEntry,
                        child: Container(
                          width: double.infinity,
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
                            child: _isSaving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: AppColors.cyan,
                                    ),
                                  )
                                : Text(
                                    isEditing ? 'UPDATE JOURNAL ENTRY ✨' : 'SAVE JOURNAL ENTRY ✨',
                                    style: AppColors.soraBold(13).copyWith(
                                      color: Colors.white,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                          ),
                        ),
                      ),
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

  /// Ruled Notebook Paper Prompt Box matching Reference Image
  Widget _buildPaperPromptBox({
    required String letter,
    required String title,
    required String question,
    required TextEditingController controller,
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

              // Transparent TextField sitting perfectly on paper lines
              Material(
                type: MaterialType.transparency,
                child: TextField(
                  controller: controller,
                  maxLines: 3,
                  minLines: 2,
                  style: AppColors.hankenMedium(13).copyWith(
                    color: const Color(0xFF0F172A),
                    height: 1.85, // Aligns text cleanly with 24px notebook lines
                  ),
                  decoration: InputDecoration(
                    hintText: 'Write here...',
                    hintStyle: AppColors.hankenMedium(12).copyWith(
                      color: const Color(0xFF94A3B8),
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.only(top: 2, bottom: 4),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMediaAttachmentSection() {
    final existingMedia = widget.entry?.media.where((m) => !_deleteMediaIds.contains(m.id)).toList() ?? [];
    final totalCount = existingMedia.length + _pickedMediaList.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'UNLIMITED MEDIA ATTACHMENTS',
              style: AppColors.geistBold(11).copyWith(color: const Color(0xFF475569), letterSpacing: 0.8),
            ),
            if (totalCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.cyan.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.cyan.withOpacity(0.3)),
                ),
                child: Text(
                  '$totalCount file${totalCount > 1 ? 's' : ''}',
                  style: AppColors.geistBold(10).copyWith(color: AppColors.cyan),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: _pickMediaFromGallery,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.photo_library_rounded, color: AppColors.cyan, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'Photos & Videos',
                        style: AppColors.geistBold(11).copyWith(color: const Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _recordVideo,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.videocam_rounded, color: Color(0xFFEC4899), size: 18),
                    SizedBox(width: 4),
                    Text('Record', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _takePhoto,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: const Icon(Icons.camera_alt_rounded, color: Color(0xFFEAB308), size: 18),
              ),
            ),
          ],
        ),

        // Display existing DB media items
        if (existingMedia.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: existingMedia.map((m) {
              final isVideo = m.fileType == 'video';
              return Stack(
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.cyan.withOpacity(0.4)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: isVideo
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.play_circle_fill_rounded, color: AppColors.cyan, size: 28),
                              const SizedBox(height: 4),
                              Text('VIDEO', style: AppColors.geistBold(9).copyWith(color: Colors.white)),
                            ],
                          )
                        : Image.network(
                            m.fileUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.image_rounded, color: Colors.white54),
                          ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _deleteMediaIds.add(m.id);
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded, size: 12, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],

        // Display newly picked media items
        if (_pickedMediaList.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _pickedMediaList.asMap().entries.map((entry) {
              final idx = entry.key;
              final item = entry.value;
              return Stack(
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: item.isVideo ? const Color(0xFFEC4899) : AppColors.cyan),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: item.isVideo
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.movie_rounded, color: Color(0xFFEC4899), size: 26),
                              const SizedBox(height: 4),
                              Text('NEW VIDEO', style: AppColors.geistBold(8).copyWith(color: Colors.white)),
                            ],
                          )
                        : Image.memory(
                            Uint8List.fromList(item.bytes),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.image_rounded, color: Colors.white54),
                          ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _pickedMediaList.removeAt(idx);
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded, size: 12, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

/// CustomPainter for Painting Physical Notebook Horizontal Ruled Paper Lines
class NotebookLinesPainter extends CustomPainter {
  final Color lineColor;
  final double lineHeight;

  NotebookLinesPainter({
    required this.lineColor,
    required this.lineHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor.withOpacity(0.55)
      ..strokeWidth = 1.0;

    for (double y = lineHeight; y < size.height; y += lineHeight) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
