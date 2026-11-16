# Vector: Project Brief

Nov 16, 2026 · @Beckett Potter

Vector is a free, open, cross-platform app that lets our club track, watch and review every rocket flight on any device we already own, with no cloud service in the middle.

## Vision

Think ForeFlight plus FlightAware for rockets. From ForeFlight: pre-flight planning, a moving map and an instrument-style HUD. From FlightAware: a live track, a flight board of everything on the field, and a history of past flights.

The whole system is two small radios and one app. A tracker flies in the rocket. A receiver sits on the ground and talks straight to the app on a phone, tablet or laptop. Nothing depends on cell service, a vendor account or a server.

The MVP targets Level 1 rockets (H and I motors). The architecture is built to grow to IREC-class vehicles (10,000 and 30,000 ft apogee targets) by adding sensors, packet fields and radio range, not by redesigning the system.

## Who it's for and design principles

Five roles at a launch use the same data differently, so the app has one data model and a few focused views.

| Role | What they need from Vector |
| --- | --- |
| Flyer | Pre-flight checks, live HUD while the rocket is up, flight stats and plots afterward |
| Recovery crew | Last known position, bearing and distance to walk, signal strength, fix age |
| Launch director / RSO | A flight board showing every rocket on the field and its phase (pad, boost, coast, descent, landed) |
| Club members and spectators | Read-only live view on their own phone, no install friction |
| Team leads (future IREC) | Full flight data, exports, and comparisons across flights |

Five principles guide every decision:

- **No middlemen.** Rocket to ground node to app. No cloud, no cell service, no accounts. Anything shared between devices stays on the field's local network.
- **Minimal hardware.** One tracker in the rocket and one receiver on the ground. Everything else is software.
- **The tracker is never flight-critical.** It is a passive telemetry payload. It does not control deployment or ignition, so a Vector failure cannot cause a failed recovery.
- **Open protocol and open data.** A documented packet format and plain-file flight logs (CSV and KML) so the club is never locked in.
- **One app, six platforms.** Mac, Windows, Linux, iPhone, iPad and Android share one codebase and behave the same.

## MVP scope (L1 rockets)

The MVP is one rocket tracked live from pad to landing, with a clean flight record afterward. Design envelope: apogee up to about 5,000 ft AGL, line-of-sight range of at least 3 km, one telemetry packet per second.

**In the MVP**

- Tracker firmware: GPS position, barometric altitude, battery, flight phase, and a unique rocket ID, sent once per second
- Ground node firmware: receives packets and serves them to the app over its own Wi-Fi network
- Live HUD: altitude AGL, vertical speed, max altitude, flight phase, GPS fix status, battery, signal strength, and time since last packet
- Live map with the rocket, its track, the pad and the user's own position
- Recovery view: bearing and distance to the last known position, and fix age
- Pre-flight: rocket profiles (name, motor, mass, ID, frequency) and a checklist
- Auto-recorded flights with a summary (apogee, max speed, time to apogee, descent rate, landing distance from the pad) and altitude and speed plots
- Export to CSV and KML
- Read-only viewers: any club device on the same local network can watch the flight board
- Offline maps pre-loaded for our launch field
- Simulator and log replay, so the app can be built and demoed with no rocket

**If time allows**

- On-board 10 Hz logging on the tracker, downloaded over USB after flight to fill gaps in the live track
- Predicted landing point from descent rate and a manual wind input

**Not in the MVP**

- More than three rockets in the air at once
- Cloud sync, accounts or any public sharing site
- Any control of ignition, deployment or other actuation
- Importing data from commercial trackers
- IREC-grade sensors and high-rate live streaming

## System architecture

Data takes two hops from the rocket to the app, first LoRa radio and then local Wi-Fi, and no server, cloud account or cell tower is involved.

&#91;embedded content: system architecture · 3 units plus a simulator\]

The tracker sends one packet a second over LoRa. The ground node is the only extra hardware on the field: it receives each packet and streams it to every device on its own Wi-Fi network. The simulator speaks the same WebSocket protocol, so the app can be built and demoed with no rocket.

## Reference hardware

A first tracker plus ground node should cost roughly $65 to $135 in parts. All prices are approximate and from memory, so confirm before ordering. The radio is LoRa at 915 MHz, the license-free ISM band in the US; the club should confirm current FCC power limits before flying.

