import 'package:club_os/shared/models/notification_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NotificationModel.fromJson', () {
    Map<String, dynamic> baseRow() => {
          'id': 'n1',
          'user_id': 'u1',
          'club_id': 'c1',
          'type': 'task_assigned',
          'message': 'You were assigned a task',
          'read': true,
          'created_at': '2026-06-20T10:30:00.000Z',
        };

    test('parses a fully-populated row', () {
      final n = NotificationModel.fromJson(baseRow());

      expect(n.id, 'n1');
      expect(n.userId, 'u1');
      expect(n.clubId, 'c1');
      expect(n.type, 'task_assigned');
      expect(n.message, 'You were assigned a task');
      expect(n.read, isTrue);
      expect(n.createdAt, DateTime.parse('2026-06-20T10:30:00.000Z'));
    });

    test('club_id may be null', () {
      final row = baseRow()..['club_id'] = null;

      expect(NotificationModel.fromJson(row).clubId, isNull);
    });

    test('read defaults to false when the key is missing', () {
      final row = baseRow()..remove('read');

      expect(NotificationModel.fromJson(row).read, isFalse);
    });

    test('parses created_at into a (UTC) DateTime', () {
      final n = NotificationModel.fromJson(baseRow());

      expect(n.createdAt, DateTime.parse('2026-06-20T10:30:00.000Z'));
      expect(n.createdAt.isUtc, isTrue);
    });
  });
}
