import 'package:uuid/uuid.dart';
import '../models/item.dart';
import '../models/elo_change.dart';
import '../services/supabase_service.dart';
import '../services/elo_service.dart';

/// Simple mutex implementation for thread safety
class _SimpleLock {
  bool _isLocked = false;

  Future<T> synchronized<T>(Future<T> Function() operation) async {
    while (_isLocked) {
      await Future.delayed(const Duration(milliseconds: 1));
    }

    _isLocked = true;
    try {
      return await operation();
    } finally {
      _isLocked = false;
    }
  }
}

/// Thread-safe instance-based ItemService with static API compatibility
class ItemService {
  static final ItemService _instance = ItemService._internal();
  static final _SimpleLock _rankLock = _SimpleLock();

  factory ItemService() => _instance;
  ItemService._internal();

  static const Uuid _uuid = Uuid();
  static const Duration staleDataThreshold = Duration(minutes: 5);

  // Current active pair for comparison (instance state)
  ItemPair? _currentPair;
  DateTime _lastPairUpdate = DateTime.now();
  bool _isProcessingRanking = false;

  /// Instance-based methods for dependency injection
  /// Get a new random pair of items for comparison
  Future<ItemPair> getRandomPair({
    required String category,
    String? subCategory,
    bool forceRefresh = false,
  }) async {
    try {
      // Check if current pair is stale
      if (!forceRefresh &&
          _currentPair != null &&
          DateTime.now().difference(_lastPairUpdate) < staleDataThreshold) {
        return _currentPair!;
      }

      // Fetch new pair from database
      final items = await SupabaseService.getRandomItemPairForComparison(
        category: category,
        subCategory: subCategory,
      );

      if (items.length != 2) {
        throw Exception(
          'Could not fetch enough items for comparison. Found: ${items.length}',
        );
      }

      _currentPair = ItemPair(
        item1: items[0],
        item2: items[1],
        category: category,
        subCategory: subCategory,
        createdAt: DateTime.now(),
      );

      _lastPairUpdate = DateTime.now();
      return _currentPair!;
    } catch (e) {
      throw Exception('Failed to get random pair: $e');
    }
  }

  /// Process a user ranking selection with mutex protection
  Future<RankingResult> processRanking({
    required Item selectedItem,
    required Item unselectedItem,
    required String category,
    String? subCategory,
    bool advancedElo = false,
  }) async {
    return _rankLock.synchronized(() async {
      if (_isProcessingRanking) {
        throw Exception('Already processing a ranking. Please wait.');
      }

      _isProcessingRanking = true;

      try {
        final result = advancedElo
            ? EloService.calculateEloChangeAdvanced(
                selectedItem,
                unselectedItem,
              )
            : EloService.calculateEloChange(selectedItem, unselectedItem);

        // Update items in database
        final updatedWinner = await SupabaseService.updateItemElo(
          result.winner.id,
          result.winner.elo,
        );

        final updatedLoser = await SupabaseService.updateItemElo(
          result.loser.id,
          result.loser.elo,
        );

        // Log changes to database
        final winnerChange = result.winnerChange.copyWith(id: 0);
        final loserChange = result.loserChange.copyWith(id: 0);

        await SupabaseService.logEloChange(winnerChange);
        await SupabaseService.logEloChange(loserChange);

        // Prepare new pair
        final newPair = await getRandomPair(
          category: category,
          subCategory: subCategory,
          forceRefresh: true,
        );

        return RankingResult(
          selectedItem: updatedWinner,
          unselectedItem: updatedLoser,
          eloChange: result.eloChange,
          newPair: newPair,
          rankingTime: DateTime.now(),
        );
      } catch (e) {
        throw Exception('Failed to process ranking: $e');
      } finally {
        _isProcessingRanking = false;
      }
    });
  }

  /// Check if current data is stale
  bool isCurrentDataStale() {
    if (_currentPair == null) return true;
    return DateTime.now().difference(_lastPairUpdate) > staleDataThreshold;
  }

  /// Get current pair with freshness information
  ItemPairInfo getCurrentPairInfo() {
    final isStale = isCurrentDataStale();
    final timeSinceUpdate = DateTime.now().difference(_lastPairUpdate);
    final minutesSinceUpdate = timeSinceUpdate.inMinutes;
    final secondsSinceUpdate = timeSinceUpdate.inSeconds;

    return ItemPairInfo(
      pair: _currentPair,
      isStale: isStale,
      timeSinceUpdate: timeSinceUpdate,
      minutesSinceUpdate: minutesSinceUpdate,
      secondsSinceUpdate: secondsSinceUpdate,
      needsRefresh: isStale || _currentPair == null,
    );
  }

  /// Refresh the current pair
  Future<ItemPair> refreshCurrentPair() async {
    if (_currentPair == null) {
      throw Exception('No current pair to refresh');
    }

    return await getRandomPair(
      category: _currentPair!.category,
      subCategory: _currentPair!.subCategory,
      forceRefresh: true,
    );
  }

  /// Get items by category with corrected pagination
  Future<List<Item>> getItems({
    required String category,
    String? subCategory,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      // Fixed pagination: Let Supabase handle offset properly
      final items = await SupabaseService.getItemsByCategory(
        category: category,
        subCategory: subCategory,
        limit: limit + offset, // Get enough items for offset
      );

      if (offset >= items.length) {
        return []; // Return empty if offset is beyond available items
      }

      // Apply client-side offset only if necessary
      if (offset > 0) {
        return items.skip(offset).take(limit).toList();
      }

      return items.take(limit).toList();
    } catch (e) {
      throw Exception('Failed to fetch items: $e');
    }
  }

