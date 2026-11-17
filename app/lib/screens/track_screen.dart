import 'dart:math' as math;

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:material_ui/material_ui.dart';

import '../link/link_controller.dart';
import '../link/link_monitor.dart';
import '../location.dart';
import '../maps/map_pack.dart';
import '../maps/maps.dart';
import '../protocol/geo.dart';
import '../settings.dart';
import '../theme.dart';
import 'format.dart';
import 'hud_screen.dart' show phaseColor;
import 'map_pack_screen.dart';

class TrackView extends StatelessWidget {
  final LinkController link;
  final DeviceLocation? location;
  final Maps? maps;
  final AppSettings? settings;
  const TrackView({super.key, required this.link, this.location, this.maps, this.settings});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([link, location, maps, settings]),
      builder: (context, _) {
        final text = Theme.of(context).textTheme;
        final track = buildTrack([for (final f in link.sessionFrames) f.packet]);
        if (track.pad == null) {
          return Center(child: Text('No GPS position yet', style: text.headlineMedium));
        }
        final old = link.monitor.status != LinkStatus.live;
        String? lostLabel;
        if (track.gpsLost || old) {
          final fixAgeMs = track.latest!.timeMs - track.lastFix!.timeMs + (link.monitor.sinceLastMs ?? 0);
          lostLabel = 'Last known position, age ${formatAge(fixAgeMs)}';
        }
        final distance = track.latestPos?.distanceM ?? 0;
        final me = location?.state == LocationState.on ? location?.fix : null;
        final pad = track.pad!;
        final mePos = me == null ? null : toEastNorth(pad.latDeg, pad.lonDeg, me.lat, me.lon);
        final pack = maps?.packFor(pad.latDeg, pad.lonDeg);
        final wantMap = settings?.showMap ?? false;
        final useMap = wantMap && pack != null && maps?.store != null;

        final Widget view = useMap
            ? TrackMap(track: track, pack: pack, store: maps!.store!, me: me == null ? null : LatLng(me.lat, me.lon))
            : Padding(
                padding: const EdgeInsets.all(8),
                child: CustomPaint(painter: TrackPainter(track, me: mePos), child: const SizedBox.expand()),
              );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(children: [
                Expanded(child: Text('${distance.toStringAsFixed(0)} m from pad', style: text.headlineMedium)),
                if (settings != null && maps != null)
                  SegmentedButton<bool>(
                    key: const Key('mapToggle'),
                    segments: const [
                      ButtonSegment(value: true, label: Text('Map')),
                      ButtonSegment(value: false, label: Text('Plot')),
                    ],
                    selected: {wantMap},
                    onSelectionChanged: (v) => settings!.showMap = v.first,
                  ),
              ]),
            ),
            if (lostLabel != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(lostLabel, style: text.titleLarge?.copyWith(color: VxColors.warning)),
              ),
            if (wantMap && pack == null && maps != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 12, children: [
                  Text('No map downloaded for this area. Showing the plot.',
                      style: text.bodyLarge?.copyWith(color: VxColors.textDim)),
                  TextButton(
                    key: const Key('downloadForField'),
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => MapPackScreen(
                            maps: maps!, location: location, lat: pad.latDeg, lon: pad.lonDeg, name: 'Launch field'))),
                    child: const Text('Download map for this field'),
                  ),
                ]),
              ),
            Expanded(child: view),
          ],
        );
      },
    );
  }
}

/// The track on the downloaded satellite imagery. Reads only stored tiles.
class TrackMap extends StatelessWidget {
  final Track track;
  final MapPack pack;
  final MapPackStore store;
  final LatLng? me;
  const TrackMap({super.key, required this.track, required this.pack, required this.store, this.me});

  static const double _r = 6371000.0;

  LatLng _toLatLng(EastNorth p) {
    final pad = track.pad!;
    return LatLng(pad.latDeg + p.northM / _r * 180 / math.pi,
        pad.lonDeg + p.eastM / (_r * math.cos(pad.latDeg * math.pi / 180)) * 180 / math.pi);
  }

