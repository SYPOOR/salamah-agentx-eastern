import 'package:flutter_test/flutter_test.dart';
import 'package:safety_lens_ai/services/live_frame.dart';

void main() {
  test('drops busy frames and never drains an old-frame queue', () {
    final gate = LiveFrameGate();
    expect(gate.tryBegin(Duration.zero), isTrue);
    for (var ms = 1; ms <= 900; ms += 33) {
      expect(gate.tryBegin(Duration(milliseconds: ms)), isFalse);
    }
    gate.complete();
    expect(gate.tryBegin(const Duration(milliseconds: 933)), isTrue);
    gate.complete();
    expect(gate.tryBegin(const Duration(milliseconds: 1000)), isFalse);
    expect(gate.tryBegin(const Duration(milliseconds: 1433)), isTrue);
  });
  test('accepts at most one frame every 500ms after fast inference', () {
    final gate = LiveFrameGate();
    var count = 0;
    for (var ms = 0; ms < 2000; ms++) {
      if (gate.tryBegin(Duration(milliseconds: ms))) {
        count++;
        gate.complete();
      }
    }
    expect(count, 4);
  });
}
