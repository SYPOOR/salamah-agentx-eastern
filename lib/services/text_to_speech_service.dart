import 'package:audioplayers/audioplayers.dart';
import 'openai_service.dart';

class TextToSpeechService {
  final player = AudioPlayer();
  Future<void> speak(
    OpenAIService api,
    String text,
    bool Function() active,
  ) async {
    final bytes = await api.speech(text);
    if (!active()) return;
    await player.play(BytesSource(bytes, mimeType: 'audio/mpeg'));
  }

  Future<void> stop() => player.stop();
  Future<void> dispose() => player.dispose();
}
