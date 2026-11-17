import 'dart:io';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../protocol/packet.dart';
import '../storage/export.dart';
import '../storage/flight_store.dart';

/// Writes the export next to the flights folder (`Vector/exports/`), then opens
/// the share sheet. Linux has no file share sheet, so there (or if sharing
/// fails) it shows where the file was saved.
Future<void> exportFlight(BuildContext context, FlightRecord record, List<GroundFrame> frames, String kind) async {
  final text = kind == 'csv' ? flightToCsv(frames) : flightToKml(frames, record.meta.name);
  final exportsDir = Directory('${record.hexFile.parent.parent.path}${Platform.pathSeparator}exports');
  await exportsDir.create(recursive: true);
  final file = File('${exportsDir.path}${Platform.pathSeparator}${record.id}.$kind');
  await file.writeAsString(text, flush: true);
  if (!context.mounted) return;

  if (!Platform.isLinux) {
    try {
      final box = context.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, mimeType: kind == 'csv' ? 'text/csv' : 'application/vnd.google-earth.kml+xml')],
        subject: record.meta.name,
        sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      ));
      return;
    } catch (_) {
      // Fall through and show the saved path instead.
    }
  }
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('${kind.toUpperCase()} saved'),
      content: SelectableText(file.path, style: const TextStyle(fontSize: 18)),
      actions: [
        TextButton(
          onPressed: () => Clipboard.setData(ClipboardData(text: file.path)),
          child: const Text('Copy path'),
        ),
        FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
      ],
    ),
  );
}
