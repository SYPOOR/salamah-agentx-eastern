// Wire names intentionally match the strict server JSON schema.
// ignore_for_file: constant_identifier_names
enum VoiceIntent {
  capture_frame,
  report_hazard,
  analyze_scene,
  safety_question,
  current_task,
  current_status,
  request_help,
  zone_question,
  unknown;

  bool get usesCamera => this == capture_frame || this == analyze_scene;
}

class VoiceDecision {
  final VoiceIntent intent;
  final String reply, severity;
  const VoiceDecision(this.intent, this.reply, this.severity);
  factory VoiceDecision.fromJson(Map<String, dynamic> json) {
    final intent = VoiceIntent.values.byName(json['intent'] as String);
    final reply = json['reply'] as String;
    final severity = json['severity'] as String;
    if (reply.length > 1600 ||
        !['safe', 'info', 'warning', 'high', 'critical'].contains(severity) ||
        json['capture_frame'] != intent.usesCamera ||
        json['create_event'] != (intent == VoiceIntent.report_hazard)) {
      throw const FormatException('Invalid assistant decision');
    }
    return VoiceDecision(intent, reply, severity);
  }
}

enum TaskPriority { low, medium, high, critical }

enum TaskStatus { pending, inProgress, completed }

class LeadershipTask {
  final String id, title, description;
  final String? zoneId;
  final TaskPriority priority;
  final TaskStatus status;
  final DateTime createdAt;
  final DateTime? dueDate, completedAt;
  const LeadershipTask({
    required this.id,
    required this.title,
    required this.description,
    required this.priority,
    required this.status,
    required this.createdAt,
    this.zoneId,
    this.dueDate,
    this.completedAt,
  });
  Map<String, Object?> toRow() => {
    'id': id,
    'title': title,
    'description': description,
    'zone_id': zoneId,
    'priority': priority.name,
    'status': status.name,
    'created_at': createdAt.toIso8601String(),
    'due_date': dueDate?.toIso8601String(),
    'completed_at': completedAt?.toIso8601String(),
  };
  factory LeadershipTask.fromRow(Map<String, Object?> r) => LeadershipTask(
    id: r['id'] as String,
    title: r['title'] as String,
    description: r['description'] as String,
    zoneId: r['zone_id'] as String?,
    priority: TaskPriority.values.byName(r['priority'] as String),
    status: TaskStatus.values.byName(r['status'] as String),
    createdAt: DateTime.parse(r['created_at'] as String),
    dueDate: DateTime.tryParse(r['due_date'] as String? ?? ''),
    completedAt: DateTime.tryParse(r['completed_at'] as String? ?? ''),
  );
}

class MissionStep {
  final String id, title;
  final int ordinal;
  final bool completed;
  const MissionStep(this.id, this.title, this.ordinal, this.completed);
  factory MissionStep.fromRow(Map<String, Object?> r) => MissionStep(
    r['id'] as String,
    r['title'] as String,
    r['ordinal'] as int,
    r['completed'] == 1,
  );
}

/// Reserved extension point; scoring never controls safety decisions.
class MissionOutcome {
  final int? missionScore, trainingScore;
  final bool? safeCompletion;
  final List<String> badges;
  const MissionOutcome({
    this.missionScore,
    this.trainingScore,
    this.safeCompletion,
    this.badges = const [],
  });
}
