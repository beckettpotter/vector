import 'package:material_ui/material_ui.dart';

import '../location.dart';
import '../maps/map_pack.dart';
import '../maps/maps.dart';
import '../theme.dart';

const String mapHonestyNote = "Downloading a map contacts the U.S. Geological Survey's servers, which can see your IP "
    'address and which map areas you requested. Vector never sends anything else. After the download, maps work '
    'offline.';

/// Settings, Maps: "Download map for the field". Nothing is downloaded until
/// Download is tapped.
class MapPackScreen extends StatefulWidget {
  final Maps maps;
  final DeviceLocation? location;

  /// Pre-fill with this point (for example the pad of the current flight).
  final double? lat, lon;
  final String? name;
  const MapPackScreen({super.key, required this.maps, this.location, this.lat, this.lon, this.name});

  @override
  State<MapPackScreen> createState() => _MapPackScreenState();
}

class _MapPackScreenState extends State<MapPackScreen> {
  late final _name = TextEditingController(text: widget.name ?? 'Hearne airport');
  late final _lat = TextEditingController(text: (widget.lat ?? hearneLat).toStringAsFixed(5));
  late final _lon = TextEditingController(text: (widget.lon ?? hearneLon).toStringAsFixed(5));
  double _radius = 5;

  @override
  void dispose() {
    _name.dispose();
    _lat.dispose();
    _lon.dispose();
    super.dispose();
  }

  void _set(String name, double lat, double lon) => setState(() {
        _name.text = name;
        _lat.text = lat.toStringAsFixed(5);
        _lon.text = lon.toStringAsFixed(5);
      });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final dim = text.bodyMedium?.copyWith(color: VxColors.textDim);
    return Scaffold(
      appBar: AppBar(title: const Text('Map for the field')),
      body: ListenableBuilder(
        listenable: Listenable.merge([widget.maps, widget.location]),
        builder: (context, _) {
          final m = widget.maps;
          final lat = double.tryParse(_lat.text.trim());
          final lon = double.tryParse(_lon.text.trim());
          final valid = lat != null && lon != null && lat.abs() <= 85 && lon.abs() <= 180;
          final count = valid ? tilesForArea(lat, lon, _radius).length : 0;
          final fix = widget.location?.state == LocationState.on ? widget.location?.fix : null;
          final p = m.progress;
          return ListView(padding: const EdgeInsets.all(16), children: [
            Text('Download satellite imagery for the launch field while you have internet (at home). At the field the '
                'map then works with no internet. US fields only.', style: text.bodyLarge),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton(
                key: const Key('presetHearne'),
                onPressed: () => _set('Hearne airport', hearneLat, hearneLon),
                child: const Text('Hearne airport'),
              ),
              if (widget.lat != null && widget.lon != null)
                OutlinedButton(
                  onPressed: () => _set(_name.text, widget.lat!, widget.lon!),
                  child: const Text('The pad of this flight'),
                ),
              if (fix != null)
                OutlinedButton(onPressed: () => _set(_name.text, fix.lat, fix.lon), child: const Text('My location')),
            ]),
            Text('The exact launch spot on Hearne airport is not known yet; the airport centre is used. Type the spot '
                'if you know it.', style: dim),
            const SizedBox(height: 12),
            TextField(
              key: const Key('packName'),
              controller: _name,
              decoration: const InputDecoration(labelText: 'Field name', border: OutlineInputBorder()),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _coord(_lat, 'Latitude', const Key('packLat'))),
              const SizedBox(width: 12),
              Expanded(child: _coord(_lon, 'Longitude', const Key('packLon'))),
            ]),
            const SizedBox(height: 12),
            Text('Area around that point', style: text.titleLarge),
            SegmentedButton<double>(
              segments: [for (final r in packRadiiKm) ButtonSegment(value: r, label: Text('${r.toStringAsFixed(0)} km'))],
              selected: {_radius},
              onSelectionChanged: (s) => setState(() => _radius = s.first),
            ),
            const SizedBox(height: 8),
            Text(
                valid
                    ? '$count tiles (zoom $packMinZoom to $packMaxZoom), about '
                        '${formatMb(count * estimatedTileBytes)}. Imagery shows detail down to about 2 m.'
                    : 'Type a latitude and longitude.',
                key: const Key('packEstimate'),
                style: text.bodyLarge),
            const SizedBox(height: 12),
            if (m.downloading && p != null) ...[
              LinearProgressIndicator(value: p.total == 0 ? null : p.done / p.total),
              Text('${p.done} of ${p.total} tiles, ${formatMb(p.bytes)}${p.failed > 0 ? ', ${p.failed} failed' : ''}',
                  style: text.bodyLarge),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(onPressed: m.cancel, child: const Text('Cancel download')),
              ),
            ] else
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  key: const Key('downloadPack'),
                  icon: const Icon(Icons.download),
                  label: const Text('Download map'),
                  onPressed: valid && _name.text.trim().isNotEmpty
                      ? () => m.download(_name.text.trim(), lat, lon, _radius)
                      : null,
                ),
              ),
            if (m.message != null) Text(m.message!, style: text.bodyLarge?.copyWith(color: VxColors.accent)),
            const SizedBox(height: 24),
            Text('Saved maps', style: text.headlineMedium),
            if (m.packs.isEmpty) Text('None yet.', style: text.bodyLarge),
            for (final pack in m.packs)
              Card(
                color: VxColors.surface,
                child: ListTile(
                  title: Text(pack.name, style: text.titleLarge),
                  subtitle: Text(
                      '${pack.lat.toStringAsFixed(4)}, ${pack.lon.toStringAsFixed(4)} · '
                      '${pack.radiusKm.toStringAsFixed(0)} km · ${formatMb(pack.bytes)}'
                      '${pack.complete ? '' : ' · incomplete'}',
                      style: dim),
                  trailing: IconButton(
                    tooltip: 'Delete map',
                    icon: const Icon(Icons.delete, color: VxColors.danger),
                    onPressed: m.downloading ? null : () => m.delete(pack),
                  ),
                ),
              ),
            const SizedBox(height: 24),
            Text(mapHonestyNote, key: const Key('mapHonesty'), style: dim),
            const SizedBox(height: 8),
            Text('Source: ${usgsImagery.name}. ${usgsImagery.credit} ${usgsImagery.imageryAge} (aerial photos, so new '
                "buildings or roads may be missing). USGS says this data is public domain. Its pages don't mention "
                'bulk tile downloads, so Vector downloads slowly, a few tiles at a time, and only the area you pick.',
                style: dim),
          ]);
        },
      ),
    );
  }

  Widget _coord(TextEditingController c, String label, Key key) => TextField(
        key: key,
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        onChanged: (_) => setState(() {}),
      );
}
