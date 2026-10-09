import 'package:flutter/material.dart';

Future<bool> confirmarNhac(
  BuildContext context, {
  required String titulo,
  required String mensagem,
  String confirmar = 'Excluir',
  String cancelar = 'Cancelar',
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        icon: const Icon(
          Icons.help_outline_rounded,
          color: Color(0xFFFF6961),
          size: 32,
        ),
        title: Text(
          titulo,
          style: const TextStyle(
            color: Color(0xFF5D201C),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(mensagem),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(cancelar),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF6961),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmar),
          ),
        ],
      ),
    ) ==
    true;
