import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/app_controller.dart';
import '../../core/theme.dart';
import '../../models/leadership.dart';
import '../../repositories/leadership_repository.dart';
import '../../services/leadership_service.dart';
import '../../widgets/common.dart';
import '../alerts/alerts_page.dart';
import '../voice/voice_page.dart';

const priorityLabels = ['منخفضة', 'متوسطة', 'عالية', 'حرجة'];
const taskLabels = ['قيد الانتظار', 'قيد التنفيذ', 'مكتملة'];

class LeadershipPage extends ConsumerStatefulWidget {
  const LeadershipPage({super.key});
  @override
  ConsumerState<LeadershipPage> createState() => _LeadershipPageState();
}

class _LeadershipPageState extends ConsumerState<LeadershipPage> {
  late final LeadershipService service;
  @override
  void initState() {
    super.initState();
    service = LeadershipService(ref.read(appProvider));
    service.load();
  }

  @override
  void dispose() {
    service.dispose();
    super.dispose();
  }

  Future<void> create() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateTaskPage()),
    );
    if (mounted) await service.load();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: service,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: const Text('لوحة القيادة'),
        actions: [
          IconButton(
            tooltip: 'اتصال المساعد',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AssistantConnectionPage(),
              ),
            ),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: service.loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: service.load,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Text(
                    'صورة أوضح.\nقرار أكثر وعيًا.',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'عمليات السلامة · من سجلات هذا الجهاز',
                    style: TextStyle(color: muted),
                  ),
                  const SizedBox(height: 14),
                  Surface(
                    padding: const EdgeInsets.all(15),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: Color(0xFFE0F2EB),
                          child: Icon(Icons.storage_rounded, color: green),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'بيانات فعلية من SQLite المحلية',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${service.facts['events_total'] ?? 0} حدث محفوظ · ${service.facts['events_today'] ?? 0} اليوم · ${service.facts['voice_commands'] ?? 0} أمر صوتي',
                                style: const TextStyle(
                                  color: muted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'إعادة قراءة البيانات',
                          onPressed: service.load,
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  LayoutBuilder(
                    builder: (context, c) => Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final item in const [
                          (
                            'open_hazards',
                            'مخاطر مفتوحة',
                            Icons.warning_amber_rounded,
                          ),
                          (
                            'critical_hazards',
                            'مخاطر حرجة',
                            Icons.priority_high_rounded,
                          ),
                          ('tasks', 'المهام', Icons.assignment_outlined),
                          ('completed_tasks', 'مهام مكتملة', Icons.task_alt),
                          ('voice_reports', 'بلاغات صوتية', Icons.mic_none),
                          (
                            'analyzed_frames',
                            'لقطات محللة',
                            Icons.image_search,
                          ),
                        ])
                          SizedBox(
                            width: (c.maxWidth - 12) / 2,
                            child: Surface(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    item.$3,
                                    color: item.$1 == 'critical_hazards'
                                        ? red
                                        : green,
                                    size: 22,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${service.facts[item.$1] ?? 0}',
                                    style: const TextStyle(
                                      fontSize: 30,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    item.$2,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Surface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.auto_awesome_outlined,
                              color: green,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'موجز السلامة',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: service.refreshing
                                  ? null
                                  : service.refreshBrief,
                              child: Text(
                                service.refreshing ? 'جارٍ التلخيص…' : 'تحديث',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          service.brief?['summary'] as String? ??
                              'حدّث الموجز للحصول على قراءة مختصرة للسجلات والمهام المحلية.',
                        ),
                        const SizedBox(height: 12),
                        Text(
                          service.brief == null
                              ? 'ملخص بالذكاء الاصطناعي · الأرقام من قاعدة البيانات'
                              : 'آخر تحديث: ${DateFormat('d/M HH:mm').format(DateTime.parse(service.brief!['created_at'] as String))} · ملخص آلي',
                          style: const TextStyle(color: muted, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  if (service.error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        service.error!,
                        style: const TextStyle(color: red),
                      ),
                    ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'المهام والمسارات الموجّهة',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'مهمة جديدة',
                        onPressed: create,
                        icon: const Icon(
                          Icons.add_circle_outline,
                          color: green,
                        ),
                      ),
                    ],
                  ),
                  if (service.tasks.isEmpty)
                    const Surface(
                      child: Text(
                        'لا توجد مهام بعد. أضف مهمة وحدد خطوات تنفيذها.',
                      ),
                    ),
                  for (final task in service.tasks)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Surface(
                        padding: EdgeInsets.zero,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          leading: Icon(
                            task.status == TaskStatus.completed
                                ? Icons.task_alt
                                : Icons.route_outlined,
                            color: green,
                          ),
                          title: Text(task.title),
                          subtitle: Text(
                            '${taskLabels[task.status.index]} · أولوية ${priorityLabels[task.priority.index]}',
                          ),
                          trailing: const Icon(Icons.chevron_left),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MissionPage(task: task),
                              ),
                            );
                            if (mounted) await service.load();
                          },
                        ),
                      ),
                    ),
                  const SectionTitle('آخر نشاط للسلامة'),
                  if (service.app.events.isEmpty)
                    const Surface(
                      child: Text('ستظهر هنا أحداث الفحص والمناطق والبلاغات.'),
                    ),
                  for (final event in service.app.events.take(12))
                    EventTile(event),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    ),
  );
}

