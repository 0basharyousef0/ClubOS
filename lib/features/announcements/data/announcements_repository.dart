import '../../../core/constants.dart';
import '../../../core/supabase_client.dart';
import '../../../shared/models/announcement_model.dart';

class AnnouncementsRepository {
  Future<List<AnnouncementModel>> getAnnouncements(String clubId) async {
    final response = await supabase
        .from(AppConstants.tableAnnouncements)
        .select('*, profiles!posted_by(id, full_name, email)')
        .eq('club_id', clubId)
        .order('created_at', ascending: false);
    return (response as List)
        .map((e) => AnnouncementModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> createAnnouncement({
    required String clubId,
    required String title,
    required String content,
  }) async {
    final user = supabase.auth.currentUser!;
    await supabase.from(AppConstants.tableAnnouncements).insert({
      'club_id': clubId,
      'title': title.trim(),
      'content': content.trim(),
      'posted_by': user.id,
    });
  }

  Future<void> deleteAnnouncement(String id) async {
    await supabase
        .from(AppConstants.tableAnnouncements)
        .delete()
        .eq('id', id);
  }
}
