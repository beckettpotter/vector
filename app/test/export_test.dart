import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vector/storage/export.dart';
import 'package:xml/xml.dart';

import 'helpers.dart';

void main() {
  test('exact decimal formatting from integers', () {
    expect(fixedFromInt(329900000, 7), '32.9900000');
    expect(fixedFromInt(-1069750000, 7), '-106.9750000');
    expect(fixedFromInt(-23, 2), '-0.23');
    expect(fixedFromInt(5, 2), '0.05');
    expect(fixedFromInt(0, 2), '0.00');
    expect(fixedFromInt(-1, 2), '-0.01');
  });

  test('CSV equals protocol/sample_flight.csv byte for byte', () {
    final expected = File('../protocol/sample_flight.csv').readAsStringSync();
    expect(flightToCsv(sampleFlight()), expected);
  });

  test('KML parses, has pad and landing placemarks, first coordinate is the pad', () {
    final frames = sampleFlight();
    final doc = XmlDocument.parse(flightToKml(frames, 'Test & <flight>'));
    expect(doc.findAllElements('name').first.innerText, 'Test & <flight>');
    final names = doc.findAllElements('Placemark').map((p) => p.getElement('name')!.innerText).toList();
    expect(names, containsAll(['Pad', 'Landing', 'Track']));
    final line = doc.findAllElements('LineString').single.getElement('coordinates')!.innerText.trim();
    final coords = line.split(RegExp(r'\s+'));
    final pad = frames.first.packet;
    expect(coords.first, '-106.9750000,32.9900000,${fixedFromInt(pad.gpsAltCm, 2)}');
    expect(coords.length, frames.where((f) => f.packet.has3dFix).length);
    final landing = doc
        .findAllElements('Placemark')
        .firstWhere((p) => p.getElement('name')!.innerText == 'Landing')
        .findAllElements('coordinates')
        .single
        .innerText;
    expect(landing, startsWith('-106.9685540,32.9913517,'));
  });
}
