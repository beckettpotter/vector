import 'package:file_picker/file_picker.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:material_ui/material_ui.dart';

import '../link/link_controller.dart';
import '../link/link_monitor.dart';
import '../link/replay_link.dart';
import '../openrocket/compare.dart';
import '../openrocket/projection.dart';
import '../openrocket/projection_store.dart';
import '../protocol/navigation.dart';
import '../protocol/packet.dart';
import '../settings.dart';
import '../theme.dart';
import 'format.dart';

const Color predictedColor = Color(0xFFB388FF);

String _m(double m) => '${m.toStringAsFixed(1)} m';
String _ft(double m) => '${(m * feetPerMeter).toStringAsFixed(0)} ft';
String _signed(double v, int places) => '${v >= 0 ? '+' : ''}${v.toStringAsFixed(places)}';

// ---------------------------------------------------------------------------
// Pre-flight: the Projection card.

class ProjectionCard extends StatelessWidget {
  final Projections projections;
  final AppSettings settings;

  /// Picks a file and returns (bytes, file name), or null if cancelled. Tests
  /// pass a fake; the app uses the system's open-file dialog.
  final Future<(List<int>, String)?> Function()? pickFile;
  const ProjectionCard({super.key, required this.projections, required this.settings, this.pickFile});

  static Future<(List<int>, String)?> systemPicker() async {
    final files = await FilePicker.pickFiles(
      dialogTitle: 'Choose an OpenRocket CSV export',
      type: FileType.custom,
      allowedExtensions: ['csv', 'txt'],
    );
    if (files.isEmpty) return null;
    return (await files.first.xFile.readAsBytes(), files.first.name);
  }

  Future<void> _import(BuildContext context) async {
    try {
      final picked = await (pickFile ?? systemPicker)();
      if (picked == null) return;
      await projections.importFile(picked.$1, picked.$2, rocketName: settings.lastRocketName);
    } catch (e) {
      projections.showError('Could not open the file dialog on this device: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final dim = text.bodyMedium?.copyWith(color: VxColors.textDim);
    final active = projections.active;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(child: Text('Projection (OpenRocket)', style: text.headlineMedium)),
        FilledButton.icon(
          key: const Key('importProjection'),
          icon: const Icon(Icons.file_open),
          label: const Text('Import CSV'),
          onPressed: () => _import(context),
        ),
      ]),
      Text('In OpenRocket, run the simulation, then Export as CSV. Vector compares the flight with it, live and '
          'afterwards. Only the CSV is used, not the .ork file.', style: dim),
      if (projections.lastError != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(projections.lastError!, style: text.bodyLarge?.copyWith(color: VxColors.warning)),
        ),
      const SizedBox(height: 8),
      if (projections.items.isEmpty)
        Text('No simulation imported yet. Everything else works without one.', style: text.bodyLarge)
      else
        RadioGroup<String>(
          groupValue: active?.id ?? '',
          onChanged: (v) => projections.setActive(v ?? ''),
          child: Column(children: [
            for (final s in projections.items)
              Card(
                color: VxColors.surface,
                child: RadioListTile<String>(
                  value: s.id,
                  title: Text(s.name, style: text.titleLarge),
                  subtitle: Text(
                      'Apogee ${_m(s.projection.apogeeM)} (${_ft(s.projection.apogeeM)})'
                      '${s.rocketName.isEmpty ? '' : ' · ${s.rocketName}'}',
                      style: dim),
                  secondary: IconButton(
                    tooltip: 'Edit',
                    icon: const Icon(Icons.edit),
                    onPressed: () => _edit(context, s),
                  ),
                ),
              ),
            RadioListTile<String>(value: '', title: Text('Fly without a projection', style: text.bodyLarge)),
          ]),
        ),
      if (active != null) ...[
        const SizedBox(height: 8),
        ProjectionDetails(projection: active.projection, settings: settings),
      ],
      const SizedBox(height: 12),
      WaiverField(settings: settings, projection: active?.projection),
    ]);
  }

  Future<void> _edit(BuildContext context, StoredProjection s) async {
    final name = TextEditingController(text: s.name);
    var rocket = s.rocketName;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Edit projection'),
          content: SizedBox(
            width: 420,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                key: const Key('projectionName'),
                controller: name,
                style: const TextStyle(fontSize: 20),
                decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: settings.profiles.any((r) => r.name == rocket) ? rocket : '',
                decoration: const InputDecoration(labelText: 'Rocket', border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem(value: '', child: Text('Not linked to a rocket')),
                  for (final r in settings.profiles) DropdownMenuItem(value: r.name, child: Text(r.name)),
                ],
                onChanged: (v) => setState(() => rocket = v ?? ''),
              ),
              const SizedBox(height: 8),
              Text('Choosing this rocket in Rocket profiles also picks this simulation.',
                  style: TextStyle(color: VxColors.textDim)),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'delete'),
              child: const Text('Delete', style: TextStyle(color: VxColors.danger)),
            ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, 'save'), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (result == 'save') await projections.update(s, name: name.text, rocketName: rocket);
    if (result == 'delete') await projections.remove(s);
  }
}

