import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../link/link_controller.dart';
import '../link/link_monitor.dart';
import '../location.dart';
import '../protocol/navigation.dart';
import '../protocol/packet.dart';
import '../settings.dart';
import '../theme.dart';
import 'format.dart';

/// Which way to walk and how far, from the viewer to the rocket's last known fix.
class RecoveryView extends StatefulWidget {
  final LinkController link;
  final AppSettings settings;
  final DeviceLocation? location;
  const RecoveryView({super.key, required this.link, required this.settings, this.location});

  @override
  State<RecoveryView> createState() => _RecoveryViewState();
}

class _RecoveryViewState extends State<RecoveryView> {
  final _lat = TextEditingController();
  final _lon = TextEditingController();
  bool _typeInstead = false;

  @override
  void initState() {
    super.initState();
    final s = widget.settings;
    if (s.viewerLat != null) _lat.text = s.viewerLat!.toStringAsFixed(7);
    if (s.viewerLon != null) _lon.text = s.viewerLon!.toStringAsFixed(7);
  }

  @override
  void dispose() {
    _lat.dispose();
    _lon.dispose();
    super.dispose();
  }

  void _prefillWithPad(Packet? pad) {
    final s = widget.settings;
    if (pad == null || s.viewerLat != null) return;
    s.viewerLat = pad.latDeg;
    s.viewerLon = pad.lonDeg;
    _lat.text = pad.latDeg.toStringAsFixed(7);
    _lon.text = pad.lonDeg.toStringAsFixed(7);
  }

