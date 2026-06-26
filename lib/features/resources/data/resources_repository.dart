import '../../../core/constants.dart';
import '../../../core/supabase_client.dart';

class ResourcesRepository {
  Future<String?> getConstitution(String clubId) async {
    final response = await supabase
        .from(AppConstants.tableClubs)
        .select('constitution_content')
        .eq('id', clubId)
        .single();
    return (response)['constitution_content']
        as String?;
  }

  Future<void> saveConstitution(String clubId, String content) async {
    await supabase
        .from(AppConstants.tableClubs)
        .update({'constitution_content': content}).eq('id', clubId);
  }
}
