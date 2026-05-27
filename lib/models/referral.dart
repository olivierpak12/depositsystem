class ReferralStats {
  final int totalTeamMembers;
  final int levelA;
  final int levelB;
  final int levelC;
  final double totalTeamDeposit;
  final double totalTeamWithdraw;
  final double referralBalance;
  final double totalReferralEarnings;
  final double todayEarnings;
  final int activeMembers;

  ReferralStats({
    required this.totalTeamMembers,
    required this.levelA,
    required this.levelB,
    required this.levelC,
    required this.totalTeamDeposit,
    required this.totalTeamWithdraw,
    required this.referralBalance,
    required this.totalReferralEarnings,
    required this.todayEarnings,
    required this.activeMembers,
  });

  factory ReferralStats.fromJson(Map<String, dynamic> json) {
    return ReferralStats(
      totalTeamMembers: json['totalTeamMembers'] ?? 0,
      levelA: json['levelA'] ?? 0,
      levelB: json['levelB'] ?? 0,
      levelC: json['levelC'] ?? 0,
      totalTeamDeposit: (json['totalTeamDeposit'] ?? 0).toDouble(),
      totalTeamWithdraw: (json['totalTeamWithdraw'] ?? 0).toDouble(),
      referralBalance: (json['referralBalance'] ?? 0).toDouble(),
      totalReferralEarnings: (json['totalReferralEarnings'] ?? 0).toDouble(),
      todayEarnings: (json['todayEarnings'] ?? 0).toDouble(),
      activeMembers: json['activeMembers'] ?? 0,
    );
  }
}

class TeamMember {
  final String username;
  final String email;
  final int level;
  final double depositAmount;
  final double withdrawAmount;
  final int joinDate;

  TeamMember({
    required this.username,
    required this.email,
    required this.level,
    required this.depositAmount,
    required this.withdrawAmount,
    required this.joinDate,
  });

  factory TeamMember.fromJson(Map<String, dynamic> json) {
    return TeamMember(
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      level: json['level'] ?? 0,
      depositAmount: (json['depositAmount'] ?? 0).toDouble(),
      withdrawAmount: (json['withdrawAmount'] ?? 0).toDouble(),
      joinDate: json['joinDate'] ?? 0,
    );
  }
}

class ReferralCommission {
  final String id;
  final String fromUserId;
  final String fromUsername;
  final int level;
  final double percent;
  final double depositAmount;
  final double commissionAmount;
  final int createdAt;

  ReferralCommission({
    required this.id,
    required this.fromUserId,
    required this.fromUsername,
    required this.level,
    required this.percent,
    required this.depositAmount,
    required this.commissionAmount,
    required this.createdAt,
  });

  factory ReferralCommission.fromJson(Map<String, dynamic> json) {
    return ReferralCommission(
      id: json['_id'] ?? '',
      fromUserId: json['fromUserId'] ?? '',
      fromUsername: json['fromUsername'] ?? '',
      level: json['level'] ?? 0,
      percent: (json['percent'] ?? 0).toDouble(),
      depositAmount: (json['depositAmount'] ?? 0).toDouble(),
      commissionAmount: (json['commissionAmount'] ?? 0).toDouble(),
      createdAt: json['createdAt'] ?? 0,
    );
  }
}

class LeaderboardEntry {
  final String username;
  final double totalEarnings;
  final int teamSize;

  LeaderboardEntry({
    required this.username,
    required this.totalEarnings,
    required this.teamSize,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      username: json['username'] ?? '',
      totalEarnings: (json['totalEarnings'] ?? 0).toDouble(),
      teamSize: json['teamSize'] ?? 0,
    );
  }
}
