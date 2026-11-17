# Task 01: Create the app and make it run

## Goal
A Flutter app called Vector exists in `app/`, runs on the person's desktop, and its checks pass.

## Read first
`AGENTS.md`. Nothing else is needed.

## Do
1. From the kit folder run `flutter create --project-name vector app`.
2. Delete the sample counter app. Replace `app/lib/main.dart` with a small app that shows a full-screen
   title "Vector" and the line "Waiting for a rocket" on a dark, high-contrast theme with large text.
3. Put the theme in `app/lib/theme.dart` (dark background, near-white text, one bright accent color,
   body text at least 18 pt). Keep `main.dart` short.
4. Replace the sample widget test in `app/test/` with one test that checks the "Vector" title and the
   "Waiting for a rocket" line appear.
5. Create the folders `app/lib/protocol/`, `app/lib/link/`, `app/lib/screens/`, `app/lib/storage/`
   (put an empty `.gitkeep` file in each). Later tasks use them.

## Do not
- Add any package.
- Add features, buttons or settings.

## Done when
- `python scripts/check.py` shows PASS for both App lines.
- The person runs `cd app && flutter run -d macos` (or `windows`, `linux`, `chrome`) and sees the dark Vector screen.

## Then
Tick task 01 in `PROGRESS.md`. Tell the person the exact `flutter run` command for their computer.
