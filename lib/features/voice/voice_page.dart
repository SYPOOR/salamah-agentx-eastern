import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_controller.dart';
import '../../core/theme.dart';
import '../../services/voice_assistant_service.dart';
import '../../services/voice_camera_service.dart';
import '../../services/openai_service.dart';
import '../../repositories/leadership_repository.dart';
import '../../widgets/common.dart';

class VoicePage extends ConsumerStatefulWidget {
  const VoicePage({super.key});
  @override
  ConsumerState<VoicePage> createState() => _VoicePageState();
}

class _VoicePageState extends ConsumerState<VoicePage>
    with WidgetsBindingObserver {
  late final VoiceCameraService camera;
  late final VoiceAssistantService voice;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    camera = VoiceCameraService();
    voice = VoiceAssistantService(
      ref.read(appProvider),
      captureFrame: camera.captureFrame,
    );
    unawaited(camera.start());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Permission sheets make iOS inactive; only leaving the foreground cancels.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      voice.cancel();
      camera.stop();
    } else if (state == AppLifecycleState.resumed) {
      camera.start();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    voice.dispose();
    camera.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([voice, camera]),
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: const Text('الأوامر الصوتية'),
        actions: [
          IconButton(
            tooltip: 'السجل',
            onPressed: voice.busy
                ? null
                : () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const VoiceHistoryPage()),
                  ),
            icon: const Icon(Icons.history),
          ),
          IconButton(
            tooltip: 'اتصال المساعد',
            onPressed: voice.busy
                ? null
                : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AssistantConnectionPage(),
                    ),
                  ),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
        children: [
          _cameraPanel(),
          if (voice.busy)
            TextButton(onPressed: voice.cancel, child: const Text('إلغاء')),
          const SizedBox(height: 14),
          if (voice.transcript.isNotEmpty)
            Surface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.graphic_eq_rounded,
                        color: green,
                        size: 18,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        voice.phase == VoicePhase.recording
                            ? 'كلامك مباشرًا'
                            : 'الأمر الذي سمعته',
                        style: const TextStyle(color: muted, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    voice.transcript,
                    style: const TextStyle(fontSize: 17, height: 1.6),
                  ),
                ],
              ),
            ),
          if (voice.reply.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Surface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: Color(0xFFE0F2EB),
                          child: Icon(
                            Icons.health_and_safety_outlined,
                            color: green,
                            size: 18,
                          ),
                        ),
                        SizedBox(width: 9),
                        Text(
                          'رد سلامة',
                          style: TextStyle(
                            color: green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Spacer(),
                        Text(
                          'نص + صوت',
                          style: TextStyle(color: muted, fontSize: 10),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      voice.reply,
                      style: const TextStyle(fontSize: 16, height: 1.7),
                    ),
                    TextButton.icon(
                      onPressed: voice.tts.stop,
                      icon: const Icon(Icons.volume_off_outlined),
                      label: const Text('إيقاف الصوت'),
                    ),
                  ],
                ),
              ),
            ),
          if (voice.error.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text(voice.error, style: const TextStyle(color: red)),
            ),
          const SizedBox(height: 24),
          const Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'جرّب أن تقول',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                Text(
                  '«ماذا أمامي؟»   ·   «وش تشوف قدامي؟»\n«صف المشهد»   ·   «هل يوجد خطر أمامي؟»\n«يوجد خطر هنا، سجله»   ·   «ما مهمتي الحالية؟»',
                  style: TextStyle(height: 1.9),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'يتحول كلامك مباشرة إلى نص عبر أدوات iOS ولا يُنشأ ملف تسجيل. اضغط زر الإيقاف لإرسال النص. تُرسل لقطة واحدة فقط عند طلبك الصريح.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: muted, height: 1.8),
          ),
        ],
      ),
    ),
  );

  Widget _cameraPanel() {
    final controller = camera.controller;
    final processing =
        voice.phase != VoicePhase.idle && voice.phase != VoicePhase.recording;
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: ColoredBox(
          color: ink,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (camera.ready &&
                  controller != null &&
                  controller.value.isInitialized)
                _coverPreview(controller)
              else if (camera.error != null)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(30),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.no_photography_outlined,
                          color: Colors.white,
                          size: 44,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          camera.error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: camera.start,
                          child: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                const Center(child: CircularProgressIndicator()),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x88000000),
                      Color(0x00000000),
                      Color(0xCC061D25),
                    ],
                    stops: [0, .45, 1],
                  ),
                ),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xBB142C36),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: camera.ready ? liveGreen : orange,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        camera.ready ? 'كاميرا مباشرة' : 'فتح الكاميرا',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 18,
                right: 18,
                bottom: 150,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: Text(
                    _phaseText(),
                    key: ValueKey(voice.phase),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      shadows: [Shadow(color: Colors.black, blurRadius: 8)],
                    ),
                  ),
                ),
              ),
              if (voice.phase == VoicePhase.recording)
                Positioned(
                  left: 92,
                  right: 92,
                  bottom: 124,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      minHeight: 6,
                      value: voice.microphoneLevel,
                      color: liveGreen,
                      backgroundColor: Colors.white24,
                    ),
                  ),
                ),
              if (processing)
                const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 18,
                child: Center(
                  child: Semantics(
                    label: voice.phase == VoicePhase.recording
                        ? 'إيقاف التسجيل'
                        : 'بدء تسجيل أمر',
                    button: true,
                    child: SizedBox(
                      width: 86,
                      height: 86,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          shape: const CircleBorder(
                            side: BorderSide(color: Colors.white, width: 4),
                          ),
                          backgroundColor: voice.phase == VoicePhase.recording
                              ? red
                              : green,
                          disabledBackgroundColor: const Color(0xFF547069),
                        ),
                        onPressed: voice.phase == VoicePhase.recording
                            ? voice.stop
                            : voice.busy || !camera.ready
                            ? null
                            : voice.start,
                        child: Icon(
                          voice.phase == VoicePhase.recording
                              ? Icons.stop_rounded
                              : Icons.mic_rounded,
                          size: 38,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _coverPreview(CameraController controller) {
    final size = controller.value.previewSize;
    if (size == null) return CameraPreview(controller);
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: size.height,
        height: size.width,
        child: CameraPreview(controller),
      ),
    );
  }

  String _phaseText() => switch (voice.phase) {
    VoicePhase.idle => 'اضغط الميكروفون وقل: ماذا أمامي؟',
    VoicePhase.recording => 'أستمع الآن… اضغط زر الإيقاف لإرسال الأمر',
    VoicePhase.transcribing => 'أثبت آخر كلماتك…',
    VoicePhase.understanding => 'أفهم أمر السلامة…',
    VoicePhase.capturing => 'ألتقط Frame واحدًا وأحلله…',
    VoicePhase.saving => 'أحفظ النتيجة في الجهاز…',
    VoicePhase.speaking => 'أجهز الرد المكتوب والصوتي…',
  };
}

