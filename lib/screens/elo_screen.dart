import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../models/item.dart';
import '../providers/app_provider.dart';
import '../services/item_service.dart';
import '../widgets/item_card.dart';
import '../widgets/elo_animation.dart';
import '../themes/app_theme.dart';

class EloScreen extends StatefulWidget {
  const EloScreen({super.key});

  @override
  State<EloScreen> createState() => _EloScreenState();
}

class _EloScreenState extends State<EloScreen> with TickerProviderStateMixin {
  bool _showEloAnimation = false;
  bool _showStaleDataPopup = false;
  Item? _selectedItem;
  Item? _unselectedItem;
  int _selectedItemIndex = -1;
  late AnimationController _popupController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeApp();
  }

  @override
  void dispose() {
    _popupController.dispose();
    super.dispose();
  }

  void _initializeAnimations() {
    _popupController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _popupController, curve: Curves.easeInOut),
    );
  }

  Future<void> _initializeApp() async {
    final appProvider = context.read<AppProvider>();
    await appProvider.initializeApp();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWeb = screenWidth > 800;

    return Scaffold(
      body: Consumer<AppProvider>(
        builder: (context, appProvider, child) {
          return _buildContent(appProvider, isWeb);
        },
      ),
    );
  }

  Widget _buildContent(AppProvider appProvider, bool isWeb) {
    // Show loading screen during initialization
    if (appProvider.isLoading) {
      return _buildLoadingScreen();
    }

    // Show error screen if there's an error
    if (appProvider.hasError) {
      return _buildErrorScreen(appProvider);
    }

    // Main ranking screen
    return Column(
      children: [
        // Stale Data Popup
        if (_showStaleDataPopup) _buildStaleDataPopup(),

        // App Bar
        _buildAppBar(appProvider, isWeb),

        // Main Content
        Expanded(child: _buildMainContent(appProvider, isWeb)),
      ],
    );
  }

  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Initializing Elo App...',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildErrorScreen(AppProvider appProvider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              appProvider.initializationError ?? 'Unknown error occurred',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _initializeApp(),
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildStaleDataPopup() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        width: double.infinity,
        color: Theme.of(context).colorScheme.tertiary.withOpacity(0.1),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _handleStaleDataRefresh(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.refresh,
                    color: Theme.of(context).colorScheme.tertiary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Time has passed, and the Elo has changed. Click here to refresh.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(AppProvider appProvider, bool isWeb) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isWeb ? 32 : 16, vertical: 16),
      child: Row(
        children: [
          // Logo and Title
          Row(
            children: [
              Icon(
                Icons.leaderboard,
                color: Theme.of(context).colorScheme.primary,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                'Elo Rankings',
                style: EloAppTheme.appTitleStyle.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),

          const Spacer(),

          // Category Selector
          _buildCategorySelector(appProvider),

          const SizedBox(width: 16),

          // User Stats
          _buildUserStats(appProvider, isWeb),
        ],
      ),
    );
  }

  Widget _buildCategorySelector(AppProvider appProvider) {
    final categories = appProvider.items.getAvailableCategories();
    if (categories.isEmpty) return const SizedBox.shrink();

    return PopupMenuButton<String>(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              appProvider.items.selectedCategory,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              size: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
      onSelected: (category) => _changeCategory(category),
      itemBuilder: (context) => categories.map((category) {
        return PopupMenuItem<String>(value: category, child: Text(category));
      }).toList(),
    );
  }

  Widget _buildUserStats(AppProvider appProvider, bool isWeb) {
    final stats = appProvider.getAppStatistics();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.person,
            size: 16,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 4),
          if (isWeb) ...[
            Text(
              '${stats.userRankings} rankings',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ] else
            Text(
              '${stats.userRankings}',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMainContent(AppProvider appProvider, bool isWeb) {
    final currentPair = appProvider.items.currentPair;

    if (currentPair == null) {
      return _buildEmptyState();
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isWeb ? 32 : 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Instructions
          _buildInstructions(),

          const SizedBox(height: 24),

          // Item Comparison
          Expanded(
            child: _buildItemComparison(currentPair, appProvider, isWeb),
          ),

          const SizedBox(height: 16),

          // Skip Button
          _buildSkipButton(),
        ],
      ),
    );
  }

  Widget _buildInstructions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.primaryContainer.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.lightbulb_outline,
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Choose which item you think is better in this category',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0);
  }

  Widget _buildItemComparison(
    ItemPair pair,
    AppProvider appProvider,
    bool isWeb,
  ) {
    return Row(
      children: [
        // First Item
        Expanded(
          child: _buildItemCard(pair.getItem(0), 0, appProvider, isLeft: true),
        ),

        const SizedBox(width: 24),

        // VS Indicator
        Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.primary,
              ),
              child: Text(
                'VS',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
            .animate()
            .scale(duration: 600.ms, curve: Curves.elasticOut)
            .fadeIn(duration: 400.ms, delay: 200.ms),

        const SizedBox(width: 24),

        // Second Item
        Expanded(
          child: _buildItemCard(pair.getItem(1), 1, appProvider, isLeft: false),
        ),
      ],
    );
  }

  Widget _buildItemCard(
    Item item,
    int index,
    AppProvider appProvider, {
    required bool isLeft,
  }) {
    final isSelected = _selectedItemIndex == index;
    final showAnimation = _showEloAnimation && item.id == _selectedItem?.id;

    return ItemCard(
          item: item,
          isSelected: isSelected,
          isHighlighted: appProvider.items.isDataStale,
          onTap: () => _handleItemSelection(index),
          showEloAnimation: showAnimation,
          previousElo: _unselectedItem?.id == item.id
              ? _unselectedItem?.elo
              : null,
        )
        .animate(delay: Duration(milliseconds: isLeft ? 100 : 200))
        .fadeIn(duration: 400.ms)
        .slideX(begin: isLeft ? -0.1 : 0.1, end: 0);
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.category_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No items available',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Try changing the category or check back later',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _refreshData(),
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  Widget _buildSkipButton() {
    return TextButton.icon(
      onPressed: _skipRanking,
      icon: const Icon(Icons.skip_next),
      label: const Text('Skip this comparison'),
      style: TextButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0);
  }

  // Event Handlers
  Future<void> _handleItemSelection(int index) async {
    if (_selectedItemIndex != -1) return; // Prevent multiple selections

    setState(() {
      _selectedItemIndex = index;
    });

    final appProvider = context.read<AppProvider>();
    final currentPair = appProvider.items.currentPair;

    if (currentPair == null) return;

    _selectedItem = currentPair.items[index];
    _unselectedItem = currentPair.items[1 - index];

    // Show Elo animation
    setState(() {
      _showEloAnimation = true;
    });

    // Process ranking
    final result = await appProvider.processRankingWorkflow(index);

    if (result != null) {
      // Show animation for 500ms, then load new pair
      await Future.delayed(const Duration(milliseconds: 500));

      // Reset selection and hide animation
      setState(() {
        _selectedItemIndex = -1;
        _showEloAnimation = false;
        _selectedItem = null;
        _unselectedItem = null;
      });

      // Check for stale data
      _checkForStaleData();
    }
  }

  void _checkForStaleData() {
    final appProvider = context.read<AppProvider>();

    if (appProvider.items.isDataStale) {
      setState(() {
        _showStaleDataPopup = true;
      });
      _popupController.forward();
    }
  }

  Future<void> _handleStaleDataRefresh() async {
    final appProvider = context.read<AppProvider>();

    await appProvider.checkAndRefreshStaleData();

    setState(() {
      _showStaleDataPopup = false;
    });
    _popupController.reset();
  }

  Future<void> _changeCategory(String category) async {
    final appProvider = context.read<AppProvider>();
    await appProvider.changeCategoryAndRefresh(category);

    // Reset selection and popup
    setState(() {
      _selectedItemIndex = -1;
      _showStaleDataPopup = false;
      _selectedItem = null;
      _unselectedItem = null;
    });
    _popupController.reset();
  }

  Future<void> _refreshData() async {
    final appProvider = context.read<AppProvider>();
    await appProvider.items.loadNewPair(forceRefresh: true);
  }

  Future<void> _skipRanking() async {
    final appProvider = context.read<AppProvider>();
    await appProvider.items.loadNewPair();

    setState(() {
      _selectedItemIndex = -1;
      _selectedItem = null;
      _unselectedItem = null;
    });
  }
}
