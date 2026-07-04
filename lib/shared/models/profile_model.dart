class ProfileModel {
  final String id;
  final String fullName;

  /// University email — also the login email (mirrors auth.users).
  final String email;

  /// Optional personal contact email, shown in the directory.
  final String? personalEmail;

  /// Null when a query embeds only a subset of profile columns.
  final DateTime? createdAt;

  const ProfileModel({
    required this.id,
    required this.fullName,
    required this.email,
    this.personalEmail,
    this.createdAt,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) => ProfileModel(
        id: json['id'] as String,
        fullName: json['full_name'] as String,
        email: json['email'] as String,
        personalEmail: json['personal_email'] as String?,
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String)
            : null,
      );
}
