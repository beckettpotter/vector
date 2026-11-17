import 'package:material_ui/material_ui.dart';

import '../link/link_controller.dart';
import '../link/link_monitor.dart';
import '../location.dart';
import '../openrocket/projection_store.dart';
import '../protocol/packet.dart';
import '../checklist.dart';
import '../settings.dart';
import '../theme.dart';
import '../time_display.dart';
import 'projection_widgets.dart';

class PreflightView extends StatelessWidget {
  final LinkController link;
  final AppSettings settings;
  final Checklist checklist;
  final DeviceLocation? location;
  final Projections? projections;
  const PreflightView(
      {super.key,
      required this.link,
      required this.settings,
      required this.checklist,
      this.location,
      this.projections});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([link, settings, checklist, location, projections]),
      builder: (context, _) {
        final text = Theme.of(context).textTheme;
        final frame = link.monitor.status == LinkStatus.live ? link.monitor.latest : null;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ChecklistSection(checklist: checklist, frame: frame),
            if (projections != null) ...[
              const SizedBox(height: 24),
              ProjectionCard(projections: projections!, settings: settings),
            ],
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
            ListTile(
              key: const Key('timeZone'),
              title: Text('Time zone', style: text.titleLarge),
              subtitle: Text(
                '${timeZoneChoiceLabel(settings)}. Now: ${settings.formatTime(DateTime.now())}. '
                'Only changes how times are shown; saved files keep UTC.',
                style: text.bodyMedium?.copyWith(color: VxColors.textDim),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => pickTimeZone(context, settings, locationOn: location?.isOn ?? false),
            ),
            if (location != null) ...[
              const SizedBox(height: 24),
              Text('Location', style: text.headlineMedium),
              LocationSetting(settings: settings, location: location!),
            ],
            const SizedBox(height: 24),
            Text('Warnings', style: text.headlineMedium),
            SwitchListTile(
              key: const Key('autoHideWarning'),
              title: Text('Auto-hide the warning after 20 s', style: text.titleLarge),
              subtitle: Text(
                'The STALE or LOST banner hides by itself. A small "No link" timer stays on screen and old '
                'numbers stay greyed as "last known". You can also tap Dismiss on the banner after 20 s.',
                style: text.bodyMedium?.copyWith(color: VxColors.textDim),
              ),
              value: settings.autoHideWarning,
              onChanged: (v) => settings.autoHideWarning = v,
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

/// The live hint under a built-in checklist item, from the latest live packet.
(String, Color)? liveHint(String id, GroundFrame? frame) {
  final p = frame?.packet;
  if (id == 'rso') return ('Ask the RSO', VxColors.textDim);
  if (!const {'armed', 'gps', 'battery', 'signal'}.contains(id)) return null;
  if (p == null) return ('no live data', VxColors.warning);
  return switch (id) {
    'armed' => p.armed ? ('ARMED', VxColors.ok) : ('not armed', VxColors.warning),
    'gps' => p.fixType == fixNone
        ? ('NO GPS FIX', VxColors.warning)
        : ('${p.has3dFix ? '3D' : '2D'} fix, ${p.sats} sats', p.has3dFix ? VxColors.ok : VxColors.warning),
    'battery' =>
      ('${p.batteryV.toStringAsFixed(2)} V', p.batteryMv >= 3700 && !p.lowBattery ? VxColors.ok : VxColors.danger),
    _ => ('${frame!.rssiDbm} dBm, SNR ${frame.snrDb} dB', VxColors.text),
  };
}

/// Checklist with ticks, notes and an Edit mode, plus the launch notes box.
class ChecklistSection extends StatefulWidget {
  final Checklist checklist;
  final GroundFrame? frame;
  const ChecklistSection({super.key, required this.checklist, required this.frame});

  @override
  State<ChecklistSection> createState() => _ChecklistSectionState();
}

class _ChecklistSectionState extends State<ChecklistSection> {
  bool _editing = false;
  late final TextEditingController _notes = TextEditingController(text: widget.checklist.launchNotes);

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<String?> _ask(String title, String initial, String label, {bool multiline = false}) {
    final c = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 420,
          child: TextField(
            key: const Key('checklistDialogField'),
            controller: c,
            autofocus: true,
            minLines: multiline ? 3 : 1,
            maxLines: multiline ? 6 : 1,
            style: const TextStyle(fontSize: 20),
            decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Save')),
        ],
      ),
    );
  }

  Future<void> _resetToDefaults() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset the checklist?'),
        content: const Text('The list goes back to the five built-in items. Your added items and the notes on '
            'items are removed. The launch notes stay.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reset')),
        ],
      ),
    );
    if (ok == true) widget.checklist.resetToDefaults();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final c = widget.checklist;
    final dim = text.bodyMedium?.copyWith(color: VxColors.textDim);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(child: Text('Pre-flight checklist', style: text.headlineMedium)),
        TextButton.icon(
          key: const Key('editChecklist'),
          icon: Icon(_editing ? Icons.done : Icons.edit),
          label: Text(_editing ? 'Done' : 'Edit list'),
          onPressed: () => setState(() => _editing = !_editing),
        ),
      ]),
      Text('Ticks clear automatically at each launch. Items and notes are kept, and each saved flight remembers '
          'what was ticked.', style: dim),
      const SizedBox(height: 8),
      for (final (i, item) in c.items.indexed)
        Card(
          color: VxColors.surface,
          child: _editing ? _editRow(item, i, c.items.length) : _tickRow(item),
        ),
      if (c.items.isEmpty) Text('The list is empty.', style: text.bodyLarge),
      if (_editing)
        Wrap(spacing: 12, children: [
          TextButton.icon(
            key: const Key('addChecklistItem'),
            icon: const Icon(Icons.add),
            label: const Text('Add item'),
            onPressed: () async {
              final t = await _ask('Add item', '', 'Item');
              if (t != null && t.isNotEmpty) c.add(t);
            },
          ),
          TextButton(onPressed: _resetToDefaults, child: const Text('Reset to defaults')),
        ])
      else
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(onPressed: c.reset, child: const Text('Clear all ticks')),
        ),
      const SizedBox(height: 8),
      TextField(
        key: const Key('launchNotes'),
        controller: _notes,
        minLines: 2,
        maxLines: 6,
        style: const TextStyle(fontSize: 18),
        decoration: const InputDecoration(
          labelText: 'Launch notes (weather, wind, anything to remember)',
          border: OutlineInputBorder(),
        ),
        onChanged: (v) => c.launchNotes = v,
      ),
    ]);
  }

  Widget _tickRow(ChecklistItem item) {
    final text = Theme.of(context).textTheme;
    final hint = liveHint(item.id, widget.frame);
    return CheckboxListTile(
      value: widget.checklist.ticked.contains(item.id),
      onChanged: (_) => widget.checklist.toggle(item.id),
      title: Text(item.text, style: text.titleLarge),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (hint != null) Text(hint.$1, style: text.bodyLarge?.copyWith(color: hint.$2)),
        if (item.note.isNotEmpty) Text('Note: ${item.note}', style: text.bodyMedium?.copyWith(color: VxColors.textDim)),
      ]),
      secondary: IconButton(
        tooltip: item.note.isEmpty ? 'Add a note' : 'Edit the note',
        icon: Icon(item.note.isEmpty ? Icons.note_add_outlined : Icons.sticky_note_2),
        onPressed: () async {
          final n = await _ask('Note for "${item.text}"', item.note, 'Note', multiline: true);
          if (n != null) widget.checklist.edit(item, note: n);
        },
      ),
      controlAffinity: ListTileControlAffinity.leading,
    );
  }

  Widget _editRow(ChecklistItem item, int index, int count) {
    final c = widget.checklist;
    return ListTile(
      title: Text(item.text, style: Theme.of(context).textTheme.titleLarge),
      trailing: Wrap(children: [
        IconButton(
            tooltip: 'Move up', icon: const Icon(Icons.arrow_upward), onPressed: index == 0 ? null : () => c.move(item, -1)),
        IconButton(
            tooltip: 'Move down',
            icon: const Icon(Icons.arrow_downward),
            onPressed: index == count - 1 ? null : () => c.move(item, 1)),
        IconButton(
          tooltip: 'Rename',
          icon: const Icon(Icons.edit),
          onPressed: () async {
            final t = await _ask('Rename item', item.text, 'Item');
            if (t != null && t.isNotEmpty) c.edit(item, text: t);
          },
        ),
        IconButton(
          tooltip: 'Delete',
          icon: const Icon(Icons.delete, color: VxColors.danger),
          onPressed: () => c.remove(item),
        ),
      ]),
    );
  }
}

