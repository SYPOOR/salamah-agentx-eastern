import 'package:flutter/foundation.dart';
import '../core/app_controller.dart';
import '../models/leadership.dart';
import '../repositories/leadership_repository.dart';
import 'openai_service.dart';

class LeadershipService extends ChangeNotifier {
  final AppController app;
  late final repository = LeadershipRepository(app.repository.db);
  final api = OpenAIService();
  Map<String, dynamic> facts = {};
  Map<String, Object?>? brief;
  List<LeadershipTask> tasks = [];
  bool loading = true, refreshing = false, _disposed = false;
  String? error;
  LeadershipService(this.app);
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    try {
      facts = await repository.facts();
      tasks = await repository.tasks();
      brief = await repository.latestBrief();
      await app.reloadEvents();
      error = null;
    } catch (_) {
      error = 'تعذر قراءة البيانات المحلية';
    }
    loading = false;
    _notify();
  }

  Future<void> refreshBrief() async {
    if (refreshing) return;
    refreshing = true;
    error = null;
    _notify();
    try {
      final snapshot = await repository.facts();
      final summary = await api.brief(snapshot);
      if (_disposed) return;
      await repository.saveBrief(summary, snapshot);
      await load();
    } catch (e) {
      error = e is AssistantException
          ? e.message
          : 'تعذر تحديث الملخص. آخر ملخص محفوظ ما زال متاحًا.';
    } finally {
      refreshing = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    api.dispose();
    super.dispose();
  }
}
