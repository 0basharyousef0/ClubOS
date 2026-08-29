class AppConstants {
  // Tables
  static const String tableClubs = 'clubs';
  static const String tableProfiles = 'profiles';
  static const String tableUserClubRoles = 'user_club_roles';
  static const String tableTasks = 'tasks';
  static const String tableTaskComments = 'task_comments';
  static const String tableEvents = 'events';
  static const String tableEventRsvps = 'event_rsvps';
  static const String tableAnnouncements = 'announcements';
  static const String tablePolls = 'polls';
  static const String tablePollOptions = 'poll_options';
  static const String tablePollVotes = 'poll_votes';
  static const String tableContentReports = 'content_reports';
  static const String tableMeetings = 'meetings';
  static const String tableMeetingAttendees = 'meeting_attendees';
  static const String tableActivityLog = 'activity_log';
  static const String tableNotifications = 'notifications';
  static const String tableFcmTokens = 'fcm_tokens';

  // Public legal + support surfaces. Required by App Store review:
  // guideline 5.1.1 (privacy policy) and 1.2 (terms with content rules
  // and a contact for reporting). Served from /docs via GitHub Pages.
  static const String urlPrivacyPolicy =
      'https://0basharyousef0.github.io/ClubOS/privacy-policy.html';
  static const String urlTermsOfService =
      'https://0basharyousef0.github.io/ClubOS/terms-of-service.html';
  static const String urlSupport = 'https://0basharyousef0.github.io/ClubOS/';

  /// Shown publicly in-app and on the App Store listing.
  static const String supportEmail = 'basharkyousef2@gmail.com';

  // Roles
  static const String rolePresident = 'president';
  static const String roleVicePresident = 'vice_president';
  static const String roleDirector = 'director';

  // Membership status
  static const String statusPending = 'pending';
  static const String statusApproved = 'approved';
  static const String statusRejected = 'rejected';

  /// Membership tombstone: the member left this club on their own.
  /// Kept (rather than deleted) so their name still resolves on the
  /// work they authored — see 20260829010000_leave_club.sql.
  static const String statusLeft = 'left';

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
  static const String audienceMyDirectors = 'my_directors';
  static const String audienceCustom = 'custom';

  // Reportable content types (App Store guideline 1.2)
  static const String reportAnnouncement = 'announcement';
  static const String reportTaskComment = 'task_comment';

  // Meeting audience
  static const String meetingAudienceVps = 'vps';
  static const String meetingAudienceVpsDirectors = 'vps_directors';
  static const String meetingAudienceMyDirectors = 'my_directors';
  static const String meetingAudienceCustom = 'custom';

  // Meeting recurrence
  static const String recurrenceOnce = 'once';
  static const String recurrenceDaily = 'daily';
  static const String recurrenceWeekly = 'weekly';
  static const String recurrenceBiweekly = 'biweekly';
  static const String recurrenceMonthly = 'monthly';

  // Notification types
  static const String notifTaskAssigned = 'task_assigned';
  static const String notifEventPosted = 'event_posted';
  static const String notifAnnouncement = 'announcement';
  static const String notifPollCreated = 'poll_created';
  static const String notifMembershipApproved = 'membership_approved';
  static const String notifJoinRequest = 'join_request';
  static const String notifMemberLeft = 'member_left';
  static const String notifPresidencyTransferred = 'presidency_transferred';
  static const String notifMeetingScheduled = 'meeting_scheduled';
  static const String notifMeetingReminder = 'meeting_reminder';
  static const String notifMeetingCancelled = 'meeting_cancelled';
  static const String notifTermStarted = 'term_started';
  static const String notifContentReported = 'content_reported';

  // Activity log action types
  static const String actionPollCreated = 'poll_created';
  static const String actionTaskAssigned = 'task_assigned';
  static const String actionTaskCompleted = 'task_completed';
  static const String actionTaskStarted = 'task_started';
  static const String actionEventRsvp = 'event_rsvp';
  static const String actionAnnouncementPosted = 'announcement_posted';
  static const String actionPollVote = 'poll_vote';
  static const String actionMemberLeft = 'member_left';
  static const String actionPresidencyTransferred = 'presidency_transferred';
  static const String actionMeetingScheduled = 'meeting_scheduled';
  static const String actionTermStarted = 'term_started';
  static const String actionContentReported = 'content_reported';
}
