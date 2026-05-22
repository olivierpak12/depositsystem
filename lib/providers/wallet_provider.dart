import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';

final balanceProvider = FutureProvider.family<String, String>((ref, userId) async {
  if (userId.isEmpty) return "0";
  final apiService = ref.read(apiServiceProvider);
  try {
    final response = await apiService.getBalance(userId);
    // Extract 'balance' field from {"balance": "..."}
    if (response.data is Map && response.data['balance'] != null) {
      return response.data['balance'].toString();
    }
    return "0";
  } catch (e) {
    print("Error fetching balance: $e");
    return "0";
  }
});

final walletProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, userId) async {
  if (userId.isEmpty) throw Exception("User not logged in");
  
  final apiService = ref.read(apiServiceProvider);
  
  // 1. Try to get existing wallet
  try {
    final response = await apiService.getWallet(userId);
    if (response.data != null && response.data['address'] != null) {
      return response.data;
    }
  } catch (e) {
    print("Error fetching wallet: $e");
  }

  // 2. If no wallet exists, generate one
  try {
    final genResponse = await apiService.generateWallet(userId);
    if (genResponse.data != null && genResponse.data['address'] != null) {
      return genResponse.data;
    }
    throw Exception("Generation returned empty data");
  } catch (e) {
    final retryResponse = await apiService.getWallet(userId);
    if (retryResponse.data != null && retryResponse.data['address'] != null) {
      return retryResponse.data;
    }
    throw Exception("Failed to generate wallet: $e");
  }
});

final transactionsProvider = FutureProvider.family<List<dynamic>, String>((ref, userId) async {
  if (userId.isEmpty) return [];
  final apiService = ref.read(apiServiceProvider);
  
  // Trigger a sync from Etherscan before returning local transactions
  try {
    await apiService.syncDeposits(userId);
  } catch (e) {
    print("Sync failed: $e");
  }

  final response = await apiService.getTransactions(userId);
  return response.data as List<dynamic>;
});

// Provider to manually trigger sync
final syncProvider = FutureProvider.family<int, String>((ref, userId) async {
  if (userId.isEmpty) return 0;
  final apiService = ref.read(apiServiceProvider);
  final response = await apiService.syncDeposits(userId);
  return response.data['foundNew'] ?? 0;
});
