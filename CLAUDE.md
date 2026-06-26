# ClubOS — Claude Context File

## Project Overview
ClubOS is a cross-platform mobile app (iOS & Android) that helps university student clubs manage their internal operations. It gives clubs a dedicated, structured space for task assignment, event scheduling, announcements, voting, and member management — replacing scattered group chats and spreadsheets.

**Target users:** University student clubs with a role hierarchy (President → Vice President → Director).

---

## Tech Stack

| Layer | Technology | Purpose |
|-------|-----------|---------|
| Mobile (iOS & Android) | Flutter | Cross-platform UI |
| Language | Dart | Flutter's native language |
| Backend & Database | Supabase (PostgreSQL) | Auth, database, real-time, storage |
| Push Notifications | Firebase Cloud Messaging (FCM) | iOS & Android push delivery |
| State Management | Riverpod | App-wide state and async data |
| Navigation | GoRouter | Declarative routing |

---

## Project Structure

```
ClubOS/
├── lib/
│   ├── main.dart
│   ├── app/
│   │   ├── router.dart            # GoRouter route definitions
│   │   └── theme.dart             # App-wide theme and design tokens
│   ├── features/
│   │   ├── auth/                  # Login, registration, club selection, approval flow
│   │   ├── dashboard/             # Personalized home screen
│   │   ├── tasks/                 # Task creation, assignment, comments, attachments
│   │   ├── events/                # Event calendar, creation, RSVP
│   │   ├── announcements/         # Announcement board
│   │   ├── directory/             # Member directory
│   │   ├── polls/                 # Voting and polls
│   │   ├── activity_log/          # President-only activity log
│   │   ├── resources/             # Club constitution and resource page
│   │   └── notifications/         # Push notification handling
│   ├── shared/
│   │   ├── models/                # Data models (User, Task, Event, Poll, etc.)
│   │   ├── providers/             # Riverpod providers
│   │   └── widgets/               # Reusable UI components
│   └── core/
│       ├── supabase_client.dart   # Supabase initialization
│       ├── fcm_service.dart       # Firebase Cloud Messaging setup
│       └── constants.dart         # App-wide constants
├── android/
├── ios/
├── supabase/
│   └── migrations/                # All database migrations go here
├── pubspec.yaml
└── .env                           # Never commit this file
```

Each feature folder follows this internal structure:
```
features/tasks/
├── data/          # Supabase queries and repository layer
├── providers/     # Riverpod providers for this feature
├── screens/       # Full page screens
└── widgets/       # Feature-specific widgets
```

---

## Commands

```bash
flutter pub get          # Install dependencies
flutter run              # Run on connected device/simulator
flutter run -d ios       # Run on iOS
flutter run -d android   # Run on Android
flutter build ipa        # Production iOS build
flutter build appbundle  # Production Android build
flutter analyze          # Static analysis
flutter test             # Run tests
```

---

## Database Schema (Supabase / PostgreSQL)

