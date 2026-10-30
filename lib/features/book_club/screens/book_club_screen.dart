import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dream_community_app/core/theme/app_theme.dart';
import 'package:dream_community_app/core/models/book_club_model.dart';
import 'package:dream_community_app/features/book_club/services/book_club_service.dart';
import 'package:dream_community_app/core/widgets/dream_toast.dart';
import 'package:dream_community_app/features/chat/screens/chat_screen.dart';
import 'package:dream_community_app/features/auth/services/auth_service.dart';
import 'package:dream_community_app/core/models/user_model.dart';
import 'package:dream_community_app/shared/widgets/tier_lock_modal.dart';
import 'package:dream_community_app/core/services/pending_approval_sync_service.dart';
import 'package:dream_community_app/shared/widgets/dream_network_image.dart';
import 'package:dream_community_app/shared/widgets/space_background.dart';

class BookClubScreen extends StatefulWidget {
  final int? initialBookId;
  final VoidCallback? onNavigateHome;

  const BookClubScreen({super.key, this.initialBookId, this.onNavigateHome});

  @override
  State<BookClubScreen> createState() => BookClubScreenState();
}

class BookClubScreenState extends State<BookClubScreen> {
  final BookClubService _service = BookClubService();
  List<BookClubBookModel> _books = [];
  BookClubBookModel? _selectedBook;
  UserModel? _currentUser;
  bool _isLoading = true;
  int _selectedTabIndex = 0;

  void refresh() {
    _loadUserAndBooks();
  }

  final List<Map<String, String>> _pillars = [
    {'letter': 'D', 'pillar': 'Destination', 'month': 'Sep'},
    {'letter': 'R', 'pillar': 'Reason', 'month': 'Oct'},
    {'letter': 'E', 'pillar': 'Energy', 'month': 'Nov'},
    {'letter': 'A', 'pillar': 'Amigos', 'month': 'Dec'},
    {'letter': 'M', 'pillar': 'Mindset', 'month': 'Jan'},
  ];

  @override
  void initState() {
    super.initState();
    PendingApprovalSyncService.instance.onAccessUnlocked.addListener(_onLiveUnlocked);
    _loadUserAndBooks();
  }

  void _onLiveUnlocked() {
    if (PendingApprovalSyncService.instance.onAccessUnlocked.value && mounted) {
      _loadUserAndBooks();
    }
  }

  @override
  void dispose() {
    PendingApprovalSyncService.instance.onAccessUnlocked.removeListener(_onLiveUnlocked);
    super.dispose();
  }

  bool get _hasAccess {
    if (_currentUser == null) return true;
    final tier = (_currentUser?.tier ?? '').toLowerCase().trim();
    final isPurchasedTier = tier.isNotEmpty && tier != 'free' && tier != 'guest';
    final isNonJournalTier = isPurchasedTier && tier != 'journal';
    return _currentUser!.hasBookClubAccess ||
        _currentUser!.hasCommunityAccess ||
        _currentUser!.hasAdminAccess ||
        isNonJournalTier ||
        tier == 'community';
  }

  Future<void> _loadUserAndBooks() async {
    AuthService().getCurrentUser().then((user) {
      if (mounted && user != null) {
        setState(() => _currentUser = user);
      }
    });
    _loadBooks();
  }

