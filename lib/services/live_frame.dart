import 'dart:typed_data';

/// Raw BGRA pixels owned in memory; no file path or encoded image.
class LiveFrame {
  final Uint8List bytes;
  final int width, height, bytesPerRow;
  const LiveFrame(this.bytes, this.width, this.height, this.bytesPerRow);
  Map<String, Object> toArguments() => {
    'pixels': bytes,
    'width': width,
    'height': height,
    'bytesPerRow': bytesPerRow,
  };
}

/// No pending queue: a frame is either accepted immediately or discarded.
class LiveFrameGate {
  final Duration interval;
  bool _busy = false;
  Duration? _last;
  LiveFrameGate({this.interval = const Duration(milliseconds: 500)});
  bool tryBegin(Duration now) {
    if (_busy || (_last != null && now - _last! < interval)) return false;
    _busy = true;
    _last = now;
    return true;
  }

  void complete() => _busy = false;
}