```sql
-- Clubs
clubs (
  id uuid PRIMARY KEY,
  name text UNIQUE NOT NULL,       -- No duplicate club names enforced here
  constitution_content text,       -- Editable by President only
  created_at timestamptz
)

-- Profiles (extends Supabase auth.users, no club_id — users can be in multiple clubs)
profiles (
  id uuid PRIMARY KEY REFERENCES auth.users,
  full_name text NOT NULL,
  email text NOT NULL,
  created_at timestamptz
)

-- User roles per club (replaces single club_id — supports multi-club membership)
user_club_roles (
  id uuid PRIMARY KEY,
  user_id uuid REFERENCES profiles,
  club_id uuid REFERENCES clubs,
  role text NOT NULL,              -- 'president' | 'vice_president' | 'director'
  status text NOT NULL,            -- 'pending' | 'approved' | 'rejected'
  approved_by uuid REFERENCES profiles,
  created_at timestamptz,
  UNIQUE (user_id, club_id)        -- One role per user per club
)

-- Tasks
tasks (
  id uuid PRIMARY KEY,
  club_id uuid REFERENCES clubs,
  title text NOT NULL,
  description text,
  assigned_to uuid REFERENCES profiles,
  assigned_by uuid REFERENCES profiles,
  due_date date,
  urgency text,                    -- 'low' | 'normal' | 'high'
  status text,                     -- 'not_started' | 'in_progress' | 'complete'
  created_at timestamptz
)

-- Task Comments
task_comments (
  id uuid PRIMARY KEY,
  task_id uuid REFERENCES tasks,
  user_id uuid REFERENCES profiles,
  content text NOT NULL,
  created_at timestamptz
)

-- Task Attachments
task_attachments (
  id uuid PRIMARY KEY,
  task_id uuid REFERENCES tasks,
  file_url text NOT NULL,
  file_name text NOT NULL,
  uploaded_by uuid REFERENCES profiles,
  created_at timestamptz
)

-- Events
events (
  id uuid PRIMARY KEY,
  club_id uuid REFERENCES clubs,
  title text NOT NULL,
  description text,
  event_date timestamptz NOT NULL,
  created_by uuid REFERENCES profiles,
  created_at timestamptz
)

-- Event RSVPs
event_rsvps (
  id uuid PRIMARY KEY,
  event_id uuid REFERENCES events,
  user_id uuid REFERENCES profiles,
  created_at timestamptz,
  UNIQUE (event_id, user_id)
)

-- Announcements
announcements (
  id uuid PRIMARY KEY,
  club_id uuid REFERENCES clubs,
  title text NOT NULL,
  content text NOT NULL,
  posted_by uuid REFERENCES profiles,
  created_at timestamptz
)

-- Polls
polls (
  id uuid PRIMARY KEY,
  club_id uuid REFERENCES clubs,
  title text NOT NULL,
  description text,
  created_by uuid REFERENCES profiles,
  audience text NOT NULL,          -- 'all' | 'vps_only' | 'directors_only'
  closes_at timestamptz,
  created_at timestamptz
)

poll_options (
  id uuid PRIMARY KEY,
  poll_id uuid REFERENCES polls,
  text text NOT NULL
)

poll_votes (
  id uuid PRIMARY KEY,
  poll_id uuid REFERENCES polls,
  option_id uuid REFERENCES poll_options,
  user_id uuid REFERENCES profiles,
  created_at timestamptz,
  UNIQUE (poll_id, user_id)        -- One vote per user per poll
)

-- Activity Log (President view only)
activity_log (
  id uuid PRIMARY KEY,
  club_id uuid REFERENCES clubs,
  user_id uuid REFERENCES profiles,
  action_type text NOT NULL,       -- 'task_completed' | 'task_started' | 'event_rsvp' | etc.
  details jsonb,
  created_at timestamptz
)

-- Notifications
notifications (
  id uuid PRIMARY KEY,
  user_id uuid REFERENCES profiles,
  club_id uuid REFERENCES clubs,
  type text NOT NULL,              -- 'task_assigned' | 'event_posted' | 'announcement' | 'poll_created' | 'membership_approved'
  message text NOT NULL,
  read boolean DEFAULT false,
  created_at timestamptz
)
```

---

## Role Permissions

| Feature | President | Vice President | Director |
|---------|-----------|---------------|----------|
| Assign tasks | ✅ | ✅ | ❌ |
| View & update own tasks | ✅ | ✅ | ✅ |
| Comment on assigned tasks | ✅ | ✅ | ✅ |
| Attach files to tasks | ✅ | ✅ | ✅ |
| Post events | ✅ | ✅ | ❌ |
| View events | ✅ | ✅ | ✅ |
| RSVP to events | ❌ (views RSVPs) | ✅ | ✅ |
| Post announcements | ✅ | ✅ | ❌ |
| View announcements | ✅ | ✅ | ✅ |
| Create polls (whole club or VPs only) | ✅ | ❌ | ❌ |
| Create polls (whole club, VPs, or Directors) | ❌ | ✅ | ❌ |
| Vote in polls | ✅ | ✅ | ✅ (if audience includes them) |
| View member directory | ✅ | ✅ | ✅ |
| Approve/reject member join requests | ✅ | ❌ | ❌ |
| Remove a member (VP or Director) | ✅ | ❌ | ❌ |
| Edit club constitution/resources | ✅ | ❌ | ❌ |
| View activity log | ✅ | ❌ | ❌ |
| Delete club (with multi-step confirmation) | ✅ | ❌ | ❌ |

---

## Key Business Logic & Rules

### Club Membership & Approval
- Presidents create the club and are automatically approved
- VPs and Directors select their club from a dropdown (fetched from DB) — never type it manually
- All VP and Director join requests go into `pending` status until the President approves them
- The President receives a notification for every pending join request
- A user can belong to multiple clubs simultaneously, each with their own role

### Club Names
- Club names must be unique across the entire platform (enforced at DB level with UNIQUE constraint)
- When a new club is being created, validate uniqueness before submission

