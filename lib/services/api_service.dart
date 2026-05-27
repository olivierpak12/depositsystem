import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ApiService {
  final Dio _dio = Dio();
  
  final String baseUrl = "https://tangible-rabbit-981.eu-west-1.convex.site";

  ApiService() {
    _dio.options.baseUrl = baseUrl;
  }

  // --- Auth Methods ---

  Future<Response> login(String email, String password) async {
    return await _dio.post('/run/users:login', data: {
      'email': email,
      'password': password,
    });
  }

  Future<Response> checkReferralCode(String code) async {
    return await _dio.get('/run/users:checkReferralCode', queryParameters: {'code': code});
  }

  Future<Response> register({
    required String email,
    required String password,
    required String transactionPassword,
    String? invitationCode,
  }) async {
    final data = {
      'email': email,
      'password': password,
      'transactionPassword': transactionPassword,
      'invitationCode': invitationCode,
    };

    return await _dio.post('/mutation/users:register', data: data);
  }

  Future<Response> verifyEmail(String userId) async {
    return await _dio.post('/mutation/users:verifyEmail', data: {
      'userId': userId,
    });
  }

  Future<Response> getUser(String userId) async {
    return await _dio.get('/run/users:getUser', queryParameters: {'userId': userId});
  }

  // --- Referral Methods ---

  Future<Response> getReferralStats(String userId) async {
    return await _dio.get('/run/referrals:getTeamStats', queryParameters: {'userId': userId});
  }

  Future<Response> getTeamMembers(String userId) async {
    return await _dio.get('/run/referrals:getTeamMembers', queryParameters: {'userId': userId});
  }

  Future<Response> getReferralEarnings(String userId) async {
    return await _dio.get('/run/referrals:getReferralEarningsHistory', queryParameters: {'userId': userId});
  }

  Future<Response> getLeaderboard() async {
    return await _dio.get('/run/referrals:getLeaderboard');
  }

  // --- Admin Methods ---

  Future<Response> listUsers() async {
    return await _dio.get('/run/users:listUsers');
  }

  Future<Response> setUserRole(String userId, String role) async {
    return await _dio.post('/mutation/users:setRole', data: {
      'userId': userId,
      'role': role,
    });
  }

  Future<Response> getAdminStats() async {
    return await _dio.get('/run/admin:getStats');
  }

  Future<Response> getPendingWithdrawals() async {
    return await _dio.get('/run/admin:getPendingWithdrawals');
  }

  Future<Response> processWithdrawal(String withdrawalId) async {
    return await _dio.post('/action/withdrawalActions:processWithdrawal', data: {'withdrawalId': withdrawalId});
  }

  Future<Response> processAllWithdrawals() async {
    return await _dio.post('/action/withdrawalActions:processAllPending');
  }

  // --- Data Methods ---

  Future<Response> getBalance(String userId) async {
    return await _dio.get('/run/balances:getTotalUsdtBalance', queryParameters: {'userId': userId});
  }

  Future<Response> getTransactions(String userId) async {
    return await _dio.get('/run/deposits:listDeposits', queryParameters: {'userId': userId});
  }

  Future<Response> getWithdrawals(String userId) async {
    return await _dio.get('/run/withdrawals:getWithdrawals', queryParameters: {'userId': userId});
  }

  Future<Response> requestWithdrawal(Map<String, dynamic> data) async {
    return await _dio.post('/mutation/withdrawals:requestWithdrawal', data: data);
  }

  Future<Response> getWallet(String userId) async {
    return await _dio.get('/run/wallets:getWallet', queryParameters: {'userId': userId});
  }

  Future<Response> generateWallet(String userId) async {
    return await _dio.post('/action/walletActions:generateWallet', data: {'userId': userId});
  }

  Future<Response> syncDeposits(String userId) async {
    return await _dio.post('/action/etherscanActions:syncUserDeposits', data: {'userId': userId});
  }
}

final apiServiceProvider = Provider((ref) => ApiService());
