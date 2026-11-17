# Vector v2.0 plan (revision 2, 2026-11-17)

Six improvements requested by Beckett. Read `HANDOFF.md`, `AGENTS.md` and `PROGRESS.md` first.
Rules that still apply: never edit the contract (`protocol/`, `tools/`, `sim/`, `tests/`) to make a test pass;
the CSV export must stay byte-identical to `protocol/sample_flight.csv`; stale data is never shown as live;
Vector never controls the rocket; no secrets in git; no accounts, no cloud, no middlemen. Explain to Beckett in plain
words (he does not code).

**Do not let v2 delay the MVP.** Finish the MVP checks, the hardware order and the first real flight test first.
Build order: e, d, f, c, a, b (smallest and least risky first). Add each item to `PROGRESS.md` as its own task with a
"Done when" line.

## Decisions Beckett has already made (do not re-ask)

1. **Cell service at the club field is unknown. Design for no internet at the field.** Every v2 feature must work fully
   offline. The only thing that ever needs internet is downloading map tiles beforehand.
2. **No Google account, no API key, ideally no billing.** Google maps are out of v2. Do not add Google SDKs, keys or
   billing prompts.
3. **Waiver ceiling is unknown.** The field is optional and blank by default; nothing warns or blocks when it is empty.
4. **Location toggle on every device.** The same "Use my location" setting exists on phone, tablet, laptop and desktop,
   per device, off by default (see c).
5. **The club field is at Hearne Municipal Airport (FAA LHB, ICAO KLHB), Hearne, Texas**: about 30.8721 N, 96.6222 W
   (AirNav lists this as estimated), field elevation about 87 m (285 ft). It is in the US, so USGS imagery covers it.
   Use it as the default centre for the map-pack downloader and offer it as a one-tap "Hearne airport" pad preset
   (the current default pad is Spaceport America). The exact launch spot on the airport is not known; ask Beckett to
   confirm or let him adjust the point on the map. Texas Central time: America/Chicago is correct for the default zone.
6. Beckett supplied a real OpenRocket export and `.ork` (see a). Put them in the repo:
   `app/test/fixtures/openrocket_real.csv` (his file is named `test.csv`) and `app/test/fixtures/journey75.ork`.

---

## a) OpenRocket import and projected-vs-actual comparison

**Goal:** import an OpenRocket simulation CSV so Beckett sees projected stats before flight, a live comparison during
flight, and a real-vs-predicted plot and table after flight. Only the CSV is parsed; the `.ork` is not (see below).

### The real file format (checked 2026-11-17 against Beckett's export)

The fixture is OpenRocket 24.12 output, UTF-8, 416 lines, **58 columns**, 399 data rows, 139,573 bytes. Rules the
parser must follow, all taken from that file:
- **The header is a comment line.** Line 6 starts `# Time (s),Altitude (m),...` (the `# ` prefix is part of the first
  cell). Find the header as the first `#` line whose first cell, after stripping `#` and spaces, starts with `Time (`.
  Also accept an uncommented header, because the export options can change this.
- **Events are `#` comment lines interleaved between data rows** (not at the top): `# Event BURNOUT occurred at
  t=2.398 seconds`. Optional text may follow a colon (`# Event SIM_WARN occurred at t=0 seconds: No recovery device
  defined in the simulation.`). Events in this file: SIM_WARN, IGNITION, LAUNCH, LIFTOFF (0.031 s), LAUNCHROD
  (0.142 s), BURNOUT (2.398 s), TUMBLE (10.798 s), APOGEE (10.841 s), EJECTION_CHARGE (16.398 s), GROUND_HIT
  (80.078 s), SIMULATION_END. Other events exist (for example deployment events); keep unknown ones as plain labels.
  The first lines also carry `# Simulation 1 (Up to date)`, the point count and `# Simulation warnings:` with indented
  warning lines. Surface warnings to Beckett.
- **Values:** plain decimals and scientific notation (`1.213e-4`); unavailable values are the text `NaN` (many columns
  are NaN at t=0); no thousands separators. Parse `NaN` as missing, not zero.
- **Units are in the header in parentheses** and contain non-ASCII characters: `m/s²`, `°`, `kg·m²`, and a zero-width
  space (U+200B) inside the unitless `(​)`. Match columns by the name before the parenthesis, case-insensitively, with
  whitespace and U+200B stripped. Read the file as UTF-8 and tolerate a byte-order mark.
