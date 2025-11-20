import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/item.dart';
import '../models/elo_change.dart';
import '../models/user.dart' as app_user;

class SupabaseService {
  static SupabaseClient? _client;

  // Initialize Supabase - call this at app startup
  static Future<void> initialize({
    required String supabaseUrl,
    required String supabaseKey,
  }) async {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
    _client = Supabase.instance.client;
  }

  static SupabaseClient get client {
    if (_client == null) {
      throw Exception(
        'Supabase not initialized. Call SupabaseService.initialize() first.',
      );
    }
    return _client!;
  }

  // Items Operations
  static Future<List<Item>> getItemsByCategory({
    required String category,
    String? subCategory,
    int limit = 50,
  }) async {
    try {
      List<dynamic> response;

      if (subCategory != null) {
        response = await client
            .from('items')
            .select()
            .eq('category', category)
            .eq('sub_category', subCategory)
            .limit(limit)
            .order('elo', ascending: false);
      } else {
        response = await client
            .from('items')
            .select()
            .eq('category', category)
            .limit(limit)
            .order('elo', ascending: false);
      }

      return response.map((json) => Item.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to fetch items: $e');
    }
  }

  static Future<Item?> getRandomItem({
    required String category,
    String? subCategory,
  }) async {
    try {
      List<dynamic> response;

      if (subCategory != null) {
        response = await client
            .from('items')
            .select()
            .eq('category', category)
            .eq('sub_category', subCategory);
      } else {
        response = await client.from('items').select().eq('category', category);
      }

      final items = response.map((json) => Item.fromJson(json)).toList();

      if (items.isEmpty) return null;

      // Get a random item
      final random =
          items[(items.length *
                  (DateTime.now().millisecondsSinceEpoch % items.length) /
                  items.length)
              .floor()];
      return random;
    } catch (e) {
      throw Exception('Failed to fetch random item: $e');
    }
  }

  static Future<List<Item>> getRandomItemPairForComparison({
    required String category,
    String? subCategory,
  }) async {
    try {
      List<dynamic> response;

      if (subCategory != null) {
        response = await client
            .from('items')
            .select()
            .eq('category', category)
            .eq('sub_category', subCategory);
      } else {
        response = await client.from('items').select().eq('category', category);
      }

      final items = response.map((json) => Item.fromJson(json)).toList();

      if (items.length < 2) throw Exception('Not enough items for comparison');

      // Get two different random items
      final randomIndex1 = DateTime.now().millisecondsSinceEpoch % items.length;
      int randomIndex2 = (randomIndex1 + 1) % items.length;

      // Ensure different items
      if (items.length > 2) {
        randomIndex2 =
            (randomIndex1 +
                DateTime.now().millisecondsSinceEpoch % (items.length - 1) +
                1) %
            items.length;
      }

      return [items[randomIndex1], items[randomIndex2]];
    } catch (e) {
      throw Exception('Failed to fetch item pair: $e');
    }
  }

  static Future<Item> updateItemElo(int itemId, int newElo) async {
    try {
      final response = await client
          .from('items')
          .update({
            'elo': newElo,
            'last_updated': DateTime.now().toIso8601String(),
          })
          .eq('id', itemId)
          .select()
          .single();

      return Item.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update item Elo: $e');
    }
  }

  // Elo Change Logging
  static Future<void> logEloChange(EloChange change) async {
    try {
      await client.from('elo_change_log').insert({
        'item_id': change.itemId,
        'elo_before': change.eloBefore,
        'elo_after': change.eloAfter,
        'timestamp': change.timestamp.toIso8601String(),
        'user_action': change.userAction,
        'reason': change.reason,
        'winner_item_id': change.winnerItemId,
      });
    } catch (e) {
      throw Exception('Failed to log Elo change: $e');
    }
  }

  static Future<List<EloChange>> getEloChangeHistory(
    int itemId, {
    int limit = 10,
  }) async {
    try {
      final response = await client
          .from('elo_change_log')
          .select()
          .eq('item_id', itemId)
          .order('timestamp', ascending: false)
          .limit(limit);

      return response.map((json) => EloChange.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to fetch Elo change history: $e');
    }
  }

  // User Operations
  static Future<void> saveUser(app_user.User user) async {
    try {
      await client.from('users').upsert({
        'id': user.id,
        'name': user.name,
        'created_at': user.createdAt.toIso8601String(),
        'last_active': user.lastActive.toIso8601String(),
        'total_rankings': user.totalRankings,
        'total_rankings_completed': user.totalRankingsCompleted,
        'categories_explored': user.categoriesExplored.toList(),
        'ranking_history': user.rankingHistory,
        'recent_choices': user.recentChoices,
      });
    } catch (e) {
      throw Exception('Failed to save user: $e');
    }
  }

  static Future<app_user.User?> getUser(String userId) async {
    try {
      final response = await client
          .from('users')
          .select()
          .eq('id', userId)
          .maybeSingle();

      return response != null ? app_user.User.fromJson(response) : null;
    } catch (e) {
      return null; // User doesn't exist yet
    }
  }

  // Real-time Subscriptions
  static RealtimeChannel subscribeToItemUpdates(
    String category, {
    required Function(Item updatedItem) onItemUpdate,
    required Function() onError,
  }) {
    var channel = client
        .channel('item_updates')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'items',
          callback: (payload) {
            if (payload.newRecord['category'] == category) {
              final updatedItem = Item.fromJson(payload.newRecord);
              onItemUpdate(updatedItem);
            }
          },
        )
        .subscribe();

    return channel;
  }

  static RealtimeChannel subscribeToEloChanges(
    String category, {
    required Function(EloChange change) onEloChange,
    required Function() onError,
  }) {
    var channel = client
        .channel('elo_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'elo_change_log',
          callback: (payload) {
            final change = EloChange.fromJson(payload.newRecord);
            // Filter changes by category (need to join with items table)
            onEloChange(change);
          },
        )
        .subscribe();

    return channel;
  }

  // Utility methods
  static List<String> getAvailableCategories() {
    // These would typically come from the database
    // For now, returning static categories
    return [
      'Phones',
      'Memes',
      'Movies',
      'Actors',
      'Cars',
      'Games',
      'Food',
      'Sports',
    ];
  }

  static List<String> getSubCategories(String category) {
    final subCategories = {
      'Phones': ['Android Phones', 'iPhone', 'Budget Phones', 'Gaming Phones'],
      'Movies': ['Action', 'Comedy', 'Drama', 'Horror', 'Sci-Fi'],
      'Actors': [
        'Action Stars',
        'Comedians',
        'Dramatic Actors',
        'International',
      ],
      'Games': ['RPG', 'FPS', 'Strategy', 'Mobile', 'Indie'],
      'Food': ['Fast Food', 'Fine Dining', 'Desserts', 'Cuisines'],
    };

    return subCategories[category] ?? [];
  }
}
