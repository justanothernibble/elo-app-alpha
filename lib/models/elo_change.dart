class EloChange {
  final int id;
  final int itemId;
  final int eloBefore;
  final int eloAfter;
  final DateTime timestamp;
  final String userAction;
  final String reason;
  final int? winnerItemId; // ID of the item that won this comparison

  const EloChange({
    required this.id,
    required this.itemId,
    required this.eloBefore,
    required this.eloAfter,
    required this.timestamp,
    required this.userAction,
    required this.reason,
    this.winnerItemId,
  });

  factory EloChange.fromJson(Map<String, dynamic> json) {
    return EloChange(
      id: json['id'] ?? 0,
      itemId: json['item_id'] ?? 0,
      eloBefore: json['elo_before'] ?? 0,
      eloAfter: json['elo_after'] ?? 0,
      timestamp: DateTime.parse(
        json['timestamp'] ?? DateTime.now().toIso8601String(),
      ),
      userAction: json['user_action'] ?? '',
      reason: json['reason'] ?? '',
      winnerItemId: json['winner_item_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'item_id': itemId,
      'elo_before': eloBefore,
      'elo_after': eloAfter,
      'timestamp': timestamp.toIso8601String(),
      'user_action': userAction,
      'reason': reason,
      'winner_item_id': winnerItemId,
    };
  }

  EloChange copyWith({
    int? id,
    int? itemId,
    int? eloBefore,
    int? eloAfter,
    DateTime? timestamp,
    String? userAction,
    String? reason,
    int? winnerItemId,
  }) {
    return EloChange(
      id: id ?? this.id,
      itemId: itemId ?? this.itemId,
      eloBefore: eloBefore ?? this.eloBefore,
      eloAfter: eloAfter ?? this.eloAfter,
      timestamp: timestamp ?? this.timestamp,
      userAction: userAction ?? this.userAction,
      reason: reason ?? this.reason,
      winnerItemId: winnerItemId ?? this.winnerItemId,
    );
  }

  int get eloChange => eloAfter - eloBefore;

  @override
  String toString() {
    return 'EloChange(id: $id, itemId: $itemId, eloChange: $eloChange, timestamp: $timestamp)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EloChange &&
        other.id == id &&
        other.itemId == itemId &&
        other.eloBefore == eloBefore &&
        other.eloAfter == eloAfter &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode =>
      id.hashCode ^
      itemId.hashCode ^
      eloBefore.hashCode ^
      eloAfter.hashCode ^
      timestamp.hashCode;
}
