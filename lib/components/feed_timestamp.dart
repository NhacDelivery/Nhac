import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class FeedTimestamp extends StatelessWidget {
  final DateTime? date;
  const FeedTimestamp(this.date, {super.key});

  @override
  Widget build(BuildContext context) {
    if (date == null) return const SizedBox.shrink();
    final label = formatarDataFeed(date!);
    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 11, color: Color(0xFF666666)),
    );
  }
}

String formatarDataFeed(DateTime data, {DateTime? agora}) {
  final local = data.toLocal();
  final now = (agora ?? DateTime.now()).toLocal();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  final prefix = day == today
      ? 'Hoje'
      : day == DateTime(today.year, today.month, today.day - 1)
      ? 'Ontem'
      : DateFormat('dd/MM/yyyy').format(local);
  return '$prefix • ${DateFormat('HH:mm').format(local)}';
}
