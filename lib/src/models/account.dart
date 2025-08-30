class Account {
  final String id;
  final String name;
  final String
  dbPath; // Primary database file path (if accessible as a file path)
  final String? mirrorUri; // Optional URI for mirrored cloud location
  final DateTime createdAt;

  Account({
    required this.id,
    required this.name,
    required this.dbPath,
    this.mirrorUri,
    required this.createdAt,
  });

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'dbPath': dbPath,
    'mirrorUri': mirrorUri,
    'createdAt': createdAt.toIso8601String(),
  };

  static Account fromJson(Map<String, Object?> json) => Account(
    id: json['id'] as String,
    name: json['name'] as String,
    dbPath: json['dbPath'] as String,
    mirrorUri: json['mirrorUri'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}
