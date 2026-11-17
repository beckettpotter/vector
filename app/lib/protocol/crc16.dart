import 'dart:typed_data';

/// CRC-16/CCITT-FALSE: poly 0x1021, init 0xFFFF, no reflection, no final XOR.
/// crc16("123456789") == 0x29B1.
int crc16(Uint8List data, [int length = -1]) {
  final n = length < 0 ? data.length : length;
  var crc = 0xFFFF;
  for (var i = 0; i < n; i++) {
    crc ^= data[i] << 8;
    for (var bit = 0; bit < 8; bit++) {
      crc = (crc & 0x8000) != 0 ? ((crc << 1) ^ 0x1021) & 0xFFFF : (crc << 1) & 0xFFFF;
    }
  }
  return crc;
}
