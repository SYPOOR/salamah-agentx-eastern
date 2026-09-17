import '../core/arabic.dart';
import 'package:flutter/material.dart';
import '../core/theme.dart';

class Surface extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const Surface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: panel,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: line),
      boxShadow: const [
        BoxShadow(
          color: Color(0x06142C36),
          blurRadius: 18,
          offset: Offset(0, 6),
        ),
      ],
    ),
    child: child,
  );
}

class SectionTitle extends StatelessWidget {
  final String title;
  final String? trailing;
  const SectionTitle(this.title, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 26, bottom: 14),
    child: Row(
      children: [
        Expanded(
          child: ArabicText(
            title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        if (trailing != null)
          ArabicText(
            trailing!,
            style: const TextStyle(color: muted, fontSize: 11),
          ),
      ],
    ),
  );
}

class StatusChip extends StatelessWidget {
  final String text;
  final Color color;
  const StatusChip(this.text, {super.key, this.color = green});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: .25)),
    ),
    child: ArabicText(
      text,
      style: TextStyle(
        color: color,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: .6,
      ),
    ),
  );
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title, description;
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
    child: Column(
      children: [
        Icon(icon, color: muted, size: 34),
        const SizedBox(height: 12),
        ArabicText(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        ArabicText(
          description,
          textAlign: TextAlign.center,
          style: const TextStyle(color: muted, fontSize: 12),
        ),
      ],
    ),
  );
}

void showError(BuildContext context, Object e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: ArabicText(e.toString().replaceFirst('Bad state: ', ''))),
  );
}
