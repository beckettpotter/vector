# Vector

Live rocket telemetry, tracking, recovery help and flight records for a rocketry club, on phones, tablets
and laptops, with no cloud in the middle. "ForeFlight plus FlightAware for rockets."

```
[Rocket tracker] --LoRa--> [Ground node] --Wi-Fi WebSocket--> [Vector app]
                                          [Simulator] --------^
```

- **Project brief** (vision, scope, hardware, plan): [`docs/BRIEF.md`](docs/BRIEF.md)
- **Packet protocol** (the contract): [`protocol/PROTOCOL.md`](protocol/PROTOCOL.md)
- **Progress**: [`PROGRESS.md`](PROGRESS.md) · **Launch day**: [`docs/LAUNCH_DAY.md`](docs/LAUNCH_DAY.md) ·
  **Building**: [`docs/BUILD.md`](docs/BUILD.md) · **Hardware questions for the club**: [`docs/HARDWARE_DECISIONS.md`](docs/HARDWARE_DECISIONS.md)

## Try it (Linux desktop)

One-time:

```
pip install -r requirements.txt
cd app && flutter pub get && cd ..
```

Then in one terminal:

```
python sim/simulate.py --speed 10 --pad-lat 30.8721 --pad-lon -96.6222
```

and in another:

```
cd app && flutter run -d linux
```

Press **Connect**. Watch the HUD climb to about 950 m, the Track drift east-northeast, and Recovery point
about 620 m at 76 degrees. The flight appears in History when it ends.

## Check everything

```
python scripts/check.py
```

Runs the Python protocol tests, `flutter analyze`, `flutter test`, and the firmware tests if PlatformIO is installed.

## Folders

| Folder | What |
| --- | --- |
| `app/` | The Flutter app |
| `protocol/` | Packet spec and generated test data (never edit by hand) |
| `tools/`, `sim/`, `tests/` | Python reference implementation, flight simulator, its tests |
| `firmware/` | C++ packet library and phase detector (boards wait for club review) |
| `tasks/` | The original task plan |
| `docs/` | Brief, launch day, build, hardware decisions, setup |

Safety: Vector is passive. It never controls ignition, ejection or deployment.
