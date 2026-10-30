import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dream_community_app/core/theme/app_theme.dart';
import 'package:dream_community_app/core/models/chat_message_model.dart';
import 'package:dream_community_app/core/models/book_club_model.dart';
import 'package:dream_community_app/core/models/book_club_prompt_model.dart';
import 'package:dream_community_app/features/book_club/services/book_club_service.dart';
import 'package:dream_community_app/features/book_club/screens/book_club_screen.dart';
import 'package:dream_community_app/features/chat/services/chat_service.dart';
import 'package:dream_community_app/shared/widgets/skeleton.dart';
import 'package:dream_community_app/shared/widgets/tier_lock_modal.dart';
import 'package:dream_community_app/core/widgets/dream_toast.dart';
import 'package:dream_community_app/features/auth/services/auth_service.dart';
import 'package:dream_community_app/core/models/user_model.dart';
import 'package:dream_community_app/core/services/pending_approval_sync_service.dart';
import 'package:dream_community_app/features/profile/services/notification_service.dart';

class ChatScreen extends StatefulWidget {
  final int? initialBookId;
  final String? initialPillar;
  final String? initialMessageId;
  final VoidCallback? onNavigateHome;

  /// Global notifier tracking the single active message triggered by a notification tap
  static final ValueNotifier<String?> globalHighlightedMessageId = ValueNotifier<String?>(null);

  const ChatScreen({
    super.key,
    this.initialBookId,
    this.initialPillar,
    this.initialMessageId,
    this.onNavigateHome,
  });

  @override
  State<ChatScreen> createState() => ChatScreenState();
}

class ChatScreenState extends State<ChatScreen> {
  final Map<String, GlobalKey> _messageKeys = {};
  String? _highlightedMessageId;
  Timer? _highlightDismissTimer;
  bool _isLoading = true;
  bool _showMembers = false;
  List<ChatMessageModel> _messages = [];
  List<UserModel> _members = [];
  List<BookClubBookModel> _bookList = [];
  ChatMessageModel? _replyTo;

  void _clearHighlight() {
    _highlightDismissTimer?.cancel();
    _highlightDismissTimer = null;
    if (_highlightedMessageId != null && mounted) {
      setState(() {
        _highlightedMessageId = null;
      });
      ChatScreen.globalHighlightedMessageId.value = null;
    }
  }

  void _startHighlightDismissTimer() {
    _highlightDismissTimer?.cancel();
    // Keep plain cyan border visible for 3.5 seconds once seen, then smoothly fade away
    _highlightDismissTimer = Timer(const Duration(milliseconds: 3500), () {
      if (mounted && _highlightedMessageId != null) {
        _clearHighlight();
      }
    });
  }

  // Local reaction state: messageId -> list of emoji reactions
  final Map<String, List<String>> _reactions = {};

  int? _selectedBookId;
  String _selectedPillar = 'R';
  String? _selectedPromptTag;

  String get _defaultPillar {
    for (final p in _pillars) {
      if (_isPillarReleased(p['letter']!)) {
        return p['letter']!;
      }
    }
    return 'R';
  }

  List<BookClubPromptModel> _prompts = BookClubPromptModel.defaultPrompts;

  BookClubPromptModel? get _activePrompt {
    if (_selectedPromptTag == null) return null;
    final match = _prompts.where((p) => p.tagSlug == _selectedPromptTag).toList();
    return match.isNotEmpty ? match.first : null;
  }

  String get _activePromptLabel {
    if (_selectedPromptTag == null) return '';
    return _formatPromptTag(_selectedPromptTag!);
  }

  String _formatPromptTag(String rawTag) {
    final match = _prompts.where((p) => p.tagSlug == rawTag).toList();
    if (match.isNotEmpty && match.first.label.isNotEmpty) {
      return match.first.label;
    }
    final cleaned = rawTag.replaceAll('_', ' ').trim();
    if (cleaned.isEmpty) return '';
    final words = cleaned.split(RegExp(r'\s+'));
    return words.map((w) {
      if (w.isEmpty) return '';
      return w[0].toUpperCase() + w.substring(1).toLowerCase();
    }).join(' ');
  }

  Color get _activePromptColor {
    return _activePrompt?.color ?? AppColors.pink;
  }

  String get _activePromptPlaceholder {
    return _activePrompt?.placeholder ?? 'Message community...';
  }

  final List<Map<String, String>> _pillars = [
    {'letter': 'D', 'pillar': 'Destination'},
    {'letter': 'R', 'pillar': 'Reason'},
    {'letter': 'E', 'pillar': 'Energy'},
    {'letter': 'A', 'pillar': 'Amigos'},
    {'letter': 'M', 'pillar': 'Mindset'},
  ];

  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _pollTimer;
  Timer? _presenceTimer;
  int _currentUserId = 1;
  UserModel? _currentUserModel;
  bool _isAtBottom = true;
  bool _isPollingMessages = false;

