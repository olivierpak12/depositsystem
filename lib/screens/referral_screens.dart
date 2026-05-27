import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/referral_provider.dart';
import '../providers/auth_provider.dart';
import '../models/referral.dart';

class ReferralDashboardScreen extends ConsumerWidget {
  const ReferralDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(referralStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('AFFILIATE PROGRAM', style: GoogleFonts.orbitron(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(referralStatsProvider.future),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              statsAsync.when(
                data: (stats) => _EarningsOverviewCard(stats: stats),
                loading: () => const _LoadingCard(),
                error: (e, s) => Center(child: Text('Error: $e')),
              ),
              const SizedBox(height: 25),
              _buildQuickActions(context),
              const SizedBox(height: 30),
              Text('TEAM STATISTICS', style: GoogleFonts.orbitron(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white54)),
              const SizedBox(height: 15),
              statsAsync.when(
                data: (stats) => _TeamStatsGrid(stats: stats),
                loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
                error: (e, s) => const SizedBox(),
              ),
              const SizedBox(height: 30),
              const _ReferralCodeCard(),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _ActionCard(icon: Icons.people_outline, label: 'My Team', color: Colors.blueAccent, onTap: () => context.push('/referrals/team'))),
        const SizedBox(width: 15),
        Expanded(child: _ActionCard(icon: Icons.history_edu_outlined, label: 'Earnings', color: Colors.purpleAccent, onTap: () => context.push('/referrals/earnings'))),
        const SizedBox(width: 15),
        Expanded(child: _ActionCard(icon: Icons.leaderboard_outlined, label: 'Leaders', color: Colors.orangeAccent, onTap: () => context.push('/referrals/leaderboard'))),
      ],
    );
  }
}