String timeZoneChoiceLabel(AppSettings s) => switch (s.timeZone) {
      chicagoZone => 'Chicago time (default)',
      deviceZoneSetting => "This device's time zone",
      locationZoneSetting => s.locationTimeZone == null
          ? "From my location (no location yet, using this device's zone)"
          : 'From my location: ${zoneLabel(s.locationTimeZone!)}',
      _ => zoneLabel(s.timeZone),
    };

Future<void> pickTimeZone(BuildContext context, AppSettings settings, {bool locationOn = false}) async {
  final choice = await showDialog<String>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: const Text('Show times in'),
      children: [
        for (final (value, label, sub) in [
          (chicagoZone, 'Chicago time (default)', 'The club field at Hearne. Daylight saving is handled.'),
          (deviceZoneSetting, "This device's time zone", 'Whatever this phone or computer is set to.'),
          (
            locationZoneSetting,
            'From my location',
            locationOn ? 'The zone where this device is now.' : 'Turn on "Use my location" first.'
          ),
          ('pick', 'Another zone...', 'Pick any zone from a list.'),
        ])
          SimpleDialogOption(
            key: Key('zone_$value'),
            onPressed: value == locationZoneSetting && !locationOn ? null : () => Navigator.pop(ctx, value),
            child: ListTile(title: Text(label), subtitle: Text(sub)),
          ),
      ],
    ),
  );
  if (choice == null || !context.mounted) return;
  if (choice != 'pick') {
    settings.timeZone = choice;
    return;
  }
  final zone = await showDialog<String>(context: context, builder: (_) => const _ZoneList());
  if (zone != null) settings.timeZone = zone;
}