  /// Get top items in a category
  Future<List<Item>> getTopItems({
    required String category,
    String? subCategory,
    int limit = 10,
  }) async {
    try {
      final items = await getItems(
        category: category,
        subCategory: subCategory,
        limit: limit * 2, // Get more to ensure we have enough
      );

      // Sort by Elo descending and take top items
      items.sort((a, b) => b.elo.compareTo(a.elo));
      return items.take(limit).toList();
    } catch (e) {
      throw Exception('Failed to fetch top items: $e');
    }
  }

  /// Get random item from category for detailed view
  Future<Item?> getRandomItemFromCategory({
    required String category,
    String? subCategory,
  }) async {
    try {
      return await SupabaseService.getRandomItem(
        category: category,
        subCategory: subCategory,
      );
    } catch (e) {
      throw Exception('Failed to fetch random item: $e');
    }
  }

  /// Get Elo change history for an item
  Future<List<EloChange>> getItemHistory({
    required int itemId,
    int limit = 10,
  }) async {
    try {
      return await SupabaseService.getEloChangeHistory(itemId, limit: limit);
    } catch (e) {
      throw Exception('Failed to fetch item history: $e');
    }
  }

  /// Check if there's enough data for comparison in a category
  Future<bool> hasEnoughItems({
    required String category,
    String? subCategory,
    int minimumItems = 2,
  }) async {
    try {
      final items = await getItems(
        category: category,
        subCategory: subCategory,
        limit: minimumItems,
      );
      return items.length >= minimumItems;
    } catch (e) {
      return false;
    }
  }

  /// Generate unique session ID for user (static for compatibility)
  static String generateSessionId() {
    return _uuid.v4();
  }

  /// Get available categories (static for compatibility)
  static List<String> getAvailableCategories() {
    return SupabaseService.getAvailableCategories();
  }

  /// Get subcategories for a category (static for compatibility)
  static List<String> getSubCategories(String category) {
    return SupabaseService.getSubCategories(category);
  }

  // Legacy static API compatibility (delegates to instance)
  static Future<ItemPair> getRandomPairStatic({
    required String category,
    String? subCategory,
    bool forceRefresh = false,
  }) => _instance.getRandomPair(
    category: category,
    subCategory: subCategory,
    forceRefresh: forceRefresh,
  );

  static Future<RankingResult> processRankingStatic({
    required Item selectedItem,
    required Item unselectedItem,
    required String category,
    String? subCategory,
    bool advancedElo = false,
  }) => _instance.processRanking(
    selectedItem: selectedItem,
    unselectedItem: unselectedItem,
    category: category,
    subCategory: subCategory,
    advancedElo: advancedElo,
  );

  static bool isCurrentDataStaleStatic() => _instance.isCurrentDataStale();

  static ItemPairInfo getCurrentPairInfoStatic() =>
      _instance.getCurrentPairInfo();

  static Future<ItemPair> refreshCurrentPairStatic() =>
      _instance.refreshCurrentPair();

  static Future<List<Item>> getItemsStatic({
    required String category,
    String? subCategory,
    int limit = 50,
    int offset = 0,
  }) => _instance.getItems(
    category: category,
    subCategory: subCategory,
    limit: limit,
    offset: offset,
  );

  static Future<List<Item>> getTopItemsStatic({
    required String category,
    String? subCategory,
    int limit = 10,
  }) => _instance.getTopItems(
    category: category,
    subCategory: subCategory,
    limit: limit,
  );

  static Future<Item?> getRandomItemFromCategoryStatic({
    required String category,
    String? subCategory,
  }) => _instance.getRandomItemFromCategory(
    category: category,
    subCategory: subCategory,
  );

  static Future<List<EloChange>> getItemHistoryStatic({
    required int itemId,
    int limit = 10,
  }) => _instance.getItemHistory(itemId: itemId, limit: limit);

  static Future<bool> hasEnoughItemsStatic({
    required String category,
    String? subCategory,
    int minimumItems = 2,
  }) => _instance.hasEnoughItems(
    category: category,
    subCategory: subCategory,
    minimumItems: minimumItems,
  );
}

/// Represents a pair of items for comparison
class ItemPair {
  final Item item1;
  final Item item2;
  final String category;
  final String? subCategory;
  final DateTime createdAt;
  final String id;

  ItemPair({
    required this.item1,
    required this.item2,
    required this.category,
    this.subCategory,
    required this.createdAt,
    String? id,
  }) : id = id ?? Uuid().v4();

  List<Item> get items => [item1, item2];
  Item getItem(int index) => items[index];
  bool containsItem(int itemId) => item1.id == itemId || item2.id == itemId;

  @override
  String toString() {
    return 'ItemPair($item1 vs $item2 in $category)';
  }
}

/// Result of processing a ranking
class RankingResult {
  final Item selectedItem;
  final Item unselectedItem;
  final int eloChange;
  final ItemPair newPair;
  final DateTime rankingTime;

  const RankingResult({
    required this.selectedItem,
    required this.unselectedItem,
    required this.eloChange,
    required this.newPair,
    required this.rankingTime,
  });
}

/// Information about current pair state
class ItemPairInfo {
  final ItemPair? pair;
  final bool isStale;
  final Duration timeSinceUpdate;
  final int minutesSinceUpdate;
  final int secondsSinceUpdate;
  final bool needsRefresh;

  const ItemPairInfo({
    required this.pair,
    required this.isStale,
    required this.timeSinceUpdate,
    required this.minutesSinceUpdate,
    required this.secondsSinceUpdate,
    required this.needsRefresh,
  });

  String get refreshMessage {
    if (pair == null) return 'Loading items...';
    if (isStale) {
      return 'Time has passed, and the Elo has changed. Click here to refresh.';
    }
    return 'Items loaded successfully';
  }
}
