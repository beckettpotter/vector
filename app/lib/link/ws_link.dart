import 'dart:async';
import 'dart:typed_data';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../protocol/packet.dart';
import 'frame_source.dart';

/// Connects to the ground node (or the simulator) and decodes every binary
/// message. Bad data is counted and ignored. Reconnects with a 1 s, 2 s, then
/// 5 s back-off until stop() is called.
class WsLink implements FrameSource {
  final Uri address;
  final List<Duration> backoff;
  WsLink(this.address, {this.backoff = const [Duration(seconds: 1), Duration(seconds: 2), Duration(seconds: 5)]});

  final _frames = StreamController<GroundFrame>.broadcast();
  final _rejects = StreamController<String>.broadcast();
  final _states = StreamController<LinkConnection>.broadcast();

  @override
  Stream<GroundFrame> get frames => _frames.stream;
  @override
  Stream<String> get rejects => _rejects.stream;
  @override
  Stream<LinkConnection> get states => _states.stream;

  LinkConnection _state = LinkConnection.disconnected;
  @override
  LinkConnection get state => _state;
  @override
  String? lastError;
  @override
  bool get isReplay => false;

  bool _wanted = false;
  int _generation = 0; // ignores results of connects started before stop()
  int _attempt = 0;
  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _retryTimer;

  void _setState(LinkConnection s) {
    _state = s;
    if (!_states.isClosed) _states.add(s);
  }

  @override
  Future<void> start() async {
    if (_wanted) return;
    _wanted = true;
    _generation++;
    _attempt = 0;
    await _connect();
  }

  Future<void> _connect() async {
    if (!_wanted) return;
    final gen = _generation;
    _setState(LinkConnection.connecting);
    try {
      final channel = WebSocketChannel.connect(address);
      _channel = channel;
      await channel.ready;
      if (!_wanted || gen != _generation) {
        await channel.sink.close();
        return;
      }
      _attempt = 0;
      lastError = null;
      _setState(LinkConnection.connected);
      _sub = channel.stream.listen(_onMessage,
          onError: (Object e) => _dropped(e.toString()), onDone: () => _dropped('connection closed'),
          cancelOnError: true);
    } catch (e) {
      if (gen == _generation) _dropped(e.toString());
    }
  }

  void _onMessage(dynamic message) {
    if (message is! List<int>) {
      if (!_rejects.isClosed) _rejects.add('not_binary');
      return;
    }
    try {
      final data = message is Uint8List ? message : Uint8List.fromList(message);
      final frame = decodeGroundFrame(data);
      if (!_frames.isClosed) _frames.add(frame);
    } on PacketError catch (e) {
      if (!_rejects.isClosed) _rejects.add(e.code);
    } catch (_) {
      if (!_rejects.isClosed) _rejects.add('bad_data');
    }
  }

  void _dropped(String why) {
    _sub?.cancel();
    _sub = null;
    _channel = null;
    if (!_wanted) return;
    lastError = why;
    final delay = backoff[_attempt < backoff.length ? _attempt : backoff.length - 1];
    _attempt++;
    _setState(LinkConnection.retrying);
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, _connect);
  }

  @override
  Future<void> stop() async {
    _wanted = false;
    _generation++;
    _retryTimer?.cancel();
    await _sub?.cancel();
    _sub = null;
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    _setState(LinkConnection.disconnected);
  }

  Future<void> dispose() async {
    await stop();
    await _frames.close();
    await _rejects.close();
    await _states.close();
  }
}
