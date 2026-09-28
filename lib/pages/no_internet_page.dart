import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nhac/components/botoes/botao_largo_nhac.dart';
import 'package:nhac/services/connectivity_service.dart';
import 'package:provider/provider.dart';
import 'package:nhac/globals/ui_utils.dart';

class NoInternetPage extends StatelessWidget {
  const NoInternetPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Image.asset('assets/nhac-logo.png', height: 120.h),
              SizedBox(height: 48.h),
              Icon(Icons.wifi_off_rounded,
                  size: 80.sp, color: const Color(0xFFFE645C)),
              SizedBox(height: 24.h),
              Text('Ops! Sem conexão',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 28.sp,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF5D201C))),
              SizedBox(height: 12.h),
              Text(
                  'Parece que você está sem internet. Verifique sua conexão para continuar pedindo no Nhac.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 16.sp, color: const Color(0xFF666666))),
              const Spacer(),
              BotaoLargoNhac(
                texto: 'Tentar Novamente',
                onPressed: () async {
                  final service =
                      Provider.of<ConnectivityService>(context, listen: false);
                  await service.checkConnection();
                  if (!context.mounted) return;
                  if (service.isOnline) {
                    context.showSuccess('Conexão restabelecida!');
                  } else {
                    context.showError('Ainda sem conexão. Tente novamente.');
                  }
                },
              ),
              SizedBox(height: 32.h),
            ],
          ),
        ),
      ),
    );
  }
}
