class User {
  final String id; // Session-based ID, not requiring authentication
  final String? name;
  final DateTime createdAt;
  final DateTime lastActive;
  final int totalRankings;
  final int totalRankingsCompleted;
  final Set<String> categoriesExplored;
  final Map<String, int> rankingHistory; // category -> count
  final List<String> recentChoices; // Recent item selections

  const User({
    required this.id,
    this.name,
    required this.createdAt,
    required this.lastActive,
    required this.totalRankings,
    required this.totalRankingsCompleted,
    required this.categoriesExplored,
    required this.rankingHistory,
    required this.recentChoices,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      name: json['name'],
      createdAt: DateTime.parse(
        json['created_at'] ?? DateTime.now().toIso8601String(),
      ),
      lastActive: DateTime.parse(
        json['last_active'] ?? DateTime.now().toIso8601String(),
      ),
      totalRankings: json['total_rankings'] ?? 0,
      totalRankingsCompleted: json['total_rankings_completed'] ?? 0,
      categoriesExplored: Set<String>.from(json['categories_explored'] ?? []),
      rankingHistory: Map<String, int>.from(json['ranking_history'] ?? {}),
      recentChoices: List<String>.from(json['recent_choices'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'created_at': createdAt.toIso8601String(),
      'last_active': lastActive.toIso8601String(),
      'total_rankings': totalRankings,
      'total_rankings_completed': totalRankingsCompleted,
      'categories_explored': categoriesExplored.toList(),
      'ranking_history': rankingHistory,
      'recent_choices': recentChoices,
    };
  }

  User copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    DateTime? lastActive,
    int? totalRankings,
    int? totalRankingsCompleted,
    Set<String>? categoriesExplored,
    Map<String, int>? rankingHistory,
    List<String>? recentChoices,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      lastActive: lastActive ?? this.lastActive,
      totalRankings: totalRankings ?? this.totalRankings,
      totalRankingsCompleted:
          totalRankingsCompleted ?? this.totalRankingsCompleted,
      categoriesExplored: categoriesExplored ?? this.categoriesExplored,
      rankingHistory: rankingHistory ?? this.rankingHistory,
      recentChoices: recentChoices ?? this.recentChoices,
    );
  }

  // Utility methods
  User updateRanking(String category, String selectedItemId) {
    final newRankingHistory = Map<String, int>.from(rankingHistory);
    newRankingHistory[category] = (newRankingHistory[category] ?? 0) + 1;

    final newRecentChoices = List<String>.from(recentChoices);
    newRecentChoices.add(selectedItemId);
    // Keep only last 10 choices
    if (newRecentChoices.length > 10) {
      newRecentChoices.removeAt(0);
    }

    return copyWith(
      lastActive: DateTime.now(),
      totalRankings: totalRankings + 1,
      totalRankingsCompleted: totalRankingsCompleted + 1,
      rankingHistory: newRankingHistory,
      recentChoices: newRecentChoices,
    );
  }

  User exploreCategory(String category) {
    final newCategories = Set<String>.from(categoriesExplored);
    newCategories.add(category);

    return copyWith(
      lastActive: DateTime.now(),
      categoriesExplored: newCategories,
    );
  }

  @override
  String toString() {
    return 'User(id: $id, name: $name, totalRankings: $totalRankings, categoriesExplored: ${categoriesExplored.length})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
