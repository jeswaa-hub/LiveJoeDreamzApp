import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dream_community_app/core/theme/app_theme.dart';
import 'package:dream_community_app/core/models/event_model.dart';
import 'package:dream_community_app/features/events/services/event_service.dart';
import 'package:dream_community_app/shared/widgets/skeleton.dart';
import 'package:dream_community_app/shared/widgets/app_toast.dart';
import 'package:dream_community_app/features/profile/services/notification_service.dart';
import 'package:dream_community_app/core/services/pending_approval_sync_service.dart';

class EventsScreen extends StatefulWidget {
  final int? initialEventId;
  const EventsScreen({super.key, this.initialEventId});

  /// Global notifier tracking the single active event triggered by a notification tap
  static final ValueNotifier<int?> globalHighlightedEventId = ValueNotifier<int?>(null);

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> with SingleTickerProviderStateMixin {
  AnimationController? _borderAnimController;
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _cardKeys = {};
  int? _highlightedEventId;
  bool _isLoading = true;
  List<EventModel> _events = [];
  String _searchQuery = '';
  String _filter = 'upcoming'; // Default is 'upcoming' as requested: 'upcoming', 'all', 'virtual', 'in-person', 'ongoing'

  AnimationController get _effectiveBorderController {
    _borderAnimController ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
    return _borderAnimController!;
  }

  @override
  void initState() {
    super.initState();
    _highlightedEventId = widget.initialEventId;
    EventsScreen.globalHighlightedEventId.value = widget.initialEventId;
    EventsScreen.globalHighlightedEventId.addListener(_onGlobalHighlightChanged);
    _borderAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
    _loadData();
  }

  void _markEventNotificationsAsRead(int? eventId) {
    NotificationService().markEventAsRead(eventId: eventId).then((success) {
      if (success) {
        PendingApprovalSyncService.instance.decrementUnread();
        PendingApprovalSyncService.instance.syncNow();
      }
    });
  }

  void _onGlobalHighlightChanged() {
    if (!mounted) return;
    final newId = EventsScreen.globalHighlightedEventId.value;
    if (newId != _highlightedEventId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _highlightedEventId = newId;
          });
          if (newId != null) {
            _markEventNotificationsAsRead(newId);
            _scrollToHighlightedCard();
          }
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant EventsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialEventId != oldWidget.initialEventId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _highlightedEventId = widget.initialEventId;
          });
          if (_highlightedEventId != null) {
            _markEventNotificationsAsRead(_highlightedEventId);
            _scrollToHighlightedCard();
          }
        }
      });
    }
  }

  @override
  void dispose() {
    EventsScreen.globalHighlightedEventId.removeListener(_onGlobalHighlightChanged);
    final currentId = _highlightedEventId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (EventsScreen.globalHighlightedEventId.value == currentId) {
        EventsScreen.globalHighlightedEventId.value = null;
      }
    });
    _borderAnimController?.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final data = await EventService().getEvents();
    if (mounted) {
      bool shouldShowAll = false;
      if (_highlightedEventId != null) {
        final match = data.where((e) => e.id == _highlightedEventId).toList();
        if (match.isNotEmpty && match.first.status.toLowerCase() != 'upcoming') {
          shouldShowAll = true;
        }
      }

      setState(() {
        _events = data;
        _isLoading = false;
        if (shouldShowAll) {
          _filter = 'all';
        }
      });

      // Auto-mark notification(s) as read since the event is now viewed on screen
      _markEventNotificationsAsRead(_highlightedEventId);

      if (_highlightedEventId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToHighlightedCard();
        });
      }
    }
  }

  void _scrollToHighlightedCard() {
    if (_highlightedEventId == null) return;
    final targetKey = _cardKeys[_highlightedEventId];
    if (targetKey != null && targetKey.currentContext != null) {
      Scrollable.ensureVisible(
        targetKey.currentContext!,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeInOutCubic,
        alignment: 0.12,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: AppColors.cyan,
          backgroundColor: AppColors.surface,
          child: _isLoading
              ? ListView(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
                  children: const [
                    SkeletonEventCard(),
                    SkeletonEventCard(),
                    SkeletonEventCard(),
                  ],
                )
              : _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    var filtered = _events;

    // Search query filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((e) {
        final q = _searchQuery.toLowerCase();
        final matchTitle = e.title.toLowerCase().contains(q);
        final matchDesc = e.description?.toLowerCase().contains(q) ?? false;
        final matchLoc = e.location?.toLowerCase().contains(q) ?? false;
        return matchTitle || matchDesc || matchLoc;
      }).toList();
    }

    // Direct 1-tap segment filter (Hick's Law) - Default is 'upcoming' status
    if (_filter == 'upcoming') {
      filtered = filtered.where((e) => e.status.toLowerCase() == 'upcoming').toList();
    } else if (_filter == 'ongoing') {
      filtered = filtered.where((e) => e.status.toLowerCase() == 'ongoing').toList();
    } else if (_filter == 'virtual') {
      filtered = filtered.where((e) => e.isVirtual).toList();
    }
    // 'all' shows everything returned from the API

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        // 1. Header with back arrow & "Upcoming Events" title
        SliverToBoxAdapter(
          child: _buildHeader(),
        ),

        // 2. Search Bar + 1-Tap Filter Pills (Hick's Law)
        SliverToBoxAdapter(
          child: _buildSearchAndFilters(),
        ),

        // 3. Event List
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          sliver: filtered.isEmpty
              ? SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 60),
                      child: Column(
                        children: [
                          Icon(Icons.event_busy_rounded, size: 52, color: AppColors.textMuted.withOpacity(0.35)),
                          const SizedBox(height: 14),
                          Text(
                            'No events found',
                            style: AppColors.soraBold(15).copyWith(color: AppColors.textMuted),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'Try adjusting your search terms'
                                : _filter == 'upcoming'
                                    ? 'No upcoming events scheduled right now'
                                    : 'Stay connected — new events are added regularly',
                            style: AppColors.geistMedium(12).copyWith(color: AppColors.textMuted.withOpacity(0.6)),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _eventCard(filtered[index]),
                    childCount: filtered.length,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.surface.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 19),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Upcoming Events',
              style: AppColors.soraBold(20).copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF0A1424).withOpacity(0.8),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.surfaceBorder),
            ),
            child: Row(
              children: [
                Icon(Icons.search_rounded, color: AppColors.textMuted, size: 19),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
                    style: AppColors.geistMedium(13).copyWith(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search by title, location or speaker...',
                      hintStyle: AppColors.geistMedium(13).copyWith(color: AppColors.textMuted.withOpacity(0.6)),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  GestureDetector(
                    onTap: () => setState(() => _searchQuery = ''),
                    child: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 18),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _filterPill('all', 'All Events', Icons.grid_view_rounded),
              _filterPill('upcoming', 'Upcoming', Icons.calendar_month_rounded),
              _filterPill('virtual', 'Virtual', Icons.videocam_rounded),
              _filterPill('ongoing', 'Ongoing', Icons.fiber_manual_record_rounded),
            ],
          ),
        ),
      ],
    );
  }

  Widget _filterPill(String key, String label, IconData icon) {
    final isSelected = _filter == key;
    return GestureDetector(
      onTap: () => setState(() => _filter = key),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.cyan.withOpacity(0.16) : const Color(0xFF0A1424).withOpacity(0.6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.cyan.withOpacity(0.5) : AppColors.surfaceBorder,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? AppColors.cyan : AppColors.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppColors.geistBold(11).copyWith(
                color: isSelected ? AppColors.cyan : AppColors.textSecondary,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _eventCard(EventModel event) {
    final isVirtual = event.isVirtual;
    final accentColor = isVirtual ? AppColors.cyan : AppColors.pink;
    final hasCapacity = event.maxParticipants != null && event.maxParticipants! > 0;
    final spotsLeft = hasCapacity ? event.maxParticipants! - event.currentParticipants : null;
    final isFull = hasCapacity && spotsLeft != null && spotsLeft <= 0;
    final isHighlighted = event.id == _highlightedEventId;

    final cardContent = Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A1424).withOpacity(0.75),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Type Icon + Title/Speaker + Status Badges
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: accentColor.withOpacity(0.3)),
                  ),
                  child: Center(
                    child: Icon(
                      isVirtual ? Icons.videocam_rounded : Icons.location_on_rounded,
                      color: accentColor,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        style: AppColors.soraBold(15).copyWith(color: Colors.white, height: 1.3),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (event.description != null && event.description!.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          event.description!,
                          style: AppColors.hankenMedium(11).copyWith(color: AppColors.textMuted, height: 1.4),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildStatusBadge(event.status),
                    if (isVirtual) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: accentColor.withOpacity(0.25)),
                        ),
                        child: Text(
                          'VIRTUAL',
                          style: AppColors.geistBold(8).copyWith(color: accentColor, letterSpacing: 0.8),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Divider
          Divider(color: Colors.white.withOpacity(0.06), height: 1),

          // Middle Details: Date/Time + Location or Zoom Link
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date & Time
                Row(
                  children: [
                    Icon(Icons.calendar_month_rounded, size: 14, color: AppColors.cyan),
                    const SizedBox(width: 6),
                    Text(
                      event.dateFormatted.isNotEmpty ? event.dateFormatted : _parseDate(event.startsAt),
                      style: AppColors.geistMedium(12).copyWith(color: Colors.white.withOpacity(0.9)),
                    ),
                    if (event.timeFormatted.isNotEmpty) ...[
                      const SizedBox(width: 14),
                      Icon(Icons.schedule_rounded, size: 14, color: AppColors.cyan),
                      const SizedBox(width: 6),
                      Text(
                        event.timeFormatted,
                        style: AppColors.geistMedium(12).copyWith(color: Colors.white.withOpacity(0.9)),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 10),

                // Location or Launch Virtual Link Chip (Clean & Actionable!)
                if (isVirtual && event.virtualLink != null && event.virtualLink!.isNotEmpty) ...[
                  GestureDetector(
                    onTap: () async {
                      final uri = Uri.tryParse(event.virtualLink!);
                      if (uri != null && await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      } else {
                        if (mounted) {
                          AppToast.show(context, 'Unable to open event link', type: ToastType.error);
                        }
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: AppColors.cyan.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.cyan.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.link_rounded, size: 14, color: AppColors.cyan),
                          const SizedBox(width: 6),
                          Text(
                            'Join Virtual Session ↗',
                            style: AppColors.geistBold(11).copyWith(color: AppColors.cyan),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else if (!isVirtual && event.location != null && event.location!.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(Icons.place_rounded, size: 14, color: AppColors.pink),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          event.location!,
                          style: AppColors.geistMedium(12).copyWith(color: Colors.white.withOpacity(0.85)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],

                if (hasCapacity) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.group_outlined, size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 6),
                      Text(
                        isFull
                            ? 'Event Full (${event.maxParticipants} max capacity)'
                            : '${event.currentParticipants}/${event.maxParticipants} capacity (${spotsLeft ?? 0} spots left)',
                        style: AppColors.geistMedium(11).copyWith(
                          color: isFull ? AppColors.pink : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    if (isHighlighted) {
      final controller = _effectiveBorderController;
      return Container(
        key: _cardKeys.putIfAbsent(event.id, () => GlobalKey()),
        margin: const EdgeInsets.only(bottom: 16),
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, child) {
            return CustomPaint(
              painter: _RotatingBorderBeamPainter(
                progress: controller.value,
                borderColor: AppColors.cyan,
                borderRadius: 24.0,
              ),
              child: child,
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(5.0),
            child: cardContent,
          ),
        ),
      );
    }

    return Container(
      key: _cardKeys.putIfAbsent(event.id, () => GlobalKey()),
      margin: const EdgeInsets.only(bottom: 16),
      child: cardContent,
    );
  }

  String _parseDate(String? dateStr) {
    if (dateStr == null) return 'TBA';
    final raw = dateStr.endsWith('Z') ? dateStr : '${dateStr}Z';
    final date = DateTime.tryParse(raw)?.toLocal();
    if (date == null) return dateStr;
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String label;
    switch (status) {
      case 'ongoing':
        color = const Color(0xFF69F0AE);
        label = 'Ongoing';
        break;
      case 'completed':
        color = AppColors.textMuted;
        label = 'Completed';
        break;
      default:
        color = AppColors.cyan;
        label = 'Upcoming';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(label, style: AppColors.geistBold(9).copyWith(color: color, letterSpacing: 0.5)),
    );
  }
}

class _RotatingBorderBeamPainter extends CustomPainter {
  final double progress;
  final Color borderColor;
  final double borderRadius;

  _RotatingBorderBeamPainter({
    required this.progress,
    required this.borderColor,
    this.borderRadius = 24.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    const strokeWidth = 1.6;
    const halfStroke = strokeWidth / 2;
    final rect = Rect.fromLTWH(
      halfStroke,
      halfStroke,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    // 1. Full unbroken base border line (buo at visible ang buong border line)
    final baseBorderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = borderColor.withOpacity(0.50);
    canvas.drawRRect(rrect, baseBorderPaint);

    // 2. Rotating luminous gradient wave (hindi napuputol ang linya, naglalakbay ang glow)
    final shader = SweepGradient(
      center: Alignment.center,
      transform: GradientRotation(progress * 2 * math.pi),
      colors: [
        borderColor.withOpacity(0.15),
        borderColor.withOpacity(0.55),
        borderColor,
        Colors.white,
        borderColor,
        borderColor.withOpacity(0.55),
        borderColor.withOpacity(0.15),
      ],
      stops: const [0.0, 0.30, 0.45, 0.50, 0.55, 0.70, 1.0],
    ).createShader(rect);

    // 3. Subtle outer glow pass na sumusunod sa rotation
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.8
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0)
      ..shader = shader;
    canvas.drawRRect(rrect, glowPaint);

    // 4. Rotating highlight beam on top of the full border
    final beamPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..shader = shader;
    canvas.drawRRect(rrect, beamPaint);
  }

  @override
  bool shouldRepaint(_RotatingBorderBeamPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.borderRadius != borderRadius;
  }
}
