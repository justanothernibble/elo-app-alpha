import 'package:elo_app_alpha/models/item.dart';
import 'package:elo_app_alpha/services/item_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../providers/items_provider.dart';
import '../providers/user_provider.dart';

class AppProvider extends ChangeNotifier {
  final ItemsProvider _itemsProvider = ItemsProvider();
  final UserProvider _userProvider = UserProvider();

  // Global app state
  AppState _appState = AppState.initializing;
  String? _initializationError;
  bool _isConnectedToBackend = false;

  // Getters
  AppState get appState => _appState;
  String? get initializationError => _initializationError;
  bool get isConnectedToBackend => _isConnectedToBackend;

  ItemsProvider get items => _itemsProvider;
  UserProvider get user => _userProvider;

  bool get isInitialized => _appState == AppState.initialized;
  bool get isLoading => _appState == AppState.initializing;
  bool get hasError => _appState == AppState.error;
  bool get isReady =>
      _appState == AppState.initialized && _isConnectedToBackend;

  /// Initialize the entire app
  Future<void> initializeApp({
    String? userName,
    String supabaseUrl = '',
    String supabaseKey = '',
  }) async {
    try {
      _setState(AppState.initializing);
      _clearError();

      // Initialize Supabase if credentials provided
      if (supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty) {
        try {
          // Supabase initialization would go here
          _isConnectedToBackend = true;
        } catch (e) {
          _setState(AppState.error);
          _setError('Failed to connect to backend: $e');
          return;
        }
      }

      // Initialize user
      await _userProvider.initializeUser(userName: userName);

      // Load initial item pair
      await _itemsProvider.loadNewPair();

      _setState(AppState.initialized);
    } catch (e) {
      _setState(AppState.error);
      _setError('Failed to initialize app: $e');
    }
  }

  /// Process a complete ranking workflow
  Future<RankingWorkflowResult?> processRankingWorkflow(
    int selectedItemIndex,
  ) async {
    if (!isReady) {
      return null;
    }

    try {
      // Get current items
      final currentPair = _itemsProvider.currentPair;
      if (currentPair == null) return null;

      final selectedItem = currentPair.items[selectedItemIndex];
      final unselectedItem = currentPair.items[1 - selectedItemIndex];

      // Process ranking through ItemsProvider
      final result = await _itemsProvider.processRanking(selectedItemIndex);
      if (result == null) return null;

      // Update user statistics
      await _userProvider.updateUserAfterRanking(
        category: _itemsProvider.selectedCategory,
        selectedItemId: selectedItem.id.toString(),
      );

      // Update user activity
      await _userProvider.updateActivity();

      return RankingWorkflowResult(
        selectedItem: result.selectedItem,
        unselectedItem: result.unselectedItem,
        eloChange: result.eloChange,
        newPair: result.newPair,
        rankingTime: result.rankingTime,
        userStats: _userProvider.getUserStatistics(),
      );
    } catch (e) {
      debugPrint('Failed to process ranking workflow: $e');
      return null;
    }
  }

  /// Change category and refresh data
  Future<void> changeCategoryAndRefresh(
    String category, {
    String? subCategory,
  }) async {
    if (!isReady) return;

    try {
      await _itemsProvider.changeCategory(category, subCategory: subCategory);

      // Update user activity
      await _userProvider.updateActivity();

      notifyListeners();
    } catch (e) {
      debugPrint('Failed to change category: $e');
    }
  }

  /// Check for stale data and refresh if needed
  Future<void> checkAndRefreshStaleData() async {
    if (_itemsProvider.isDataStale) {
      await _itemsProvider.refreshStaleData();
    }
  }

  /// Get app-wide statistics
  AppStatistics getAppStatistics() {
    final userStats = _userProvider.getUserStatistics();
    final currentPair = _itemsProvider.currentPair;

    return AppStatistics(
      currentCategory: _itemsProvider.selectedCategory,
      currentSubCategory: _itemsProvider.selectedSubCategory,
      userRankings: userStats.totalRankings,
      userExperience: userStats.experienceLevel,
      categoriesExplored: userStats.categoriesExplored,
      hasCurrentPair: currentPair != null,
      isDataStale: _itemsProvider.isDataStale,
      isProcessingRanking: _itemsProvider.isProcessingRanking,
      appState: _appState,
      isBackendConnected: _isConnectedToBackend,
    );
  }

  /// Reset app to initial state
  Future<void> resetApp() async {
    await _userProvider.resetUser();
    _itemsProvider.clearCurrentPair();

    _appState = AppState.initializing;
    _initializationError = null;
    _isConnectedToBackend = false;

    notifyListeners();
  }

  /// Handle app lifecycle events
  void onAppLifecycleStateChanged(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // Check for stale data when app comes to foreground
        checkAndRefreshStaleData();
        break;
      case AppLifecycleState.paused:
        // Update user activity when app goes to background
        _userProvider.updateActivity();
        break;
      default:
        break;
    }
  }

  /// Set Supabase connection status
  void setBackendConnectionStatus(bool connected) {
    _isConnectedToBackend = connected;
    notifyListeners();
  }

  /// Clear errors
  void clearErrors() {
    _userProvider.clearError();
    _itemsProvider.clearError();
    _initializationError = null;
    notifyListeners();
  }

  // Private methods
  void _setState(AppState state) {
    _appState = state;
    notifyListeners();
  }

  void _setError(String error) {
    _initializationError = error;
    notifyListeners();
  }

  void _clearError() {
    _initializationError = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _itemsProvider.dispose();
    _userProvider.dispose();
    super.dispose();
  }
}

/// App states for initialization and error handling
enum AppState { initializing, initialized, error }

/// Result of processing a complete ranking workflow
class RankingWorkflowResult {
  final Item selectedItem;
  final Item unselectedItem;
  final int eloChange;
  final ItemPair newPair;
  final DateTime rankingTime;
  final UserStatistics userStats;

  const RankingWorkflowResult({
    required this.selectedItem,
    required this.unselectedItem,
    required this.eloChange,
    required this.newPair,
    required this.rankingTime,
    required this.userStats,
  });
}

/// App-wide statistics
class AppStatistics {
  final String currentCategory;
  final String? currentSubCategory;
  final int userRankings;
  final String userExperience;
  final int categoriesExplored;
  final bool hasCurrentPair;
  final bool isDataStale;
  final bool isProcessingRanking;
  final AppState appState;
  final bool isBackendConnected;

  const AppStatistics({
    required this.currentCategory,
    this.currentSubCategory,
    required this.userRankings,
    required this.userExperience,
    required this.categoriesExplored,
    required this.hasCurrentPair,
    required this.isDataStale,
    required this.isProcessingRanking,
    required this.appState,
    required this.isBackendConnected,
  });

  bool get isHealthy =>
      appState == AppState.initialized && isBackendConnected && hasCurrentPair;

  String get statusSummary {
    if (appState == AppState.error) return 'Error state';
    if (appState == AppState.initializing) return 'Loading...';
    if (!isBackendConnected) return 'Offline mode';
    if (!hasCurrentPair) return 'No items loaded';
    if (isDataStale) return 'Data needs refresh';
    if (isProcessingRanking) return 'Processing...';
    return 'Ready';
  }
}
