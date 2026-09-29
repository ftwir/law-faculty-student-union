class Hub {
  final int id;
  final String name;
  final String description;
  final String coverImageUrl;
  final int memberCount;

  Hub({
    required this.id,
    required this.name,
    required this.description,
    required this.coverImageUrl,
    required this.memberCount,
  });

  factory Hub.fromJson(Map<String, dynamic> json) => Hub(
        id: json['id'],
        name: json['name'] ?? '',
        description: json['description'] ?? '',
        coverImageUrl: json['cover_image_url'] ?? '',
        memberCount: json['member_count'] ?? 0,
      );
}
