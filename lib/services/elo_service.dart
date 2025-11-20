import '../models/item.dart';
import '../models/elo_change.dart';

class EloService {
  static const int kFactor = 32; // K-factor for Elo calculation
  static const int defaultElo = 1500; // Starting Elo score

  /// Calculate Elo change for two items based on their selection
  ///
  /// [winnerElo] - Current Elo of the winning item
  /// [loserElo] - Current Elo of the losing item
  /// [winnerItemId] - ID of the winning item
  /// [loserItemId] - ID of the losing item
  static EloCalculationResult calculateEloChange(Item winner, Item loser) {
    // Expected score calculation
    final winnerExpected =
        1 / (1 + (loser.elo - winner.elo).toDouble().abs() / 400.0);
    final loserExpected =
        1 / (1 + (winner.elo - loser.elo).toDouble().abs() / 400.0);

    // For now, using simplified +5/-5 system as specified
    // In the future, this can be enhanced to use proper Elo formulas
    final eloChange = 5; // Winner gains 5 points

    final winnerNewElo = winner.elo + eloChange;
    final loserNewElo = loser.elo - eloChange;

    // Create Elo change records for both items
    final now = DateTime.now();

    final winnerChange = EloChange(
      id: 0, // Will be assigned by database
      itemId: winner.id,
      eloBefore: winner.elo,
      eloAfter: winnerNewElo,
      timestamp: now,
      userAction: 'user ranking',
      reason: 'ranked against ${loser.name}',
      winnerItemId: winner.id,
    );

    final loserChange = EloChange(
      id: 0, // Will be assigned by database
      itemId: loser.id,
      eloBefore: loser.elo,
      eloAfter: loserNewElo,
      timestamp: now,
      userAction: 'user ranking',
      reason: 'lost against ${winner.name}',
      winnerItemId: winner.id,
    );

    return EloCalculationResult(
      winner: winner.copyWith(elo: winnerNewElo, lastUpdated: now),
      loser: loser.copyWith(elo: loserNewElo, lastUpdated: now),
      winnerChange: winnerChange,
      loserChange: loserChange,
      eloChange: eloChange,
    );
  }

  /// Calculate expected score based on Elo difference
  static double expectedScore(int playerElo, int opponentElo) {
    return 1 / (1 + (opponentElo - playerElo).toDouble().abs() / 400.0);
  }

  /// Calculate new Elo based on result and K-factor
  static int calculateNewElo(
    int currentElo,
    double expectedScore,
    double actualScore,
  ) {
    final eloChange = (kFactor * (actualScore - expectedScore)).round();
    return currentElo + eloChange;
  }

  /// Enhanced Elo calculation using proper Elo formulas
  /// This is for future implementation
  static EloCalculationResult calculateEloChangeAdvanced(
    Item winner,
    Item loser,
  ) {
    final winnerExpected = expectedScore(winner.elo, loser.elo);
    final loserExpected = expectedScore(loser.elo, winner.elo);

    // Actual scores: winner gets 1, loser gets 0
    final winnerActual = 1.0;
    final loserActual = 0.0;

    final winnerNewElo = calculateNewElo(
      winner.elo,
      winnerExpected,
      winnerActual,
    );
    final loserNewElo = calculateNewElo(loser.elo, loserExpected, loserActual);

    final now = DateTime.now();
    final eloChange = winnerNewElo - winner.elo;

    final winnerChange = EloChange(
      id: 0,
      itemId: winner.id,
      eloBefore: winner.elo,
      eloAfter: winnerNewElo,
      timestamp: now,
      userAction: 'user ranking',
      reason: 'ranked against ${loser.name}',
      winnerItemId: winner.id,
    );

    final loserChange = EloChange(
      id: 0,
      itemId: loser.id,
      eloBefore: loser.elo,
      eloAfter: loserNewElo,
      timestamp: now,
      userAction: 'user ranking',
      reason: 'lost against ${winner.name}',
      winnerItemId: winner.id,
    );

    return EloCalculationResult(
      winner: winner.copyWith(elo: winnerNewElo, lastUpdated: now),
      loser: loser.copyWith(elo: loserNewElo, lastUpdated: now),
      winnerChange: winnerChange,
      loserChange: loserChange,
      eloChange: eloChange,
    );
  }

  /// Determine if two items are fairly matched based on Elo difference
  static bool isFairMatch(int elo1, int elo2, {int threshold = 100}) {
    return (elo1 - elo2).abs() <= threshold;
  }

  /// Get the quality of match based on Elo difference
  static MatchQuality getMatchQuality(int elo1, int elo2) {
    final difference = (elo1 - elo2).abs();

    if (difference <= 50) return MatchQuality.veryClose;
    if (difference <= 100) return MatchQuality.close;
    if (difference <= 200) return MatchQuality.reasonable;
    if (difference <= 300) return MatchQuality.uneven;
    return MatchQuality.verUneven;
  }
}

/// Result class for Elo calculations
class EloCalculationResult {
  final Item winner;
  final Item loser;
  final EloChange winnerChange;
  final EloChange loserChange;
  final int eloChange;

  const EloCalculationResult({
    required this.winner,
    required this.loser,
    required this.winnerChange,
    required this.loserChange,
    required this.eloChange,
  });

  @override
  String toString() {
    return 'EloCalculationResult(winner: ${winner.name} ($winner.elo -> ${winner.elo}), loser: ${loser.name} ($loser.elo -> ${loser.elo}), change: $eloChange)';
  }
}

/// Match quality enum for determining how fair a match is
enum MatchQuality {
  veryClose, // 0-50 Elo difference
  close, // 51-100 Elo difference
  reasonable, // 101-200 Elo difference
  uneven, // 201-300 Elo difference
  verUneven, // 300+ Elo difference
}

extension MatchQualityExtension on MatchQuality {
  String get displayName {
    switch (this) {
      case MatchQuality.veryClose:
        return 'Very Close Match';
      case MatchQuality.close:
        return 'Close Match';
      case MatchQuality.reasonable:
        return 'Reasonable Match';
      case MatchQuality.uneven:
        return 'Uneven Match';
      case MatchQuality.verUneven:
        return 'Very Uneven Match';
    }
  }

  String get color {
    switch (this) {
      case MatchQuality.veryClose:
        return 'green';
      case MatchQuality.close:
        return 'blue';
      case MatchQuality.reasonable:
        return 'orange';
      case MatchQuality.uneven:
        return 'red';
      case MatchQuality.verUneven:
        return 'purple';
    }
  }
}
