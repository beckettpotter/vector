import 'package:material_ui/material_ui.dart';

import '../protocol/flight_stats.dart';
import '../protocol/packet.dart';
import '../storage/flight_store.dart';
import '../storage/recorder.dart';
import '../theme.dart';
import 'flight_detail_screen.dart';

class FlightSummary {
  final FlightRecord record;
  final FlightStats? stats;
  final int packetCount;
  const FlightSummary(this.record, this.stats, this.packetCount);
}

FlightStats? tryStats(List<GroundFrame> frames) {
  try {
    return frames.isEmpty ? null : computeStats([for (final f in frames) f.packet]);
  } on StateError {
    return null;
  }
}

String formatDateUtc(DateTime t) {
  final u = t.toUtc();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${u.year}-${two(u.month)}-${two(u.day)} ${two(u.hour)}:${two(u.minute)} UTC';
}

class HistoryView extends StatefulWidget {
  final FlightStore store;
  final Recorder recorder;
  final DetailActions actions;
  const HistoryView({super.key, required this.store, required this.recorder, this.actions = const DetailActions()});

  @override
  State<HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends State<HistoryView> {
  Future<List<FlightSummary>>? _flights;
  int _seenSaved = -1;

  Future<List<FlightSummary>> _load() async {
    final out = <FlightSummary>[];
    for (final r in await widget.store.list()) {
      final frames = await widget.store.load(r);
      out.add(FlightSummary(r, tryStats(frames), frames.length));
    }
    return out;
  }

  void _reload() => setState(() => _flights = _load());

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: widget.recorder,
      builder: (context, _) {
        if (_seenSaved != widget.recorder.savedCount) {
          _seenSaved = widget.recorder.savedCount;
          _flights = _load();
        }
        return FutureBuilder<List<FlightSummary>>(
          future: _flights,
          builder: (context, snap) {
            final recording = widget.recorder.recording
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Recording now: ${widget.recorder.recordedPackets} packets',
                        style: text.titleLarge?.copyWith(color: VxColors.danger)),
                  )
                : const SizedBox.shrink();
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final flights = snap.data!;
            if (flights.isEmpty) {
              return ListView(children: [
                recording,
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('No flights yet. Flights are saved automatically after launch.',
                      style: text.headlineMedium, textAlign: TextAlign.center),
                ),
              ]);
            }
            return ListView(
              padding: const EdgeInsets.all(8),
              children: [
                recording,
                for (final f in flights)
                  Card(
                    color: VxColors.surface,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      title: Text(f.record.meta.name, style: text.titleLarge),
                      subtitle: Text(formatDateUtc(f.record.meta.startedAtUtc),
                          style: text.bodyMedium?.copyWith(color: VxColors.textDim)),
                      trailing: Text(
                        f.stats == null ? '${f.packetCount} pkts' : '${f.stats!.apogeeM.toStringAsFixed(1)} m',
                        style: text.headlineMedium?.copyWith(color: VxColors.accent),
                      ),
                      onTap: () async {
                        await Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => FlightDetailScreen(store: widget.store, record: f.record, actions: widget.actions),
                        ));
                        _reload();
                      },
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
