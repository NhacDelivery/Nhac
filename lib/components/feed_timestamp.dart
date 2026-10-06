import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class FeedTimestamp extends StatelessWidget {
  final DateTime? date;
  const FeedTimestamp(this.date, {super.key});

  @override
  Widget build(BuildContext context) {
    if (date == null) return const SizedBox.shrink();
    final local = date!.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    final prefix = day == today
        ? 'Hoje'
        : day == DateTime(today.year, today.month, today.day - 1)
        ? 'Ontem'
        : DateFormat('dd/MM/yyyy').format(local);
    final label = '$prefix • ${DateFormat('HH:mm').format(local)}';
    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 11, color: Color(0xFF666666)),
    );
  }
}