/// The predicted numbers, with the honesty rules: no-recovery descent in grey,
/// OpenRocket's own stability number, and its warnings.
class ProjectionDetails extends StatelessWidget {
  final Projection projection;
  final AppSettings settings;
  const ProjectionDetails({super.key, required this.projection, required this.settings});

  @override
  Widget build(BuildContext context) {
    final p = projection;
    final text = Theme.of(context).textTheme;
    final noRec = p.noRecoveryDevice;
    final items = <(String, String, String?, bool)>[
      ('Predicted apogee', _m(p.apogeeM), _ft(p.apogeeM), false),
      ('Time to apogee', '${p.apogeeT.toStringAsFixed(1)} s', null, false),
      ('Max vertical speed', '${p.maxVerticalSpeedMs.toStringAsFixed(1)} m/s', null, false),
      if (p.maxAccelG != null) ('Max acceleration', '${p.maxAccelG!.toStringAsFixed(1)} g', null, false),
      if (p.maxMach != null) ('Max Mach', p.maxMach!.toStringAsFixed(2), null, false),
      if (p.burnoutT != null)
        ('Burnout', '${p.burnoutT!.toStringAsFixed(2)} s',
            p.burnoutAltM == null ? null : 'at ${_m(p.burnoutAltM!)}', false),
      ('Descent rate', p.descentRateMs.isNaN ? '--' : '${p.descentRateMs.toStringAsFixed(1)} m/s',
          noRec ? noRecoveryLabel : null, noRec),
      ('Flight time', '${p.groundHitT.toStringAsFixed(1)} s', noRec ? noRecoveryLabel : null, noRec),
      if (p.driftM != null)
        ('Landing drift', _m(p.driftM!),
            p.driftDirDeg == null ? null : 'toward ${cardinal16(p.driftDirDeg!)} (${p.driftDirDeg!.toStringAsFixed(0)}°)',
            noRec),
      if (p.stabilityRodExitCal != null)
        ('Stability margin at rod exit', '${p.stabilityRodExitCal!.toStringAsFixed(2)} cal', "OpenRocket's number",
            false),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      LayoutBuilder(builder: (context, c) {
        final cols = c.maxWidth >= 700 ? 3 : (c.maxWidth >= 420 ? 2 : 1);
        final w = (c.maxWidth - 12 * (cols - 1)) / cols;
        return Wrap(spacing: 12, runSpacing: 12, children: [
          for (final (label, value, sub, grey) in items)
            Container(
              width: w,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: VxColors.surface, borderRadius: BorderRadius.circular(12)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: text.bodyMedium?.copyWith(color: VxColors.textDim)),
                Text(value, style: text.headlineMedium?.copyWith(color: grey ? VxColors.textDim : null)),
                if (sub != null) Text(sub, style: text.bodyMedium?.copyWith(color: VxColors.textDim)),
              ]),
            ),
        ]);
      }),
      if (p.marginalStability)
        _note(context,
            'OpenRocket reports this design as unstable or marginal (below 1.0 caliber at rod exit); check the '
            "design before flying. This is OpenRocket's number, not Vector's measurement. The simulation may just "
            'be incomplete (no recovery device, no payload).'),
      if (noRec)
        _note(context,
            'This simulation has no recovery device, so descent rate and flight time are the rocket falling, not a '
            'parachute descent. In OpenRocket, add the recovery device (and the motor), run the simulation and '
            'export the CSV again.'),
      for (final w in p.warnings) _note(context, 'OpenRocket warning: $w', color: VxColors.textDim),
    ]);
  }

  Widget _note(BuildContext context, String s, {Color color = VxColors.warning}) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(s, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: color)),
      );
}