| Unit | Part | Notes | Approx. cost |
| --- | --- | --- | --- |
| Tracker | LoRa board with SX1262 radio and ESP32-S3 or RP2040 | Runs the firmware and the radio | $15 to $30 |
| Tracker | u-blox GPS module (M10 class) | Set to airborne mode; expect lost fix during boost and re-acquire in coast | $10 to $25 |
| Tracker | Barometer (BMP390 or MS5611) | Altitude and vertical speed | $5 to $15 |
| Tracker | 1S LiPo, 500 to 1000 mAh, plus 915 MHz antenna | Mount the antenna in a fiberglass or plastic section, never inside carbon fiber or metal | $10 to $20 |
| Ground node | Same LoRa board with an external antenna | Hosts the Wi-Fi network and relays packets to apps | $25 to $45 |
| Ground node (later) | Directional Yagi antenna | For homing in on a rocket when GPS is lost | $30 to $60 |

Firmware is C++ on PlatformIO using the open-source RadioLib library for the radio. Commercial trackers, such as Altus Metrum's TeleGPS or Featherweight's GPS tracker, stay out of scope for the MVP but could be added later as input adapters.

## App features

The app has four modes that follow the life of a flight, plus a club-wide flight board. It must be readable in direct sunlight: large type, high contrast, and a dark theme.

**1. Pre-launch**

- Rocket profiles with name, motor, mass, expected apogee, recovery method, and tracker ID
- A checklist per rocket (tracker armed, GPS fix, battery voltage, signal check at the pad)
- A link test that shows signal strength before the rocket leaves the pad

**2. Live HUD and tracker**

- Instrument panel: altitude AGL, vertical speed, max altitude, flight phase, GPS fix, battery, signal strength, and a stale-data warning when no packet has arrived recently
- Map with the rocket's track, the pad, and the viewer's position
- Automatic phase detection: pad, boost, coast, apogee, descent, landed

**3. Recovery**

- Bearing and distance from the viewer to the last known position, with the age of that fix
- Copy or share coordinates to other apps
- Later: signal-strength homing when GPS is lost

**4. Post-flight**

- Auto-saved flight with apogee, max speed, time to apogee, descent rate, and landing distance from the pad
- Altitude and speed plots, and a replayable track
- Export to CSV and KML for Google Earth

**Club flight board**

- Any device on the field's network sees every rocket's phase and status in read-only mode, like an arrivals board for the launch
- A flight history list the club can browse and compare

## Tech stack and vibecoding plan

The app is Flutter, the firmware is C++, and the ground node serves telemetry to every device over its own Wi-Fi network. That last choice is the key decision: Bluetooth and USB behave differently on each operating system (iOS cannot use generic USB serial, for example), while a Wi-Fi WebSocket connects identically on all six platforms and lets many devices watch at once.

| Layer | Choice | Why |
| --- | --- | --- |
| App | Flutter (Dart) | One codebase for iPhone, iPad, Android, macOS, Windows and Linux |
| Device link | WebSocket from the ground node's Wi-Fi access point | Same code path everywhere; multiple viewers at once |
| Maps | flutter\_map with pre-downloaded tiles | Works with no internet; check the tile source's terms allow offline use, since OpenStreetMap's public servers forbid bulk downloads |
| Storage | Local SQLite | Flights live on the device; no server |
| Firmware | C++ with PlatformIO and RadioLib | Mature open-source LoRa support |
| Simulator | Script that streams synthetic or recorded flights over the same WebSocket | Build and demo with no rocket |

Known gotchas: the phone joins a Wi-Fi network with no internet, and iOS asks for Local Network permission the first time.

**Vibecoding workflow**

1. Write the protocol spec first: packet layout, units, flight phases. Keep it in the repo as the source of truth, with test vectors.
2. Use one monorepo with folders for the app, tracker firmware, ground firmware, protocol, simulator and docs.
3. Build the simulator in week 1, then develop every screen against replayed flights. Replay data from the club's existing altimeters as well.
4. Keep an AGENTS.md file with conventions (SI units, UTC time, "the tracker is never flight-critical") so every AI session starts from the same rules.
5. Work in small vertical slices. Put unit tests on the pure logic, meaning packet parsing and phase detection.
6. Have a club member review anything involving radio settings, power or battery handling; do not accept those from AI output unchecked.
7. Set up CI that builds all six platforms. Ship iOS and iPad through TestFlight (needs an Apple developer account, about $99 a year), Android as an APK, and desktop as zipped builds.

## Data format and protocol