class _ZoneList extends StatefulWidget {
  const _ZoneList();
  @override
  State<_ZoneList> createState() => _ZoneListState();
}

class _ZoneListState extends State<_ZoneList> {
  final _all = allZoneNames();
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final f = _filter.toLowerCase().replaceAll(' ', '_');
    final shown = [for (final z in _all) if (z.toLowerCase().contains(f)) z];
    return AlertDialog(
      title: const Text('Pick a time zone'),
      content: SizedBox(
        width: 420,
        height: 480,
        child: Column(children: [
          TextField(
            key: const Key('zoneSearch'),
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Search (for example Denver)', border: OutlineInputBorder()),
            onChanged: (v) => setState(() => _filter = v.trim()),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: shown.length,
              itemBuilder: (context, i) => ListTile(
                title: Text(zoneLabel(shown[i])),
                subtitle: Text(shown[i]),
                onTap: () => Navigator.pop(context, shown[i]),
              ),
            ),
          ),
        ]),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))],
    );
  }
}

/// The per-device "Use my location" switch. Vector's own explanation comes
/// before the system prompt; saying no never blocks anything.
class LocationSetting extends StatelessWidget {
  final AppSettings settings;
  final DeviceLocation location;
  const LocationSetting({super.key, required this.settings, required this.location});

  Future<void> _turnOn(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Use your location?'),
        content: const SizedBox(
          width: 460,
          child: Text('Vector can show where you are on the map and point you toward the rocket. Your location '
              "stays on this device. Vector doesn't send it anywhere or save it. You can turn this off any time "
              'here, and everything still works without it: you can type your position instead.',
              style: TextStyle(fontSize: 18)),
        ),
        actions: [
          TextButton(key: const Key('locationNotNow'), onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Not now')),
          FilledButton(key: const Key('locationYes'), onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Use my location')),
        ],
      ),
    );
    if (ok != true) return;
    settings.useLocation = true;
    await location.start();
    // If the system said no, the switch goes back off; the line below says why.
    if (location.state == LocationState.denied) settings.useLocation = false;
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final f = location.fix;
    final (String line, Color color) = switch (location.state) {
      LocationState.off => ('Off. Vector uses positions you type.', VxColors.textDim),
      LocationState.starting => ('Asking this device for its location...', VxColors.textDim),
      LocationState.on => f == null
          ? ('On. Waiting for the first position...', VxColors.textDim)
          : ('On. Accurate to about ${f.accuracyM.toStringAsFixed(0)} m.', VxColors.ok),
      LocationState.denied => (
          "Location wasn't allowed, so Vector uses positions you type. You can allow it later in this "
              "device's settings.",
          VxColors.textDim
        ),
      LocationState.unavailable => (
          "This device can't provide a location right now. You can type your position instead.",
          VxColors.textDim
        ),
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SwitchListTile(
        key: const Key('useLocation'),
        title: Text('Use my location', style: text.titleLarge),
        subtitle: Text(line, style: text.bodyMedium?.copyWith(color: color)),
        value: settings.useLocation && location.isOn,
        onChanged: (v) {
          if (v) {
            _turnOn(context);
          } else {
            settings.useLocation = false;
            location.stop();
          }
        },
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          'Only on this device, only while Vector is open. Phones and tablets use GPS: a few meters, and it '
          'works with no internet. Most laptops and desktops have no GPS: the system guesses from nearby '
          'Wi-Fi over the internet (tens to hundreds of meters), so at a field with no internet they '
          'usually cannot find a location. Typing your position always works.',
          style: text.bodyMedium?.copyWith(color: VxColors.textDim),
        ),
      ),
    ]);
  }
}
