class TenantData {
  final String id;
  final String name;
  final String slug;

  const TenantData({required this.id, required this.name, required this.slug});

  factory TenantData.fromJson(Map<String, dynamic> json) => TenantData(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    slug: json['slug']?.toString() ?? '',
  );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'slug': slug};
}
