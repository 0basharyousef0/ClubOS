class AppConstants {
  // Tables
  static const String tableClubs = 'clubs';
  static const String tableProfiles = 'profiles';
  static const String tableUserClubRoles = 'user_club_roles';
  static const String tableTasks = 'tasks';
  static const String tableTaskComments = 'task_comments';
  static const String tableTaskAttachments = 'task_attachments';
  static const String tableEvents = 'events';
  static const String tableEventRsvps = 'event_rsvps';
  static const String tableAnnouncements = 'announcements';
  static const String tablePolls = 'polls';
  static const String tablePollOptions = 'poll_options';
  static const String tablePollVotes = 'poll_votes';
  static const String tableActivityLog = 'activity_log';
  static const String tableNotifications = 'notifications';
  static const String tableFcmTokens = 'fcm_tokens';

  // Storage buckets
  static const String bucketTaskAttachments = 'task-attachments';

  // Roles
  static const String rolePresident = 'president';
  static const String roleVicePresident = 'vice_president';
  static const String roleDirector = 'director';

  // Membership status
  static const String statusPending = 'pending';
  static const String statusApproved = 'approved';
  static const String statusRejected = 'rejected';

  // Task urgency
  static const String urgencyLow = 'low';
  static const String urgencyNormal = 'normal';
  static const String urgencyHigh = 'high';

  // Task status
  static const String taskNotStarted = 'not_started';
  static const String taskInProgress = 'in_progress';
  static const String taskComplete = 'complete';

  // Poll audience
  static const String audienceAll = 'all';
  static const String audienceVpsOnly = 'vps_only';
  static const String audienceDirectorsOnly = 'directors_only';

  // Notification types
  static const String notifTaskAssigned = 'task_assigned';
  static const String notifEventPosted = 'event_posted';
  static const String notifAnnouncement = 'announcement';
  static const String notifPollCreated = 'poll_created';
  static const String notifMembershipApproved = 'membership_approved';
  static const String notifJoinRequest = 'join_request';

  // Activity log action types
  static const String actionTaskCompleted = 'task_completed';
  static const String actionTaskStarted = 'task_started';
  static const String actionEventRsvp = 'event_rsvp';
  static const String actionAnnouncementPosted = 'announcement_posted';
  static const String actionPollVote = 'poll_vote';
}
