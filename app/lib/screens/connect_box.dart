import 'package:material_ui/material_ui.dart';

import '../link/frame_source.dart';
import '../link/link_controller.dart';
import '../theme.dart';
import 'format.dart';

/// Address field, Connect/Disconnect button and live link numbers.
class ConnectBox extends StatefulWidget {
  final LinkController link;
  const ConnectBox({super.key, required this.link});

  @override
  State<ConnectBox> createState() => _ConnectBoxState();
}

class _ConnectBoxState extends State<ConnectBox> {
  late final TextEditingController _address = TextEditingController(text: widget.link.address);
  String? _formatError;

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    final link = widget.link;
    if (link.isActive) {
      await link.disconnect();
      return;
    }
    try {
      setState(() => _formatError = null);
      await link.connect(_address.text);
    } on FormatException catch (e) {
      setState(() => _formatError = e.message);
    }
  }

  void _pick(String address) {
    _address.text = address;
    widget.link.address = address;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: widget.link,
      builder: (context, _) {
        final link = widget.link;
        final m = link.monitor;
        final active = link.isActive;
        final stateColor = switch (link.connection) {
          LinkConnection.connected => VxColors.ok,
          LinkConnection.retrying => VxColors.warning,
          _ => VxColors.textDim,
        };
        return Card(
          color: VxColors.surface,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Connection', style: text.titleLarge),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('address'),
                  controller: _address,
                  enabled: !active,
                  style: text.bodyLarge,
                  decoration: InputDecoration(
                    labelText: 'Address',
                    errorText: _formatError,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (v) => link.address = v,
                  onSubmitted: (_) => _toggle(),
                ),
                const SizedBox(height: 8),
                Wrap(spacing: 8, children: [
                  ActionChip(
                      label: const Text('Simulator'), onPressed: active ? null : () => _pick(simulatorAddress)),
                  ActionChip(
                      label: const Text('Ground node'), onPressed: active ? null : () => _pick(groundNodeAddress)),
                ]),
                const SizedBox(height: 12),
                FilledButton(
                  key: const Key('connect'),
                  onPressed: _toggle,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    backgroundColor: active ? VxColors.danger : VxColors.accent,
                  ),
                  child: Text(active ? 'Disconnect' : 'Connect'),
                ),
                const SizedBox(height: 12),
                Text(
                    link.connection == LinkConnection.retrying && m.frameCount > 0
                        ? 'Connection dropped, reconnecting...'
                        : connectionLabel(link.connection),
                    style: text.bodyLarge?.copyWith(color: stateColor)),
                if (link.connection == LinkConnection.retrying && link.lastError != null)
                  Text(_hint(link.address), style: text.bodyMedium?.copyWith(color: VxColors.textDim)),
                if (link.connection == LinkConnection.connected && m.frameCount == 0)
                  Text('Connected, but no packets yet. Is the tracker powered on?',
                      style: text.bodyMedium?.copyWith(color: VxColors.warning)),
                const SizedBox(height: 4),
                _line(text, 'Link', statusLabel(m.status)),
                _line(text, 'Frames received', '${m.frameCount}'),
                _line(text, 'Rejected', '${m.rejectedCount}'),
                _line(text, 'Lost packets', '${m.lostCount}'),
                _line(text, 'Since last frame', formatAge(m.sinceLastMs)),
              ],
            ),
          ),
        );
      },
    );
  }

  String _hint(String address) => address.contains('localhost') || address.contains('127.0.0.1')
      ? 'Is the simulator running? Start it with: python sim/simulate.py --speed 10'
      : 'Is this device on the ground node\'s Wi-Fi, and is the ground node powered on?';

  Widget _line(TextTheme text, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Expanded(child: Text(label, style: text.bodyMedium?.copyWith(color: VxColors.textDim))),
          Text(value, style: text.bodyMedium),
        ]),
      );
}
