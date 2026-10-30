import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:dream_community_app/core/theme/app_theme.dart';
import 'package:dream_community_app/core/models/journal_entry_model.dart';
import 'package:dream_community_app/features/journal/services/journal_entry_service.dart';
import 'package:dream_community_app/features/journal/screens/journal_entry_form_modal.dart';
import 'package:dream_community_app/features/journal/screens/journal_entry_detail_modal.dart';
import 'package:dream_community_app/features/journal/widgets/journal_paywall_modal.dart';
import 'package:dream_community_app/core/widgets/dream_toast.dart';
import 'package:dream_community_app/shared/widgets/skeleton.dart';

import 'package:dream_community_app/features/journal/screens/journal_checkout_screen.dart';
import 'package:dream_community_app/features/community_tier/services/tier_service.dart';
import 'package:dream_community_app/features/auth/services/auth_service.dart';
import 'package:dream_community_app/features/journal/widgets/dream_journal_fullscreen_cover.dart';
import 'package:dream_community_app/features/home/screens/community_hub_screen.dart';
import 'package:dream_community_app/core/services/pending_approval_sync_service.dart';

class JournalScreen extends StatefulWidget {
  final VoidCallback? onToggleCover;
  final VoidCallback? onNavigateCommunity;
  final VoidCallback? onNavigateHome;
  final ValueChanged<bool>? onCoverAnimationChanged;
  final VoidCallback? onJournalUnlocked;

  const JournalScreen({
    super.key,
    this.onToggleCover,
    this.onNavigateCommunity,
    this.onNavigateHome,
    this.onCoverAnimationChanged,
    this.onJournalUnlocked,
  });

  @override
  State<JournalScreen> createState() => JournalScreenState();
}

class JournalScreenState extends State<JournalScreen> with TickerProviderStateMixin {
  bool _isLoading = true;
  bool _hasAccess = true;
  bool _showCoverAnimation = true;
  double? _journalPrice;
  List<JournalEntryModel> _entries = [];
  String _activeFilterTab = 'all';
  String _selectedPillar = 'ALL';
  String _userName = 'Joshua';

  void showCover() {
    if (_hasAccess && mounted) {
      setState(() => _showCoverAnimation = true);
      widget.onCoverAnimationChanged?.call(true);
    }
  }

