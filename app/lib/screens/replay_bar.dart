import 'package:material_ui/material_ui.dart';

import '../link/link_controller.dart';
import '../link/replay_link.dart';
import '../theme.dart';

/// Shown on every tab while a saved flight is being replayed.
class ReplayBar extends StatelessWidget {
  final LinkController link;
  final ReplayLink replay;
  const ReplayBar({super.key, required this.link, required this.replay});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: replay,
      builder: (context, _) {
        final text = Theme.of(context).textTheme;
        return Container(
          color: const Color(0xFF0D3B66),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Column(children: [
            Row(children: [
              Expanded(
                child: Text('REPLAY: ${replay.name}',
                    style: text.titleLarge, overflow: TextOverflow.ellipsis),
              ),
              IconButton(
                key: const Key('replayPlay'),
                iconSize: 36,
                tooltip: replay.playing ? 'Pause' : 'Play',
                icon: Icon(replay.playing ? Icons.pause : Icons.play_arrow),
                onPressed: () => replay.playing ? replay.pause() : replay.play(),
              ),
              for (final s in ReplayLink.speeds)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: ChoiceChip(
                    label: Text('${s.toStringAsFixed(0)}x'),
                    selected: replay.speed == s,
                    onSelected: (_) => replay.setSpeed(s),
                  ),
                ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => link.disconnect(),
                child: const Text('Stop replay', style: TextStyle(color: VxColors.warning)),
              ),
            ]),
            Row(children: [
              Text('${replay.position}/${replay.length}', style: text.bodyMedium),
              Expanded(
                child: Slider(
                  value: replay.position.toDouble(),
                  max: replay.length.toDouble(),
                  onChanged: (v) => replay.seek(v.round()),
                ),
              ),
            ]),
          ]),
        );
      },
    );
  }
}
