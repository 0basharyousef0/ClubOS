import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/models/user_club_role_model.dart';
import '../data/auth_repository.dart';


final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository());

final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

// All roles for the current user (approved + pending)
final userClubRolesProvider = FutureProvider<List<UserClubRoleModel>>((ref) async {
  // Re-fetch whenever auth state changes
  ref.watch(authStateChangesProvider);
  final repo = ref.watch(authRepositoryProvider);
  return repo.getUserClubRoles();
});

// Currently selected club role (for multi-club users; persists in memory)
final selectedClubRoleProvider = StateProvider<UserClubRoleModel?>((ref) => null);

// Active role: explicit selection, or first approved role, or null
final activeClubRoleProvider = Provider<UserClubRoleModel?>((ref) {
  final selected = ref.watch(selectedClubRoleProvider);
  if (selected != null) return selected;

  final rolesState = ref.watch(userClubRolesProvider);
  return rolesState.whenOrNull(
    data: (roles) {
      final approved = roles.where((r) => r.isApproved).toList();
      return approved.isNotEmpty ? approved.first : null;
    },
  );
});