  static final List<BookClubBookModel> _defaultBooks = [
    BookClubBookModel(
      id: 1,
      month: 'September',
      letter: 'D',
      pillar: 'Destination',
      title: 'The Compound Effect',
      subtitle: 'Jumpstart Your Income, Your Life, Your Success',
      author: 'Darren Hardy',
      duration: '5h 59m',
      rating: 4.8,
      coverImage: 'assets/images/books/compound_effect.jpg',
      summary: 'No gimmicks. No hyperbole. No magic bullet. The Compound Effect is based on the principle that decisions shape your destiny. Little, everyday decisions will either take you to the life you desire or to disaster by default. This powerful guide reveals the core principles that drive success in business, relationships, and beyond.',
    ),
    BookClubBookModel(
      id: 2,
      month: 'October',
      letter: 'R',
      pillar: 'Reason',
      title: 'Start with Why',
      subtitle: 'How Great Leaders Inspire Everyone to Take Action',
      author: 'Simon Sinek',
      duration: '7h 18m',
      rating: 4.7,
      coverImage: 'assets/images/books/start_with_why.jpg',
      summary: 'The inspirational bestseller that ignited a movement and asked us to find our why. Discover the book that has captivated millions on TikTok and inspired changemakers worldwide to build businesses, lead teams, and live lives fueled by genuine purpose.',
    ),
    BookClubBookModel(
      id: 3,
      month: 'November',
      letter: 'E',
      pillar: 'Energy',
      title: 'The TB12 Method',
      subtitle: 'How to Achieve a Lifetime of Sustained Peak Performance',
      author: 'Tom Brady',
      duration: '6h 55m',
      rating: 4.2,
      coverImage: 'assets/images/books/tb12_method.jpg',
      summary: 'Seven-time Super Bowl champion Tom Brady shares his revolutionary approach to sustained peak athletic performance, pliability training, nutrition, hydration, and mental fitness. A comprehensive blueprint for vitality and sustained energy.',
    ),
    BookClubBookModel(
      id: 4,
      month: 'December',
      letter: 'A',
      pillar: 'Amigos',
      title: 'Who Not How',
      subtitle: 'The Formula to Achieve Bigger Goals Through Accelerating Teamwork',
      author: 'Dan Sullivan and Dr. Benjamin Hardy',
      duration: '5h 24m',
      rating: 4.8,
      coverImage: 'assets/images/books/who_not_how.jpg',
      summary: 'The formula to achieve bigger goals through accelerating teamwork and collaboration. Stop asking "How can I do this?" and start asking "Who can help me achieve this?" Transform your network and unlock exponential growth.',
    ),
    BookClubBookModel(
      id: 5,
      month: 'January',
      letter: 'M',
      pillar: 'Mindset',
      title: 'The 7 Habits of Highly Effective People',
      subtitle: 'Powerful Lessons in Personal Change',
      author: 'Stephen R. Covey',
      duration: '13h 4m',
      rating: 4.8,
      coverImage: 'assets/images/books/seven_habits.jpg',
      summary: 'One of the most inspiring and impactful books ever written. Stephen Covey presents a holistic, integrated, principle-centered approach for solving personal and professional problems with profound insights and practical wisdom.',
    ),
  ];

  Future<void> _loadBooks({bool showLoading = false}) async {
    if (showLoading) setState(() => _isLoading = true);
    final list = await _service.getBooks();
    if (mounted) {
      setState(() {
        _books = list.isNotEmpty ? list : _defaultBooks;
        _isLoading = false;
        if (_books.isNotEmpty) {
          final targetId = _selectedBook?.id ?? widget.initialBookId;
          final found = targetId != null
              ? _books.firstWhere((b) => b.id == targetId, orElse: () => _books.first)
              : _books.first;
          _selectedBook = found;
          final idx = _pillars.indexWhere((p) => p['letter'] == found.letter);
          if (idx >= 0) _selectedTabIndex = idx;
        }
      });
    }
  }

