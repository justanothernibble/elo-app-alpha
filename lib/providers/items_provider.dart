import 'package:flutter/foundation.dart';
import 'dart:async';
import '../models/item.dart';
import '../models/elo_change.dart';
import '../services/item_service.dart';
import '../services/supabase_service.dart';

class ItemsProvider extends ChangeNotifier {
  // Current state
  ItemPair? _currentPair;
  ItemPairInfo? _pairInfo;
  String _selectedCategory = 'Phones';
  String? _selectedSubCategory;
  bool _isLoading = false;
  bool _isProcessingRanking = false;
  String? _error;

  // Generic mutex for critical sections
  final Future<T> Function<T>(Future<T> Function() work) _criticalSection;

  ItemsProvider({Future<T> Function<T>(Future<T> Function())? mutex})
    : _criticalSection =
          mutex ?? (<T>(Future<T> Function() work) async => work());

  // Getters
  ItemPair? get currentPair => _currentPair;
  ItemPairInfo? get pairInfo => _pairInfo;
  String get selectedCategory => _selectedCategory;
  String? get selectedSubCategory => _selectedSubCategory;
  bool get isLoading => _isLoading;
  bool get isProcessingRanking => _isProcessingRanking;
  String? get error => _error;

  bool get hasCurrentPair => _currentPair != null;
  bool get hasError => _error != null;
  bool get isDataStale => _pairInfo?.isStale ?? true;

  /// Load a new random pair of items
  Future<void> loadNewPair({
    String? category,
    String? subCategory,
    bool forceRefresh = false,
  }) async {
    return _criticalSection(() async {
      try {
        _setLoading(true);
        _clearError();

        final cat = category ?? _selectedCategory;
        final subCat = subCategory ?? _selectedSubCategory;

        final pair = await ItemService.getRandomPairStatic(
          category: cat,
          subCategory: subCat,
          forceRefresh: forceRefresh,
        );

        final info = ItemService.getCurrentPairInfoStatic();

        _currentPair = pair;
        _pairInfo = info;
        _selectedCategory = cat;
        _selectedSubCategory = subCat;

        _notifyListeners();
      } catch (e) {
        _setError('Failed to load item pair: $e');
      } finally {
        _setLoading(false);
      }
    });
  }

  /// Process user ranking selection - FIXED: Now returns RankingResult?
  Future<RankingResult?> processRanking(int selectedItemIndex) async {
    if (_currentPair == null || _isProcessingRanking) {
      return null;
    }

    try {
      return await _criticalSection(() async {
        _setProcessingRanking(true);
        _clearError();

        final selectedItem = _currentPair!.items[selectedItemIndex];
        final unselectedItem = _currentPair!.items[1 - selectedItemIndex];

        final result = await ItemService.processRankingStatic(
          selectedItem: selectedItem,
          unselectedItem: unselectedItem,
          category: _selectedCategory,
          subCategory: _selectedSubCategory,
        );

        // Update current pair with new result
        _currentPair = result.newPair;
        _pairInfo = ItemService.getCurrentPairInfoStatic();

        _notifyListeners();
        return result;
      });
    } catch (e) {
      _setError('Failed to process ranking: $e');
      return null;
    } finally {
      _setProcessingRanking(false);
    }
  }

  /// Refresh current pair if data is stale
  Future<void> refreshStaleData() async {
    if (_pairInfo?.needsRefresh == true) {
      await loadNewPair(forceRefresh: true);
    }
  }

  /// Change category
  Future<void> changeCategory(String category, {String? subCategory}) async {
    _selectedCategory = category;
    _selectedSubCategory = subCategory;
    await loadNewPair(category: category, subCategory: subCategory);
  }

  /// Get items by category (for leaderboard, etc.)
  Future<List<Item>> getItemsByCategory({
    String? category,
    int limit = 50,
  }) async {
    try {
      final cat = category ?? _selectedCategory;
      return await ItemService.getItemsStatic(
        category: cat,
        subCategory: _selectedSubCategory,
        limit: limit,
      );
    } catch (e) {
      _setError('Failed to fetch items: $e');
      return [];
    }
  }

  /// Get top items in current category
  Future<List<Item>> getTopItems({int limit = 10}) async {
    try {
      return await ItemService.getTopItemsStatic(
        category: _selectedCategory,
        subCategory: _selectedSubCategory,
        limit: limit,
      );
    } catch (e) {
      _setError('Failed to fetch top items: $e');
      return [];
    }
  }

  /// Get item history
  Future<List<EloChange>> getItemHistory(int itemId, {int limit = 10}) async {
    try {
      return await ItemService.getItemHistoryStatic(
        itemId: itemId,
        limit: limit,
      );
    } catch (e) {
      _setError('Failed to fetch item history: $e');
      return [];
    }
  }

  /// Get available categories
  List<String> getAvailableCategories() {
    return SupabaseService.getAvailableCategories();
  }

  /// Get subcategories for current category
  List<String> getSubCategories() {
    return SupabaseService.getSubCategories(_selectedCategory);
  }

  /// Check if current category has enough items
  Future<bool> hasEnoughItems({int minimumItems = 2}) async {
    try {
      return await ItemService.hasEnoughItemsStatic(
        category: _selectedCategory,
        subCategory: _selectedSubCategory,
        minimumItems: minimumItems,
      );
    } catch (e) {
      return false;
    }
  }

  /// Clear current pair
  void clearCurrentPair() {
    _currentPair = null;
    _pairInfo = null;
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

  void _setProcessingRanking(bool processing) {
    _isProcessingRanking = processing;
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
