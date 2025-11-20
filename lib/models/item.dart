class Item {
  final int id;
  final String name;
  final int elo;
  final String category;
  final String subCategory;
  final DateTime lastUpdated;
  final String? imageUrl;
  final String? description;

  const Item({
    required this.id,
    required this.name,
    required this.elo,
    required this.category,
    required this.subCategory,
    required this.lastUpdated,
    this.imageUrl,
    this.description,
  });

  factory Item.fromJson(Map<String, dynamic> json) {
    return Item(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      elo: json['elo'] ?? 1500,
      category: json['category'] ?? '',
      subCategory: json['sub_category'] ?? '',
      lastUpdated: DateTime.parse(
        json['last_updated'] ?? DateTime.now().toIso8601String(),
      ),
      imageUrl: json['image_url'],
      description: json['description'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'elo': elo,
      'category': category,
      'sub_category': subCategory,
      'last_updated': lastUpdated.toIso8601String(),
      'image_url': imageUrl,
      'description': description,
    };
  }

  Item copyWith({
    int? id,
    String? name,
    int? elo,
    String? category,
    String? subCategory,
    DateTime? lastUpdated,
    String? imageUrl,
    String? description,
  }) {
    return Item(
      id: id ?? this.id,
      name: name ?? this.name,
      elo: elo ?? this.elo,
      category: category ?? this.category,
      subCategory: subCategory ?? this.subCategory,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      imageUrl: imageUrl ?? this.imageUrl,
      description: description ?? this.description,
    );
  }

  @override
  String toString() {
    return 'Item(id: $id, name: $name, elo: $elo, category: $category, subCategory: $subCategory)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Item && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
