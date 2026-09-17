import '../../core/arabic.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/app_controller.dart';
import '../../core/theme.dart';
import '../../models/safety.dart';
import '../../widgets/common.dart';

class AlertsPage extends ConsumerStatefulWidget {
  const AlertsPage({super.key});
  @override
  ConsumerState<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends ConsumerState<AlertsPage> {
  String filter = 'All';
  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appProvider);
    final events = app.events
        .where(
          (e) => switch (filter) {
            'PPE' => e.type.startsWith('ppe'),
            'Zones' => e.type.startsWith('zone'),
            'Critical' => e.severity == Severity.critical,
            _ => true,
          },
        )
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const ArabicText('Safety events'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Center(
              child: StatusChip('${app.events.length} حدث', color: muted),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              runSpacing: 6,
              children: ['All', 'PPE', 'Zones', 'Critical']
                  .map(
                    (f) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: ArabicText(f),
                        selected: filter == f,
                        onSelected: (_) => setState(() => filter = f),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          Expanded(
            child: events.isEmpty
                ? const EmptyState(
                    icon: Icons.notifications_none_rounded,
                    title: 'A clear event log',
                    description:
                        'Recorded PPE checks and zone events will appear here.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                    itemCount: events.length,
                    separatorBuilder: (_, i) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => EventTile(events[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class EventTile extends StatelessWidget {
  final SafetyEvent event;
  const EventTile(this.event, {super.key});
  @override
  Widget build(BuildContext context) {
    final color = severityColor(event.severity);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => EventDetails(event)),
      ),
      child: Surface(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: color.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                event.type.startsWith('zone')
                    ? Icons.radar_rounded
                    : Icons.health_and_safety_outlined,
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ArabicText(
                    event.title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ArabicText(
                    '${DateFormat.MMMd().format(event.timestamp)} · ${DateFormat.jm().format(event.timestamp)}',
                    style: const TextStyle(color: muted, fontSize: 11),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: muted, size: 18),
          ],
        ),
      ),
    );
  }
}

class EventDetails extends ConsumerWidget {
  final SafetyEvent event;
  const EventDetails(this.event, {super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appProvider);
    final zone = app.zones.where((z) => z.id == event.zoneId).firstOrNull;
    return Scaffold(
      appBar: AppBar(title: const ArabicText('Event details')),
      body: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          StatusChip(
            event.severity.name.toUpperCase(),
            color: severityColor(event.severity),
          ),
          const SizedBox(height: 20),
          ArabicText(
            event.title,
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 12),
          ArabicText(event.description, style: const TextStyle(color: muted)),
          const SizedBox(height: 24),
          Surface(
            child: Column(
              children: [
                _row('Event type', event.type.replaceAll('_', ' ')),
                if (event.source != null)
                  _row(
                    'المصدر',
                    event.source == 'voice' ? 'أمر صوتي' : 'لوحة القيادة',
                  ),
                if (event.status != null)
                  _row(
                    'الحالة',
                    event.status == 'open' ? 'مفتوح' : event.status!,
                  ),
                _row(
                  'Recorded',
                  DateFormat('MMM d, yyyy · HH:mm:ss').format(event.timestamp),
                ),
                _row(
                  'Zone',
                  zone?.name ??
                      (event.zoneId != null
                          ? 'Deleted zone'
                          : 'Not associated'),
                ),
                _row(
                  'Location',
                  event.latitude == null
                      ? 'Not available'
                      : '${event.latitude!.toStringAsFixed(6)}, ${event.longitude!.toStringAsFixed(6)}',
                ),
                if (event.compliance != null)
                  _row(
                    'Compliance',
                    '${event.compliance!.toStringAsFixed(1)}%',
                  ),
              ],
            ),
          ),
          const SectionTitle('Safety snapshot'),
          if (event.snapshotPath != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.file(
                File(event.snapshotPath!),
                errorBuilder: (_, e, s) =>
                    const ArabicText('Snapshot no longer available'),
              ),
            )
          else
            const EmptyState(
              icon: Icons.no_photography_outlined,
              title: 'No snapshot saved',
              description:
                  'Snapshots are optional and stored only on this device.',
            ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: ArabicText(
            label,
            style: const TextStyle(color: muted, fontSize: 12),
          ),
        ),
        Expanded(
          child: ArabicText(value, style: const TextStyle(fontSize: 12)),
        ),
      ],
    ),
  );
}