### Polls Logic
- **President** can send a poll to: the entire club (`all`) or VPs only (`vps_only`)
- **VP** can send a poll to: the entire club (`all`) or their own Directors only (`directors_only`)
- Each user can only vote once per poll
- Poll results are visible to everyone who can see the poll

### Event RSVP
- Only VPs and Directors can RSVP
- Only the President can view the RSVP list

### Destructive Actions (require multi-step confirmation)
- **Delete club** — President only. Requires typing the club name to confirm, then a final "I understand this is permanent" confirmation
- **Remove a member** — President only. Requires a confirmation dialog before proceeding

### Activity Log
- Automatically written to on: task status changes, RSVP actions, announcement posts, poll votes
- Only readable by the President of that club

---

## Coding Conventions

- Use feature-first folder structure — all code for a feature lives in its `features/` subfolder
- Every screen is a separate file in `screens/`, named in `snake_case.dart`
- All Supabase queries live in the `data/` layer of each feature — never call Supabase directly from a widget or screen
- Use Riverpod `AsyncNotifierProvider` for any async data; `NotifierProvider` for pure sync state
- Use GoRouter for all navigation — no `Navigator.push` directly
- All string constants (table names, column names, role values, status values) go in `core/constants.dart`
- Never hardcode Supabase URLs or keys — always read from `.env`
- RLS (Row Level Security) policies should be set up in Supabase for every table — don't rely only on app-level checks
- Widget files should not contain business logic — keep widgets dumb, logic in providers
- Use named routes throughout (defined in `router.dart`)

---

## Environment Setup

```env
# .env (never commit)
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
```

Firebase config files (also never commit):
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`

---

## Build Order (Phase by Phase)

Work through these phases in order. Do not start a new phase until the current one is working end-to-end.

### Phase 1 — Foundation
- [ ] Flutter project setup with all dependencies in `pubspec.yaml`
- [ ] Supabase client initialization
- [ ] FCM basic setup
- [ ] App theme and design tokens
- [ ] GoRouter skeleton with placeholder screens for all routes

### Phase 2 — Auth & Club System
- [ ] Sign up flow (name, email, password, role selection)
- [ ] Club creation (Presidents) with unique name validation
- [ ] Club selection dropdown (VPs and Directors) — fetched from DB
- [ ] Join request system — pending approval by President
- [ ] President approval/rejection screen
- [ ] Login flow with multi-club support (if user is in multiple clubs, show club switcher)
- [ ] Session persistence and auto-login
- [ ] Role-based routing after login

### Phase 3 — Dashboard
- [ ] Personalized home screen showing pending tasks, upcoming events, and unread announcements
- [ ] Adapts to role (President sees pending approvals badge if any)

### Phase 4 — Task Management
- [ ] Task creation (P and VP) with title, description, due date, urgency
- [ ] Task assignment to a member
- [ ] Task list screen with filters (by status, urgency)
- [ ] Task detail screen
- [ ] Status update by assigned member (not_started → in_progress → complete)
- [ ] Task comments (assigned member only)
- [ ] File attachments on tasks (upload to Supabase Storage)

### Phase 5 — Events
- [ ] Event creation (P and VP)
- [ ] Shared calendar view
- [ ] Event detail screen
- [ ] RSVP button (VP and Director only)
- [ ] RSVP list view (President only)

### Phase 6 — Announcements
- [ ] Announcement creation (P and VP)
- [ ] Announcement feed (all members)

### Phase 7 — Member Directory
- [ ] Searchable directory of all approved club members
- [ ] Member profile cards (name, role, email)
- [ ] President-only: remove member action (with confirmation)

### Phase 8 — Push Notifications
- [ ] FCM token registration per user/device
- [ ] Notification triggers: task assigned, event posted, announcement posted, membership approved
- [ ] In-app notification list screen
- [ ] Mark as read

### Phase 9 — Polls & Voting
- [ ] Poll creation with audience targeting
- [ ] Active polls list
- [ ] Voting screen (single choice)
- [ ] Results view

### Phase 10 — Activity Log
- [ ] Auto-log writes on task updates, RSVPs, etc.
- [ ] Activity log screen (President only)
- [ ] Filters: by member, by action type, by date range

### Phase 11 — Resources
- [ ] Club constitution/resource page
- [ ] President-only edit mode (rich text or markdown)
- [ ] Read-only view for all members

### Phase 12 — Destructive & Admin Actions
- [ ] Multi-step club deletion (President only)
- [ ] Remove member with confirmation (President only)
- [ ] Multi-club switcher (if user is in more than one club)

---
