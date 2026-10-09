import 'package:flutter/material.dart';

class FeedContent extends StatelessWidget {
  final String conteudo;
  final List<String> tags;
  const FeedContent({super.key, required this.conteudo, required this.tags});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        conteudo,
        style: const TextStyle(color: Color(0xFF5D201C), height: 1.5),
      ),
      if (tags.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: tags
                .toSet()
                .map(
                  (tag) => Text(
                    tag,
                    style: const TextStyle(
                      color: Color(0xFFFF6961),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
                .toList(),
          ),
        ),
    ],
  );
}