class AssistantConnectionPage extends StatefulWidget {
  const AssistantConnectionPage({super.key});
  @override
  State<AssistantConnectionPage> createState() =>
      _AssistantConnectionPageState();
}

class _AssistantConnectionPageState extends State<AssistantConnectionPage> {
  final url = TextEditingController(), token = TextEditingController();
  bool busy = false;
  String message = '';
  @override
  void initState() {
    super.initState();
    OpenAIService.storage.read(key: 'assistant_url').then((v) {
      if (mounted) {
        url.text = v ?? const String.fromEnvironment('ASSISTANT_URL');
      }
    });
  }

  @override
  void dispose() {
    url.dispose();
    token.dispose();
    super.dispose();
  }

  Future<void> save() async {
    setState(() {
      busy = true;
      message = '';
    });
    final api = OpenAIService();
    try {
      await OpenAIService.configure(url.text, token.text);
      // A real request checks gateway authentication and model access.
      await api.intent('ما مجال مساعدتك؟');
      if (mounted) {
        setState(() => message = 'تم حفظ الاتصال والتحقق من المساعد');
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => message = e is AssistantException
              ? e.message
              : 'تعذر التحقق من اتصال الخادم',
        );
      }
    } finally {
      api.dispose();
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('اتصال المساعد')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'اتصال آمن بخادم سلامة',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        const Text(
          'يُحفظ رمز اتصال هذا الجهاز في Keychain. مفتاح OpenAI يبقى في الخادم فقط.',
        ),
        const SizedBox(height: 24),
        TextField(
          controller: url,
          keyboardType: TextInputType.url,
          textDirection: TextDirection.ltr,
          decoration: const InputDecoration(labelText: 'رابط الخادم HTTPS'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: token,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          decoration: const InputDecoration(labelText: 'رمز اتصال الجهاز'),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: busy ? null : save,
          child: Text(busy ? 'جارٍ التحقق…' : 'حفظ والتحقق'),
        ),
        const SizedBox(height: 16),
        Text(message),
      ],
    ),
  );
}

class VoiceHistoryPage extends ConsumerWidget {
  const VoiceHistoryPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('سجل الأوامر')),
    body: FutureBuilder(
      future: LeadershipRepository(
        ref.read(appProvider).repository.db,
      ).voices(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('تعذر قراءة السجل'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final rows = snapshot.data!;
        if (rows.isEmpty) {
          return const Center(child: Text('ستظهر الأوامر المنفذة هنا'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: rows.length,
          separatorBuilder: (_, i) => const SizedBox(height: 12),
          itemBuilder: (_, i) => Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rows[i]['transcript'] as String,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(rows[i]['assistant_response'] as String),
                const SizedBox(height: 8),
                Text(
                  (rows[i]['created_at'] as String)
                      .replaceFirst('T', ' ')
                      .substring(0, 16),
                  style: const TextStyle(color: muted, fontSize: 11),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
