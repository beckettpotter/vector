import 'packet.dart';

/// Reads the format of protocol/sample_flight.hex: one 36-byte ground frame as
/// hex per line. Blank lines are ignored; a bad line throws PacketError.
List<GroundFrame> parseHexFlight(String text) => [
      for (final line in text.split('\n'))
        if (line.trim().isNotEmpty) decodeGroundFrame(hexToBytes(line.trim())),
    ];