  int get _onlineCount {
    return _members.where((m) => m.isOnline).isEmpty
        ? 1
        : _members.where((m) => m.isOnline).length;
  }

  @override
  void initState() {
    super.initState();
    _selectedBookId = widget.initialBookId;
    _selectedPillar = widget.initialPillar ?? _defaultPillar;
    _highlightedMessageId = widget.initialMessageId;
    ChatScreen.globalHighlightedMessageId.value = widget.initialMessageId;
    ChatScreen.globalHighlightedMessageId.addListener(_onGlobalHighlightChanged);

    PendingApprovalSyncService.instance.onAccessUnlocked.addListener(_onLiveUnlocked);
    _loadUser();
    _loadBooks();
    _loadPrompts();
    _loadData().then((_) => _startPolling());
  }

  void _markChatNotificationAsRead() {
    final link = '/chat';
    NotificationService().markLinkAsRead(link).then((success) {
      if (success) {
        PendingApprovalSyncService.instance.decrementUnread();
        PendingApprovalSyncService.instance.syncNow();
      }
    });
  }

  void _onGlobalHighlightChanged() {
    if (!mounted) return;
    final newId = ChatScreen.globalHighlightedMessageId.value;
    if (newId != _highlightedMessageId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _highlightedMessageId = newId;
          });
          if (newId != null) {
            _markChatNotificationAsRead();
            _scrollToHighlightedMessage();
          } else {
            _highlightDismissTimer?.cancel();
          }
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialMessageId != oldWidget.initialMessageId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _highlightedMessageId = widget.initialMessageId;
          });
          if (_highlightedMessageId != null) {
            _markChatNotificationAsRead();
            _scrollToHighlightedMessage();
          }
        }
      });
    }
  }

  void _scrollToHighlightedMessage() {
    if (_highlightedMessageId == null) return;
    final targetKey = _messageKeys[_highlightedMessageId];
    if (targetKey != null && targetKey.currentContext != null) {
      Scrollable.ensureVisible(
        targetKey.currentContext!,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeInOutCubic,
        alignment: 0.5,
      ).then((_) {
        _startHighlightDismissTimer();
      });
    } else {
      _startHighlightDismissTimer();
    }
  }

  void _onLiveUnlocked() {
    if (PendingApprovalSyncService.instance.onAccessUnlocked.value && mounted) {
      _loadUser();
      _loadData();
    }
  }

  Future<void> refresh() async {
    await _loadUser();
    await _loadPrompts();
    await _loadData();
    await _refreshMembers();
  }

  Future<void> _loadPrompts() async {
    final prompts = await ChatService().getPrompts(bookId: _selectedBookId);
    if (mounted && prompts.isNotEmpty) {
      setState(() {
        _prompts = prompts;
      });
    }
  }

  Future<void> _loadBooks() async {
    final books = await BookClubService().getBooks();
    if (mounted) {
      setState(() {
        _bookList = books;
        if (!_isPillarReleased(_selectedPillar)) {
          final released = _bookList.where((b) => _isPillarReleased(b.letter)).toList();
          if (released.isNotEmpty) {
            _selectedPillar = released.first.letter;
            _selectedBookId = released.first.id;
          } else {
            _selectedPillar = _defaultPillar;
          }
        }
        if (_selectedBookId == null) {
          final match = _bookList.where((b) => b.letter.toUpperCase() == _selectedPillar.toUpperCase()).toList();
          if (match.isNotEmpty) {
            _selectedBookId = match.first.id;
          }
        }
      });
    }
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _pollMessages());
    _presenceTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _sendPresence();
      _refreshMembers();
    });
  }

  Future<void> _sendPresence() async {
    await ChatService().sendPresence();
  }

  Future<void> _refreshMembers() async {
    if (!mounted) return;
    try {
      final members = await ChatService().getMembers();
      if (mounted) setState(() => _members = members);
    } catch (_) {}
  }

  Future<void> _pollMessages() async {
    if (!mounted || _isPollingMessages) return;
    _isPollingMessages = true;
    try {
      final data = await ChatService().getMessages(
        bookId: _selectedBookId,
        pillar: _selectedPillar == 'ALL' ? null : _selectedPillar,
      );
      if (!mounted) return;
      setState(() => _messages = data);
      if (_isAtBottom) _scrollToBottom();
    } catch (_) {
    } finally {
      _isPollingMessages = false;
    }
  }

  bool get _hasChatAccess {
    if (_currentUserModel == null) return false;
    if (_currentUserModel!.hasAdminAccess) return true;
    if (_currentUserModel!.isFreeTier) return false;

    final role = _currentUserModel!.role.toLowerCase().trim();
    final tier = (_currentUserModel!.tier ?? '').toLowerCase().trim();
    if (role == 'guest' && (tier.isEmpty || tier == 'guest' || tier == 'free')) {
      return false;
    }

    final isPurchasedTier = tier.isNotEmpty && tier != 'free' && tier != 'guest';
    final isNonJournalTier = isPurchasedTier && tier != 'journal';
    return _currentUserModel!.hasChatAccess ||
        _currentUserModel!.hasCommunityAccess ||
        _currentUserModel!.hasBookClubAccess ||
        isNonJournalTier ||
        tier == 'community';
  }

  String get _currentMonthName {
    const monthNames = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return monthNames[DateTime.now().month];
  }

  bool _isPillarReleased(String letter) {
    if (letter == 'ALL') return true;
    if (_currentUserModel?.hasAdminAccess == true) return true;

    final month = _getPillarMonth(letter);
    if (month.isEmpty) return true;

    // Strict Website Match: strcasecmp($month, now()->format('F')) === 0
    // Kung anong month na, yun lang ang open para sa non-admin/guest role!
    return month.trim().toLowerCase() == _currentMonthName.toLowerCase();
  }

  String _getPillarMonth(String letter) {
    final match = _bookList.where((b) => b.letter.toUpperCase() == letter.toUpperCase()).toList();
    if (match.isNotEmpty && match.first.month.isNotEmpty) {
      return match.first.month;
    }
    const defaultMonths = {
      'D': 'September',
      'R': 'October',
      'E': 'November',
      'A': 'December',
      'M': 'January',
    };
    return defaultMonths[letter.toUpperCase()] ?? '';
  }

  Future<void> _loadUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString('user_data');
      if (data != null && mounted) {
        try {
          final json = jsonDecode(data);
          setState(() {
            _currentUserModel = UserModel.fromJson(json);
            _currentUserId = int.tryParse(_currentUserModel!.id) ?? 1;
          });
        } catch (_) {}
      }

      final user = await AuthService().getCurrentUser();
      if (user != null && mounted) {
        setState(() {
          _currentUserModel = user;
          _currentUserId = int.tryParse(user.id) ?? 1;
        });
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  Future<void> _loadData() async {
    final data = await ChatService().getMessages(
      bookId: _selectedBookId,
      pillar: _selectedPillar == 'ALL' ? null : _selectedPillar,
    );
    final membersData = await ChatService().getMembers();
    await ChatService().sendPresence();
    if (mounted) {
      setState(() {
        _messages = data;
        _members = membersData;
        _isLoading = false;
      });
      if (_highlightedMessageId != null) {
        _markChatNotificationAsRead();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToHighlightedMessage();
        });
      } else {
        _scrollToBottom(immediate: true);
      }
      _scrollController.addListener(_checkScrollPosition);
    }
  }

  void _checkScrollPosition() {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    final current = _scrollController.offset;
    _isAtBottom = (max - current) < 80;
  }

  void _selectPillar(String letter) {
    if (!_isPillarReleased(letter)) {
      final month = _getPillarMonth(letter);
      HapticFeedback.lightImpact();
      DreamToast.info(context, 'Opens in $month — only the active month ($_currentMonthName) is open!');
      return;
    }
    setState(() {
      _selectedPillar = letter;
      final match = _bookList.where((b) => b.letter.toUpperCase() == letter).toList();
      _selectedBookId = match.isNotEmpty ? match.first.id : null;
      _isLoading = true;
    });
    _loadPrompts();
    _loadData();
  }

  void _resetTopicFilter() {
    setState(() {
      _selectedPillar = _defaultPillar;
      final match = _bookList.where((b) => b.letter.toUpperCase() == _selectedPillar.toUpperCase()).toList();
      _selectedBookId = match.isNotEmpty ? match.first.id : null;
      _isLoading = true;
    });
    _loadPrompts();
    _loadData();
  }

  Future<void> _send() async {
    _clearHighlight();
    if (!_hasChatAccess) {
      TierLockModal.show(context, featureName: 'D.R.E.A.M. Book Club Chat');
      return;
    }
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();

    final parentId = _replyTo?.id;
    final mentions = _extractMentions(text);

    final tagToSend = _selectedPromptTag;
    int? bookIdToSend = _selectedBookId;
    if (bookIdToSend == null && _selectedPillar != 'ALL') {
      final match = _bookList.where((b) => b.letter.toUpperCase() == _selectedPillar).toList();
      if (match.isNotEmpty) bookIdToSend = match.first.id;
    }

    setState(() {
      _replyTo = null;
      _selectedPromptTag = null;
    });

    final sent = await ChatService().sendMessage(
      text,
      parentId: parentId,
      mentions: mentions.isNotEmpty ? mentions : null,
      bookClubBookId: bookIdToSend,
      promptTag: tagToSend,
    );
    if (sent != null) {
      setState(() => _messages.add(sent));
      _scrollToBottom();
    }
  }

  List<String> _extractMentions(String text) {
    final regex = RegExp(r'@(\w+)');
    return regex.allMatches(text).map((m) => m.group(1)!).toList();
  }

  void _startReply(ChatMessageModel msg) {
    _clearHighlight();
    HapticFeedback.lightImpact();
    setState(() {
      _replyTo = msg;
    });
  }

  void _toggleReaction(String messageId, String emoji) {
    HapticFeedback.lightImpact();
    setState(() {
      final currentList = _reactions[messageId] ?? [];
      if (currentList.contains(emoji)) {
        currentList.remove(emoji);
      } else {
        currentList.add(emoji);
      }
      _reactions[messageId] = currentList;
    });
  }

  void _quickHeartReaction(String messageId) {
    _toggleReaction(messageId, '❤️');
  }

  void _showReactionSheet(BuildContext context, ChatMessageModel msg, bool isMe) {
    HapticFeedback.mediumImpact();
    final emojis = ['❤️', '👍', '🔥', '👏', '💡', '😮'];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF0C1726),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: emojis.map((emoji) {
                final hasReacted = (_reactions[msg.id] ?? []).contains(emoji);
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(ctx);
                    _toggleReaction(msg.id, emoji);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: hasReacted ? AppColors.cyan.withValues(alpha: 0.2) : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Text(emoji, style: const TextStyle(fontSize: 26)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            const Divider(color: Colors.white10, height: 1),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _startReply(msg);
                  },
                  icon: const Icon(Icons.reply_rounded, color: AppColors.cyan, size: 18),
                  label: Text('Reply', style: GoogleFonts.sora(color: AppColors.cyan, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
                TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: msg.content));
                    Navigator.pop(ctx);
                    DreamToast.info(context, 'Copied to clipboard');
                  },
                  icon: const Icon(Icons.copy_rounded, color: Colors.white70, size: 16),
                  label: Text('Copy', style: GoogleFonts.sora(color: Colors.white70, fontSize: 12)),
                ),
                if (isMe || (_currentUserModel?.hasAdminAccess == true))
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _deleteMessage(msg);
                    },
                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 16),
                    label: Text('Delete', style: GoogleFonts.sora(color: AppColors.error, fontSize: 12)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showTagPicker() {
    if (!_hasChatAccess) {
      TierLockModal.show(context, featureName: 'D.R.E.A.M. Book Club Chat');
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF0C1726),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Tag Your Reflection', style: GoogleFonts.sora(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                if (_selectedPromptTag != null)
                  GestureDetector(
                    onTap: () {
                      setState(() => _selectedPromptTag = null);
                      Navigator.pop(ctx);
                    },
                    child: Text('Clear', style: GoogleFonts.sora(color: AppColors.pink, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _prompts.map((p) {
                final isSelected = _selectedPromptTag == p.tagSlug;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedPromptTag = isSelected ? null : p.tagSlug);
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? p.color.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isSelected ? p.color : Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Text(
                      p.label,
                      style: GoogleFonts.sora(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : Colors.white70,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteMessage(ChatMessageModel msg) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0C1524),
        title: Text('Delete Message', style: AppColors.soraBold(16)),
        content: Text('Are you sure you want to delete this message?', style: AppColors.geistMedium(13).copyWith(color: AppColors.textMuted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: AppColors.geistMedium(13).copyWith(color: AppColors.textMuted))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Delete', style: AppColors.geistMedium(13).copyWith(color: AppColors.error))),
        ],
      ),
    );
    if (confirmed == true) {
      final success = await ChatService().deleteMessage(msg.id);
      if (success && mounted) {
        setState(() {
          _messages.removeWhere((m) => m.id == msg.id);
        });
      }
    }
  }

  void _scrollToBottom({bool immediate = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        try {
          if (immediate) {
            _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
          } else {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        } catch (_) {}
      }
    });
  }

  @override
  void dispose() {
    _highlightDismissTimer?.cancel();
    ChatScreen.globalHighlightedMessageId.removeListener(_onGlobalHighlightChanged);
    final currentId = _highlightedMessageId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ChatScreen.globalHighlightedMessageId.value == currentId) {
        ChatScreen.globalHighlightedMessageId.value = null;
      }
    });
    PendingApprovalSyncService.instance.onAccessUnlocked.removeListener(_onLiveUnlocked);
    _pollTimer?.cancel();
    _presenceTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<Color> _getAvatarGradient(int index) {
    final gradients = [
      [const Color(0xFF00ECD8), const Color(0xFF1565C0)],
      [const Color(0xFF00E676), const Color(0xFF00796B)],
      [const Color(0xFFFFA726), const Color(0xFFE65100)],
      [const Color(0xFFF48FB1), const Color(0xFFAD1457)],
      [const Color(0xFFBA68C8), const Color(0xFF5E35B1)],
      [const Color(0xFF29B6F6), const Color(0xFF0288D1)],
      [const Color(0xFF26A69A), const Color(0xFF00695C)],
      [const Color(0xFFE040FB), const Color(0xFF880E4F)],
    ];
    return gradients[index % 8];
  }

  Color _getNameColor(int index) {
    final colors = [
      const Color(0xFF00E5FF),
      const Color(0xFF69F0AE),
      const Color(0xFFFFD740),
      const Color(0xFFFF4081),
      const Color(0xFFE040FB),
      const Color(0xFF40C4FF),
      const Color(0xFF1DE9B6),
      const Color(0xFFFF5252),
    ];
    return colors[index % 8];
  }

  String _getDateDividerLabel(DateTime? date) {
    if (date == null) return '';
    final dt = date.toLocal();
    final now = DateTime.now();
    
    final todayMidnight = DateTime(now.year, now.month, now.day);
    final msgMidnight = DateTime(dt.year, dt.month, dt.day);
    final diffDays = todayMidnight.difference(msgMidnight).inDays;

    if (diffDays == 0) {
      return 'TODAY';
    } else if (diffDays == 1) {
      return 'YESTERDAY';
    } else {
      final months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF051424),
      body: Stack(
        children: [
          // Dot Grid Pattern Overlay
          Positioned.fill(
            child: CustomPaint(
              painter: DotGridPainter(),
            ),
          ),

          // Content Column
          SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    _buildHeader(),
                    _buildPillarStrip(),
                    if (_selectedPillar != 'ALL' || _selectedBookId != null)
                      _buildContextBar(),
                    Expanded(
                      child: _isLoading
                          ? ListView(
                              padding: const EdgeInsets.all(16),
                              children: const [SkeletonPostCard(), SkeletonPostCard(), SkeletonPostCard()],
                            )
                          : _messages.isEmpty
                              ? _buildEmptyState()
                              : ListView.builder(
                                  controller: _scrollController,
                                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
                                  itemCount: _messages.length,
                                  itemBuilder: (context, index) {
                                    final msg = _messages[index];
                                    
                                    bool showDateDivider = false;
                                    if (index == 0) {
                                      showDateDivider = true;
                                    } else {
                                      final prev = _messages[index - 1].createdAt;
                                      final curr = msg.createdAt;
                                      if (prev != null && curr != null) {
                                        if (prev.day != curr.day ||
                                            prev.month != curr.month ||
                                            prev.year != curr.year) {
                                          showDateDivider = true;
                                        }
                                      }
                                    }

                                    bool showNameAndAvatar = true;
                                    if (index > 0) {
                                      final prev = _messages[index - 1];
                                      if (prev.userId == msg.userId && !showDateDivider) {
                                        final prevTime = prev.createdAt;
                                        final currTime = msg.createdAt;
                                        if (prevTime != null && currTime != null) {
                                          if (currTime.difference(prevTime).inMinutes < 4) {
                                            showNameAndAvatar = false;
                                          }
                                        }
                                      }
                                    }

                                    return Container(
                                      key: _messageKeys.putIfAbsent(msg.id, () => GlobalKey()),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          if (showDateDivider) _buildDateDivider(msg.createdAt),
                                          _buildMessageBubble(msg, showNameAndAvatar),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                    ),
                    _buildInputBar(),
                  ],
                ),
                if (_showMembers) _buildMembersPanel(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 10, 14, 10),
      decoration: const BoxDecoration(
        color: Color(0xE6051424),
        border: Border(bottom: BorderSide(color: Color(0x12FFFFFF))),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
            onPressed: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else if (widget.initialBookId != null) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const BookClubScreen()),
                );
              } else if (widget.onNavigateHome != null) {
                widget.onNavigateHome!();
              } else {
                Navigator.pushReplacementNamed(context, '/home');
              }
            },
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF00DBE9).withValues(alpha: 0.25),
                      const Color(0xFF00DBE9).withValues(alpha: 0.05),
                    ],
                  ),
                  border: Border.all(color: const Color(0xFF00DBE9).withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.forum_rounded, size: 18, color: Color(0xFF00DBE9)),
              ),
              Positioned(
                bottom: -1,
                right: -1,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF69F0AE),
                    border: Border.all(color: const Color(0xFF051424), width: 1.5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.initialBookId != null ? 'D.R.E.A.M. Book Club Chat' : 'D.R.E.A.M. Community',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  '$_onlineCount online • Book & Community',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppColors.geistMedium(11).copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.people_alt_outlined, color: Color(0xFF00E5FF), size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => setState(() => _showMembers = !_showMembers),
          ),
        ],
      ),
    );
  }

  Widget _buildPillarStrip() {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF081422),
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _pillars.length,
        itemBuilder: (context, index) {
          final p = _pillars[index];
          final letter = p['letter']!;
          final isSelected = _selectedPillar == letter;
          final isLocked = !_isPillarReleased(letter);

          return GestureDetector(
            onTap: () => _selectPillar(letter),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.cyan
                    : (isLocked
                        ? Colors.white.withValues(alpha: 0.02)
                        : Colors.white.withValues(alpha: 0.04)),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected
                      ? AppColors.cyan
                      : (isLocked
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.white.withValues(alpha: 0.08)),
                ),
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isLocked) ...[
                      Icon(
                        Icons.lock_rounded,
                        size: 11,
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      '$letter · ${p['pillar']}',
                      style: GoogleFonts.sora(
                        fontSize: 10.5,
                        fontWeight: isSelected ? FontWeight.w700 : (isLocked ? FontWeight.w400 : FontWeight.w500),
                        color: isSelected
                            ? const Color(0xFF051424)
                            : (isLocked
                                ? Colors.white.withValues(alpha: 0.3)
                                : Colors.white.withValues(alpha: 0.8)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContextBar() {
    String topicName = 'Active Pillar: $_selectedPillar';
    if (_selectedBookId != null) {
      final match = _bookList.where((b) => b.id == _selectedBookId).toList();
      if (match.isNotEmpty) {
        topicName = '[${match.first.letter}] ${match.first.title}';
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: AppColors.cyan.withValues(alpha: 0.08),
      child: Row(
        children: [
          const Icon(Icons.filter_list_rounded, size: 14, color: AppColors.cyan),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Filtering: $topicName',
              style: AppColors.geistMedium(11).copyWith(color: AppColors.cyan),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: _resetTopicFilter,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.cyan.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(Icons.close, size: 12, color: AppColors.cyan),
                  const SizedBox(width: 2),
                  Text('Reset', style: AppColors.geistBold(10).copyWith(color: AppColors.cyan)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.cyan.withValues(alpha: 0.1),
                border: Border.all(color: AppColors.cyan.withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.forum_outlined, size: 28, color: AppColors.cyan),
            ),
            const SizedBox(height: 16),
            Text(
              'No messages yet in this discussion',
              style: AppColors.soraBold(14).copyWith(color: Colors.white),
            ),
            const SizedBox(height: 6),
            Text(
              'Start the conversation! Share a reflection or ask a question.',
              textAlign: TextAlign.center,
              style: AppColors.geistMedium(12).copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateDivider(DateTime? date) {
    final label = _getDateDividerLabel(date);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Expanded(child: Container(height: 1, color: Colors.white.withValues(alpha: 0.08))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: AppColors.geistBold(10).copyWith(color: AppColors.textMuted, letterSpacing: 1.5),
            ),
          ),
          Expanded(child: Container(height: 1, color: Colors.white.withValues(alpha: 0.08))),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessageModel msg, bool showNameAndAvatar) {
    // Robust detection of whether the message belongs to current user
    final isMe = msg.userId.isNotEmpty && (
      msg.userId == _currentUserId.toString() ||
      (_currentUserModel != null && (
        msg.userId == _currentUserModel!.id ||
        (msg.userName != null && _currentUserModel!.name.isNotEmpty && msg.userName!.trim().toLowerCase() == _currentUserModel!.name.trim().toLowerCase())
      ))
    );

    if (msg.isDeleted) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Deleted message',
              style: AppColors.geistMedium(11).copyWith(color: AppColors.textMuted, fontStyle: FontStyle.italic),
            ),
          ),
        ),
      );
    }

    final reactions = _reactions[msg.id] ?? [];
    final isHighlighted = msg.id == _highlightedMessageId;

    return GestureDetector(
      onTap: isHighlighted ? _clearHighlight : null,
      onLongPress: () => _showReactionSheet(context, msg, isMe),
      onDoubleTap: () => _quickHeartReaction(msg.id),
      child: Dismissible(
        key: Key('reply_${msg.id}'),
        direction: DismissDirection.startToEnd,
        confirmDismiss: (_) async {
          _startReply(msg);
          HapticFeedback.lightImpact();
          return false;
        },
        background: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 16),
          child: const Icon(Icons.reply_rounded, color: AppColors.cyan, size: 22),
        ),
        child: Padding(
          padding: EdgeInsets.only(bottom: showNameAndAvatar ? 10 : 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              // Avatar for incoming messages only
              if (!isMe && showNameAndAvatar)
                Container(
                  width: 30,
                  height: 30,
                  margin: const EdgeInsets.only(right: 8, bottom: 2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: _getAvatarGradient(msg.userId.hashCode)),
                  ),
                  child: Center(
                    child: Text(
                      msg.initials,
                      style: GoogleFonts.sora(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                )
              else if (!isMe)
                const SizedBox(width: 38),

              // Message Body
              Flexible(
                child: Column(
                  crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    // Sender Name (Only on first of cluster for incoming)
                    if (!isMe && showNameAndAvatar)
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              msg.userName ?? 'Member',
                              style: GoogleFonts.sora(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: _getNameColor(msg.userId.hashCode),
                              ),
                            ),
                            if (msg.isSuperAdmin) ...[
                              const SizedBox(width: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppColors.cyan.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: AppColors.cyan.withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  'ADMIN',
                                  style: GoogleFonts.sora(fontSize: 8, fontWeight: FontWeight.bold, color: AppColors.cyan),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                    // Main Bubble (Clean Plain Border Line for Dream Book Club Chat)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                      padding: EdgeInsets.all(isHighlighted ? 3.0 : 0.0),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(19.0),
                        border: Border.all(
                          color: isHighlighted ? AppColors.cyan : Colors.transparent,
                          width: isHighlighted ? 1.8 : 0.0,
                        ),
                        boxShadow: isHighlighted
                            ? [
                                BoxShadow(
                                  color: AppColors.cyan.withValues(alpha: 0.35),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: _buildBubbleContent(context, msg, isMe, showNameAndAvatar, reactions),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildBubbleContent(
    BuildContext context,
    ChatMessageModel msg,
    bool isMe,
    bool showNameAndAvatar,
    List<String> reactions,
  ) {
    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.76),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                          decoration: BoxDecoration(
                            gradient: isMe
                                ? const LinearGradient(
                                    colors: [Color(0xFF00DBE9), Color(0xFF00C7D7)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : null,
                            color: isMe ? null : const Color(0xFF0C1929),
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(16),
                              topRight: const Radius.circular(16),
                              bottomLeft: Radius.circular(!isMe && showNameAndAvatar ? 4 : 16),
                              bottomRight: Radius.circular(isMe && showNameAndAvatar ? 4 : 16),
                            ),
                            border: Border.all(
                              color: isMe ? const Color(0xFF00DBE9) : Colors.white.withValues(alpha: 0.08),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: isMe
                                    ? AppColors.cyan.withValues(alpha: 0.22)
                                    : Colors.black.withValues(alpha: 0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              // Quoted parent message (if replying)
                              if (msg.parentContent != null && msg.parentContent!.isNotEmpty) ...[
                                Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: isMe ? Colors.black.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border(
                                      left: BorderSide(
                                        color: isMe ? const Color(0xFF051424) : AppColors.cyan,
                                        width: 2.5,
                                      ),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        msg.parentUserName ?? 'Replying',
                                        style: GoogleFonts.sora(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                          color: isMe ? const Color(0xFF051424) : AppColors.cyan,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        msg.parentContent!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppColors.geistMedium(10.5).copyWith(
                                          color: isMe ? const Color(0xFF051424).withValues(alpha: 0.8) : Colors.white70,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              // Clean subtle reflection tag / book reference
                              if (msg.promptTag != null || msg.bookTitle != null) ...[
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (msg.promptTag != null) ...[
                                        Text(
                                          _formatPromptTag(msg.promptTag!),
                                          style: GoogleFonts.sora(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w700,
                                            color: isMe ? const Color(0xFF051424).withValues(alpha: 0.8) : AppColors.pink,
                                          ),
                                        ),
                                      ],
                                      if (msg.promptTag != null && msg.bookTitle != null)
                                        Text(
                                          ' • ',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: isMe ? const Color(0xFF051424).withValues(alpha: 0.5) : Colors.white38,
                                          ),
                                        ),
                                      if (msg.bookTitle != null) ...[
                                        Flexible(
                                          child: Text(
                                            '📖 ${msg.bookTitle}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.sora(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w600,
                                              color: isMe ? const Color(0xFF051424).withValues(alpha: 0.8) : AppColors.cyan,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],

                              // Message Text
                              Text(
                                msg.content,
                                style: GoogleFonts.sora(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                  color: isMe ? const Color(0xFF051424) : Colors.white,
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: 3),

                              // Timestamp & Read Ticks
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                                children: [
                                  Text(
                                    msg.timeFormatted,
                                    style: GoogleFonts.sora(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w500,
                                      color: isMe ? const Color(0xFF051424).withValues(alpha: 0.65) : AppColors.textMuted,
                                    ),
                                  ),
                                  if (isMe) ...[
                                    const SizedBox(width: 3),
                                    Icon(
                                      Icons.done_all_rounded,
                                      size: 12,
                                      color: const Color(0xFF051424).withValues(alpha: 0.7),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Emoji Reaction Pill (Floating at bottom of bubble)
                        if (reactions.isNotEmpty)
                          Positioned(
                            bottom: -10,
                            right: isMe ? 4 : null,
                            left: !isMe ? 4 : null,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF081220),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.4),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    reactions.take(3).join(''),
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  if (reactions.length > 1) ...[
                                    const SizedBox(width: 2),
                                    Text(
                                      '${reactions.length}',
                                      style: GoogleFonts.sora(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white70),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                      ],
                    );
  }

  Widget _buildLockedInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: const BoxDecoration(
        color: Color(0xFF051424),
        border: Border(top: BorderSide(color: Color(0x12FFFFFF))),
      ),
      child: SafeArea(
        top: false,
        child: GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            TierLockModal.show(context, featureName: 'D.R.E.A.M. Book Club Chat');
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF091626),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cyan.withValues(alpha: 0.25)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.cyan.withValues(alpha: 0.12),
                    border: Border.all(color: AppColors.cyan.withValues(alpha: 0.3)),
                  ),
                  child: const Center(
                    child: Icon(Icons.lock_rounded, color: AppColors.cyan, size: 16),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chat Participation Gated',
                        style: GoogleFonts.sora(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Reserved for Community Members',
                        style: AppColors.geistMedium(10.5).copyWith(
                          color: Colors.white.withValues(alpha: 0.45),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.cyan,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.cyan.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    'UPGRADE',
                    style: GoogleFonts.sora(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF051424),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    if (!_hasChatAccess) {
      return _buildLockedInputBar();
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      decoration: const BoxDecoration(
        color: Color(0xFF051424),
        border: Border(top: BorderSide(color: Color(0x12FFFFFF))),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Reply Preview Bar
            if (_replyTo != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1B2A),
                  borderRadius: BorderRadius.circular(10),
                  border: const Border(left: BorderSide(color: AppColors.cyan, width: 3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.reply_rounded, color: AppColors.cyan, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Replying to ${_replyTo!.userName ?? "Member"}',
                            style: GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.cyan),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _replyTo!.content,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppColors.geistMedium(11).copyWith(color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _replyTo = null),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.close_rounded, color: AppColors.textMuted, size: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Guided Discussion Topics / Tag Reflection Bar
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.auto_awesome, size: 12, color: AppColors.cyan),
                        const SizedBox(width: 4),
                        Text(
                          'TAG REFLECTION:',
                          style: GoogleFonts.sora(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: Colors.white.withValues(alpha: 0.45),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                    ),
                    ..._prompts.map((p) {
                      final isSelected = _selectedPromptTag == p.tagSlug;
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _selectedPromptTag = isSelected ? null : p.tagSlug;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? p.color.withValues(alpha: 0.22)
                                : Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? p.color : Colors.white.withValues(alpha: 0.08),
                              width: isSelected ? 1.4 : 1.0,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: p.color.withValues(alpha: 0.3),
                                      blurRadius: 6,
                                      offset: const Offset(0, 1),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Text(
                            p.label,
                            style: GoogleFonts.sora(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.75),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),

            // Active Tag indicator
            if (_selectedPromptTag != null) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: _activePromptColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _activePromptColor.withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.label_rounded, size: 12, color: _activePromptColor),
                          const SizedBox(width: 5),
                          Text(
                            'Active Tag: $_activePromptLabel',
                            style: GoogleFonts.sora(fontSize: 10.5, fontWeight: FontWeight.w600, color: _activePromptColor),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _selectedPromptTag = null),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.close_rounded, size: 11, color: Colors.white60),
                            const SizedBox(width: 3),
                            Text(
                              'Clear tag',
                              style: GoogleFonts.sora(fontSize: 10, color: Colors.white60),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Input Row: Tag button + Pill Text Field + Circular Cyan Send Button
            Row(
              children: [
                // Tag reflection button
                GestureDetector(
                  onTap: _showTagPicker,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _selectedPromptTag != null ? _activePromptColor.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
                      border: Border.all(
                        color: _selectedPromptTag != null ? _activePromptColor : Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Icon(
                      Icons.lightbulb_outline_rounded,
                      size: 18,
                      color: _selectedPromptTag != null ? _activePromptColor : Colors.white70,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Text Input Pill
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF091626),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
                    ),
                    child: TextField(
                      controller: _controller,
                      style: GoogleFonts.sora(fontSize: 13, color: Colors.white),
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: _selectedPromptTag != null ? _activePromptPlaceholder : 'Message community...',
                        hintStyle: GoogleFonts.sora(fontSize: 12.5, color: Colors.white.withValues(alpha: 0.35)),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 9),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Circular Cyan Send Button
                GestureDetector(
                  onTap: _send,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.cyan,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.cyan.withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.arrow_upward_rounded, color: Color(0xFF051424), size: 20),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMembersPanel() {
    final onlineMembers = _members.where((m) => m.isOnline).toList();
    final offlineMembers = _members.where((m) => !m.isOnline).toList();
    final sortedMembers = [...onlineMembers, ...offlineMembers];

    return Positioned(
      top: 0,
      right: 0,
      bottom: 0,
      width: 240,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0A1929),
          border: Border(left: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Members (${_members.length})', style: AppColors.soraBold(13).copyWith(color: Colors.white)),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textMuted, size: 18),
                    onPressed: () => setState(() => _showMembers = false),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: sortedMembers.length,
                itemBuilder: (context, index) {
                  final m = sortedMembers[index];
                  return ListTile(
                    leading: Stack(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: AppColors.cyan.withValues(alpha: 0.2),
                          child: Text(
                            m.initials,
                            style: AppColors.soraBold(10).copyWith(color: AppColors.cyan),
                          ),
                        ),
                        if (m.isOnline)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF69F0AE),
                              ),
                            ),
                          ),
                      ],
                    ),
                    title: Text(m.name, style: AppColors.geistMedium(12).copyWith(color: Colors.white)),
                    dense: true,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x0A00DBE9)
      ..strokeWidth = 1.0;
    const double spacing = 28.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.0, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