  @override
  Widget build(BuildContext context) {
    final pad = LatLng(track.pad!.latDeg, track.pad!.lonDeg);
    final maxD = track.points.fold<double>(0, (m, p) => math.max(m, p.pos.distanceM));
    final rings = chooseRings(math.max(maxD, 50));
    final pts = [for (final p in track.points) _toLatLng(p.pos)];
    final solid = <List<LatLng>>[[]];
    final gaps = <Polyline>[];
    for (var i = 0; i < track.points.length; i++) {
      if (i > 0 && track.points[i].gapBefore) {
        gaps.add(Polyline(points: [pts[i - 1], pts[i]], color: VxColors.warning, strokeWidth: 2,
            pattern: StrokePattern.dashed(segments: const [6, 6])));
        solid.add([]);
      }
      solid.last.add(pts[i]);
    }
    final latest = track.latestPos == null ? null : _toLatLng(track.latestPos!);
    final ringLat = rings.last / 111320.0;
    return Stack(children: [
      FlutterMap(
        options: MapOptions(
          initialCameraFit: CameraFit.bounds(
            bounds: LatLngBounds(LatLng(pad.latitude - ringLat, pad.longitude - ringLat),
                LatLng(pad.latitude + ringLat, pad.longitude + ringLat)),
            padding: const EdgeInsets.all(24),
          ),
          minZoom: packMinZoom.toDouble(),
          maxZoom: 19,
          backgroundColor: VxColors.background,
        ),
        children: [
          TileLayer(
            tileProvider: PackTileProvider(store, pack),
            minNativeZoom: packMinZoom,
            maxNativeZoom: packMaxZoom,
            maxZoom: 19,
            userAgentPackageName: 'club.vector.vector',
          ),
          CircleLayer(circles: [
            for (final r in rings)
              CircleMarker(
                  point: pad,
                  radius: r,
                  useRadiusInMeter: true,
                  color: Colors.transparent,
                  borderColor: Colors.white54,
                  borderStrokeWidth: 1.5),
          ]),
          PolylineLayer(polylines: [
            for (final seg in solid)
              if (seg.length > 1) Polyline(points: seg, color: VxColors.accent, strokeWidth: 3),
            ...gaps,
          ]),
          MarkerLayer(markers: [
            Marker(
                point: pad,
                width: 14,
                height: 14,
                child: const _Labelled(label: 'PAD', color: Colors.white, size: 14,
                    child: ColoredBox(color: Colors.white))),
            if (me != null)
              Marker(
                  point: me!,
                  width: 16,
                  height: 16,
                  child: const _Labelled(label: 'YOU', color: Color(0xFF5DA3FF), size: 16,
                      child: _Dot(color: Color(0xFF2F80ED), size: 16))),
            if (latest != null && track.latest != null)
              Marker(point: latest, width: 24, height: 24, child: _Dot(color: phaseColor(track.latest!.phase), size: 22)),
          ]),
        ],
      ),
      Positioned(
        left: 8,
        right: 8,
        bottom: 8,
        child: Container(
          key: const Key('mapCredit'),
          padding: const EdgeInsets.all(6),
          color: Colors.black54,
          child: Text(
            '${usgsImagery.credit} ${usgsImagery.imageryAge}. Imagery limited to about 2 m detail.'
            '${pack.complete ? '' : ' Part of this map was not downloaded.'}',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ),
      ),
    ]);
  }
}

/// A marker anchored on [child], with its label drawn to the right of it.
class _Labelled extends StatelessWidget {
  final String label;
  final Color color;
  final double size;
  final Widget child;
  const _Labelled({required this.label, required this.color, required this.size, required this.child});
  @override
  Widget build(BuildContext context) => Stack(clipBehavior: Clip.none, children: [
        SizedBox(width: size, height: size, child: child),
        Positioned(
          left: size + 4,
          top: -2,
          child: Text(label, softWrap: false, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
        ),
      ]);
}

class _Dot extends StatelessWidget {
  final Color color;
  final double size;
  const _Dot({required this.color, required this.size});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
      );
}

class TrackPainter extends CustomPainter {
  final Track track;

