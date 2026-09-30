class Hub {
  final int id;
  final String name;
  final String description;
  final String coverImageUrl;
  final int memberCount;
  final String? membershipStatus;
  final bool isHubAdmin;
  final String slug;

  Hub({
    required this.id,
    required this.name,
    required this.description,
    required this.coverImageUrl,
    required this.memberCount,
    required this.membershipStatus,
    required this.isHubAdmin,
    required this.slug,
  });

  factory Hub.fromJson(Map<String, dynamic> json) => Hub(
        id: json['id'],
        name: json['name'] ?? '',
        description: json['description'] ?? '',
        coverImageUrl: json['cover_image_url'] ?? '',
        memberCount: json['member_count'] ?? 0,
        membershipStatus: json['membership_status']?.toString(),
        isHubAdmin: json['is_hub_admin'] == true,
        slug: json['slug']?.toString() ?? '',
      );
}
