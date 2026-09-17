import 'package:flutter/foundation.dart';
import '../core/app_controller.dart';
import '../models/leadership.dart';
import '../models/safety.dart';
import '../repositories/leadership_repository.dart';
import 'device_speech_service.dart';
import 'openai_service.dart';
import 'text_to_speech_service.dart';

enum VoicePhase {
  idle,
  recording,
  transcribing,
  understanding,
  capturing,
  saving,
  speaking,
}

String _normalizedVoiceCommand(String text) => text
    .toLowerCase()
    .replaceAll(RegExp('[أإآٱ]'), 'ا')
    .replaceAll('ى', 'ي')
    .replaceAll('ة', 'ه')
    .replaceAll(RegExp(r'[ًٌٍَُِّْـ]'), '')
    .replaceAll(RegExp(r'[^\u0600-\u06ffa-z0-9 ]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

bool _cameraCommandDenied(String command) {
  if (RegExp(
    r'(^|\s)(لا|بدون|ليس|لات|dont|don t|do not|never|not)(\s|$)',
  ).hasMatch(command)) {
    return true;
  }
  return RegExp(
    r'(اشرح|فسر|ما معني|معنى|كيف اقول|اذا قلت|عباره).{0,18}(التقط|صور|فريم|كاميرا|مشهد)',
  ).hasMatch(command);
}

/// Accepts natural Arabic visual requests while still rejecting negation and
/// discussion *about* a command. Speech recognition commonly changes spelling
/// and drops punctuation, so matching intentionally uses semantic word groups.
bool explicitCameraCommand(String text) {
  final s = _normalizedVoiceCommand(text);
  if (s.isEmpty || _cameraCommandDenied(s)) return false;

  final patterns = <RegExp>[
    RegExp(
      r'(التقط|خذ|صور|صوّر).{0,18}(فريم|صوره|لقطه|المشهد|امامي|قدامي|حولي)',
    ),
    RegExp(
      r'(ماذا|ما ?ا?لذي|ماهو|ما هو|وش|ايش|اش|شنو).{0,18}(امامي|قدامي|حولي|حولنا|في محيطي|تشوف|تري|ترى)',
    ),
    RegExp(
      r'(صف|حلل|افحص|شوف|انظر|وريني|ارني|اكتشف).{0,22}(امامي|قدامي|حولي|المشهد|المحيط|الكاميرا|الطريق)',
    ),
    RegExp(
      r'(هل|فيه|يوجد).{0,20}(خطر|شخص|عامل|خوذه|ستره|معدات|شيء|شي).{0,18}(امامي|قدامي|حولي|بالمشهد|في المشهد)',
    ),
    RegExp(
      r'(capture|take|scan|analy[sz]e|describe|show).{0,24}(frame|photo|picture|scene|ahead|front|surroundings)',
    ),
    RegExp(r'what.{0,12}(ahead|in front|around me|do you see)'),
  ];
  return patterns.any((pattern) => pattern.hasMatch(s));
}

class VoiceAssistantService extends ChangeNotifier {
  final AppController app;
  final Future<Uint8List> Function(bool Function()) captureFrame;
  late final repository = LeadershipRepository(app.repository.db);
  OpenAIService api = OpenAIService();
  final speech = DeviceSpeechService();
  final tts = TextToSpeechService();
  VoicePhase phase = VoicePhase.idle;
  String transcript = '', reply = '', error = '';
  double microphoneLevel = 0;
  Uint8List? capturedImage;
  int _generation = 0;
  bool _disposed = false;
  VoiceAssistantService(this.app, {required this.captureFrame});
  bool get busy => phase != VoicePhase.idle;
  void _update() {
    if (!_disposed) notifyListeners();
  }

  void _phase(VoicePhase p) {
    phase = p;
    _update();
  }

  Future<void> start() async {
    if (busy) return;
    final generation = ++_generation;
    transcript = '';
    reply = '';
    error = '';
    capturedImage = null;
    microphoneLevel = 0;
    _phase(VoicePhase.recording);
    try {
      await tts.stop();
      if (!_active(generation)) return;
      await speech.start(
        onText: (text, isFinal) {
          if (!_active(generation) || phase != VoicePhase.recording) return;
          transcript = text;
          _update();
        },
        onLevel: (level) {
          if (!_active(generation) || phase != VoicePhase.recording) return;
          microphoneLevel = level;
          _update();
        },
        onFailure: (message) {
          if (!_active(generation) || phase != VoicePhase.recording) return;
          error = message;
          microphoneLevel = 0;
          _phase(VoicePhase.idle);
        },
      );
      if (!_active(generation)) await speech.cancel();
    } catch (e) {
      if (_active(generation)) {
        error = _message(e);
        _phase(VoicePhase.idle);
      }
    }
  }

  bool _active(int g) => !_disposed && g == _generation;
  Future<void> stop() async {
    if (phase != VoicePhase.recording) return;
    final g = _generation;
    microphoneLevel = 0;
    _phase(VoicePhase.transcribing);
    try {
      final recognized = await speech.stop();
      if (!_active(g)) return;
      transcript = recognized.trim();
      _update();
      if (transcript.isEmpty) {
        throw const AssistantException(
          'لم يظهر نص من كلامك. تأكد من صلاحية التعرف على الكلام ثم حاول مرة أخرى.',
        );
      }
      _phase(VoicePhase.understanding);
      await _execute(g);
    } catch (e) {
      if (_active(g)) {
        error = _message(e);
        _phase(VoicePhase.idle);
      }
    }
  }

  Future<void> _execute(int g) async {
    final decision = await api.intent(transcript);
    if (!_active(g)) return;
    final normalized = _normalizedVoiceCommand(transcript);
    final directCameraRequest = explicitCameraCommand(transcript);
    final modelCameraRequest =
        decision.intent.usesCamera && !_cameraCommandDenied(normalized);
    final shouldCapture = directCameraRequest || modelCameraRequest;
    final effectiveIntent = shouldCapture
        ? VoiceIntent.capture_frame
        : decision.intent;
    String response = decision.reply;
    String? analysis;
    SafetyEvent? event;
    final id = 'voice-${DateTime.now().microsecondsSinceEpoch}';
    if (shouldCapture) {
      _phase(VoicePhase.capturing);
      final jpeg = await captureFrame(() => _active(g));
      if (!_active(g)) return;
      capturedImage = jpeg;
      _update();
      analysis = await api.analyze(jpeg);
      if (!_active(g)) return;
      response = analysis;
    } else if (decision.intent == VoiceIntent.report_hazard) {
      final position = app.locationFresh ? app.position : null;
      final inside = app.currentReadings.where((r) => r.inside).toList();
      event = SafetyEvent(
        id: id,
        type: 'hazard_report',
        title: 'بلاغ خطر صوتي',
        description: transcript,
        severity: decision.severity == 'critical'
            ? Severity.critical
            : Severity.high,
        timestamp: DateTime.now(),
        latitude: position?.latitude,
        longitude: position?.longitude,
        zoneId: inside.isEmpty ? null : inside.first.zone.id,
        source: 'voice',
        transcript: transcript,
        status: 'open',
      );
      response = 'تم تسجيل الخطر في لوحة القيادة.';
    } else if (decision.intent == VoiceIntent.current_task) {
      final tasks = (await repository.tasks())
          .where((t) => t.status != TaskStatus.completed)
          .toList();
      response = tasks.isEmpty
          ? 'لا توجد مهام مفتوحة مسجلة.'
          : 'مهمتك المسجلة: ${tasks.first.title}.';
    } else if (decision.intent == VoiceIntent.current_status) {
      response = app.risk.severity == Severity.critical
          ? 'يوجد تنبيه حرج حسب قراءات السلامة الحالية. توقف وراجع مصدر الخطر في التطبيق.'
          : app.ppe == null
          ? 'لا يوجد فحص حديث لمعدات الوقاية. ابدأ فحص السلامة.'
          : 'مستوى الخطر الحالي: ${['آمن حسب القراءات المتاحة', 'معلومات', 'تحذير', 'مرتفع', 'حرج'][app.risk.severity.index]}. راجع شاشة الفحص للمزيد.';
    } else if (decision.intent == VoiceIntent.zone_question) {
      final inside = app.currentReadings.where((r) => r.inside).toList();
      response = !app.locationFresh
          ? 'الموقع غير متاح حاليًا. فعّل مراقبة المناطق.'
          : inside.isEmpty
          ? 'أنت خارج المناطق المسجلة حسب قراءة الموقع الحالية.'
          : 'المنطقة الحالية: ${inside.map((r) => r.zone.name).join('، ')}.';
    } else if (decision.intent == VoiceIntent.request_help) {
      response =
          'ابتعد عن مصدر الخطر واتبع إجراءات الموقع. تواصل مباشرة مع مسؤول السلامة؛ التطبيق لا يرسل طلب نجدة.';
    } else if (decision.intent == VoiceIntent.unknown) {
      response =
          'أنا مساعد للسلامة الميدانية. أستطيع تسجيل خطر أو تحليل لقطة أو عرض المهمة.';
    }
    if (!_active(g)) return;
    _phase(VoicePhase.saving);
    await repository.saveVoice(
      id: id,
      transcript: transcript,
      intent: effectiveIntent,
      reply: response,
      severity: event?.severity.name ?? decision.severity,
      event: event,
      analysis: analysis,
    );
    // Persistence has succeeded before any completion claim is displayed or spoken.
    await app.reloadEvents();
    if (!_active(g)) return;
    reply = response;
    _phase(VoicePhase.speaking);
    try {
      await tts.speak(api, response, () => _active(g));
    } catch (_) {
      if (_active(g)) error = 'الرد محفوظ. تعذر تشغيل الصوت؛ يمكنك قراءة الرد.';
    }
    if (_active(g)) _phase(VoicePhase.idle);
  }

  String _message(Object e) => e is AssistantException
      ? e.message
      : 'تعذر إكمال الأمر. تحقق من الاتصال والصلاحيات وحاول مجددًا.';
  Future<void> cancel() async {
    ++_generation;
    api.dispose();
    api = OpenAIService();
    await speech.cancel();
    await tts.stop();
    phase = VoicePhase.idle;
    _update();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    api.dispose();
    speech.dispose();
    tts.dispose();
    super.dispose();
  }
}