/// Optional waiver ceiling. Blank by default; says nothing while blank.
class WaiverField extends StatefulWidget {
  final AppSettings settings;
  final Projection? projection;
  const WaiverField({super.key, required this.settings, this.projection});

  @override
  State<WaiverField> createState() => _WaiverFieldState();
}

class _WaiverFieldState extends State<WaiverField> {
  late final TextEditingController _c = TextEditingController(
      text: widget.settings.waiverCeilingM == null
          ? ''
          : (widget.settings.waiverCeilingM! * feetPerMeter).toStringAsFixed(0));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ceiling = widget.settings.waiverCeilingM;
    final p = widget.projection;
    final over = ceiling != null && p != null && p.apogeeM > ceiling;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextField(
        key: const Key('waiverCeiling'),
        controller: _c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: const TextStyle(fontSize: 20),
        decoration: const InputDecoration(
          labelText: 'Waiver ceiling in feet above the pad (optional)',
          border: OutlineInputBorder(),
        ),
        onChanged: (v) {
          final ft = double.tryParse(v.trim());
          widget.settings.waiverCeilingM = ft == null || ft <= 0 ? null : ft / feetPerMeter;
        },
      ),
      if (over)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            'Projected apogee ${_ft(p.apogeeM)} is above the waiver ceiling of ${_ft(ceiling)}.',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(color: VxColors.danger),
          ),
        ),
    ]);
  }
}

// ---------------------------------------------------------------------------
// HUD: live comparison.

/// The projection in use: a replay uses the one saved with its flight.
(Projection?, double) projectionInUse(LinkController link, Projections projections) {
  final src = link.source;
  if (src is ReplayLink) return (src.projection, src.projectionOffsetS + projections.offsetS);
  return (projections.active?.projection, projections.offsetS);
}

class LiveProjectionPanel extends StatelessWidget {
  final LinkController link;
  final Projections projections;
  const LiveProjectionPanel({super.key, required this.link, required this.projections});

