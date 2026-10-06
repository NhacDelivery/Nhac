import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class FeedTimestamp extends StatelessWidget {
  final DateTime? date;
  const FeedTimestamp(this.date, {super.key});

  @override
  Widget build(BuildContext context) {
    if (date == null) return const SizedBox.shrink();
    final label = DateFormat('dd/MM/yyyy • HH:mm').format(date!.toLocal());
    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 11, color: Color(0xFF666666)),
    );
  }
}
