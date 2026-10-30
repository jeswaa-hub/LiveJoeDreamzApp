import 'dart:convert';
import 'package:dream_community_app/core/api/dio_client.dart';
import 'package:dream_community_app/core/api/api_endpoints.dart';
import 'package:dream_community_app/core/models/user_model.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dream_community_app/core/services/fcm_service.dart';

class AuthResult {
  final UserModel? user;
  final String? error;

  AuthResult({this.user, this.error});

  bool get isSuccess => user != null;
}

class AuthService {
  final Dio _dio = DioClient().dio;

  /// Register a new user (Free Tier) via Laravel API.
  Future<AuthResult> register(String name, String email, String password, {String? username}) async {
    try {
      final response = await _dio.post('/mobile/auth/register', data: {
        'name': name,
        'email': email,
        'password': password,
        if (username != null && username.isNotEmpty) 'username': username,
      });

      final data = response.data;
      final user = UserModel.fromJson(data['user']);
      final token = data['token'] as String;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);
      await prefs.setString('user_id', user.id);
      await prefs.setString('user_data', jsonEncode(data['user']));
      DioClient.setToken(token);

      return AuthResult(user: user);
    } on DioException catch (e) {
      final body = e.response?.data;
      if (e.response?.statusCode == 422) {
        final errors = body?['errors'];
        if (errors != null && errors is Map) {
          final first = errors.values.first;
          if (first is List && first.isNotEmpty) {
            return AuthResult(error: first.first.toString());
          }
        }
      }
      return AuthResult(error: body?['message'] ?? 'Registration failed. Please try again.');
    } catch (e) {
      return AuthResult(error: 'Registration failed. Please try again.');
    }
  }

  /// Check if an email is already registered in database
  Future<bool> checkEmailExists(String email) async {
    try {
      final response = await _dio.post('/mobile/auth/check-email', data: {
        'email': email.trim().toLowerCase(),
      });
      return response.data['exists'] == true;
    } catch (e) {
      return false;
    }
  }

  /// Login with email + password via Laravel API.
  Future<AuthResult> login(String email, String password) async {
    try {
      final response = await _dio.post(ApiEndpoints.login, data: {
        'email': email,
        'password': password,
      });

      final data = response.data;
      final user = UserModel.fromJson(data['user']);
      final token = data['token'] as String;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);
      await prefs.setString('user_id', user.id);
      await prefs.setString('user_data', jsonEncode(data['user']));
      await prefs.setBool('has_journal_access', user.hasJournalAccess);
      DioClient.setToken(token);

      // Register device FCM token with backend in background
      FcmService.instance.registerTokenWithBackend();

      return AuthResult(user: user);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final body = e.response?.data;

      if (status == 401) {
        return AuthResult(error: body?['message'] ?? 'Invalid email or password.');
      }
      if (status == 422) {
        final errors = body?['errors'];
        if (errors != null && errors is Map) {
          final first = errors.values.first;
          if (first is List && first.isNotEmpty) {
            return AuthResult(error: first.first.toString());
          }
        }
      }
      return AuthResult(error: 'Login failed. Please try again.');
    } catch (e) {
      return AuthResult(error: 'Login failed. Please try again.');
    }
  }

  /// Logout — call Laravel API then clear local storage.
  Future<void> logout() async {
    try {
      await FcmService.instance.revokeToken();
    } catch (_) {
      // Ignore if offline
    }

    try {
      await _dio.post(ApiEndpoints.logout);
    } catch (_) {
      // Token may already be expired — clear locally regardless
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_id');
    await prefs.remove('user_data');
    DioClient.clearToken();
  }

  /// Get current user from Laravel API using stored token.
  Future<UserModel?> getCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null || token.isEmpty) return null;

      final response = await _dio.get(ApiEndpoints.user);
      final userData = response.data['user'];
      if (userData == null) return null;

      final user = UserModel.fromJson(userData);

      // Refresh local cache
      await prefs.setString('user_id', user.id);
      await prefs.setString('user_data', jsonEncode(userData));
      await prefs.setBool('has_journal_access', user.hasJournalAccess);

      // Refresh FCM token registration with backend
      FcmService.instance.registerTokenWithBackend();

      return user;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        // Token expired — clear auth
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_id');
    await prefs.remove('user_data');
    DioClient.clearToken();
  }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Check if user has a stored auth token.
  Future<bool> hasToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    return token != null && token.isNotEmpty;
  }

  /// Clear stored auth data.
  Future<void> clearAuth() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_id');
    await prefs.remove('user_data');
  }

  /// Update user profile via Laravel API.
  Future<UserModel?> updateProfile(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post(ApiEndpoints.profile, data: data);
      final userData = response.data['user'];
      if (userData == null) return null;

      final user = UserModel.fromJson(userData);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_id', user.id);
      await prefs.setString('user_data', jsonEncode(userData));
      return user;
    } catch (e) {
      return null;
    }
  }

  /// Change password via Laravel API.
  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _dio.post(ApiEndpoints.changePassword, data: {
        'current_password': currentPassword,
        'new_password': newPassword,
      });
      return null;
    } on DioException catch (e) {
      return e.response?.data?['message'] ?? 'Failed to change password';
    } catch (e) {
      return e.toString();
    }
  }

  /// Upload avatar image to server (works on web + mobile)
  Future<UserModel?> uploadAvatarBytes(List<int> bytes, String fileName) async {
    try {
      final formData = FormData.fromMap({
        'avatar': MultipartFile.fromBytes(bytes, filename: fileName),
      });

      final response = await _dio.post(
        ApiEndpoints.uploadAvatar,
        data: formData,
      );

      final data = response.data;
      if (data is Map && data['user'] != null) {
        final user = UserModel.fromJson(Map<String, dynamic>.from(data['user']));
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_id', user.id);
        await prefs.setString('user_data', jsonEncode(data['user']));
        return user;
      }
      return await getCurrentUser();
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? e.message;
      print('[Avatar Upload Error] $msg');
      return null;
    } catch (e) {
      print('[Avatar Upload Error] $e');
      return null;
    }
  }

  /// Delete avatar
  Future<UserModel?> deleteAvatar() async {
    try {
      final response = await _dio.delete(ApiEndpoints.deleteAvatar);
      final data = response.data;
      if (data is Map && data['user'] != null) {
        final user = UserModel.fromJson(Map<String, dynamic>.from(data['user']));
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_id', user.id);
        await prefs.setString('user_data', jsonEncode(data['user']));
        return user;
      }
      return await getCurrentUser();
    } catch (e) {
      return null;
    }
  }
}
