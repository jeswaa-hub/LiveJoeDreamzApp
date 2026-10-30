import 'package:flutter_test/flutter_test.dart';
import 'package:dream_community_app/core/theme/app_theme.dart';
import 'package:dream_community_app/core/models/user_model.dart';
import 'package:dream_community_app/core/models/journal_entry_model.dart';

void main() {
  group('1. Theme & Design System Integrity', () {
    test('Brand Colors are valid and defined', () {
      expect(AppColors.background, isNotNull);
      expect(AppColors.cyan, isNotNull);
      expect(AppColors.pink, isNotNull);
      expect(AppColors.surface, isNotNull);
    });
  });

  group('2. User Model & Permission Parsing', () {
    test('UserModel parses correctly with journal access = false', () {
      final json = {
        'id': 2,
        'name': 'Admin User',
        'email': 'admin@test.com',
        'role': 'admin',
        'has_journal_access': false,
        'avatar_url': null,
      };

      final user = UserModel.fromJson(json);
      expect(user.id, '2');
      expect(user.name, 'Admin User');
      expect(user.email, 'admin@test.com');
      expect(user.role, 'admin');
      expect(user.hasJournalAccess, false);
    });

    test('UserModel parses correctly with journal access = true', () {
      final json = {
        'id': '10',
        'name': 'VIP Member',
        'email': 'vip@test.com',
        'role': 'guest',
        'has_journal_access': true,
      };

      final user = UserModel.fromJson(json);
      expect(user.id, '10');
      expect(user.hasJournalAccess, true);
    });
  });

  group('3. D.R.E.A.M. Journal Model Parsing', () {
    test('JournalEntryModel parses full D.R.E.A.M. schema correctly', () {
      final json = {
        'id': 12,
        'user_id': 2,
        'entry_date': '2026-09-07',
        'dream': 'Launch Mobile App',
        'destination': 'Worldwide Community',
        'reason': 'Empower individuals',
        'energy': 'High',
        'amigos': 'Dream Team',
        'mindset': 'Growth',
        'media': [
          {
            'id': 1,
            'file_name': 'test.jpg',
            'file_url': 'http://127.0.0.1:8001/uploads/test.jpg',
            'file_type': 'image'
          }
        ],
        'created_at': '2026-09-07T14:00:00.000Z',
      };

      final entry = JournalEntryModel.fromJson(json);
      expect(entry.id, 12);
      expect(entry.dream, 'Launch Mobile App');
      expect(entry.destination, 'Worldwide Community');
      expect(entry.reason, 'Empower individuals');
      expect(entry.energy, 'High');
      expect(entry.amigos, 'Dream Team');
      expect(entry.mindset, 'Growth');
      expect(entry.media.length, 1);
      expect(entry.media.first.fileName, 'test.jpg');
    });
  });
}