  /// This device's position, if "Use my location" is on.
  final EastNorth? me;
  TrackPainter(this.track, {this.me});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final center = size.center(Offset.zero);
    var maxD = track.points.fold<double>(0, (m, p) => math.max(m, p.pos.distanceM));
    // Keep the viewer on the plot unless they are very far away.
    if (me != null && me!.distanceM < 10000) maxD = math.max(maxD, me!.distanceM);
    final rings = chooseRings(math.max(maxD, 50));
    final radiusPx = math.max(10.0, math.min(size.width, size.height) / 2 - 24);
    final pxPerM = radiusPx / rings.last;
    Offset toPx(EastNorth p) => center + Offset(p.eastM * pxPerM, -p.northM * pxPerM);

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = const Color(0xFF3A3A3A);
    for (final r in rings) {
      canvas.drawPath(_ring(center, r * pxPerM), ringPaint);
      _label(canvas, ringLabel(r), center + Offset(4, -r * pxPerM - 20), VxColors.textDim, 15);
    }

    // North arrow, top-right.
    final n = Offset(size.width - 32, 40);
    final arrow = Path()
      ..moveTo(n.dx, n.dy - 22)
      ..lineTo(n.dx - 10, n.dy + 6)
      ..lineTo(n.dx + 10, n.dy + 6)
      ..close();
    canvas.drawPath(arrow, Paint()..color = VxColors.text);
    _label(canvas, 'N', n + const Offset(-6, 8), VxColors.text, 18);

    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = VxColors.accent;
    final dashed = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = VxColors.warning;
    for (var i = 1; i < track.points.length; i++) {
      final a = toPx(track.points[i - 1].pos), b = toPx(track.points[i].pos);
      if (track.points[i].gapBefore) {
        _dashedLine(canvas, a, b, dashed);
      } else {
        canvas.drawLine(a, b, line);
      }
    }

    // Pad marker.
    final pad = Rect.fromCenter(center: center, width: 16, height: 16);
    canvas.drawRect(pad, Paint()..color = VxColors.text);
    _label(canvas, 'PAD', center + const Offset(12, 4), VxColors.text, 15);

    // The viewer, as a blue dot.
    if (me != null && me!.distanceM < 10000) {
      final at = toPx(me!);
      canvas.drawCircle(at, 9, Paint()..color = const Color(0xFF2F80ED));
      canvas.drawCircle(
          at,
          9,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = Colors.white);
      _label(canvas, 'YOU', at + const Offset(12, -8), const Color(0xFF5DA3FF), 15);
    }

    // Rocket's latest position, coloured by phase.
    final last = track.latestPos;
    if (last != null && track.latest != null) {
      final c = phaseColor(track.latest!.phase);
      canvas.drawCircle(toPx(last), 11, Paint()..color = c);
      canvas.drawCircle(
          toPx(last),
          11,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = Colors.white);
    }
  }

  // Built from short segments on purpose: large stroked circles (drawCircle or
  // addOval) rendered as a filled grey box with the software OpenGL renderer.
  Path _ring(Offset c, double r) {
    final path = Path()..moveTo(c.dx + r, c.dy);
    for (var i = 1; i <= 180; i++) {
      final a = i * 2 * math.pi / 180;
      path.lineTo(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
    }
    return path;
  }

  void _dashedLine(Canvas canvas, Offset a, Offset b, Paint paint) {
    final d = b - a;
    final len = d.distance;
    if (len == 0) return;
    final dir = d / len;
    for (double s = 0; s < len; s += 12) {
      canvas.drawLine(a + dir * s, a + dir * math.min(s + 6, len), paint);
    }
  }

  void _label(Canvas canvas, String s, Offset at, Color color, double size) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(color: color, fontSize: size, fontWeight: FontWeight.w600)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at);
  }

  @override
  bool shouldRepaint(TrackPainter old) => true;
}
