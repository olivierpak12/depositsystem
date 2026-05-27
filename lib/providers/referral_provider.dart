import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/referral.dart';
import '../services/api_service.dart';
import 'auth_provider.dart';

final referralStatsProvider = FutureProvider.autoDispose<ReferralStats>((ref) async {
  final userId = ref.watch(authProvider).userId;
  if (userId == null) throw Exception("User not logged in");
  
  final apiService = ref.read(apiServiceProvider);
  final response = await apiService.getReferralStats(userId);
  return ReferralStats.fromJson(response.data);
});

final teamMembersProvider = FutureProvider.autoDispose<List<TeamMember>>((ref) async {
  final userId = ref.watch(authProvider).userId;
  if (userId == null) throw Exception("User not logged in");
  
  final apiService = ref.read(apiServiceProvider);
  final response = await apiService.getTeamMembers(userId);
  return (response.data as List).map((e) => TeamMember.fromJson(e)).toList();
});

final referralEarningsProvider = FutureProvider.autoDispose<List<ReferralCommission>>((ref) async {
  final userId = ref.watch(authProvider).userId;
  if (userId == null) throw Exception("User not logged in");
  
  final apiService = ref.read(apiServiceProvider);
  final response = await apiService.getReferralEarnings(userId);
  return (response.data as List).map((e) => ReferralCommission.fromJson(e)).toList();
});

final leaderboardProvider = FutureProvider.autoDispose<List<LeaderboardEntry>>((ref) async {
  final apiService = ref.read(apiServiceProvider);
  final response = await apiService.getLeaderboard();
  return (response.data as List).map((e) => LeaderboardEntry.fromJson(e)).toList();
});