Each second the tracker sends one fixed 34-byte binary packet with a version byte and a CRC. The layout below is a proposed starting point; the final version lives in the repo's protocol spec.

| Field | Type | Unit or meaning |
| --- | --- | --- |
| version | uint8 | Protocol version |
| rocket\_id | uint16 | Unique per tracker |
| seq | uint16 | Packet counter, used to spot dropped packets |
| time | uint32 | Milliseconds since tracker boot |
| lat, lon | int32 each | Degrees × 10^-7 |
| gps\_alt | int32 | Centimeters above sea level |
| baro\_alt | int32 | Centimeters above the pad reference set when armed |
| vspeed | int16 | Centimeters per second |
| battery | uint16 | Millivolts |
| gps\_status | uint8 | Satellite count and fix type |
| phase | uint8 | Pad, boost, coast, apogee, descent, landed |
| flags | uint8 | Armed, low battery, other status bits |
| crc16 | uint16 | Integrity check |

The version byte and a packet-type field let us add richer packets later (accelerometer, gyro, pressure, temperatures) without breaking older apps, which is the path to IREC scale. Packets are not encrypted in the MVP.

Every flight is saved on the device as an open file: a header (rocket, pad location, date) followed by one row per packet. The app exports it as CSV for spreadsheets and KML for Google Earth, and can re-import it for replay.

## Roadmap: MVP to IREC

Vector grows in four phases, and each must pass a flight-test gate before the next begins.

&#91;embedded content: roadmap · 4 phases, 3 gates\]

The MVP (highlighted) is the only phase this brief plans in detail. Later phases reuse the same packet format, which is versioned for exactly this reason.

## Four-week plan

The MVP can be ready for rollout on Monday, December 14, 2026 if parts are ordered this week and a real flight test fits in week 4.

&#91;embedded content: four-week plan · 10 rows, Nov 16 to Dec 14\]

Software starts on the simulator, so hardware delays do not block it. Thanksgiving week (Nov 23 to 29) will be slow, and the flight test date depends on when the club next launches.

## Risks, safety and open questions

The biggest schedule risk is hardware, not software: parts arrive late or the radio and GPS take longer to bring up than planned. The plan below keeps software moving with the simulator so hardware delays do not stall the app.

| Risk | Mitigation |
| --- | --- |
| Hardware lead time and bring-up delays | Order parts in week 1, buy a spare of each board, build the simulator first |
| GPS loses lock during boost, leaving a gap in the live track | Set GPS airborne mode, expect re-acquire in coast, show the gap clearly, and later add on-board logging |
| Antenna blocked by carbon fiber or a metal bay | Place it in a fiberglass or plastic section, and range-test in the real airframe |
| Phones behave differently on a Wi-Fi network with no internet | Test iOS and Android in week 2; document the Local Network permission and cellular-fallback settings |
| Six platforms in one month is a lot | Ship iPhone and Android first plus one desktop OS; the others come from the same codebase but are verified after |
| Apple distribution takes time | Enroll in the Apple developer program in week 1 and plan for TestFlight |
| Several rockets on one radio channel | MVP supports up to three, each with a unique ID and randomized send timing |

**Safety and regulatory notes**

- The tracker must never connect to ejection, ignition or any recovery electronics. Follow the club's RSO rules and the NAR or Tripoli safety codes, and get RSO approval before the first flight.
- 915 MHz LoRa is license-free in the US within FCC power limits. Higher power or the 70 cm band would need an amateur radio license. Confirm the details with the club before launch day.

**Open questions for the club**

- Which date is the first launch where we can fly a tracker?
- Does anyone hold an amateur radio license?
- Who owns the repo and the Apple developer account?
- Which devices do members use most, so we can set platform priority?
- What is the parts budget?

## Success criteria

The MVP is ready for club rollout when a real L1 flight meets these targets. They are proposed numbers for the club to adjust.

- [ ] At least 90% of packets received from pad to landing on a real flight
- [ ] Signal confirmed at 3 km or more line of sight in a ground range test
- [ ] HUD updates within 1 second of each received packet
- [ ] Three devices (for example iPhone, Android and a laptop) watch the same flight at once
- [ ] Recovery view brings the crew to within 10 m of the rocket
- [ ] Flight auto-saves, and its CSV and KML exports open in a spreadsheet and Google Earth
- [ ] Simulator demo runs on all six platforms
- [ ] Tracker battery lasts at least 3 hours, enough for a long pad wait
- [ ] RSO sign-off confirms the tracker has no connection to recovery or ignition electronics
