import 'package:material_ui/material_ui.dart';

import '../link/link_controller.dart';
import '../link/link_monitor.dart';
import '../openrocket/projection_store.dart';
import '../protocol/packet.dart';
import '../settings.dart';
import '../theme.dart';
import 'format.dart';
import 'projection_widgets.dart';

String phaseWord(Phase p) => p.name.toUpperCase();

Color phaseColor(Phase p) => switch (p) {
      Phase.pad => VxColors.textDim,
      Phase.boost => VxColors.danger,
      Phase.coast => VxColors.warning,
      Phase.apogee => VxColors.accent,
      Phase.descent => VxColors.ok,
      Phase.landed => VxColors.text,
    };

/// After this long without a packet the banner can be dismissed (or hides by
/// itself if the setting is on). The STALE and LOST thresholds do not change.
const int warningHideAfterMs = 20000;

/// Full-width STALE / LOST banner. Shown on every screen that shows live data.
/// Once dismissed or auto-hidden, a small "No link" chip stays in its place
/// until packets come back; the next outage shows the full banner again.
class StaleBanner extends StatelessWidget {
  final LinkController link;
  final AppSettings settings;
  const StaleBanner({super.key, required this.link, required this.settings});

  @override
  Widget build(BuildContext context) {
    final m = link.monitor;
    final status = m.status;
    if (status != LinkStatus.stale && status != LinkStatus.lost) return const SizedBox.shrink();
    final lost = status == LinkStatus.lost;
    final sinceMs = m.sinceLastMs ?? 0;
    final seconds = (sinceMs / 1000).floor();
    final color = lost ? VxColors.danger : VxColors.warning;
    final canHide = sinceMs >= warningHideAfterMs;

    if (canHide && (link.warningDismissed || settings.autoHideWarning)) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
          child: Text(
            'No link ${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      color: color,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(children: [
        Expanded(
          child: Text(
            '${lost ? 'LOST' : 'STALE'}: no packet for $seconds s',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.black),
          ),
        ),
        if (canHide)
          TextButton.icon(
            key: const Key('dismissWarning'),
            onPressed: link.dismissWarning,
            icon: const Icon(Icons.close, color: Colors.black),
            label: const Text('Dismiss', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
          ),
      ]),
    );
  }
}

class HudPanel extends StatelessWidget {
  final LinkController link;
  final AppSettings settings;
  final Projections? projections;
  const HudPanel({super.key, required this.link, required this.settings, this.projections});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([link, settings, projections]),
      builder: (context, _) {
        final frame = link.monitor.latest;
        if (frame == null) {
          final text = Theme.of(context).textTheme;
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              const Icon(Icons.rocket_launch, size: 72, color: VxColors.accent),
              const SizedBox(height: 12),
              Text('Waiting for a rocket', style: text.headlineMedium),
              const SizedBox(height: 12),
              Text(
                '1. At the field, join the ground node\'s Wi-Fi. To practise, run the simulator.\n'
                '2. Pick Ground node or Simulator in the Connection box.\n'
                '3. Press Connect. Live numbers appear here within a second of each packet.',
                style: text.bodyLarge?.copyWith(color: VxColors.textDim),
              ),
            ]),
          );
        }
        final p = frame.packet;
        final status = link.monitor.status;
        final old = status != LinkStatus.live;
        final feet = settings.useFeet;
        String alt(double m) => feet ? '${(m * feetPerMeter).toStringAsFixed(0)} ft' : '${m.toStringAsFixed(1)} m';
        String altSmall(double m) =>
            feet ? '${m.toStringAsFixed(1)} m' : '${(m * feetPerMeter).toStringAsFixed(0)} ft';
        final noFix = p.fixType == fixNone;
        final fixWord = switch (p.fixType) { 1 => '2D', 2 => '3D', 3 => '3D+', _ => 'NONE' };

        final tiles = <Widget>[
          _Tile(label: 'ALTITUDE (above pad)', value: alt(p.baroAltM), sub: altSmall(p.baroAltM), old: old),
          _Tile(label: 'MAX ALTITUDE', value: alt(link.maxAltM), sub: altSmall(link.maxAltM), old: old),
          _Tile(label: 'VERTICAL SPEED', value: '${p.vspeedMs.toStringAsFixed(1)} m/s', old: old),
          _Tile(label: 'PHASE', value: phaseWord(p.phase), color: phaseColor(p.phase), old: old),
          _Tile(
            label: 'GPS',
            value: noFix ? 'NO GPS FIX' : '$fixWord fix',
            sub: '${p.sats} satellites',
            color: noFix ? VxColors.warning : null,
            old: old,
          ),
          _Tile(
            label: 'BATTERY',
            value: '${p.batteryV.toStringAsFixed(2)} V',
            sub: p.lowBattery ? 'LOW BATTERY' : null,
            color: p.lowBattery ? VxColors.warning : null,
            old: old,
          ),
          _Tile(label: 'SIGNAL', value: '${frame.rssiDbm} dBm', sub: 'SNR ${frame.snrDb} dB', old: old),
          _Tile(
            label: 'SINCE LAST PACKET',
            value: formatAge(link.monitor.sinceLastMs),
            color: switch (status) {
              LinkStatus.stale => VxColors.warning,
              LinkStatus.lost => VxColors.danger,
              _ => null,
            },
          ),
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              const Spacer(),
              Text('Feet', style: Theme.of(context).textTheme.bodyMedium),
              Switch(key: const Key('feet'), value: feet, onChanged: (v) => settings.useFeet = v),
            ]),
            LayoutBuilder(builder: (context, c) {
              final columns = c.maxWidth >= 560 ? 2 : 1;
              final w = (c.maxWidth - 12 * (columns - 1)) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [for (final t in tiles) SizedBox(width: w, child: t)],
              );
            }),
            if (projections != null) LiveProjectionPanel(link: link, projections: projections!),
          ],
        );
      },
    );
  }
}

class _Tile extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final Color? color;
  final bool old;
  const _Tile({required this.label, required this.value, this.sub, this.color, this.old = false});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final valueColor = old ? VxColors.textDim : (color ?? VxColors.text);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VxColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: old ? VxColors.warning : const Color(0xFF2A2A2A), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(label, style: text.bodyMedium?.copyWith(color: VxColors.textDim))),
            if (old)
              Text('last known', style: text.bodyMedium?.copyWith(color: VxColors.warning)),
          ]),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: text.displayMedium?.copyWith(color: valueColor)),
          ),
          if (sub != null)
            Text(sub!, style: text.bodyLarge?.copyWith(color: old ? VxColors.textDim : (color ?? VxColors.textDim))),
        ],
      ),
    );
  }
}