- **The time step is not constant** (0.001 s to 0.5 s, finer during boost). Never assume a fixed rate: interpolate by
  time. Times are strictly increasing in this file; reject or sort a file where they are not.
- **Separators:** comma here, but the export also offers semicolon, space and tab. Detect from the header line.
- **Columns the app uses** (by name): `Time`, `Altitude`, `Vertical velocity`, `Vertical acceleration`,
  `Total velocity`, `Lateral distance`, `Lateral direction`, `Position East of launch`, `Position North of launch`,
  `Stability margin calibers`, `Mach number`. Everything else is ignored. Missing `Time` or `Altitude` → plain-words
  error naming the column to tick in OpenRocket's export dialog. Missing optional columns → hide that statistic.
- **Use `Altitude`** (above the launch site). `Altitude above sea level` is the same column plus the launch elevation
  (identical in this file); never mix them. Latitude and longitude in this file are OpenRocket's default Florida site
  (28.61, -80.6), **not Beckett's field**: do not use them for the map or the pad.

### What this specific export predicts (use as a test fixture, values computed from the file)

| Statistic | Value |
| --- | --- |
| Apogee | 852.6 m (2,797 ft) at t = 10.841 s |
| Burnout | t = 2.398 s, 348.9 m, 187.5 m/s up |
| Max vertical velocity | 211.2 m/s (max total velocity 211.2 m/s) |
| Max vertical acceleration | 16.8 g (peak of the `Vertical acceleration` column) |
| Max Mach | 0.62 |
| Descent rate (t = 20 to 70 s) | about 12.5 m/s |
| Ground hit | t = 80.078 s, lateral drift 160.7 m, direction 270° (west) |
| Stability margin | -0.41 cal at rod exit, minimum -10.5 cal |

Add a test that parses the real fixture and asserts these numbers within tolerance.

### Things this file teaches us (build these in)

- **No recovery device in the simulation.** The file warns of it. The "descent rate" (about 12.5 m/s) and "flight time"
  (80 s) are the airframe falling, not a parachute descent, and EJECTION_CHARGE at 16.398 s deploys nothing. If the file
  carries a `No recovery device` warning, label descent rate and flight time "Simulation has no recovery device" in
  gray, exclude them from the real-vs-predicted comparison table (still draw the curve, labelled), and tell Beckett
  in one line to add a recovery device in OpenRocket and re-export. Do not present them as a prediction.
- **The sample shows a negative stability margin** (-0.41 cal at rod exit). Show "Stability margin at rod exit"
  from OpenRocket's own number, with neutral wording when it is below 1.0 cal ("OpenRocket reports this design as
  unstable or marginal; check the design before flying"). Say plainly that it is OpenRocket's number, not Vector's
  measurement. Mention it to Beckett: the simulation may just be incomplete (no recovery, no payload), but check.
- **The `.ork` carries no simulation and no motor.** `JOURNEY_75.ork` is a zip containing `rocket.ork` (XML, kit name
  "Journey 75", fiberglass airframe, 75 mm, 3 fins) with an empty `<simulations>` section and no motor chosen. So
  the CSV is the only source of predictions. Do not parse the `.ork` for physics. Optionally read the kit name for a
  friendly default label. Offer Beckett a one-line instruction: in OpenRocket, add the motor and a recovery device,
  run the simulation, export the CSV again.
- **Filename is not the rocket.** Name the projection from the user (default: the file name) and let him link it to
  a rocket profile.

### Pre-flight (Pre-flight tab, attached to a rocket profile; copy the file into app storage)

A "Projection" card: predicted apogee (m and ft), max velocity, max acceleration (g), time to apogee, burnout time and
altitude, descent rate and flight time (subject to the no-recovery rule above), lateral drift and direction if the
columns exist, stability margin at rod exit if it exists, and any simulation warnings. Include an **optional "Waiver
ceiling" field, blank by default**; if filled, warn when projected apogee exceeds it, and say nothing when blank.
Stretch: up to three sims (for example low, nominal, high wind) shown as a range. One OpenRocket run is
deterministic, so do not invent error bars.

### During flight

