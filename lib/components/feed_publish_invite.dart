import 'package:flutter/material.dart';

/// Convite editorial do feed. Não depende do catálogo nem anuncia ofertas.
class FeedPublishInvite extends StatelessWidget {
  final VoidCallback onPublish;

  const FeedPublishInvite({super.key, required this.onPublish});

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF5D201C);
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ExcludeSemantics(
                  child: CircleAvatar(
                    backgroundColor: Color(0xFFFFE7E5),
                    foregroundColor: ink,
                    child: Icon(Icons.restaurant_outlined),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Comeu bem? Conta no feed.',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: ink,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Compartilhe uma foto do prato, conte como foi e mencione a loja.',
              style: TextStyle(color: ink, height: 1.5),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onPublish,
              icon: const Icon(Icons.edit_square, size: 20),
              label: const Text('Criar publicação'),
              style: OutlinedButton.styleFrom(
                foregroundColor: ink,
                minimumSize: const Size(48, 48),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                side: const BorderSide(color: ink),
                shape: const StadiumBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
