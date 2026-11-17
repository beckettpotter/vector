import 'dart:async';

import 'package:flutter/foundation.dart';

import '../protocol/packet.dart';
import 'frame_source.dart';

/// Plays saved frames as if they were a live link, through the same frame
/// stream and link monitor, so every screen works unchanged.
class ReplayLink extends ChangeNotifier implements FrameSource {
  final List<GroundFrame> recorded;
  final String name;
  ReplayLink(this.recorded, {required this.name, this.speed = 1});

  static const List<double> speeds = [1, 5, 10];

  final _frames = StreamController<GroundFrame>.broadcast();
  final _rejects = StreamController<String>.broadcast();
  final _states = StreamController<LinkConnection>.broadcast();

  @override
  Stream<GroundFrame> get frames => _frames.stream;
  @override
  Stream<String> get rejects => _rejects.stream;
  @override
  Stream<LinkConnection> get states => _states.stream;
  @override
  String? get lastError => null;
  @override
  bool get isReplay => true;

  LinkConnection _state = LinkConnection.disconnected;
  @override
  LinkConnection get state => _state;

  double speed;

  /// Index of the next frame to play.
  int position = 0;
  bool playing = false;
  Timer? _timer;

  int get length => recorded.length;

  void _setState(LinkConnection s) {
    _state = s;
    if (!_states.isClosed) _states.add(s);
    notifyListeners();
  }

  @override
  Future<void> start() async {
    position = 0;
    _setState(LinkConnection.connected);
    play();
  }

  void play() {
    if (position >= length) position = 0;
    playing = true;
    if (_state != LinkConnection.connected) _setState(LinkConnection.connected);
    _schedule(first: true);
    notifyListeners();
  }

  void pause() {
    playing = false;
    _timer?.cancel();
    notifyListeners();
  }

  void setSpeed(double s) {
    speed = s;
    if (playing) _schedule(first: true);
    notifyListeners();
  }

  /// Jump so that frames before [index] have been played. Going backwards
  /// replays from the start, which the link monitor sees as a new session.
  void seek(int index) {
    index = index.clamp(0, length);
    _timer?.cancel();
    if (index < position) position = 0;
    while (position < index) {
      _emit(recorded[position++]);
    }
    notifyListeners();
    if (playing) _schedule(first: true);
  }

  void _schedule({bool first = false}) {
    _timer?.cancel();
    if (!playing) return;
    if (position >= length) {
      playing = false;
      _setState(LinkConnection.finished);
      return;
    }
    var gapMs = 0;
    if (!first && position > 0) {
      gapMs = (recorded[position].packet.timeMs - recorded[position - 1].packet.timeMs).clamp(0, 10000);
    } else if (first && position > 0) {
      gapMs = 1000;
    }
    _timer = Timer(Duration(microseconds: (gapMs * 1000 / speed).round()), () {
      _emit(recorded[position++]);
      notifyListeners();
      _schedule();
    });
  }

  void _emit(GroundFrame f) {
    if (!_frames.isClosed) _frames.add(f);
  }

  @override
  Future<void> stop() async {
    _timer?.cancel();
    playing = false;
    _setState(LinkConnection.disconnected);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _frames.close();
    _rejects.close();
    _states.close();
    super.dispose();
  }
}