Time zero is the first boost packet (OpenRocket t = 0 is ignition, liftoff is 0.031 s). Packets are 1 Hz, so launch
detection can be off by up to 1 s: document it and offer a ±1 s nudge. Interpolate the prediction at each packet's
time (never resample the real data). On the HUD show predicted altitude and vertical speed at this moment, the
difference, and an ahead/behind chip; add a small live altitude chart, real versus predicted. Before launch show the
projection only. Everything works without internet.

### After flight

On the flight detail screen (and in Replay): overlay plots of altitude and vertical velocity, real versus predicted,
plus a table (statistic, predicted, actual, difference, percent). Add RMS altitude error and error by phase (boost,
coast, descent). Write a short summary from the numbers ("flew 4.2% higher than predicted") with no claims about
causes. Save the projection into the flight's `.json` so History comparisons keep working later. OpenRocket altitude is
above the launch site; compare it to `baro_alt_cm` (above the pad reference).

### Tests

Synthetic OpenRocket-style CSV built from the sample flight with known perturbations (apogee 5% high, descent 1 m/s
slower) asserting the deltas; the real fixture (values above); NaN cells; comment-line header; events between rows;
semicolon, tab and space separators; missing optional columns; missing Time or Altitude; BOM; non-increasing time;
the no-recovery warning behaviour.

---

## b) Satellite map behind the track plot (offline-first, no key, no account, no billing)

**Goal:** real satellite imagery behind the track plot instead of a black background, working at a field with no cell
service, with the existing offline plot as the fallback. **Google is dropped for v2** (needs a key and billing; its Map
Tiles policy forbids pre-fetching and caching, so it cannot work offline; `google_maps_flutter` also lists no
Windows, macOS or Linux). Re-check these pages if Beckett ever asks for Google again.

### Chosen source: USGS National Map imagery (US fields)

Facts checked 2026-11-17 (re-read the pages before building; they can change):
- Service: `USGSImageryOnly` tile cache at `basemap.nationalmap.gov`. It needs **no account, no key and no billing**.
- Web Mercator, 256 px tiles, cached levels 0 to about 23 but **visible only to about zoom 16 (1:9,028)**.
  Resolution ranges 6 inch to 1 m per pixel. Main source for the lower 48 is NAIP aerial photos, **collected 2017-2021
  (Alaska 2020, Hawaii 2013)**, so new buildings or roads may be missing. Copyright line: "USDA, USGS The National Map:
  Orthoimagery. Data refreshed June, 2024."
- Terms: USGS says National Map data is "free and in the public domain" with "no restrictions on downloaded data", and
  asks for the credit "Map services and data available from U.S. Geological Survey, National Geospatial Program."
  **The pages checked do not say anything about caching tiles or bulk tile fetching.** The service's own item page has
  a blank license field. USGS offers bulk imagery through its Bulk Download Web Application; programmatic bulk is by
  request. So: keep downloads small and polite (below), and ask Beckett to be aware of this note. Re-read
  https://www.usgs.gov/faqs/what-are-terms-uselicensing-map-services-and-data-national-map before building.
- Coverage is US only. For a non-US field there is no free equivalent verified; show the plot.
- The tile URL pattern follows the ArcGIS REST convention `.../MapServer/tile/{z}/{y}/{x}` (note y before x). Verify
  with one real tile request before building; if it fails, read the service's own page for the right pattern.

### How it works

- **Offline map pack** (Settings, Maps, "Download map for the field"): while Beckett is on home Wi-Fi he picks the field
  (type coordinates, tap the map, or use his location if that setting is on), a radius (2, 5 or 10 km) and the pack is
  downloaded for zoom 12 to 16. Show the tile count and approximate size before starting (an estimate: a 10 km square
  at zoom 12 to 16 is on the order of a few hundred to a thousand tiles, roughly 10 to 30 MB; compute the real number
  in code), a progress bar, cancel and delete. Store tiles on the device. Never download without a tap.
- **Be polite to the server:** at most 2 to 4 requests at once, a short pause between batches, a User-Agent that names
  Vector, stop on repeated errors, no re-downloading tiles already stored, no background syncing, one pack per field.