  Future<void> refresh() async {
    await _checkAccessAndLoad();
  }

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.onCoverAnimationChanged?.call(_showCoverAnimation);
      }
    });
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _checkAccessAndLoad();
    PendingApprovalSyncService.instance.onAccessUnlocked.addListener(_onLiveAccessUnlocked);
  }

  void _onLiveAccessUnlocked() {
    if (PendingApprovalSyncService.instance.onAccessUnlocked.value && mounted) {
      _checkAccessAndLoad();
      widget.onJournalUnlocked?.call();
    }
  }

  @override
  void dispose() {
    PendingApprovalSyncService.instance.onAccessUnlocked.removeListener(_onLiveAccessUnlocked);
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _checkAccessAndLoad() async {
    final info = await TierService().getJournalInfo();
    if (info != null && info['price'] != null && mounted) {
      setState(() {
        _journalPrice = (info['price'] as num).toDouble();
      });
    }

    final hasAccess = await _checkHasJournalAccess();
    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataStr = prefs.getString('user_data');
      if (userDataStr != null) {
        final map = jsonDecode(userDataStr);
        final name = (map['name'] ?? '').toString().trim();
        if (name.isNotEmpty && mounted) {
          setState(() => _userName = name.split(' ').first);
        }
      }
    } catch (_) {}

    if (!hasAccess) {
      if (mounted) {
        setState(() {
          _hasAccess = false;
          _isLoading = false;
        });
      }
      return;
    }

    _loadEntries();
  }

  Future<void> _loadEntries() async {
    final data = await JournalEntryService().getEntries();
    if (mounted) {
      setState(() {
        _entries = data;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleFavorite(JournalEntryModel entry) async {
    final oldFavorite = entry.isFavorite;
    final newFavorite = !oldFavorite;

    setState(() {
      final idx = _entries.indexWhere((e) => e.id == entry.id);
      if (idx != -1) {
        _entries[idx] = entry.copyWith(isFavorite: newFavorite);
      }
    });

    DreamToast.success(
      context,
      newFavorite ? 'Added to favorites ⭐' : 'Removed from favorites',
    );

    final success = await JournalEntryService().toggleFavorite(entry.id);
    if (!success && mounted) {
      setState(() {
        final idx = _entries.indexWhere((e) => e.id == entry.id);
        if (idx != -1) {
          _entries[idx] = entry.copyWith(isFavorite: oldFavorite);
        }
      });
      DreamToast.error(context, 'Failed to update favorite status');
    }
  }

  List<JournalEntryModel> get _filteredEntries {
    var list = _entries;
    if (_activeFilterTab == 'favorites') {
      list = list.where((e) => e.isFavorite == true).toList();
    }
    if (_selectedPillar == 'ALL') return list;
    return list.where((e) {
      switch (_selectedPillar) {
        case 'D':
          return (e.dream != null && e.dream!.isNotEmpty) ||
                 (e.destination != null && e.destination!.isNotEmpty);
        case 'R':
          return e.reason != null && e.reason!.isNotEmpty;
        case 'E':
          return e.energy != null && e.energy!.isNotEmpty;
        case 'A':
          return e.amigos != null && e.amigos!.isNotEmpty;
        case 'M':
          return e.mindset != null && e.mindset!.isNotEmpty;
        default:
          return true;
      }
    }).toList();
  }

  Future<bool> _checkHasJournalAccess() async {
    // Local pref fallback — set immediately after purchase
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('has_journal_access') == true) return true;

    // Check cached user_data
    final userDataStr = prefs.getString('user_data');
    if (userDataStr != null) {
      final map = jsonDecode(userDataStr);
      if (map['has_journal_access'] == true || map['hasJournalAccess'] == true) {
        return true;
      }
    }

    // Authoritative server check
    try {
      final user = await AuthService().getCurrentUser();
      if (user != null && user.hasJournalAccess) return true;
    } catch (_) {}

    return false;
  }

  void _openNewEntryModal() async {
    final hasAccess = await _checkHasJournalAccess();
    if (!hasAccess) {
      if (mounted) {
        JournalPaywallModal.show(context, onUnlocked: () {
          _openNewEntryModal();
        });
      }
      return;
    }

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => JournalEntryFormModal(
        onSaved: () => _loadEntries(),
      ),
    );
  }

  void _openEditEntryModal(JournalEntryModel entry) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => JournalEntryFormModal(
        onSaved: () => _loadEntries(),
        entry: entry,
      ),
    );
  }

  void _confirmDelete(int entryId) {
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: const Color(0xFF071829),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.pink.withOpacity(0.4)),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.pink.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_outline_rounded, color: AppColors.pink, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Delete Entry?', style: AppColors.soraBold(16).copyWith(color: Colors.white)),
            ),
          ],
        ),
        content: Text(
          'This action cannot be undone. The entry and all attachments will be permanently removed.',
          style: AppColors.geistMedium(13).copyWith(color: AppColors.textMuted),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: Text('Cancel', style: AppColors.geistMedium(13).copyWith(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dCtx);
              final success = await JournalEntryService().deleteEntry(entryId);
              if (success && mounted) {
                DreamToast.success(context, 'Entry deleted');
                _loadEntries();
              } else if (mounted) {
                DreamToast.error(context, 'Failed to delete entry');
              }
            },
            child: Text('Delete', style: AppColors.geistBold(13).copyWith(color: AppColors.pink)),
          ),
        ],
      ),
    );
  }

  void _showEntryDetail(JournalEntryModel entry) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => JournalEntryDetailModal(
        entry: entry,
        onEdit: () => _openEditEntryModal(entry),
        onDelete: () => _confirmDelete(entry.id),
      ),
    );
  }

  Widget _buildPerkCard(IconData icon, String title, String subtitle, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1524),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.35)),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.08), blurRadius: 10),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppColors.soraBold(13).copyWith(color: Colors.white),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: AppColors.geistMedium(11).copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasAccess) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 36, 20, 12),
                  child: Column(
                    children: [
                      const SizedBox(height: 24),
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _pulseAnimation.value,
                            child: Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: AppColors.cyan.withOpacity(0.12),
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.cyan.withOpacity(0.45), width: 1.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.cyan.withOpacity(0.3 * _pulseAnimation.value),
                                    blurRadius: 22 * _pulseAnimation.value,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.menu_book_rounded, color: AppColors.cyan, size: 34),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'D.R.E.A.M. JOURNAL',
                        style: AppColors.soraBold(24).copyWith(color: Colors.white, letterSpacing: 1.2),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Unlock your private space to document dreams, track growth, and reflect daily.',
                        style: AppColors.geistMedium(12).copyWith(color: AppColors.textMuted.withOpacity(0.85), height: 1.4),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      _buildPerkCard(
                        Icons.auto_awesome_rounded,
                        'Daily Guided Reflection',
                        'Thoughtful prompts to help you focus on your vision, goals, and mindset',
                        AppColors.cyan,
                      ),
                      _buildPerkCard(
                        Icons.perm_media_rounded,
                        'Photo & Video Attachments',
                        'Attach visual memories, progress photos, and video clips to each entry',
                        AppColors.pink,
                      ),
                      _buildPerkCard(
                        Icons.lock_outline_rounded,
                        '100% Private & Personal Space',
                        'Your entries, thoughts, and media are completely confidential to you',
                        const Color(0xFFFFB800),
                      ),
                      _buildPerkCard(
                        Icons.all_inclusive_rounded,
                        'Unlimited Lifetime Reflections',
                        'One-time purchase with permanent access, unlimited entries & no monthly fees',
                        const Color(0xFF00E5FF),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () async {
                          final unlocked = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => JournalCheckoutScreen(
                                onUnlocked: () {
                                  if (mounted) {
                                    setState(() => _hasAccess = true);
                                    _loadEntries();
                                  }
                                  widget.onJournalUnlocked?.call();
                                },
                              ),
                            ),
                          );

                          if (unlocked == true && mounted) {
                            setState(() => _hasAccess = true);
                            _loadEntries();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.cyan,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 4,
                        ),
                        child: Text(
                          _journalPrice == null ? 'CLAIM LIFETIME ACCESS' : 'CLAIM LIFETIME ACCESS (\$${_journalPrice!.toStringAsFixed(2)})',
                          style: AppColors.soraBold(13).copyWith(letterSpacing: 1.1),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () {
                        if (widget.onNavigateHome != null) {
                          widget.onNavigateHome!();
                        } else if (widget.onNavigateCommunity != null) {
                          widget.onNavigateCommunity!();
                        } else {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => const CommunityHubScreen(initialIndex: 0)),
                          );
                        }
                      },
                      child: Text(
                        'Maybe later',
                        style: AppColors.geistMedium(13).copyWith(
                          color: Colors.white54,
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.white54,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final filtered = _filteredEntries;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColors.background,
          floatingActionButton: Padding(
            padding: const EdgeInsets.only(bottom: 70),
            child: FloatingActionButton(
              heroTag: 'journal_fab',
              onPressed: _openNewEntryModal,
              backgroundColor: AppColors.cyan,
              elevation: 6,
              shape: const CircleBorder(),
              child: const Icon(Icons.add_rounded, color: AppColors.background, size: 28),
            ),
          ),
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: _loadEntries,
              color: AppColors.cyan,
              backgroundColor: AppColors.surface,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'D.R.E.A.M. JOURNAL',
                                  style: AppColors.soraBold(22).copyWith(
                                    color: AppColors.cyan,
                                    letterSpacing: 1.2,
                                    shadows: [
                                      Shadow(color: AppColors.cyan.withOpacity(0.4), blurRadius: 14),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${filtered.length} ${filtered.length == 1 ? 'entry' : 'entries'} logged',
                                style: AppColors.hankenMedium(11).copyWith(color: Colors.white.withOpacity(0.4)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        _filterChip('ALL', 'ALL', Colors.white),
                        const SizedBox(width: 8),
                        _filterChip('D', 'D', const Color(0xFF00DBE9)),
                        const SizedBox(width: 8),
                        _filterChip('R', 'R', const Color(0xFFFFABF0)),
                        const SizedBox(width: 8),
                        _filterChip('E', 'E', const Color(0xFF38BDF8)),
                        const SizedBox(width: 8),
                        _filterChip('A', 'A', const Color(0xFFFACC15)),
                        const SizedBox(width: 8),
                        _filterChip('M', 'M', const Color(0xFF4ADE80)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _isLoading
                        ? _buildSkeleton()
                        : filtered.isEmpty
                            ? _buildEmptyState()
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                                itemCount: filtered.length,
                                itemBuilder: (context, index) {
                                  final entry = filtered[index];
                                  return _websiteStyleEntryCard(entry);
                                },
                              ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_showCoverAnimation)
          Positioned.fill(
            child: DreamJournalFullScreenCover(
              userName: _userName,
              totalEntries: _entries.length,
              onOpenComplete: () {
                if (mounted) {
                  setState(() => _showCoverAnimation = false);
                  widget.onCoverAnimationChanged?.call(false);
                }
              },
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.menu_book_rounded, size: 48, color: Colors.white.withOpacity(0.15)),
          const SizedBox(height: 12),
          Text('No entries yet', style: AppColors.geistMedium(14).copyWith(color: Colors.white38)),
          const SizedBox(height: 4),
          Text('Tap + to create your first entry', style: AppColors.geistMedium(12).copyWith(color: Colors.white24)),
        ],
      ),
    );
  }

  Widget _filterChip(String value, String label, Color accentColor) {
    final isSelected = _selectedPillar == value;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedPillar = value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? accentColor.withOpacity(0.2) : AppColors.surface.withOpacity(0.4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? accentColor : Colors.white.withOpacity(0.08),
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(color: accentColor.withOpacity(0.25), blurRadius: 10),
                ]
              : [],
        ),
        child: Center(
          child: Text(
            label,
            style: AppColors.geistBold(11).copyWith(
              color: isSelected ? accentColor : Colors.white.withOpacity(0.6),
            ),
          ),
        ),
      ),
    );
  }

  Widget _websiteStyleEntryCard(JournalEntryModel entry) {
    final parsedDate = DateTime.tryParse(entry.entryDate);
    final monthStr = _getMonthName(parsedDate?.month);
    final dayStr = parsedDate?.day.toString() ?? '';
    final yearStr = parsedDate?.year.toString() ?? '';

    final hasD = (entry.dream != null && entry.dream!.isNotEmpty) ||
                 (entry.destination != null && entry.destination!.isNotEmpty);
    final hasR = entry.reason != null && entry.reason!.isNotEmpty;
    final hasE = entry.energy != null && entry.energy!.isNotEmpty;
    final hasA = entry.amigos != null && entry.amigos!.isNotEmpty;
    final hasM = entry.mindset != null && entry.mindset!.isNotEmpty;

    final firstImage = entry.media.isNotEmpty ? entry.media.first : null;
    final isFavorite = entry.isFavorite;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showEntryDetail(entry),
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isFavorite
                  ? const Color(0xFFFBBF24).withOpacity(0.04)
                  : const Color(0xFF0C1524).withOpacity(0.7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isFavorite
                    ? const Color(0xFFFBBF24).withOpacity(0.3)
                    : Colors.white.withOpacity(0.08),
                width: isFavorite ? 1.2 : 1.0,
              ),
            ),
            child: Row(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _toggleFavorite(entry),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isFavorite
                          ? const Color(0xFFFBBF24).withOpacity(0.15)
                          : Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isFavorite
                            ? const Color(0xFFFBBF24).withOpacity(0.35)
                            : Colors.white.withOpacity(0.04),
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: isFavorite ? const Color(0xFFFBBF24) : Colors.white24,
                        size: 20,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 48,
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        monthStr,
                        style: AppColors.geistBold(10).copyWith(
                          color: AppColors.cyan.withOpacity(0.7),
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dayStr,
                        style: AppColors.soraBold(20).copyWith(
                          color: Colors.white,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        yearStr,
                        style: AppColors.geistMedium(9).copyWith(
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              entry.displayTitle,
                              style: AppColors.hankenMedium(13).copyWith(
                                color: Colors.white.withOpacity(0.85),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isFavorite) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFBBF24).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xFFFBBF24).withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                '★ Favorite',
                                style: AppColors.geistBold(9).copyWith(
                                  color: const Color(0xFFFBBF24),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (hasD) _badgeLetter('D', const Color(0xFF00DBE9)),
                          if (hasR) _badgeLetter('R', const Color(0xFFFFABF0)),
                          if (hasE) _badgeLetter('E', const Color(0xFF38BDF8)),
                          if (hasA) _badgeLetter('A', const Color(0xFFFACC15)),
                          if (hasM) _badgeLetter('M', const Color(0xFF4ADE80)),
                        ],
                      ),
                    ],
                  ),
                ),
                if (firstImage != null) ...[
                  const SizedBox(width: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      firstImage.fileUrl,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white.withOpacity(0.2),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: 4,
      itemBuilder: (_, __) => const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: SkeletonFeaturedCard(),
      ),
    );
  }

  Widget _badgeLetter(String letter, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Center(
        child: Text(
          letter,
          style: AppColors.geistBold(10).copyWith(color: color),
        ),
      ),
    );
  }

  String _getMonthName(int? month) {
    switch (month) {
      case 1: return 'JAN';
      case 2: return 'FEB';
      case 3: return 'MAR';
      case 4: return 'APR';
      case 5: return 'MAY';
      case 6: return 'JUN';
      case 7: return 'JUL';
      case 8: return 'AUG';
      case 9: return 'SEP';
      case 10: return 'OCT';
      case 11: return 'NOV';
      case 12: return 'DEC';
      default: return 'JOURNAL';
    }
  }
}
