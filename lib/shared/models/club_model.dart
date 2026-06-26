class ClubModel {
  final String id;
  final String name;
  final String? constitutionContent;
  final DateTime createdAt;

  const ClubModel({
    required this.id,
    required this.name,
    this.constitutionContent,
    required this.createdAt,
  });

  factory ClubModel.fromJson(Map<String, dynamic> json) => ClubModel(
        id: json['id'] as String,
        name: json['name'] as String,
        constitutionContent: json['constitution_content'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
