# Vector: rules for the coding assistant

You are building Vector for a rocketry club. Vector is a cross-platform app
(macOS, Windows, Linux, iPhone, iPad, Android) that shows live telemetry from a
model rocket's tracker on a phone, tablet or laptop. Think of it as a flight
instrument panel plus a flight tracker for rockets.

The person you are working with **does not write code**. They run what you build
and report what happened. So:

- Explain what you did in plain words, in at most 5 lines. No jargon without a one-line explanation.
- Never ask them to edit code by hand. Make the edit yourself.
- Give them exact commands to run, one per line, and say what a good result looks like.
- If you are unsure, ask one short question instead of guessing.

## How to work

1. Read `PROGRESS.md` first. It says what is done and what is next.
2. Do **one task file** from `tasks/` at a time, in numeric order. Read it fully before you start.
3. Stay inside the task. Do not add features, rename things or refactor things it did not ask for.
4. Write the tests the task asks for, then run `python scripts/check.py`.
5. If anything fails, fix it and run the check again. Stop when it passes.
6. Update `PROGRESS.md` (tick the task, add one line on what changed and anything the person must know).
7. Tell the person the task is done, how to see it working, and what the next task is.

If you cannot make the check pass after 3 honest attempts, stop. Write down exactly what you
tried and the error text in `PROGRESS.md`, and tell the person to paste `last_check.txt`
and `PROGRESS.md` to Claude.

## The contract (never break it)

- `protocol/PROTOCOL.md` defines the packet format. `protocol/vectors.json`, `vectors.h`,
  `sample_flight.hex`, `sample_flight.csv` and `expected_stats.json` are generated test data.
- **Never edit anything in `protocol/`, `tools/`, `sim/` or `tests/`.** If you think one of them is wrong,
  stop and tell the person to ask Claude. Do not "fix" it to make your code pass.
- Your code must reproduce the test data exactly. That is how we know it is right.
- Never weaken, skip or delete a test to make a check pass.

## Safety rules (rocketry)

- Vector is a passive tracker. It must **never** control ignition, ejection, deployment
  or anything else on the rocket. Do not write code that sends commands to the rocket.
- Never invent radio settings, frequencies, transmit power or battery-charging code.
  Those need a club member's review. If a task needs them, stop and ask.
- Bad data must never crash the app. Rejected packets are counted and ignored.
- If data is old, say so loudly in the UI. Never show an old value as if it were live.

## Code conventions

- App: Flutter and Dart in `app/`. Firmware: C++ in `firmware/`. Do not add other languages.
- Units inside the app: meters, seconds, meters per second, degrees. Convert from the packet units at the edge only.
- Times are UTC. Use a clear name with the unit for every number (`altitudeM`, `ageMs`).
- Keep files short and single-purpose. Put pure logic (parsing, statistics, phase handling) in its own files
  with no UI code, so it can be tested without a screen.
- Prefer a small, well-known package over writing your own. Add a package only if the task allows it,
  and say which one and why.
- Large type and high contrast. The app is read outdoors in direct sunlight.
- No cloud services, accounts, analytics or network calls except to the rocket's ground node or the simulator.
- Comments explain *why*, not *what*.

## Commands

```
python scripts/check.py              # checks everything; saves last_check.txt
python sim/simulate.py --speed 10    # fake rocket flight on ws://localhost:8765
python sim/listen.py                 # prints what the simulator is sending
cd app && flutter run -d macos       # run the app (or windows, linux, chrome)
cd app && flutter test               # app tests only
```

## Where things are

```
protocol/   the contract: spec + generated test data      (read only)
tools/      Python reference implementation               (read only)
sim/        flight simulator                              (read only)
tests/      Python tests for the above                    (read only)
app/        the Vector app (Flutter)                   (you build this)
firmware/   tracker and ground-node code (C++)            (you build this)
tasks/      the ordered task files                        (read only)
docs/       setup and workflow guides
PROGRESS.md what is done and what is next                 (you update this)
```
