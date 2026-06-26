import '../../../core/constants.dart';
import '../../../core/supabase_client.dart';
import '../../../shared/models/notification_model.dart';

class NotificationsRepository {
  /// The current user's notifications, newest first. RLS (`notifications_select`)
  /// already scopes this to `user_id = auth.uid()`.
  Future<List<NotificationModel>> getMyNotifications() async {
    final user = supabase.auth.currentUser;
    if (user == null) return const [];
    final response = await supabase
        .from(AppConstants.tableNotifications)
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .limit(100);
    return (response as List)
        .map((e) => NotificationModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> markAsRead(String id) async {
    await supabase
        .from(AppConstants.tableNotifications)
        .update({'read': true})
        .eq('id', id);
  }

  Future<void> markAllAsRead() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    await supabase
        .from(AppConstants.tableNotifications)
        .update({'read': true})
        .eq('user_id', user.id)
        .eq('read', false);
  }
}
