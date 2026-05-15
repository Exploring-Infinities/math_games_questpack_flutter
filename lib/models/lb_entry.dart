class LbEntry {
  const LbEntry({
    required this.id,
    required this.name,
    required this.level,
    required this.totalSolved,
    required this.totalCorrect,
  });

  final String id;
  final String name;
  final int level;
  final int totalSolved;
  final int totalCorrect;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'level': level,
        'totalSolved': totalSolved,
        'totalCorrect': totalCorrect,
      };

  factory LbEntry.fromJson(Map<String, dynamic> j) {
    return LbEntry(
      id: j['id'] as String? ?? '',
      name: j['name'] as String? ?? '',
      level: (j['level'] as num?)?.toInt() ?? 0,
      totalSolved: (j['totalSolved'] as num?)?.toInt() ?? 0,
      totalCorrect: (j['totalCorrect'] as num?)?.toInt() ?? 0,
    );
  }
}