class CreateTaskPage extends ConsumerStatefulWidget {
  const CreateTaskPage({super.key});
  @override
  ConsumerState<CreateTaskPage> createState() => _CreateTaskPageState();
}

class _CreateTaskPageState extends ConsumerState<CreateTaskPage> {
  final form = GlobalKey<FormState>(),
      title = TextEditingController(),
      description = TextEditingController();
  TaskPriority priority = TaskPriority.medium;
  String? zone;
  DateTime? due;
  bool mission = true, busy = false;
  String error = '';
  @override
  void dispose() {
    title.dispose();
    description.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      final now = DateTime.now();
      await LeadershipRepository(
        ref.read(appProvider).repository.db,
      ).createTask(
        LeadershipTask(
          id: 'task-${now.microsecondsSinceEpoch}',
          title: title.text.trim(),
          description: description.text.trim(),
          priority: priority,
          status: TaskStatus.pending,
          createdAt: now,
          zoneId: zone,
          dueDate: due,
        ),
        mission: mission,
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          error = 'تعذر حفظ المهمة. حاول مجددًا.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final zones = ref.read(appProvider).zones;
    return Scaffold(
      appBar: AppBar(title: const Text('مهمة جديدة')),
      body: Form(
        key: form,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            TextFormField(
              controller: title,
              maxLength: 100,
              decoration: const InputDecoration(labelText: 'عنوان المهمة'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'أدخل عنوانًا' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: description,
              maxLength: 1000,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'وصف التنفيذ'),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<TaskPriority>(
              initialValue: priority,
              decoration: const InputDecoration(labelText: 'الأولوية'),
              items: TaskPriority.values
                  .map(
                    (p) => DropdownMenuItem(
                      value: p,
                      child: Text(priorityLabels[p.index]),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => priority = v!),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: zone,
              decoration: const InputDecoration(
                labelText: 'منطقة العمل (اختياري)',
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('دون منطقة')),
                ...zones.map(
                  (z) => DropdownMenuItem(value: z.id, child: Text(z.name)),
                ),
              ],
              onChanged: (v) => setState(() => zone = v),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: Text(
                due == null
                    ? 'تحديد موعد الاستحقاق'
                    : DateFormat('yyyy/MM/dd').format(due!),
              ),
              trailing: due == null
                  ? null
                  : IconButton(
                      onPressed: () => setState(() => due = null),
                      icon: const Icon(Icons.close),
                    ),
              onTap: () async {
                final now = DateTime.now();
                final d = await showDatePicker(
                  context: context,
                  initialDate: due ?? now,
                  firstDate: DateTime(now.year, now.month, now.day),
                  lastDate: DateTime(now.year + 3),
                );
                if (d != null && mounted) setState(() => due = d);
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('مسار سلامة موجّه'),
              subtitle: const Text('خمس خطوات يتابعها العامل ويؤكد إنجازها'),
              value: mission,
              onChanged: (v) => setState(() => mission = v),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: busy ? null : save,
              child: Text(busy ? 'جارٍ الحفظ…' : 'إنشاء المهمة'),
            ),
            if (error.isNotEmpty)
              Text(error, style: const TextStyle(color: red)),
          ],
        ),
      ),
    );
  }
}

class MissionPage extends ConsumerStatefulWidget {
  final LeadershipTask task;
  const MissionPage({super.key, required this.task});
  @override
  ConsumerState<MissionPage> createState() => _MissionPageState();
}

class _MissionPageState extends ConsumerState<MissionPage> {
  late final repo = LeadershipRepository(ref.read(appProvider).repository.db);
  List<MissionStep>? steps;
  late LeadershipTask task = widget.task;
  bool busy = false;
  String error = '';
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final s = await repo.steps(task.id);
      final t = (await repo.tasks()).firstWhere((t) => t.id == task.id);
      if (mounted) {
        setState(() {
          steps = s;
          task = t;
        });
      }
    } catch (_) {
      if (mounted) setState(() => error = 'تعذر قراءة المهمة');
    }
  }

  Future<void> act(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = '';
    });
    try {
      await action();
      await ref.read(appProvider).reloadEvents();
      await load();
    } catch (_) {
      if (mounted) setState(() => error = 'تعذر حفظ التقدم. حاول مجددًا.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = steps;
    final done = s?.where((s) => s.completed).length ?? 0;
    return Scaffold(
      appBar: AppBar(title: const Text('مسار المهمة')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          StatusChip(taskLabels[task.status.index]),
          const SizedBox(height: 18),
          Text(
            task.title,
            style: const TextStyle(fontSize: 27, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(task.description),
          const SizedBox(height: 10),
          Text(
            'الأولوية: ${priorityLabels[task.priority.index]}',
            style: const TextStyle(color: muted),
          ),
          if (task.dueDate != null)
            Text(
              'الاستحقاق: ${DateFormat('d/M/yyyy').format(task.dueDate!)}',
              style: const TextStyle(color: muted),
            ),
          const SizedBox(height: 24),
          if (s == null && error.isEmpty)
            const Center(child: CircularProgressIndicator()),
          if (s != null && s.isNotEmpty) ...[
            Surface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$done / ${s.length} خطوات مكتملة',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: done / s.length,
                    minHeight: 7,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'تأكيد يدوي من العامل. لا يُعد إثباتًا آليًا لاجتياز الفحص أو أمان الدخول.',
                    style: TextStyle(fontSize: 11, color: muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            for (final step in s)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Surface(
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: step.completed ? green : canvas,
                        child: step.completed
                            ? const Icon(Icons.check, color: Colors.white)
                            : Text('${step.ordinal + 1}'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(step.title)),
                      if (!step.completed && step.ordinal == done)
                        TextButton(
                          onPressed: busy
                              ? null
                              : () => act(
                                  () => repo.completeStep(task.id, step.id),
                                ),
                          child: const Text('أنجزت'),
                        ),
                    ],
                  ),
                ),
              ),
          ],
          if (s != null && s.isEmpty && task.status != TaskStatus.completed)
            FilledButton(
              onPressed: busy
                  ? null
                  : () => act(
                      () => task.status == TaskStatus.pending
                          ? repo.startTask(task.id)
                          : repo.completeTask(task.id),
                    ),
              child: Text(
                task.status == TaskStatus.pending
                    ? 'بدء المهمة'
                    : 'إنهاء المهمة',
              ),
            ),
          if (task.status == TaskStatus.completed)
            const Surface(
              child: Row(
                children: [
                  Icon(Icons.verified_outlined, color: green),
                  SizedBox(width: 12),
                  Expanded(child: Text('اكتملت المهمة وتم تسجيل الحدث')),
                ],
              ),
            ),
          if (error.isNotEmpty) Text(error, style: const TextStyle(color: red)),
        ],
      ),
    );
  }
}