  void _onTyped() {
    final lat = double.tryParse(_lat.text.trim());
    final lon = double.tryParse(_lon.text.trim());
    final s = widget.settings;
    s.viewerLat = (lat != null && lat.abs() <= 90) ? lat : null;
    s.viewerLon = (lon != null && lon.abs() <= 180) ? lon : null;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.link, widget.settings, widget.location]),
      builder: (context, _) {
        final text = Theme.of(context).textTheme;
        final packets = [for (final f in widget.link.sessionFrames) f.packet];
        Packet? pad;
        for (final p in packets) {
          if (p.has3dFix) {
            pad = p;
            break;
          }
        }
        _prefillWithPad(pad);
        final fix = lastKnownFix(packets);
        final s = widget.settings;
        final loc = widget.location;
        final device = (loc != null && loc.state == LocationState.on && !_typeInstead) ? loc.fix : null;
        final viewerLat = device?.lat ?? s.viewerLat;
        final viewerLon = device?.lon ?? s.viewerLon;
        final viewerOk = viewerLat != null && viewerLon != null;
        final latest = packets.isEmpty ? null : packets.last;
        final flying = latest != null && latest.phase != Phase.landed;
        final linkOld = widget.link.monitor.status != LinkStatus.live;

        final children = <Widget>[];
        if (fix == null) {
          children.add(Padding(
            padding: const EdgeInsets.all(24),
            child: Text('No rocket position yet', style: text.headlineMedium, textAlign: TextAlign.center),
          ));
        } else {
          final r = fix.packet;
          final ageMs = fix.ageMs + (widget.link.monitor.sinceLastMs ?? 0);
          if (flying) {
            children.add(Container(
              color: VxColors.warning,
              padding: const EdgeInsets.all(12),
              child: const Text('ROCKET STILL FLYING: position will change',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.black)),
            ));
          }
          if (viewerOk) {
            final d = haversineM(viewerLat, viewerLon, r.latDeg, r.lonDeg);
            final b = bearingDeg(viewerLat, viewerLon, r.latDeg, r.lonDeg);
            children.add(Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(children: [
                SizedBox(
                  width: 140,
                  height: 140,
                  child: CustomPaint(painter: ArrowPainter(b, linkOld ? VxColors.textDim : VxColors.accent)),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('${d.toStringAsFixed(0)} m', style: text.displayLarge),
                    ),
                    Text('${(d * feetPerMeter).toStringAsFixed(0)} ft',
                        style: text.titleLarge?.copyWith(color: VxColors.textDim)),
                    const SizedBox(height: 8),
                    Text('${b.toStringAsFixed(0)}°  ${cardinal16(b)}',
                        style: text.displayMedium?.copyWith(color: VxColors.accent)),
                    Text('Arrow is north-up: turn so you face north, then follow it',
                        style: text.bodyMedium?.copyWith(color: VxColors.textDim)),
                  ]),
                ),
              ]),
            ));
          } else {
            children.add(Text('Type your position below to get distance and bearing.',
                style: text.titleLarge?.copyWith(color: VxColors.warning)));
          }
          final coords = '${r.latDeg.toStringAsFixed(7)}, ${r.lonDeg.toStringAsFixed(7)}';
          children.addAll([
            Text('Rocket last known position', style: text.bodyMedium?.copyWith(color: VxColors.textDim)),
            SelectableText(coords, style: text.headlineMedium),
            Text('Fix age: ${formatAge(ageMs)}',
                style: text.titleLarge?.copyWith(color: ageMs > 10000 ? VxColors.warning : VxColors.text)),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                icon: const Icon(Icons.copy),
                label: const Text('Copy coordinates'),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: coords));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Copied $coords')));
                  }
                },
              ),
            ),
          ]);
        }

        final locOn = loc != null && loc.state == LocationState.on;
        children.addAll([
          const SizedBox(height: 24),
          Text('Your position', style: text.titleLarge),
          if (device != null) ...[
            Text('From this device, accurate to about ${device.accuracyM.toStringAsFixed(0)} m. '
                'Not saved or sent anywhere.', style: text.bodyLarge?.copyWith(color: VxColors.ok)),
            SelectableText('${device.lat.toStringAsFixed(7)}, ${device.lon.toStringAsFixed(7)}',
                style: text.titleLarge),
          ] else if (locOn && !_typeInstead)
            Text('Waiting for this device\'s location. Using the typed position until then.',
                style: text.bodyMedium?.copyWith(color: VxColors.warning)),
          if (locOn)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('typeInstead'),
                onPressed: () => setState(() => _typeInstead = !_typeInstead),
                child: Text(_typeInstead ? 'Use this device\'s location' : 'Type my position instead'),
              ),
            ),
          if (device == null) ...[
            Text(
                'Type your latitude and longitude. Pre-filled with the pad.'
                '${locOn ? '' : ' To use this device\'s location, turn on "Use my location" in Pre-flight.'}',
                style: text.bodyMedium?.copyWith(color: VxColors.textDim)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _field(_lat, 'Latitude', const Key('viewerLat'))),
              const SizedBox(width: 12),
              Expanded(child: _field(_lon, 'Longitude', const Key('viewerLon'))),
            ]),
          ],
        ]);

        return ListView(padding: const EdgeInsets.all(16), children: children);
      },
    );
  }

  Widget _field(TextEditingController c, String label, Key key) => TextField(
        key: key,
        controller: c,
        style: const TextStyle(fontSize: 20),
        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        onChanged: (_) => _onTyped(),
      );
}

/// A north-up arrow rotated to the bearing.
class ArrowPainter extends CustomPainter {
  final double bearingDeg;
  final Color color;
  ArrowPainter(this.bearingDeg, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = math.min(size.width, size.height) / 2;
    canvas.drawCircle(c, r - 2, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFF3A3A3A));
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(bearingDeg * math.pi / 180);
    final arrow = Path()
      ..moveTo(0, -r * 0.85)
      ..lineTo(r * 0.38, r * 0.45)
      ..lineTo(0, r * 0.2)
      ..lineTo(-r * 0.38, r * 0.45)
      ..close();
    canvas.drawPath(arrow, Paint()..color = color);
    canvas.restore();
    final tp = TextPainter(
      text: const TextSpan(text: 'N', style: TextStyle(color: VxColors.textDim, fontSize: 14, fontWeight: FontWeight.w700)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(c.dx - tp.width / 2, c.dy - r - 2));
  }

  @override
  bool shouldRepaint(ArrowPainter old) => old.bearingDeg != bearingDeg || old.color != color;
}
