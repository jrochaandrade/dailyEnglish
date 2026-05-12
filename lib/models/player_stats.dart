class PlayerStats {
  final int xp;
  final int level;
  final int streak;
  final int shields;
  final String? lastActivityDate;
  final bool streakAtRisk;
  final String gamesPlayedToday;

  const PlayerStats({
    this.xp = 0,
    this.level = 1,
    this.streak = 0,
    this.shields = 0,
    this.lastActivityDate,
    this.streakAtRisk = false,
    this.gamesPlayedToday = '',
  });

  factory PlayerStats.fromMap(Map<String, dynamic> map) => PlayerStats(
        xp: map['xp'] as int? ?? 0,
        level: map['level'] as int? ?? 1,
        streak: map['streak'] as int? ?? 0,
        shields: map['shields'] as int? ?? 0,
        lastActivityDate: map['last_activity_date'] as String?,
        streakAtRisk: (map['streak_at_risk'] as int? ?? 0) == 1,
        gamesPlayedToday: map['games_played_today'] as String? ?? '',
      );

  Map<String, dynamic> toMap() => {
        'id': 1,
        'xp': xp,
        'level': level,
        'streak': streak,
        'shields': shields,
        'last_activity_date': lastActivityDate,
        'streak_at_risk': streakAtRisk ? 1 : 0,
        'games_played_today': gamesPlayedToday,
      };

  PlayerStats copyWith({
    int? xp,
    int? level,
    int? streak,
    int? shields,
    String? lastActivityDate,
    bool? streakAtRisk,
    String? gamesPlayedToday,
  }) =>
      PlayerStats(
        xp: xp ?? this.xp,
        level: level ?? this.level,
        streak: streak ?? this.streak,
        shields: shields ?? this.shields,
        lastActivityDate: lastActivityDate ?? this.lastActivityDate,
        streakAtRisk: streakAtRisk ?? this.streakAtRisk,
        gamesPlayedToday: gamesPlayedToday ?? this.gamesPlayedToday,
      );
}
