import 'package:fl_chart/fl_chart.dart';
import 'package:material_ui/material_ui.dart';

import '../protocol/flight_stats.dart';
import '../protocol/packet.dart';
import '../storage/flight_store.dart';
import '../theme.dart';
import 'format.dart';
import 'history_screen.dart';

/// Extra buttons on the detail screen (export and replay are added by later tasks).
class DetailActions {
  final List<Widget> Function(BuildContext context, FlightRecord record, List<GroundFrame> frames)? build;
  const DetailActions([this.build]);
}

class FlightDetailScreen extends StatefulWidget {
  final FlightStore store;
  final FlightRecord record;
  final DetailActions actions;
  const FlightDetailScreen({super.key, required this.store, required this.record, this.actions = const DetailActions()});

  @override
  State<FlightDetailScreen> createState() => _FlightDetailScreenState();
}

class _FlightDetailScreenState extends State<FlightDetailScreen> {
  late final Future<List<GroundFrame>> _frames = widget.store.load(widget.record);

  Future<void> _rename() async {
    final c = TextEditingController(text: widget.record.meta.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename flight'),
        content: TextField(controller: c, autofocus: true, style: const TextStyle(fontSize: 20)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await widget.store.rename(widget.record, name);
      setState(() {});
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this flight?'),
        content: Text('"${widget.record.meta.name}" will be removed from this device. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: VxColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await widget.store.delete(widget.record);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.record.meta.name, style: text.titleLarge),
        actions: [
          IconButton(tooltip: 'Rename', icon: const Icon(Icons.edit), onPressed: _rename),
          IconButton(tooltip: 'Delete', icon: const Icon(Icons.delete), onPressed: _delete),
        ],
      ),
      body: FutureBuilder<List<GroundFrame>>(
        future: _frames,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final frames = snap.data!;
          final stats = tryStats(frames);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(formatDateUtc(widget.record.meta.startedAtUtc), style: text.bodyLarge),
              Text('File: ${widget.record.hexFile.path}', style: text.bodyMedium?.copyWith(color: VxColors.textDim)),
              const SizedBox(height: 12),
              if (widget.actions.build != null)
                Wrap(spacing: 12, runSpacing: 12, children: widget.actions.build!(context, widget.record, frames)),
              const SizedBox(height: 12),
              if (stats == null)
                Text('Not a complete flight (no launch or no landing was received). ${frames.length} packets.',
                    style: text.titleLarge?.copyWith(color: VxColors.warning))
              else
                _StatsGrid(stats),
              ..._checklist(text),
              const SizedBox(height: 24),
              Text('Altitude above pad (m)', style: text.titleLarge),
              SizedBox(height: 260, child: _plot(frames, (p) => p.baroAltM, VxColors.accent)),
              const SizedBox(height: 24),
              Text('Vertical speed (m/s)', style: text.titleLarge),
              SizedBox(height: 260, child: _plot(frames, (p) => p.vspeedMs, VxColors.warning)),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _checklist(TextTheme text) {
    final meta = widget.record.meta;
    final items = meta.checklist;
    if (items == null && meta.launchNotes.isEmpty) return const [];
    final dim = text.bodyMedium?.copyWith(color: VxColors.textDim);
    return [
      const SizedBox(height: 24),
      Text('Pre-flight checklist at launch', style: text.titleLarge),
      for (final c in items ?? const <CheckedItem>[])
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(c.ticked ? Icons.check_box : Icons.check_box_outline_blank,
                color: c.ticked ? VxColors.ok : VxColors.warning),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${c.text}${c.ticked ? '' : ' (not ticked)'}', style: text.bodyLarge),
                if (c.note.isNotEmpty) Text('Note: ${c.note}', style: dim),
              ]),
            ),
          ]),
        ),
      if (meta.launchNotes.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text('Launch notes', style: text.bodyLarge),
        Text(meta.launchNotes, style: dim),
      ],
    ];
  }

  Widget _plot(List<GroundFrame> frames, double Function(Packet) y, Color color) {
    if (frames.isEmpty) return const SizedBox.shrink();
    final t0 = frames.first.packet.timeMs;
    final spots = [for (final f in frames) FlSpot((f.packet.timeMs - t0) / 1000.0, y(f.packet))];
    const label = TextStyle(color: VxColors.textDim, fontSize: 14);
    return LineChart(LineChartData(
      lineBarsData: [LineChartBarData(spots: spots, color: color, barWidth: 3, dotData: const FlDotData(show: false))],
      gridData: const FlGridData(show: true, drawVerticalLine: false),
      borderData: FlBorderData(show: false),
      lineTouchData: const LineTouchData(enabled: false),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          axisNameWidget: const Text('seconds', style: label),
          sideTitles: SideTitles(
              showTitles: true, reservedSize: 28, getTitlesWidget: (v, m) => _tick(v, m, label)),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
              showTitles: true, reservedSize: 52, getTitlesWidget: (v, m) => _tick(v, m, label)),
        ),
      ),
    ));
  }
}

// Skip the extra labels fl_chart adds at the exact min and max; they overlap.
Widget _tick(double v, TitleMeta m, TextStyle style) =>
    (v % m.appliedInterval).abs() > 1e-6 ? const SizedBox.shrink() : Text(v.toStringAsFixed(0), style: style);

class _StatsGrid extends StatelessWidget {
  final FlightStats s;
  const _StatsGrid(this.s);

  @override
  Widget build(BuildContext context) {
    final items = <(String, String, String?)>[
      ('Apogee', '${s.apogeeM.toStringAsFixed(1)} m', '${(s.apogeeM * feetPerMeter).toStringAsFixed(0)} ft'),
      ('Time to apogee', '${s.timeToApogeeS.toStringAsFixed(1)} s', null),
      ('Max vertical speed', '${s.maxVerticalSpeedMs.toStringAsFixed(1)} m/s',
          '${(s.maxVerticalSpeedMs * feetPerMeter).toStringAsFixed(0)} ft/s'),
      ('Descent rate', s.descentRateMs.isNaN ? '--' : '${s.descentRateMs.toStringAsFixed(1)} m/s',
          s.descentRateMs.isNaN ? null : '${(s.descentRateMs * feetPerMeter).toStringAsFixed(1)} ft/s'),
      ('Flight time', '${s.flightTimeS.toStringAsFixed(1)} s', null),
      ('Landing distance', s.landingDistanceM.isNaN ? '--' : '${s.landingDistanceM.toStringAsFixed(1)} m',
          s.landingDistanceM.isNaN ? null : '${(s.landingDistanceM * feetPerMeter).toStringAsFixed(0)} ft'),
      ('Packets', '${s.packetCount}', null),
    ];
    final text = Theme.of(context).textTheme;
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 700 ? 3 : (c.maxWidth >= 420 ? 2 : 1);
      final w = (c.maxWidth - 12 * (cols - 1)) / cols;
      return Wrap(spacing: 12, runSpacing: 12, children: [
        for (final (label, value, sub) in items)
          Container(
            width: w,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: VxColors.surface, borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: text.bodyMedium?.copyWith(color: VxColors.textDim)),
              Text(value, style: text.headlineMedium),
              if (sub != null) Text(sub, style: text.bodyMedium?.copyWith(color: VxColors.textDim)),
            ]),
          ),
      ]);
    });
  }
}
