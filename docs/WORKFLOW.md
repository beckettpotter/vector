# The daily workflow (editing tool such as Cline)

Using Open WebUI instead? See `docs/OPENWEBUI.md`. The checks and the rules are the same.

The same four steps for every task.

## 1. Start a fresh session

Start a new chat in your coding tool for each task (long chats make small models forget the rules).
Open the kit folder, then send exactly this, with the task number filled in:

```
Read AGENTS.md and PROGRESS.md. Then do tasks/05_live_hud.md and nothing else.
```

## 2. Let it work, then run the check

When Devstral says it is done, run:

```
python scripts/check.py
```

- All **PASS** or **SKIP**: the task is done. Go to step 4.
- Any **FAIL**: go to step 3.

## 3. If something fails

1. Send Devstral: `The check failed. Here is last_check.txt:` and paste the file. Let it try again.
2. After 3 tries with no progress, or if it starts editing `protocol/`, `tools/`, `sim/` or `tests/`, stop it.
3. Paste `last_check.txt`, `PROGRESS.md`, and Devstral's last message to Claude.

Never accept "I removed the failing test". That is cheating the check.

## 4. See it with your own eyes

Passing tests is not enough for screens. Run the fake rocket and the app:

```
python sim/simulate.py --speed 10        # in one terminal window
cd app && flutter run -d macos           # in another (or -d windows / linux / chrome)
```

Each task file says what you should see. If what you see does not match, tell Devstral
in plain words ("the altitude number is cut off", "nothing changes after I press Connect") and
add a screenshot if the tool allows. Save your progress as you go: copy the whole kit folder
to a backup, or ask Claude how to set up Git (free, one-time).

## What to give Claude (me) instead of Devstral

- Anything about the protocol, radio, GPS, battery or safety.
- Anything Devstral could not fix in 3 tries.
- Changing the plan, adding a feature, or deciding between two approaches.
- Reviewing a finished task before you move on, if you want a second opinion: paste the changed files.

## Weekly rhythm for the four-week plan

| Week | Tasks |
| --- | --- |
| 1 | 01, 02, 03, 04 |
| 2 | 05, 06, 07, and order hardware |
| 3 | 08, 09, 10, and start 11 with a club hardware reviewer |
| 4 | 11, 12, real flight test |
