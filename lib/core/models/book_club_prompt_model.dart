import 'package:flutter/material.dart';
import 'package:dream_community_app/core/theme/app_theme.dart';

class BookClubPromptModel {
  final int id;
  final String label;
  final String tagSlug;
  final String placeholder;
  final String colorTheme;
  final int? bookClubBookId;

  const BookClubPromptModel({
    required this.id,
    required this.label,
    required this.tagSlug,
    required this.placeholder,
    this.colorTheme = 'cyan',
    this.bookClubBookId,
  });

  factory BookClubPromptModel.fromJson(Map<String, dynamic> json) {
    return BookClubPromptModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      label: json['label']?.toString() ?? '',
      tagSlug: json['tag_slug']?.toString() ?? '',
      placeholder: json['placeholder']?.toString() ?? 'Share your reflection...',
      colorTheme: json['color_theme']?.toString() ?? 'cyan',
      bookClubBookId: json['book_club_book_id'] != null
          ? int.tryParse(json['book_club_book_id'].toString())
          : null,
    );
  }

  Color get color {
    switch (colorTheme.toLowerCase()) {
      case 'pink':
      case 'rose':
        return AppColors.pink;
      case 'amber':
      case 'orange':
        return const Color(0xFFF59E0B);
      case 'purple':
        return const Color(0xFFA855F7);
      case 'blue':
        return const Color(0xFF3B82F6);
      case 'emerald':
      case 'green':
        return const Color(0xFF10B981);
      case 'cyan':
      default:
        return AppColors.cyan;
    }
  }

  /// Default fallback prompts if offline / waiting for network
  static List<BookClubPromptModel> get defaultPrompts => const [
    BookClubPromptModel(
      id: 1,
      label: 'What I Learned Today?',
      tagSlug: 'what_i_learned_today',
      placeholder: 'Share what you learned from today\'s reading...',
      colorTheme: 'cyan',
    ),
    BookClubPromptModel(
      id: 2,
      label: 'How I Applied It / Results',
      tagSlug: 'applied_results',
      placeholder: 'How did you put this principle into action today?...',
      colorTheme: 'emerald',
    ),
    BookClubPromptModel(
      id: 3,
      label: 'Key Takeaway & Quotes',
      tagSlug: 'key_takeaway',
      placeholder: 'Share a quote or key takeaway that stood out...',
      colorTheme: 'amber',
    ),
    BookClubPromptModel(
      id: 4,
      label: 'Discussion Question',
      tagSlug: 'discussion_question',
      placeholder: 'Ask a question to start a group discussion...',
      colorTheme: 'purple',
    ),
    BookClubPromptModel(
      id: 5,
      label: 'What are you working on today ?',
      tagSlug: 'what_are_you_working_on_today',
      placeholder: 'What goals or tasks are you crushing today?...',
      colorTheme: 'rose',
    ),
  ];
}

