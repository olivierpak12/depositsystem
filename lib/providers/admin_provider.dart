import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';

final usersProvider = FutureProvider<List<dynamic>>((ref) async {
  final apiService = ref.read(apiServiceProvider);
  final response = await apiService.listUsers();
  return response.data as List<dynamic>;
});

final adminStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final apiService = ref.read(apiServiceProvider);
  final response = await apiService.getAdminStats();
  return response.data as Map<String, dynamic>;
});

class AdminNotifier extends StateNotifier<bool> {
  final Ref ref;
  AdminNotifier(this.ref) : super(false);

  Future<void> updateUserRole(String userId, String role) async {
    final apiService = ref.read(apiServiceProvider);
    await apiService.setUserRole(userId, role);
    ref.invalidate(usersProvider);
  }
}

final adminNotifierProvider = StateNotifierProvider<AdminNotifier, bool>((ref) {
  return AdminNotifier(ref);
});
