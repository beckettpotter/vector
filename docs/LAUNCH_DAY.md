# Vector: launch-day procedure

One page. Print it and keep it in the range box.

**Safety first.** The Vector tracker is passive telemetry. It must never be connected to ignition,
ejection, deployment or recovery electronics. The RSO's word overrides anything on this page.

## Bring

- Ground node (LoRa receiver) with its antenna, and a USB power bank (charged) plus cable
- The tracker, its battery (charged), and its antenna, installed in a fiberglass or plastic section (never inside carbon fiber or metal)
- One or more devices with Vector installed (phone, tablet, laptop), charged, plus chargers
- This sheet, and the rocket's details for its Vector profile (name, motor, mass, tracker id)

## The night before (at home, with internet)

The club field (Hearne airport) may have no cell service. Everything in Vector works offline, but two things must
be done at home first:

- **Map:** Pre-flight, Maps, **Download map for the field**. Tap **Hearne airport**, pick 5 km, tap **Download map**.
  Do this on every device you will bring. Without it, the Track tab shows the plain plot (which still works).
- **OpenRocket (optional):** in OpenRocket add the motor and a recovery device, set the launch site to Hearne,
  run the simulation and export it as CSV. In Vector: Pre-flight, Projection, **Import CSV**, and link it to the
  rocket. Then the HUD compares the flight with the prediction.

## Set up at the field

1. Place the ground node with a clear view of the pad and the downrange area, antenna vertical, as high as practical.
2. Power the ground node from the power bank. Wait for it to create its Wi-Fi network.
3. On each device, join the ground node's Wi-Fi. **Phones may warn "no internet". That is expected.** Choose
   to stay connected (Android: "Keep Wi-Fi connection"; iPhone: allow Vector to find devices on the local network).
4. Open Vector. In **Connection**, tap **Ground node** (address `ws://192.168.4.1:81`), then **Connect**.
5. In **Pre-flight**, pick or add the rocket profile, so its flight is saved under its name. Write wind and
   weather in **Launch notes**; they are saved with the flight.

## Pre-flight checklist (in the app's Pre-flight tab)

- [ ] **Tracker armed**: the app shows ARMED.
- [ ] **GPS fix on the pad**: 3D fix, ideally 8 or more satellites. Wait for it. Without a pad fix there is no track.
- [ ] **Battery above 3.7 V**: shown in green. Below that, swap or charge before flying.
- [ ] **Signal check**: RSSI and SNR update every second. Walk the rocket to the pad and check it still updates.
- [ ] **Club RSO approval**: the RSO has seen that the tracker is not connected to any recovery or ignition electronics.

Ticks clear automatically when the rocket launches; what was ticked is saved with the flight. Tap **Edit list**
to add, rename, reorder or delete items, and the note icon to add a note to an item.

## During the flight

- The **HUD** shows altitude, max altitude, vertical speed, phase, GPS, battery, signal and time since the last packet.
- Expect **NO GPS FIX** during boost. The GPS usually comes back in coast. The track shows a dashed line across the gap.
- The flight is **saved automatically** from launch until 15 s after landing.
- With a projection, the HUD shows the predicted altitude now and **ABOVE / ON / BELOW PREDICTION**. Launch time is
  taken from the first boost packet (one per second), so use the **+ / -** nudge if the curves look shifted by a second.

## What the warnings mean

| You see | It means | Do this |
| --- | --- | --- |
| Amber **STALE** banner, numbers grey "last known" | No packet for 5 s | Keep watching. Common near apogee or at long range. Point the ground node antenna at the rocket. After 20 s you can tap **Dismiss**; a small "No link 0:42" timer stays. |
| Red **LOST** banner | No packet for 30 s | Use the last known position in **Recovery**. Walk toward it; the signal often returns when you get closer or higher. |
| **NO GPS FIX** | Tracker has no position right now | Normal during boost. On the pad, wait before launching. |
| Battery in amber or red, LOW BATTERY | Tracker battery is low | Do not fly until it is charged or swapped. |
| "Cannot reach it, retrying" | The device cannot reach the ground node | Check the device is on the ground node's Wi-Fi (not cellular), the ground node is powered, and the address is `ws://192.168.4.1:81`. |
| "Connected, but no packets yet" | Ground node is fine, tracker not heard | Check the tracker is powered and armed, and is on the club's agreed radio settings. |

## Recovery

1. After landing, open **Recovery**. It shows the distance and direction from **your position** to the rocket's last known fix.
2. Your position: with **Use my location** on (Pre-flight, Location), a phone or tablet uses its GPS, which works with
   no internet. Laptops usually cannot find their location at a field with no internet. Otherwise your position
   starts as the pad; type your current latitude and longitude if you have moved.
3. The arrow is **north-up** (there is no compass): face north first, then walk along the arrow. On the Track tab,
   the blue **YOU** dot shows where you are.
4. Tap **Copy coordinates** to paste the rocket's position into a maps app.
5. Fix age tells you how old the position is. If it is old, the rocket may have moved, for example dragged by the parachute.

## After the flight

- **History** lists every saved flight with apogee, in Chicago time (change it in Pre-flight, Time zone). Open one
  for stats, plots, **Real versus predicted** (if a projection was used), the checklist as it was at launch,
  **Export CSV** (spreadsheet), **Export KML** (Google Earth) and **Replay**.
- Flight files are plain text in `Documents/Vector/flights/` on each device that was connected.

## Practise at home

Run `python sim/simulate.py --speed 10` on a computer, choose **Simulator** in Vector, and press **Connect**.
To practise at Hearne (to try the downloaded map), add the field's position:
`python sim/simulate.py --speed 10 --pad-lat 30.8721 --pad-lon -96.6222`.
