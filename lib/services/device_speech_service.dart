import 'dart:async';

import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'openai_service.dart';

typedef LiveTranscript = void Function(String text, bool isFinal);

/// Live speech recognition through Apple's Speech framework.
///
/// Audio stays in the recognizer pipeline: this service never creates an audio
/// file. Partial text is published immediately and the caller decides when to
/// stop and submit the command.
class DeviceSpeechService {
  final SpeechToText _speech = SpeechToText();

  bool _initialized = false;
  bool _manualSession = false;
  bool _startingSegment = false;
  bool _preferOnDevice = true;
  String _committed = '';
  String _segment = '';
  String? _lastError;
  String? _localeId;
  LiveTranscript? _onText;
  void Function(double level)? _onLevel;
  void Function(String message)? _onFailure;

  bool get isListening => _manualSession;
  bool get usingOnDeviceRecognition => _preferOnDevice;
  String get text => _join(_committed, _segment).trim();

  Future<void> start({
    required LiveTranscript onText,
    required void Function(double level) onLevel,
    required void Function(String message) onFailure,
  }) async {
    await cancel();
    _committed = '';
    _segment = '';
    _lastError = null;
    _preferOnDevice = true;
    _onText = onText;
    _onLevel = onLevel;
    _onFailure = onFailure;

    if (!_initialized) {
      _initialized = await _speech.initialize(
        finalTimeout: const Duration(milliseconds: 450),
        onError: _handleError,
        onStatus: _handleStatus,
      );
    }
    if (!_initialized) {
      throw const AssistantException(
        'تعذر تشغيل التعرف على الكلام. فعّل الميكروفون والتعرف على الكلام من إعدادات الآيفون.',
      );
    }

    _localeId ??= await _arabicLocale();
    _manualSession = true;
    await _startSegment();
  }

  Future<String> stop() async {
    if (!_manualSession) return text;
    _manualSession = false;
    await _speech.stop();
    // iOS can deliver the final hypothesis immediately after stop(). The live
    // partial result remains usable even if no final callback is produced.
    await Future<void>.delayed(const Duration(milliseconds: 500));
    _commitSegment();
    _onLevel?.call(0);
    return text;
  }

  Future<void> cancel() async {
    _manualSession = false;
    if (_initialized) await _speech.cancel();
    _onLevel?.call(0);
  }

  Future<String> _arabicLocale() async {
    final locales = await _speech.locales();
    if (locales.isEmpty) {
      throw const AssistantException(
        'لا توجد لغة متاحة للتعرف على الكلام في هذا الآيفون.',
      );
    }
    LocaleName? arabicSaudi;
    LocaleName? arabic;
    for (final locale in locales) {
      final id = locale.localeId.toLowerCase().replaceAll('-', '_');
      if (id == 'ar_sa') arabicSaudi = locale;
      if (id.startsWith('ar_') || id == 'ar') arabic ??= locale;
    }
    return (arabicSaudi ??
            arabic ??
            await _speech.systemLocale() ??
            locales.first)
        .localeId;
  }

  Future<void> _startSegment() async {
    if (!_manualSession || _startingSegment) return;
    _startingSegment = true;
    _segment = '';
    try {
      await _listen(onDevice: _preferOnDevice);
    } on ListenFailedException {
      // Some Arabic installations expose the locale but do not have its
      // offline speech model downloaded. Continue through Apple's recognizer
      // instead of leaving the microphone button apparently broken.
      if (!_manualSession || !_preferOnDevice) rethrow;
      _preferOnDevice = false;
      await _listen(onDevice: false);
    } finally {
      _startingSegment = false;
    }
  }

  Future<void> _listen({required bool onDevice}) => _speech.listen(
    onResult: (result) {
      if (!_manualSession && result.recognizedWords.trim().isEmpty) return;
      _segment = result.recognizedWords.trim();
      _onText?.call(text, result.finalResult);
    },
    onSoundLevelChange: (level) {
      // AVAudioEngine reports dB, normally about -60 (quiet) to 0 (loud).
      final normalized = ((level + 60) / 60).clamp(0.0, 1.0).toDouble();
      _onLevel?.call(normalized);
    },
    listenOptions: SpeechListenOptions(
      localeId: _localeId,
      partialResults: true,
      onDevice: onDevice,
      listenMode: ListenMode.dictation,
      cancelOnError: true,
      autoPunctuation: true,
      enableHapticFeedback: true,
      contextualPhrases: const [
        'سلامة',
        'معدات الوقاية',
        'خوذة',
        'سترة السلامة',
        'قفازات',
        'نظارات السلامة',
        'منطقة محظورة',
        'التقط فريم',
        'ماذا أمامي',
      ],
    ),
  );

  void _handleStatus(String status) {
    if (!_manualSession) return;
    if (status == SpeechToText.doneStatus ||
        status == SpeechToText.notListeningStatus) {
      _commitSegment();
      // The OS may close one recognition task after a long pause. Keep the
      // user-controlled session alive until the red Stop button is pressed.
      Future<void>.delayed(const Duration(milliseconds: 180), () async {
        if (!_manualSession) return;
        try {
          await _startSegment();
        } catch (_) {
          if (_manualSession) {
            _manualSession = false;
            _onFailure?.call(_friendlyError(_lastError));
          }
        }
      });
    }
  }

  void _handleError(SpeechRecognitionError error) {
    _lastError = error.errorMsg;
    if (_manualSession &&
        _preferOnDevice &&
        (error.errorMsg == 'error_language_unavailable' ||
            error.errorMsg == 'error_language_not_supported' ||
            error.errorMsg == 'error_retry')) {
      _preferOnDevice = false;
      unawaited(_restartWithAppleRecognition());
      return;
    }
    if (!error.permanent || !_manualSession) return;
    _manualSession = false;
    _onFailure?.call(_friendlyError(error.errorMsg));
  }

  Future<void> _restartWithAppleRecognition() async {
    await _speech.cancel();
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!_manualSession) return;
    _startingSegment = false;
    try {
      await _startSegment();
    } catch (_) {
      if (_manualSession) {
        _manualSession = false;
        _onFailure?.call(_friendlyError(_lastError));
      }
    }
  }

  void _commitSegment() {
    if (_segment.trim().isEmpty) return;
    _committed = _join(_committed, _segment);
    _segment = '';
    _onText?.call(_committed, true);
  }

  static String _join(String first, String second) {
    if (first.trim().isEmpty) return second.trim();
    if (second.trim().isEmpty) return first.trim();
    return '${first.trim()} ${second.trim()}';
  }

  String _friendlyError(String? code) {
    if (code == 'error_permission' ||
        code == 'error_speech_recognizer_disabled') {
      return 'فعّل الميكروفون والتعرف على الكلام لتطبيق SafetyLens من إعدادات الآيفون.';
    }
    if (code == 'error_language_unavailable' ||
        code == 'error_language_not_supported') {
      return 'العربية غير متاحة للتعرف على الكلام. أضف لوحة مفاتيح العربية وفعّل الإملاء من إعدادات الآيفون.';
    }
    return 'توقف التعرف على الكلام في iOS. اضغط الميكروفون وابدأ مرة أخرى.';
  }

  void dispose() {
    _manualSession = false;
    unawaited(_speech.cancel());
  }
}