  @override
  Widget build(BuildContext context) {
    final (proj, offset) = projectionInUse(link, projections);
    if (proj == null) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    final packets = [for (final f in link.sessionFrames) f.packet];
    final live = liveComparison(proj, packets, offsetS: offset);
    final old = link.monitor.status != LinkStatus.live;
    final dim = text.bodyMedium?.copyWith(color: VxColors.textDim);

    final children = <Widget>[
      Text('Projection: ${proj.name}', style: text.titleLarge),
    ];
    if (live == null) {
      children.add(Text(
          'Predicted apogee ${_m(proj.apogeeM)} (${_ft(proj.apogeeM)}) at ${proj.apogeeT.toStringAsFixed(1)} s. '
          'The comparison starts at launch.',
          style: text.bodyLarge));
    } else {
      final (chip, chipColor) = live.above
          ? ('ABOVE PREDICTION', VxColors.ok)
          : live.below
              ? ('BELOW PREDICTION', VxColors.warning)
              : ('ON PREDICTION', VxColors.accent);
      children.addAll([
        Wrap(spacing: 24, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          _value(context, 'PREDICTED NOW', _m(live.predictedAltM), old),
          _value(context, 'DIFFERENCE', '${_signed(live.altDiffM, 1)} m', old),
          _value(context, 'PREDICTED VERTICAL SPEED', '${live.predictedVvelMs.toStringAsFixed(1)} m/s', old),
          Container(
            key: const Key('aheadChip'),
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            decoration: BoxDecoration(
                color: old ? VxColors.textDim : chipColor, borderRadius: BorderRadius.circular(16)),
            child: Text(chip, style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.black)),
          ),
        ]),
        Text('${live.tS.toStringAsFixed(1)} s after launch${old ? ', last known' : ''}', style: dim),
        SizedBox(height: 180, child: _liveChart(packets, proj, offset)),
      ]);
    }
    children.add(Row(children: [
      Expanded(
        child: Text(
            'Launch time is taken from the first boost packet (1 per second), so it can be up to 1 s off. '
            'Nudge: ${_signed(projections.offsetS, 1)} s',
            style: dim),
      ),
      IconButton(
          key: const Key('nudgeMinus'),
          tooltip: 'Prediction 0.5 s later',
          onPressed: () => projections.nudge(-0.5),
          icon: const Icon(Icons.remove)),
      IconButton(
          key: const Key('nudgePlus'),
          tooltip: 'Prediction 0.5 s earlier',
          onPressed: () => projections.nudge(0.5),
          icon: const Icon(Icons.add)),
    ]));
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VxColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: old ? VxColors.warning : const Color(0xFF2A2A2A), width: 2),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _value(BuildContext context, String label, String value, bool old) {
    final text = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: text.bodyMedium?.copyWith(color: VxColors.textDim)),
      Text(value, style: text.headlineMedium?.copyWith(color: old ? VxColors.textDim : null)),
    ]);
  }

  Widget _liveChart(List<Packet> packets, Projection proj, double offset) {
    final launch = launchTimeMs(packets)!;
    final real = [
      for (final p in packets)
        if (p.timeMs >= launch) FlSpot(flightTimeS(p, launch, offset), p.baroAltM),
    ];
    return comparisonChart(real, proj.t, proj.alt, tMax: proj.groundHitT);
  }
}

/// Real (solid) against predicted (dashed purple).
Widget comparisonChart(List<FlSpot> real, List<double> pt, List<double> py, {required double tMax}) {
  final predicted = [
    for (var i = 0; i < pt.length; i++)
      if (!py[i].isNaN && pt[i] <= tMax) FlSpot(pt[i], py[i]),
  ];
  const label = TextStyle(color: VxColors.textDim, fontSize: 13);
  return LineChart(LineChartData(
    lineBarsData: [
      LineChartBarData(
          spots: predicted, color: predictedColor, barWidth: 2, dashArray: [6, 4], dotData: const FlDotData(show: false)),
      if (real.isNotEmpty)
        LineChartBarData(spots: real, color: VxColors.accent, barWidth: 3, dotData: const FlDotData(show: false)),
    ],
    gridData: const FlGridData(show: true, drawVerticalLine: false),
    borderData: FlBorderData(show: false),
    lineTouchData: const LineTouchData(enabled: false),
    titlesData: FlTitlesData(
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      bottomTitles: AxisTitles(
          axisNameWidget: const Text('seconds after launch', style: label),
          sideTitles: SideTitles(showTitles: true, reservedSize: 26, getTitlesWidget: (v, m) => _tick(v, m, label))),
      leftTitles: AxisTitles(
          sideTitles: SideTitles(showTitles: true, reservedSize: 52, getTitlesWidget: (v, m) => _tick(v, m, label))),
    ),
  ));
}

Widget _tick(double v, TitleMeta m, TextStyle style) =>
    (v % m.appliedInterval).abs() > 1e-6 ? const SizedBox.shrink() : Text(v.toStringAsFixed(0), style: style);

Widget chartLegend() => const Wrap(spacing: 16, children: [
      Text('━ real', style: TextStyle(color: VxColors.accent, fontWeight: FontWeight.w700)),
      Text('┅ OpenRocket prediction', style: TextStyle(color: predictedColor, fontWeight: FontWeight.w700)),
    ]);

// ---------------------------------------------------------------------------
// Flight detail: real versus predicted after the flight.

class ComparisonSection extends StatefulWidget {
  final Projection projection;
  final double initialOffsetS;
  final List<Packet> packets;
  const ComparisonSection({super.key, required this.projection, required this.packets, this.initialOffsetS = 0});

  @override
  State<ComparisonSection> createState() => _ComparisonSectionState();
}