  void _onSelectPillar(int index) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedTabIndex = index;
      final targetLetter = _pillars[index]['letter'];
      final book = _books.firstWhere(
        (b) => b.letter.toUpperCase() == targetLetter,
        orElse: () => _defaultBooks.firstWhere(
          (d) => d.letter.toUpperCase() == targetLetter,
          orElse: () => _books.first,
        ),
      );
      _selectedBook = book;
    });
  }

  Future<void> _launchUrl(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _openChatWithBook(BookClubBookModel book) {
    if (!_hasAccess) {
      TierLockModal.show(context, featureName: 'D.R.E.A.M. Book Club Chat');
      return;
    }
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          initialBookId: book.id,
          initialPillar: book.letter,
        ),
      ),
    );
  }


  String? _getLocalCoverAsset(String? title, String? letter) {
    final t = (title ?? '').toLowerCase();
    final l = (letter ?? '').toUpperCase();
    if (t.contains('compound') || l == 'D') return 'assets/images/books/compound_effect.jpg';
    if (t.contains('why') || l == 'R') return 'assets/images/books/start_with_why.jpg';
    if (t.contains('tb12') || t.contains('brady') || l == 'E') return 'assets/images/books/tb12_method.jpg';
    if (t.contains('who not how') || l == 'A') return 'assets/images/books/who_not_how.jpg';
    if (t.contains('7 habits') || t.contains('seven') || l == 'M') return 'assets/images/books/seven_habits.jpg';
    return null;
  }

  void _showAddNoteModal() {
    if (!_hasAccess) {
      TierLockModal.show(context, featureName: 'D.R.E.A.M. Book Club Notes');
      return;
    }
    if (_selectedBook == null) return;
    HapticFeedback.selectionClick();
    final textController = TextEditingController();
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
          decoration: BoxDecoration(
            color: const Color(0xFF0C1626),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Add Reading Note',
                    style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Note for: ${_selectedBook!.title}',
                style: AppColors.geistMedium(12).copyWith(color: AppColors.cyan),
              ),
              const SizedBox(height: 14),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF050C16),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: TextField(
                  controller: textController,
                  maxLines: 4,
                  style: AppColors.geistMedium(13.5).copyWith(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Share a key insight, quote, or personal reflection...',
                    hintStyle: AppColors.geistMedium(12).copyWith(color: AppColors.textMuted),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(14),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              GestureDetector(
                onTap: isSaving
                    ? null
                    : () async {
                        final content = textController.text.trim();
                        if (content.isEmpty) return;
                        setModalState(() => isSaving = true);
                        final note = await _service.saveNote(_selectedBook!.id, content);
                        if (context.mounted) {
                          Navigator.pop(context);
                          if (note != null) {
                            DreamToast.success(context, 'Note saved successfully!');
                            if (_selectedBook != null) {
                              setState(() {
                                final currentNotes = _selectedBook!.userNotes.where((item) => item.id != note.id).toList();
                                _selectedBook = _selectedBook!.copyWith(userNotes: [note, ...currentNotes]);
                              });
                            }
                            _loadBooks();
                          } else {
                            DreamToast.error(context, 'Failed to save note');
                          }
                        }
                      },
                child: Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.cyan,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.cyan.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF050C16)),
                          )
                        : Text(
                            'SAVE NOTE',
                            style: GoogleFonts.sora(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF050C16), letterSpacing: 1.2),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF05101E),
      body: SpaceBackground(
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.cyan))
              : CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    // Minimalist Header Bar
                    SliverToBoxAdapter(
                      child: _buildHeader(context),
                    ),

                    // Clean 5-Pillar Segmented Ribbon
                    SliverToBoxAdapter(
                      child: _buildPillarRibbon(),
                    ),

                    // Main Book Showcase & Content
                    if (_selectedBook != null) ...[
                      // Hero Book Card (Minimalist, Real Cover, Clean Meta & Actions)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
                          child: _buildBookHeroCard(_selectedBook!),
                        ),
                      ),

                      // Book Summary Card (Resilient fallback to official book overview)
                      () {
                        final summary = (_selectedBook!.summary != null && _selectedBook!.summary!.trim().isNotEmpty)
                            ? _selectedBook!.summary
                            : _defaultBooks.firstWhere(
                                (d) => d.letter.toUpperCase() == _selectedBook!.letter.toUpperCase(),
                                orElse: () => _selectedBook!,
                              ).summary;

                        if (summary == null || summary.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

                        return SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                            child: _buildSummaryCard(_selectedBook!, resolvedSummary: summary),
                          ),
                        );
                      }(),

                      // Personal Reading Notes Section
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
                          child: _buildNotesSection(_selectedBook!),
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }

  // ── Header Bar ──
  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  if (widget.onNavigateHome != null) {
                    widget.onNavigateHome!();
                  } else if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  } else {
                    Navigator.pushReplacementNamed(context, '/home');
                  }
                },
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 15),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'D.R.E.A.M. Book Club',
                style: GoogleFonts.sora(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),

          // Community Chat Action Chip
          GestureDetector(
            onTap: () {
              if (_selectedBook != null) {
                _openChatWithBook(_selectedBook!);
              } else {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatScreen()));
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.cyan.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.cyan.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.cyan, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    'Chat',
                    style: GoogleFonts.sora(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.cyan),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 5-Pillar Segmented Ribbon (Minimalist, Compact, No Heavy Cards) ──
  Widget _buildPillarRibbon() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      height: 42,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _pillars.length,
        itemBuilder: (context, index) {
          final p = _pillars[index];
          final isSelected = _selectedTabIndex == index;

          return GestureDetector(
            onTap: () => _onSelectPillar(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.cyan : Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? AppColors.cyan : Colors.white.withValues(alpha: 0.08),
                  width: 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.cyan.withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    p['letter']!,
                    style: GoogleFonts.sora(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? const Color(0xFF051424) : AppColors.cyan,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    p['pillar']!,
                    style: GoogleFonts.sora(
                      fontSize: 11.5,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? const Color(0xFF051424) : Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '• ${p['month']}',
                    style: AppColors.geistMedium(10).copyWith(
                      color: isSelected ? const Color(0xFF051424).withValues(alpha: 0.7) : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Book Hero Card (Real 3D Cover, Crisp Typography, Clean Actions) ──
  Widget _buildBookHeroCard(BookClubBookModel book) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1626),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row: Book Cover + Details
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 3D Realistic Book Cover
              _buildBookCover(book),

              const SizedBox(width: 16),

              // Book Meta & Titles
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Pillar Tag
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.cyan.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${book.letter} · ${book.pillar.toUpperCase()}',
                        style: GoogleFonts.sora(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppColors.cyan, letterSpacing: 0.8),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Book Title
                    Text(
                      book.title,
                      style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, height: 1.25),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 4),

                    // Author
                    Text(
                      'By ${book.author}',
                      style: AppColors.geistBold(12).copyWith(color: AppColors.cyan),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    if (book.subtitle != null && book.subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        book.subtitle!,
                        style: AppColors.geistMedium(10.5).copyWith(color: AppColors.textMuted, height: 1.3),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    const SizedBox(height: 10),

                    // Meta Row: Rating & Duration
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, color: Color(0xFFFFD700), size: 14),
                        const SizedBox(width: 3),
                        Text(
                          book.rating.toStringAsFixed(1),
                          style: GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        if (book.duration != null && book.duration!.isNotEmpty) ...[
                          const SizedBox(width: 10),
                          const Icon(Icons.headphones_rounded, color: AppColors.cyan, size: 13),
                          const SizedBox(width: 4),
                          Text(
                            book.duration!,
                            style: AppColors.geistMedium(11).copyWith(color: AppColors.cyan),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Primary Dominant Action: Discuss in Chat
          GestureDetector(
            onTap: () => _openChatWithBook(book),
            child: Container(
              width: double.infinity,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.cyan,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.cyan.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.forum_rounded, color: Color(0xFF051424), size: 17),
                  const SizedBox(width: 8),
                  Text(
                    'DISCUSS IN COMMUNITY CHAT',
                    style: GoogleFonts.sora(fontSize: 11.5, fontWeight: FontWeight.bold, color: const Color(0xFF051424), letterSpacing: 0.8),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Secondary Action: Buy/Listen Audiobook if available
          if ((book.audibleUrl ?? book.purchaseUrl) != null && (book.audibleUrl ?? book.purchaseUrl)!.isNotEmpty) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => _launchUrl(book.audibleUrl ?? book.purchaseUrl),
              child: Container(
                width: double.infinity,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFF9900).withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.menu_book_rounded, color: Color(0xFFFF9900), size: 15),
                    const SizedBox(width: 6),
                    Text(
                      'Get book',
                      style: GoogleFonts.sora(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                    const SizedBox(width: 5),
                    const Icon(Icons.open_in_new_rounded, color: Color(0xFFFF9900), size: 12),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── 3D Realistic Book Cover ──
  Widget _buildBookCover(BookClubBookModel book) {
    final localAsset = _getLocalCoverAsset(book.title, book.letter);
    final coverUrl = book.coverImage;

    return Container(
      width: 104,
      height: 154,
      decoration: BoxDecoration(
        color: const Color(0xFF0C1626),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: AppColors.cyan.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: (coverUrl != null && coverUrl.isNotEmpty)
          ? DreamNetworkImage(
              imageUrl: coverUrl,
              fit: BoxFit.cover,
              width: 104,
              height: 154,
              placeholder: (_) => (localAsset != null)
                  ? Image.asset(localAsset, fit: BoxFit.cover)
                  : _defaultBookCover(book.letter),
            )
          : (localAsset != null)
              ? Image.asset(localAsset, fit: BoxFit.cover)
              : _defaultBookCover(book.letter),
    );
  }

  Widget _defaultBookCover(String letter) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0A1E33), Color(0xFF05101E)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.menu_book_rounded, color: AppColors.cyan, size: 28),
            const SizedBox(height: 6),
            Text(
              letter,
              style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  // ── Book Summary Card ──
  Widget _buildSummaryCard(BookClubBookModel book, {String? resolvedSummary}) {
    final text = (resolvedSummary != null && resolvedSummary.isNotEmpty)
        ? resolvedSummary
        : (book.summary ?? '');

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1626),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.menu_book_rounded, color: AppColors.cyan, size: 16),
              const SizedBox(width: 8),
              Text(
                'Overview & Core Principles',
                style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            text,
            style: AppColors.geistMedium(13).copyWith(
              color: Colors.white.withValues(alpha: 0.76),
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }

  // ── Personal Reading Notes Section ──
  Widget _buildNotesSection(BookClubBookModel book) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1626),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.edit_note_rounded, color: AppColors.cyan, size: 19),
                  const SizedBox(width: 8),
                  Text(
                    'My Reading Notes',
                    style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
              GestureDetector(
                onTap: _showAddNoteModal,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.cyan.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.cyan.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.add_rounded, color: AppColors.cyan, size: 13),
                      const SizedBox(width: 4),
                      Text(
                        'Add Note',
                        style: GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.cyan),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (book.userNotes.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
              ),
              child: Column(
                children: [
                  Icon(Icons.notes_rounded, color: Colors.white.withValues(alpha: 0.25), size: 24),
                  const SizedBox(height: 6),
                  Text(
                    'No notes recorded yet.\nTap "+ Add Note" to capture key insights and quotes.',
                    textAlign: TextAlign.center,
                    style: AppColors.geistMedium(11.5).copyWith(color: AppColors.textMuted, height: 1.4),
                  ),
                ],
              ),
            )
          else
            ...book.userNotes.map(
              (n) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        n.content,
                        style: AppColors.geistMedium(12.5).copyWith(color: Colors.white, height: 1.4),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFFF5252), size: 16),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () async {
                        final noteId = n.id;
                        final ok = await _service.deleteNote(book.id, noteId);
                        if (ok && mounted && context.mounted) {
                          DreamToast.success(context, 'Note removed');
                          if (_selectedBook != null) {
                            setState(() {
                              final updated = _selectedBook!.userNotes.where((item) => item.id != noteId).toList();
                              _selectedBook = _selectedBook!.copyWith(userNotes: updated);
                            });
                          }
                          _loadBooks();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
