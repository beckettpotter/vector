import 'package:material_ui/material_ui.dart';

import '../link/link_controller.dart';
import '../link/link_monitor.dart';
import '../protocol/packet.dart';
import '../settings.dart';
import '../theme.dart';

class PreflightView extends StatelessWidget {
  final LinkController link;
  final AppSettings settings;
  final Checklist checklist;
  const PreflightView({super.key, required this.link, required this.settings, required this.checklist});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([link, settings, checklist]),
      builder: (context, _) {
        final text = Theme.of(context).textTheme;
        final frame = link.monitor.status == LinkStatus.live ? link.monitor.latest : null;
        final p = frame?.packet;

        (String, Color) live(String item) {
          if (item == 'Club RSO approval') return ('Ask the RSO', VxColors.textDim);
          if (p == null) return ('no live data', VxColors.warning);
          return switch (item) {
            'Tracker armed' => p.armed ? ('ARMED', VxColors.ok) : ('not armed', VxColors.warning),
            'GPS fix on the pad' => p.fixType == fixNone
                ? ('NO GPS FIX', VxColors.warning)
                : ('${p.has3dFix ? '3D' : '2D'} fix, ${p.sats} sats', p.has3dFix ? VxColors.ok : VxColors.warning),
            'Battery above 3.7 V' => ('${p.batteryV.toStringAsFixed(2)} V',
                p.batteryMv >= 3700 && !p.lowBattery ? VxColors.ok : VxColors.danger),
            'Signal check' => ('${frame!.rssiDbm} dBm, SNR ${frame.snrDb} dB', VxColors.text),
            _ => ('', VxColors.text),
          };
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Pre-flight checklist', style: text.headlineMedium),
            Text('Ticks clear automatically at each launch.',
                style: text.bodyMedium?.copyWith(color: VxColors.textDim)),
            const SizedBox(height: 8),
            for (final item in Checklist.items)
              Card(
                color: VxColors.surface,
                child: CheckboxListTile(
                  value: checklist.ticked.contains(item),
                  onChanged: (_) => checklist.toggle(item),
                  title: Text(item, style: text.titleLarge),
                  subtitle: Text(live(item).$1, style: text.bodyLarge?.copyWith(color: live(item).$2)),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(onPressed: checklist.reset, child: const Text('Clear all ticks')),
            ),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(child: Text('Rocket profiles', style: text.headlineMedium)),
              FilledButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add rocket'),
                onPressed: () => _edit(context, null),
              ),
            ]),
            Text('Saved flights are named after the rocket whose tracker id matches, or the rocket chosen here.',
                style: text.bodyMedium?.copyWith(color: VxColors.textDim)),
            const SizedBox(height: 8),
            if (settings.profiles.isEmpty)
              Text('No rockets yet.', style: text.bodyLarge)
            else
              RadioGroup<String>(
                groupValue: settings.lastRocketName,
                onChanged: (v) => settings.lastRocketName = v ?? '',
                child: Column(children: [
                  for (final r in settings.profiles)
                    Card(
                      color: VxColors.surface,
                      child: RadioListTile<String>(
                        value: r.name,
                        title: Text(r.name, style: text.titleLarge),
                        subtitle: Text(_summary(r), style: text.bodyMedium?.copyWith(color: VxColors.textDim)),
                        secondary: IconButton(icon: const Icon(Icons.edit), onPressed: () => _edit(context, r)),
                      ),
                    ),
                ]),
              ),
            const SizedBox(height: 24),
            Text('Units', style: text.headlineMedium),
            SwitchListTile(
              title: Text('Show altitude in feet', style: text.titleLarge),
              value: settings.useFeet,
              onChanged: (v) => settings.useFeet = v,
            ),
          ],
        );
      },
    );
  }

  String _summary(RocketProfile r) => [
        if (r.motor.isNotEmpty) 'Motor ${r.motor}',
        if (r.massKg != null) '${r.massKg} kg',
        if (r.trackerId != null) 'Tracker id ${r.trackerId}',
        if (r.notes.isNotEmpty) r.notes,
      ].join(' · ');

  Future<void> _edit(BuildContext context, RocketProfile? existing) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final motor = TextEditingController(text: existing?.motor ?? '');
    final mass = TextEditingController(text: existing?.massKg?.toString() ?? '');
    final tracker = TextEditingController(text: existing?.trackerId?.toString() ?? '');
    final notes = TextEditingController(text: existing?.notes ?? '');
    Widget field(TextEditingController c, String label, {bool number = false}) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            controller: c,
            style: const TextStyle(fontSize: 20),
            keyboardType: number ? const TextInputType.numberWithOptions(decimal: true) : null,
            decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
          ),
        );
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Add rocket' : 'Edit rocket'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              field(name, 'Name'),
              field(motor, 'Motor (for example H128W)'),
              field(mass, 'Mass (kg)', number: true),
              field(tracker, 'Tracker id (rocket id in packets)', number: true),
              field(notes, 'Notes'),
            ]),
          ),
        ),
        actions: [
          if (existing != null)
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'delete'),
              child: const Text('Delete', style: TextStyle(color: VxColors.danger)),
            ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, 'save'), child: const Text('Save')),
        ],
      ),
    );
    if (result == 'delete' && existing != null) {
      settings.profiles.remove(existing);
      if (settings.lastRocketName == existing.name) settings.lastRocketName = '';
      settings.saveProfiles();
    } else if (result == 'save' && name.text.trim().isNotEmpty) {
      final r = existing ?? RocketProfile(name: '');
      final oldName = r.name;
      r
        ..name = name.text.trim()
        ..motor = motor.text.trim()
        ..massKg = double.tryParse(mass.text.trim())
        ..trackerId = int.tryParse(tracker.text.trim())
        ..notes = notes.text.trim();
      if (existing == null) settings.profiles.add(r);
      if (settings.lastRocketName == oldName || settings.lastRocketName.isEmpty) settings.lastRocketName = r.name;
      settings.saveProfiles();
    }
  }
}
