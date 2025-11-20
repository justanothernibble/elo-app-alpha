import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/item.dart';

class ItemCard extends StatelessWidget {
  final Item item;
  final bool isSelected;
  final bool isHighlighted;
  final VoidCallback? onTap;
  final bool showEloAnimation;
  final int? previousElo;

  const ItemCard({
    super.key,
    required this.item,
    this.isSelected = false,
    this.isHighlighted = false,
    this.onTap,
    this.showEloAnimation = false,
    this.previousElo,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isWeb = screenWidth > 800;

    return Card(
      elevation: isHighlighted ? 8 : 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? theme.colorScheme.primary : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.all(isWeb ? 24 : 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colorScheme.surface,
                theme.colorScheme.surface.withOpacity(0.8),
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Item Image or Icon Placeholder
              _buildItemImage(theme, isWeb),

              const SizedBox(height: 16),

              // Item Name
              Text(
                item.name,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 8),

              // Category and Subcategory
              _buildCategoryInfo(theme),

              const SizedBox(height: 16),

              // Elo Score with Animation
              _buildEloScore(theme, isWeb),

              const SizedBox(height: 8),

              // Last Updated
              _buildLastUpdated(theme),
            ],
          ),
        ),
      ),
    ).animate().scale(
      duration: 300.ms,
      curve: Curves.elasticOut,
      delay: isSelected ? 100.ms : 0.ms,
    );
  }

  Widget _buildItemImage(ThemeData theme, bool isWeb) {
    if (item.imageUrl != null && item.imageUrl!.isNotEmpty) {
      return Container(
        width: isWeb ? 120 : 80,
        height: isWeb ? 120 : 80,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: theme.colorScheme.surfaceVariant,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            item.imageUrl!,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _buildFallbackIcon(theme);
            },
          ),
        ),
      );
    }

    return _buildFallbackIcon(theme);
  }

  Widget _buildFallbackIcon(ThemeData theme) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: theme.colorScheme.primaryContainer,
      ),
      child: Icon(
        _getCategoryIcon(item.category),
        size: 40,
        color: theme.colorScheme.onPrimaryContainer,
      ),
    );
  }

  Widget _buildCategoryInfo(ThemeData theme) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            item.category,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        if (item.subCategory.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            item.subCategory,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEloScore(ThemeData theme, bool isWeb) {
    final eloChange = previousElo != null ? item.elo - previousElo! : null;
    final isPositiveChange = eloChange != null && eloChange > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            'Elo Score',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showEloAnimation && eloChange != null)
                _buildEloChangeIndicator(theme, eloChange, isPositiveChange),
              Text(
                    '${item.elo}',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface,
                    ),
                  )
                  .animate()
                  .fadeIn(duration: 400.ms)
                  .scale(duration: 400.ms, curve: Curves.elasticOut),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEloChangeIndicator(
    ThemeData theme,
    int change,
    bool isPositive,
  ) {
    return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isPositive ? Icons.trending_up : Icons.trending_down,
                size: 16,
                color: isPositive
                    ? theme.colorScheme.primary
                    : theme.colorScheme.error,
              ),
              const SizedBox(width: 2),
              Text(
                '${isPositive ? '+' : ''}$change',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: isPositive
                      ? theme.colorScheme.primary
                      : theme.colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        )
        .animate()
        .slideX(
          begin: isPositive ? 0.5 : -0.5,
          duration: 500.ms,
          curve: Curves.elasticOut,
        )
        .fadeIn(duration: 500.ms);
  }

  Widget _buildLastUpdated(ThemeData theme) {
    final timeDiff = DateTime.now().difference(item.lastUpdated);
    String timeText;

    if (timeDiff.inMinutes < 1) {
      timeText = 'Just now';
    } else if (timeDiff.inHours < 1) {
      timeText = '${timeDiff.inMinutes}m ago';
    } else if (timeDiff.inDays < 1) {
      timeText = '${timeDiff.inHours}h ago';
    } else {
      timeText = '${timeDiff.inDays}d ago';
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.access_time,
          size: 12,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Text(
          timeText,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'phones':
      case 'mobile':
        return Icons.phone_android;
      case 'movies':
      case 'films':
        return Icons.movie;
      case 'actors':
        return Icons.person;
      case 'memes':
        return Icons.tag;
      case 'games':
        return Icons.videogame_asset;
      case 'music':
        return Icons.music_note;
      default:
        return Icons.category;
    }
  }
}
