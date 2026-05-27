import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/api_service.dart';

class AuthState {
  final String? userId;
  final String? email;
  final String? role; 
  final String? referralCode;
  final String? referralLink;
  final bool isEmailVerified;
  final bool isLoading;
  final String? error;
  final bool skippedVerification;

  AuthState({
    this.userId,
    this.email,
    this.role,
    this.referralCode,
    this.referralLink,
    this.isEmailVerified = false,
    this.isLoading = false,
    this.error,
    this.skippedVerification = false,
  });

  bool get isAdmin => role == 'admin';

  AuthState copyWith({
    String? userId,
    String? email,
    String? role,
    String? referralCode,
    String? referralLink,
    bool? isEmailVerified,
    bool? isLoading,
    String? error,
    bool? skippedVerification,
  }) {
    return AuthState(
      userId: userId ?? this.userId,
      email: email ?? this.email,
      role: role ?? this.role,
      referralCode: referralCode ?? this.referralCode,
      referralLink: referralLink ?? this.referralLink,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      skippedVerification: skippedVerification ?? this.skippedVerification,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final Ref ref;
  final _storage = const FlutterSecureStorage();

  AuthNotifier(this.ref) : super(AuthState()) {
    _loadSession();
  }

  Future<void> _loadSession() async {
    final userId = await _storage.read(key: 'userId');
    final email = await _storage.read(key: 'email');
    final role = await _storage.read(key: 'role');
    final refCode = await _storage.read(key: 'referralCode');
    final refLink = await _storage.read(key: 'referralLink');
    final verified = await _storage.read(key: 'emailVerified') == 'true';
    
    if (userId != null) {
      state = AuthState(
        userId: userId, 
        email: email, 
        role: role, 
        referralCode: refCode,
        referralLink: refLink,
        isEmailVerified: verified
      );
      await refreshUser();
    }
  }

  Future<void> refreshUser() async {
    if (state.userId == null) return;
    try {
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.getUser(state.userId!);
      final userData = response.data;
      
      if (userData != null) {
        final newRole = userData['role'] ?? 'user';
        final isVerified = userData['emailVerified'] ?? false;
        final refCode = userData['referralCode'];
        final refLink = userData['referralLink'];
        
        await _storage.write(key: 'role', value: newRole);
        await _storage.write(key: 'emailVerified', value: isVerified.toString());
        if (refCode != null) await _storage.write(key: 'referralCode', value: refCode);
        if (refLink != null) await _storage.write(key: 'referralLink', value: refLink);

        state = state.copyWith(
          role: newRole, 
          isEmailVerified: isVerified,
          referralCode: refCode,
          referralLink: refLink,
        );
      }
    } catch (e) {
      print("Session refresh failed: $e");
    }
  }

  String _handleError(dynamic e) {
    if (e is DioException) {
      if (e.response?.data != null) {
        String errorMessage = e.response!.data.toString().replaceAll('"', '');
        return errorMessage
            .replaceFirst(RegExp(r'\[CONVEX.*?\]\s*'), '')
            .replaceFirst('Uncaught Error: ', '')
            .trim();
      }
      return e.message ?? "Connection error";
    }
    return e.toString();
  }

  Future<bool> checkReferralCode(String code) async {
    try {
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.checkReferralCode(code);
      return response.data['isValid'] == true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.login(email, password);
      
      final userId = response.data['_id'];
      final userEmail = response.data['email'];
      final userRole = response.data['role'] ?? 'user';
      final isVerified = response.data['emailVerified'] ?? false;
      final refCode = response.data['referralCode'];
      final refLink = response.data['referralLink'];

      await _storage.write(key: 'userId', value: userId);
      await _storage.write(key: 'email', value: userEmail);
      await _storage.write(key: 'role', value: userRole);
      await _storage.write(key: 'emailVerified', value: isVerified.toString());
      if (refCode != null) await _storage.write(key: 'referralCode', value: refCode);
      if (refLink != null) await _storage.write(key: 'referralLink', value: refLink);

      state = AuthState(
        userId: userId, 
        email: userEmail, 
        role: userRole, 
        isEmailVerified: isVerified,
        referralCode: refCode,
        referralLink: refLink,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _handleError(e));
      return false;
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    required String transactionPassword,
    String? invitationCode,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final apiService = ref.read(apiServiceProvider);
      await apiService.register(
        email: email,
        password: password,
        transactionPassword: transactionPassword,
        invitationCode: invitationCode,
      );
      
      return await login(email, password);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _handleError(e));
      return false;
    }
  }

  void skipVerification() {
    state = state.copyWith(skippedVerification: true);
  }

  Future<void> verifyEmail() async {
    if (state.userId == null) return;
    try {
      final apiService = ref.read(apiServiceProvider);
      await apiService.verifyEmail(state.userId!);
      await _storage.write(key: 'emailVerified', value: 'true');
      state = state.copyWith(isEmailVerified: true);
    } catch (e) {
      state = state.copyWith(error: _handleError(e));
    }
  }

  Future<void> logout() async {
    await _storage.deleteAll();
    state = AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});