- **At the field:** the map reads only from the stored pack. No network calls at the field, so the ground node's Wi-Fi
  (no internet) is fine. Tiles are shown from zoom 16 onward by scaling the zoom-16 tile (say "Imagery limited to about
  2 m detail" in a footnote).
- **Fallback:** if no pack exists, or the position is outside the pack, show the existing offline track plot plus one
  calm line: "No map downloaded for this area. Showing the plot." with a button "Download map for this field".
  The plot, the distance rings, the path, the pad and the rocket marker work with or without the map. Tapping off the
  map toggle also returns to the plot.
- **Use `flutter_map`** (works on all six platforms) with a small provider interface so another source can be added
  later (for example a user-supplied tile URL in an Advanced section; Beckett supplies his own terms-checked source).
  Pick the tile-caching approach (a package or a simple file cache) after checking what works on Linux, Windows, macOS,
  iOS and Android; the contract and CSV rules are unaffected.
- **Credit and age:** always show the USGS credit and "Imagery 2017-2021" (the dates for the pack's area if the
  service exposes them) on the map.
- **Honesty note in Settings:** "Downloading a map contacts the U.S. Geological Survey's servers, which can see your IP
  address and which map areas you requested. Vector never sends anything else. After the download, maps work offline."
- **Tests:** tile-math (lat/lon to tile for known points), tile counting for a radius, pack storage and deletion,
  fallback when the pack is missing, no network call when a pack exists (assert with a fake HTTP client), UI shows the
  credit. Do one real one-tile request manually and note the result in `PROGRESS.md`.

---

## c) Optional user location (clear opt-in), on every device

**Goal:** an optional "use my location" feature (blue dot on the map, and the Recovery view replacing typed
coordinates). **Off by default; asked only when the user taps a button for it; never in the background; never stored
beyond the current session; never sent anywhere by Vector.** The setting exists on every platform, per device (it is
not synced, there are no accounts). Show Vector's own explanation before the system prompt. Suggested wording
(adjust, but keep it plain, direct and true):

> **Use your location?**
> Vector can show where you are on the map and point you toward the rocket. Your location stays on this device.
> Vector doesn't send it anywhere or save it. You can turn this off any time in Settings, and everything still works
> without it: you can type your position instead.
> [Use my location]  [Not now]

Do **not** mention map providers in this text any more; the map only contacts a server when a pack is downloaded
(see b), and that request contains the field area Beckett chose, not his live position.

If the OS says no, show one calm line and keep manual entry working. No guilt, countdowns or repeat nagging.
**Platform honesty:** phones and tablets have GPS; Windows and macOS use the OS location service; desktop Linux relies on
GeoClue and may be slow, coarse or unavailable. Check what each platform really supports (see `geolocator` and its
platform packages) and tell Beckett plainly which devices will work and how accurate they are. Heading or compass only
where the device has one. Each device keeps its own toggle; a device that cannot provide location still shows the toggle
with "This device can't provide a location" and manual entry.

---

## d) Editable pre-flight checklist with notes

Add, edit, delete and (stretch) reorder checklist items; a "Reset to defaults" button; an optional note per item, and
one general notes box for the launch. Ticks reset each launch; items and notes persist. Save the checklist state and
notes into the flight record so History shows what was checked. Wrap storage reads so a failure falls back to defaults.

## e) Dismissible stale-link warning

After the link has been stale for about 20 s, show a dismiss control on the STALE banner, plus a setting "Auto-hide the
warning after 20 s" (off by default). Dismissing must not hide that the data is old: numbers stay greyed and labelled
"last known", and a small chip stays visible ("No link 0:42"). Re-arm the banner when frames resume and the link later
drops again. Keep the existing thresholds (stale 5 s, lost 30 s) unless Beckett says otherwise.

## f) Local time display

Setting "Time zone": **Chicago (default)**, this device's time zone, from my location (only if location is on), or any
zone picked from a list. Use IANA zone `America/Chicago` so daylight saving is handled (the UI should say "Chicago time",
not hard-code CST). Convert only for display (History, flight start, notes, checklist). Everything stored stays UTC.
Do not change the CSV format (the contract test requires the existing bytes); KML stays UTC. Durations like "time since
last packet" are not clock times. Location is not needed for the Chicago default or the picked zone.

---

## Still open (ask Beckett one at a time, only when needed)

1. Where exactly on Hearne airport is the launch spot (a point on the map is enough)? Optional; the airport centre works
   as a default.
2. Re-export the OpenRocket simulation with the motor, a recovery device and the launch site set to Hearne (about
   30.872 N, 96.622 W, 87 m elevation, so air density and altitude match), and check the stability margin, then send
   the new CSV; replace the fixture, update the numbers in the table above, and keep the old file as a second test case.
3. What is the real launch date for the first flight test?
