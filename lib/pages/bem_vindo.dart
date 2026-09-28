import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:flutter/services.dart';
import 'package:nhac/components/nhac_logo.dart';
import 'package:go_router/go_router.dart';
import 'package:nhac/components/botoes/botao_nhac.dart';
import 'package:nhac/e2e/e2e_keys.dart';

@NowaGenerated()
class BemVindo extends StatefulWidget {
  @NowaGenerated({'loader': 'auto-constructor'})
  const BemVindo({super.key});

  @override
  State<BemVindo> createState() => _BemVindoState();
}

@NowaGenerated()
class _BemVindoState extends State<BemVindo> {
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SizedBox(width: 132.w, height: 49.h, child: const NhacLogo()),
                    ElevatedButton(
                      onPressed: () => context.push('/bem-vindo-motoca'),
                      style: ButtonStyle(
                        backgroundColor: const WidgetStatePropertyAll<Color?>(Color(0xFFFFF5F5)),
                        elevation: const WidgetStatePropertyAll<double?>(0.0),
                        shape: WidgetStatePropertyAll<RoundedRectangleBorder>(
                          RoundedRectangleBorder(borderRadius: BorderRadius.circular(50.r)),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Para Entregadores', style: TextStyle(color: const Color(0xFF7C6F6F), fontSize: 12.sp, fontWeight: FontWeight.w600)),
                          SizedBox(width: 8.w),
                          Icon(Icons.arrow_forward_ios, size: 14.sp, color: const Color(0xFF7C6F6F)),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 406.h, child: Center(child: Image.asset('assets/lanche-bem-vindo.png', fit: BoxFit.contain))),
                SizedBox(
                  width: 301.w,
                  height: 34.h,
                  child: Text(
                    'O Nhac que sua fome pedia',
                    style: TextStyle(fontSize: 28.sp, color: const Color(0xFF5D201C), fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(height: 12.h),
                Text(
                  'Encontre os melhores restaurantes locais e peça sua comida favorita com rapidez e facilidade.',
                  style: TextStyle(fontSize: 16.sp, color: const Color(0x995D201C), fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 32.h),
                SizedBox(
                  width: double.infinity,
                  height: 49.h,
                  child: const BotaoNhac(key: E2EKeys.welcomeContinue),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
