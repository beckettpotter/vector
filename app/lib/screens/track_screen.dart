import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../link/link_controller.dart';
import '../link/link_monitor.dart';
import '../protocol/geo.dart';
import '../theme.dart';
import 'format.dart';
import 'hud_screen.dart' show phaseColor;

class TrackView extends StatelessWidget {
  final LinkController link;
  const TrackView({super.key, required this.link});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: link,
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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text('${distance.toStringAsFixed(0)} m from pad', style: text.headlineMedium),
            ),
            if (lostLabel != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(lostLabel, style: text.titleLarge?.copyWith(color: VxColors.warning)),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: CustomPaint(
                  painter: TrackPainter(track),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class TrackPainter extends CustomPainter {
  final Track track;
  TrackPainter(this.track);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final center = size.center(Offset.zero);
    final maxD = track.points.fold<double>(0, (m, p) => math.max(m, p.pos.distanceM));
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