class _EarningsOverviewCard extends StatelessWidget {
  final ReferralStats stats;
  const _EarningsOverviewCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [BoxShadow(color: Colors.blueAccent.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Referral Wallet Balance', style: TextStyle(color: Colors.white70, fontSize: 13, letterSpacing: 1)),
          const SizedBox(height: 8),
          Text('\$${stats.referralBalance.toStringAsFixed(2)}', style: GoogleFonts.orbitron(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSmallStat('Today Earnings', '\$${stats.todayEarnings.toStringAsFixed(2)}'),
              _buildSmallStat('Total Earnings', '\$${stats.totalReferralEarnings.toStringAsFixed(2)}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmallStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _TeamStatsGrid extends StatelessWidget {
  final ReferralStats stats;
  const _TeamStatsGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.6,
      mainAxisSpacing: 15,
      crossAxisSpacing: 15,
      children: [
        _buildStatTile('Total Team', stats.totalTeamMembers.toString(), Icons.group),
        _buildStatTile('Active Members', stats.activeMembers.toString(), Icons.bolt, color: Colors.greenAccent),
        _buildStatTile('Team Deposits', '\$${stats.totalTeamDeposit.toStringAsFixed(0)}', Icons.arrow_downward, color: Colors.greenAccent),
        _buildStatTile('Team Withdraws', '\$${stats.totalTeamWithdraw.toStringAsFixed(0)}', Icons.arrow_upward, color: Colors.orangeAccent),
      ],
    );
  }

  Widget _buildStatTile(String label, String value, IconData icon, {Color color = Colors.blueAccent}) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _ReferralCodeCard extends ConsumerWidget {
  const _ReferralCodeCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final String code = authState.referralCode ?? "---"; 
    final String link = authState.referralLink ?? "https://cryptovault.com/register?ref=$code";

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          const Text('INVITE FRIENDS', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
          const SizedBox(height: 20),
          _buildCopyField('Referral Code', code, context),
          const SizedBox(height: 15),
          _buildCopyField('Invitation Link', link, context),
          const SizedBox(height: 25),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: code == "---" ? null : () {
                Share.share("Join me on CryptoVault! Use my code $code to get bonuses. Register here: $link");
              },
              icon: const Icon(Icons.share),
              label: const Text('Share Invitation'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCopyField(String label, String value, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
        const SizedBox(height: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
          decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 10),
              InkWell(
                onTap: value == "---" ? null : () {
                  Clipboard.setData(ClipboardData(text: value));
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label copied!')));
                },
                child: const Icon(Icons.copy, size: 18, color: Colors.greenAccent),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class TeamMembersScreen extends ConsumerWidget {
  const TeamMembersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(teamMembersProvider);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('MY TEAM'),
          bottom: const TabBar(
            indicatorColor: Colors.greenAccent,
            labelColor: Colors.greenAccent,
            unselectedLabelColor: Colors.white54,
            tabs: [
              Tab(text: 'Team A'),
              Tab(text: 'Team B'),
              Tab(text: 'Team C'),
            ],
          ),
        ),
        body: membersAsync.when(
          data: (members) {
            final teamA = members.where((m) => m.level == 1).toList();
            final teamB = members.where((m) => m.level == 2).toList();
            final teamC = members.where((m) => m.level == 3).toList();

            return TabBarView(
              children: [
                _TeamListView(members: teamA, emptyMessage: 'No level A members yet.'),
                _TeamListView(members: teamB, emptyMessage: 'No level B members yet.'),
                _TeamListView(members: teamC, emptyMessage: 'No level C members yet.'),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, s) => Center(child: Text('Error: $e')),
        ),
      ),
    );
  }
}

class _TeamListView extends StatelessWidget {
  final List<TeamMember> members;
  final String emptyMessage;
  const _TeamListView({required this.members, required this.emptyMessage});

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Text(emptyMessage, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white38)),
      ));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: members.length,
      itemBuilder: (context, index) {
        final member = members[index];
        return _TeamMemberTile(member: member);
      },
    );
  }
}

class _TeamMemberTile extends StatelessWidget {
  final TeamMember member;
  const _TeamMemberTile({required this.member});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: _getLevelColor(member.level).withValues(alpha: 0.1),
            child: Text(
              _getLevelLabel(member.level), 
              style: TextStyle(color: _getLevelColor(member.level), fontWeight: FontWeight.bold, fontSize: 12)
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(member.username, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(member.email, style: const TextStyle(color: Colors.white38, fontSize: 12)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('\$${member.depositAmount.toStringAsFixed(0)}', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
              const Text('Deposit', style: TextStyle(color: Colors.white38, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  Color _getLevelColor(int level) {
    if (level == 1) return Colors.greenAccent;
    if (level == 2) return Colors.blueAccent;
    return Colors.purpleAccent;
  }

  String _getLevelLabel(int level) {
    if (level == 1) return 'A';
    if (level == 2) return 'B';
    return 'C';
  }
}

class ReferralEarningsScreen extends ConsumerWidget {
  const ReferralEarningsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final earningsAsync = ref.watch(referralEarningsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('EARNING HISTORY')),
      body: earningsAsync.when(
        data: (earnings) {
          if (earnings.isEmpty) return const Center(child: Text('No earnings yet.'));
          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: earnings.length,
            itemBuilder: (context, index) {
              final item = earnings[index];
              return _EarningTile(item: item);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _EarningTile extends StatelessWidget {
  final ReferralCommission item;
  const _EarningTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Level ${item.level} Commission', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text('From ${item.fromUsername}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('+\$${item.commissionAmount.toStringAsFixed(2)}', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 16)),
              Text('${item.percent}% of \$${item.depositAmount}', style: const TextStyle(color: Colors.white38, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaderboardAsync = ref.watch(leaderboardProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('TOP EARNERS')),
      body: leaderboardAsync.when(
        data: (list) {
          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final entry = list[index];
              return _LeaderboardTile(entry: entry, rank: index + 1);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _LeaderboardTile extends StatelessWidget {
  final LeaderboardEntry entry;
  final int rank;
  const _LeaderboardTile({required this.entry, required this.rank});

  @override
  Widget build(BuildContext context) {
    bool isTop3 = rank <= 3;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isTop3 ? Colors.greenAccent.withValues(alpha: 0.05) : const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
        border: isTop3 ? Border.all(color: Colors.greenAccent.withValues(alpha: 0.2)) : null,
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            alignment: Alignment.center,
            child: Text('#$rank', style: TextStyle(
              fontWeight: FontWeight.bold, 
              color: isTop3 ? Colors.greenAccent : Colors.white38,
              fontSize: 16
            )),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.username, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('Team Size: ${entry.teamSize}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
          Text('\$${entry.totalEarnings.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.greenAccent)),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionCard({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 10),
            Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(30),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}
