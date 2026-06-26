import 'package:club_os/shared/models/activity_log_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ActivityLogModel.fromJson', () {
    Map<String, dynamic> baseRow() => {
          'id': 'a1',
          'club_id': 'c1',
          'user_id': 'u1',
          'action_type': 'task_completed',
          'details': {'title': 'Design the poster', 'task_id': 't1'},
          'created_at': '2026-06-25T14:00:00.000Z',
          'profiles': {'id': 'u1', 'full_name': 'Jane Doe'},
        };

    test('parses a full row, including the joined actor name', () {
      final a = ActivityLogModel.fromJson(baseRow());

      expect(a.id, 'a1');
      expect(a.clubId, 'c1');
      expect(a.userId, 'u1');
      expect(a.actionType, 'task_completed');
      expect(a.actorName, 'Jane Doe');
      expect(a.createdAt, DateTime.parse('2026-06-25T14:00:00.000Z'));
    });

    test('subjectTitle reads details.title', () {
      expect(ActivityLogModel.fromJson(baseRow()).subjectTitle,
          'Design the poster');
    });

    test('actorName is null when no profile was joined', () {
      final row = baseRow()..remove('profiles');
      expect(ActivityLogModel.fromJson(row).actorName, isNull);
    });

    test('subjectTitle is null when details is missing or blank', () {
      final noDetails = baseRow()..remove('details');
      expect(ActivityLogModel.fromJson(noDetails).subjectTitle, isNull);

      final blankTitle = baseRow()..['details'] = {'title': '   '};
      expect(ActivityLogModel.fromJson(blankTitle).subjectTitle, isNull);
    });
  });
}
