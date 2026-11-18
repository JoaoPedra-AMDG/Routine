# Routine

Flutter app for a daily checklist and monthly calendar.

## Run

```sh
flutter pub get
flutter run -d chrome
```

## Check and build

```sh
flutter analyze
flutter test
flutter build web --release --no-web-resources-cdn
```

Web output: `build/web`. Android, iOS and Windows platform projects are included. iOS builds require macOS; native builds require the corresponding platform toolchain.

## Install the web app

Open Routine in Chrome or Edge and choose **Settings & backup → Install app**. If the browser does not provide a direct install prompt, use its **Install app** or **Add to Home screen** menu. On iPhone/iPad, use Safari’s **Share → Add to Home Screen**. The app caches offline resources after the first online visit.

The deployment validates the manifest scope, packaged installation integration, app icons and offline service-worker resources. No browser/site evaluation is required.

## Data

Plans, completion, skips and date-specific time changes save on the current device. Browser storage is separate per browser and origin. Android uses SharedPreferences, iOS uses UserDefaults, and desktop uses an application-data JSON file. Backup and restore use JSON through the clipboard. Existing Daybook browser data uses the same storage key and schema.

## Schedule

Seed events use November–December 2026. Dates and the current day use South African time (UTC+2). Chores, teaching and app development use one-hour defaults. The jog defaults to 30 minutes and moves earlier when a timed activity overlaps 5pm. Friday development starts at 1:30pm. Unknown event times stay above the timetable.

## Project requirements

Use Flutter/Dart for app screens and application logic. Visible text must serve a functional purpose. See `AGENTS.md`.
