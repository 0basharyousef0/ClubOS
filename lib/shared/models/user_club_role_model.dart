import 'club_model.dart';
import 'profile_model.dart';

class UserClubRoleModel {
  final String id;
  final String userId;
  final String clubId;
  final String role;
  final String? roleTitle;
  final String status;
  final String? approvedBy;
  final DateTime createdAt;
  final ClubModel? club;
  final ProfileModel? profile;

  const UserClubRoleModel({
    required this.id,
    required this.userId,
    required this.clubId,
    required this.role,
    this.roleTitle,
    required this.status,
    this.approvedBy,
    required this.createdAt,
    this.club,
    this.profile,
  });

  bool get isApproved => status == 'approved';
  bool get isPending => status == 'pending';
  bool get isRejected => status == 'rejected';
  bool get isPresident => role == 'president';
  bool get isVicePresident => role == 'vice_president';
  bool get isDirector => role == 'director';
  bool get canAssignTasks => isPresident || isVicePresident;
  bool get canPostEvents => isPresident || isVicePresident;
  bool get canPostAnnouncements => isPresident || isVicePresident;
  bool get canCreatePolls => isPresident || isVicePresident;
  bool get canRsvp => isVicePresident || isDirector;
  bool get canViewRsvps => isPresident;

  String get roleDisplayName {
    if (roleTitle != null && roleTitle!.trim().isNotEmpty) return roleTitle!.trim();
    return switch (role) {
      'president' => 'President',
      'vice_president' => 'Vice President',
      'director' => 'Director',
      _ => role,
    };
  }

  factory UserClubRoleModel.fromJson(Map<String, dynamic> json) => UserClubRoleModel(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        clubId: json['club_id'] as String,
        role: json['role'] as String,
        roleTitle: json['role_title'] as String?,
        status: json['status'] as String,
        approvedBy: json['approved_by'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        club: json['clubs'] != null
            ? ClubModel.fromJson(json['clubs'] as Map<String, dynamic>)
            : null,
        profile: json['profiles'] != null
            ? ProfileModel.fromJson(json['profiles'] as Map<String, dynamic>)
            : null,
      );
}
