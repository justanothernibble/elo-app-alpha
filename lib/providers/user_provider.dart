import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/supabase_service.dart';
import '../services/item_service.dart';

class UserProvider extends ChangeNotifier {
  // Current user state
  User? _currentUser;
  bool _isInitialized = false;
  bool _isLoading = false;
  String? _error;

  // Getters
  User? get currentUser => _currentUser;
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  String? get error => _error;

  bool get hasUser => _currentUser != null;
  bool get hasError => _error != null;
  bool get isLoggedIn => _currentUser != null;

  /// Initialize user session
  Future<void> initializeUser({String? userName}) async {
    try {
      _setLoading(true);
      _clearError();

      // Generate or retrieve session ID
      final sessionId = ItemService.generateSessionId();

      // Try to get existing user
      User? user = await SupabaseService.getUser(sessionId);

      if (user == null) {
        // Create new user
        user = User(
          id: sessionId,
          name: userName,
          createdAt: DateTime.now(),
          lastActive: DateTime.now(),
          totalRankings: 0,
          totalRankingsCompleted: 0,
          categoriesExplored: {},
          rankingHistory: {},
          recentChoices: [],
        );

        await SupabaseService.saveUser(user);
      }

      _currentUser = user;
      _isInitialized = true;

      _notifyListeners();
    } catch (e) {
      _setError('Failed to initialize user: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Update user after ranking
  Future<void> updateUserAfterRanking({
    required String category,
    required String selectedItemId,
  }) async {
    if (_currentUser == null) return;

    try {
      final updatedUser = _currentUser!.updateRanking(category, selectedItemId);
      updatedUser.exploreCategory(category);

      await SupabaseService.saveUser(updatedUser);

      _currentUser = updatedUser;
      _notifyListeners();
    } catch (e) {
      _setError('Failed to update user: $e');
    }
  }

  /// Update user activity
  Future<void> updateActivity() async {
    if (_currentUser == null) return;

    try {
      final updatedUser = _currentUser!.copyWith(lastActive: DateTime.now());

      await SupabaseService.saveUser(updatedUser);

      _currentUser = updatedUser;
      _notifyListeners();
    } catch (e) {
      // Silently fail for activity updates
      debugPrint('Failed to update activity: $e');
    }
  }

  /// Set user name
  Future<void> setUserName(String name) async {
    if (_currentUser == null) return;

    try {
      final updatedUser = _currentUser!.copyWith(name: name);

      await SupabaseService.saveUser(updatedUser);

      _currentUser = updatedUser;
      _notifyListeners();
    } catch (e) {
      _setError('Failed to update user name: $e');
    }
  }

  /// Get user statistics
  UserStatistics getUserStatistics() {
    if (_currentUser == null) {
      return UserStatistics.empty();
    }

    final user = _currentUser!;

    return UserStatistics(
      totalRankings: user.totalRankings,
      totalRankingsCompleted: user.totalRankingsCompleted,
      categoriesExplored: user.categoriesExplored.length,
      rankingHistory: user.rankingHistory,
      lastActive: user.lastActive,
      memberSince: user.createdAt,
      averageRankingsPerCategory: user.rankingHistory.isNotEmpty
          ? (user.totalRankings / user.rankingHistory.length).round()
          : 0,
      mostActiveCategory: user.rankingHistory.isNotEmpty
          ? user.rankingHistory.entries
                .reduce((a, b) => a.value > b.value ? a : b)
                .key
          : null,
    );
  }

  /// Get recent activity
  List<UserActivity> getRecentActivity() {
    if (_currentUser == null) return [];

    final activities = <UserActivity>[];

    // Add ranking history as activities
    for (final entry in _currentUser!.rankingHistory.entries) {
      activities.add(
        UserActivity(
          type: UserActivityType.ranking,
          category: entry.key,
          details: '${entry.value} rankings completed',
          timestamp: _currentUser!.lastActive,
        ),
      );
    }

    // Add recent choices as activities
    for (final choice in _currentUser!.recentChoices) {
      activities.add(
        UserActivity(
          type: UserActivityType.selection,
          category: _currentUser!.categoriesExplored.first,
          details: 'Selected item $choice',
          timestamp: _currentUser!.lastActive,
        ),
      );
    }

    // Sort by timestamp and take most recent 10
    activities.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return activities.take(10).toList();
  }

  /// Check if user has explored a category
  bool hasExploredCategory(String category) {
    return _currentUser?.categoriesExplored.contains(category) ?? false;
  }

  /// Get user's ranking count for a category
  int getRankingCountForCategory(String category) {
    return _currentUser?.rankingHistory[category] ?? 0;
  }

  /// Reset user data (for testing or new session)
  Future<void> resetUser() async {
    _currentUser = null;
    _isInitialized = false;
    _error = null;
    _notifyListeners();
  }

  /// Clear error
  void clearError() {
    _clearError();
  }

  // Private methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    _notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    _notifyListeners();
  }

  void _clearError() {
    _error = null;
    _notifyListeners();
  }

  void _notifyListeners() {
    notifyListeners();
  }

  @override
  void dispose() {
    // Clean up any resources if needed
    super.dispose();
  }
}

/// User statistics data class
class UserStatistics {
  final int totalRankings;
  final int totalRankingsCompleted;
  final int categoriesExplored;
  final Map<String, int> rankingHistory;
  final DateTime lastActive;
  final DateTime memberSince;
  final int averageRankingsPerCategory;
  final String? mostActiveCategory;

  const UserStatistics({
    required this.totalRankings,
    required this.totalRankingsCompleted,
    required this.categoriesExplored,
    required this.rankingHistory,
    required this.lastActive,
    required this.memberSince,
    required this.averageRankingsPerCategory,
    this.mostActiveCategory,
  });

  factory UserStatistics.empty() {
    return UserStatistics(
      totalRankings: 0,
      totalRankingsCompleted: 0,
      categoriesExplored: 0,
      rankingHistory: {},
      lastActive: DateTime.now(),
      memberSince: DateTime.now(),
      averageRankingsPerCategory: 0,
    );
  }

  bool get isNewUser => totalRankings == 0;
  bool get isActiveUser => totalRankings > 10;
  bool get isVeteranUser => totalRankings > 100;

  String get experienceLevel {
    if (isNewUser) return 'Newbie';
    if (isActiveUser) return 'Active';
    if (isVeteranUser) return 'Veteran';
    return 'Beginner';
  }

  Duration get memberDuration => DateTime.now().difference(memberSince);
  Duration get lastActiveDuration => DateTime.now().difference(lastActive);

  String get lastActiveFormatted {
    final duration = lastActiveDuration;
    if (duration.inMinutes < 1) return 'Just now';
    if (duration.inHours < 1) return '${duration.inMinutes} minutes ago';
    if (duration.inDays < 1) return '${duration.inHours} hours ago';
    return '${duration.inDays} days ago';
  }
}

/// User activity data class
class UserActivity {
  final UserActivityType type;
  final String category;
  final String details;
  final DateTime timestamp;

  const UserActivity({
    required this.type,
    required this.category,
    required this.details,
    required this.timestamp,
  });
}

enum UserActivityType { ranking, selection, categoryExploration, profileUpdate }
