import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:go_router/go_router.dart';

@NowaGenerated({'auto-width': 351, 'auto-height': 49})
class BotaoNhac extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final double fontSize;

  @NowaGenerated({'loader': 'auto-constructor'})
  const BotaoNhac({
    super.key,
    this.label = 'Começar',
    this.onPressed,
    this.fontSize = 18.0,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed ?? () => context.push('/email-cliente'),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFFE645C),
        foregroundColor: const Color(0xFFFEE3E1),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 8.h),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: fontSize.sp, fontWeight: FontWeight.w600, letterSpacing: 0.1),
      ),
    );
  }
}
