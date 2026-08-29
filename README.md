# ClubOS

**A cross-platform mobile app that helps university student clubs run their internal operations** — task assignment, events, announcements, polls, and member management — in one structured place instead of scattered group chats and spreadsheets.

Built with Flutter (iOS & Android), Supabase, and Firebase Cloud Messaging.

---

## Features

- **Role-based access** — a President → Vice President → Director hierarchy, with permissions enforced per role and by PostgreSQL Row-Level Security.
- **Multi-club membership** — a user can belong to several clubs at once, each with its own role; join requests are approved by the club President.
- **Tasks** — create, assign, and track tasks with due dates, urgency, status, and comments.
- **Events** — shared calendar, event creation, and RSVPs.
- **Announcements** — a club-wide announcement board.
- **Polls & voting** — audience-targeted polls (whole club / VPs / Directors) with one vote per member and shared results.
- **Member directory** — searchable directory with role-aware profiles.
- **Push notifications** — FCM-powered alerts for assignments, events, announcements, and approvals, plus an in-app notification feed.
- **Activity log** — a President-only audit view of club activity.
- **Resources** — a club constitution / resource page, editable by the President.

## Tech stack

| Layer | Technology |
|-------|------------|
| Mobile (iOS & Android) | Flutter / Dart |
| Backend · auth · storage · realtime | Supabase (PostgreSQL) |
| Push notifications | Firebase Cloud Messaging |
| State management | Riverpod |
| Navigation | GoRouter |

## Project structure

```
lib/
├── app/         # Router and theme
├── core/        # Supabase client, FCM service, constants
├── features/    # Feature-first modules (auth, tasks, events, polls, …)
│   └── <feature>/
│       ├── data/        # Supabase queries / repositories
│       ├── providers/   # Riverpod providers
│       ├── screens/     # Full-page screens
│       └── widgets/     # Feature-specific widgets
└── shared/      # Shared models, providers, and widgets
supabase/
├── migrations/  # Database schema & RLS policies
└── functions/   # Edge functions (e.g. push-notification sender)
```

## Getting started

### Prerequisites
- Flutter SDK (Dart `^3.11.1`)
- A [Supabase](https://supabase.com) project
- A [Firebase](https://firebase.google.com) project (for push notifications)

### 1. Install dependencies
```bash
flutter pub get
```

### 2. Configure environment
Create a `.env` file in the project root. It is **gitignored — never commit it**:
```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
```

### 3. Add Firebase config
Place your Firebase config files (also gitignored):
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`

### 4. Set up the database
Apply the migrations in `supabase/migrations/` to your Supabase project using the [Supabase CLI](https://supabase.com/docs/guides/cli):
```bash
supabase link --project-ref <your-project-ref>
supabase db push
```

### 5. Run
```bash
flutter run            # current device / simulator
flutter run -d ios
flutter run -d android
```

## Useful commands

```bash
flutter analyze          # static analysis
flutter test             # run tests
flutter build appbundle  # Android release
flutter build ipa        # iOS release
```

## License

[MIT](LICENSE) © 2026 Bashar Yousef