class _ComparisonSectionState extends State<ComparisonSection> {
  late double _offset = widget.initialOffsetS;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final proj = widget.projection;
    final c = compareFlight(proj, widget.packets, offsetS: _offset);
    final dim = text.bodyMedium?.copyWith(color: VxColors.textDim);
    if (c == null) {
      return Text('No launch in this recording, so there is nothing to compare with "${proj.name}".', style: dim);
    }
    final launch = launchTimeMs(widget.packets)!;
    final after = [for (final p in widget.packets) if (p.timeMs >= launch) p];
    final tMax = [proj.groundHitT, if (after.isNotEmpty) flightTimeS(after.last, launch, _offset)]
        .reduce((a, b) => a > b ? a : b);

    String fmt(double v, String unit) => v.isNaN ? '--' : '${v.toStringAsFixed(1)} $unit';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Real versus predicted', style: text.headlineMedium),
      Text('OpenRocket simulation: ${proj.name}. OpenRocket altitude is above the launch site; Vector compares it '
          'with the barometric altitude above the pad.', style: dim),
      const SizedBox(height: 8),
      for (final s in c.summary) Text(s, style: text.titleLarge),
      const SizedBox(height: 12),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Statistic')),
            DataColumn(label: Text('Predicted'), numeric: true),
            DataColumn(label: Text('Actual'), numeric: true),
            DataColumn(label: Text('Difference'), numeric: true),
            DataColumn(label: Text('%'), numeric: true),
          ],
          rows: [
            for (final r in c.rows)
              DataRow(cells: [
                DataCell(Text(r.label)),
                DataCell(Text(fmt(r.predicted, r.unit),
                    style: TextStyle(color: r.excluded != null ? VxColors.textDim : null))),
                DataCell(Text(fmt(r.actual, r.unit))),
                if (r.excluded != null) ...[
                  DataCell(Text(r.excluded!, style: const TextStyle(color: VxColors.textDim))),
                  const DataCell(Text('')),
                ] else ...[
                  DataCell(Text(r.comparable ? '${_signed(r.difference, 1)} ${r.unit}' : '--')),
                  DataCell(Text(r.comparable && !r.percent.isNaN ? '${_signed(r.percent, 1)}%' : '--')),
                ],
              ]),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Text('Altitude error (real minus predicted, at each packet): RMS ${fmt(c.rmsAltM, 'm')}', style: text.titleLarge),
      for (final e in c.phases)
        if (e.packets > 0)
          Text('${e.phase}: RMS ${fmt(e.rmsM, 'm')}, average ${_signed(e.meanM, 1)} m (${e.packets} packets)',
              style: text.bodyLarge),
      Row(children: [
        Expanded(child: Text('Launch time nudge: ${_signed(_offset, 1)} s', style: dim)),
        IconButton(
            key: const Key('detailNudgeMinus'),
            onPressed: () => setState(() => _offset = (_offset - 0.5).clamp(-1.0, 1.0)),
            icon: const Icon(Icons.remove)),
        IconButton(
            key: const Key('detailNudgePlus'),
            onPressed: () => setState(() => _offset = (_offset + 0.5).clamp(-1.0, 1.0)),
            icon: const Icon(Icons.add)),
      ]),
      const SizedBox(height: 12),
      Text('Altitude (m), real versus predicted', style: text.titleLarge),
      chartLegend(),
      SizedBox(
        height: 260,
        child: comparisonChart([for (final p in after) FlSpot(flightTimeS(p, launch, _offset), p.baroAltM)], proj.t,
            proj.alt,
            tMax: tMax),
      ),
      const SizedBox(height: 24),
      Text('Vertical speed (m/s), real versus predicted', style: text.titleLarge),
      chartLegend(),
      SizedBox(
        height: 260,
        child: comparisonChart([for (final p in after) FlSpot(flightTimeS(p, launch, _offset), p.vspeedMs)], proj.t,
            proj.vvel,
            tMax: tMax),
      ),
      if (proj.noRecoveryDevice)
        Text('The predicted descent is the rocket falling with no recovery device in the simulation.', style: dim),
    ]);
  }
}
