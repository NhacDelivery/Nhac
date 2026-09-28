import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:nhac/controllers/endereco_provider.dart';
import 'package:provider/provider.dart';

class HomeAddressBottomSheet extends StatelessWidget {
  const HomeAddressBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final enderecos = context.watch<EnderecoProvider>().enderecos;
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
      ),
      padding: EdgeInsets.only(top: 16.h, bottom: 32.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40.w,
            height: 4.h,
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2.r)),
          ),
          SizedBox(height: 24.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Selecione o endereço de entrega',
                style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF5D201C)),
              ),
            ),
          ),
          SizedBox(height: 16.h),
          ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5),
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              itemCount: enderecos.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final endereco = enderecos[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  onTap: () async {
                    await context
                        .read<EnderecoProvider>()
                        .definirComoPadrao(endereco.id);
                    if (context.mounted) Navigator.pop(context);
                  },
                  leading: Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6961).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      endereco.bairro.toLowerCase().contains('trabalho') ||
                             (endereco.complemento ?? '').toLowerCase().contains('trabalho')
                          ? Icons.work_outline
                          : Icons.home_outlined,
                      color: const Color(0xFFFF6961),
                      size: 20.r,
                    ),
                  ),
                  title: Text('${endereco.rua}, ${endereco.numero}',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15.sp)),
                  subtitle: Text(
                    '${endereco.bairro}${(endereco.complemento?.isNotEmpty ?? false) ? ' - ${endereco.complemento}' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13.sp),
                  ),
                  trailing: endereco.isPadrao
                      ? Icon(Icons.check_circle,
                          color: const Color(0xFFFF6961), size: 22.r)
                      : null,
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: const Divider(height: 32),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: InkWell(
              onTap: () {
                Navigator.pop(context);
                context.push('/enderecos-salvos');
              },
              borderRadius: BorderRadius.circular(12.r),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8.h),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8.w),
                      decoration: BoxDecoration(
                          color: Colors.grey.shade100, shape: BoxShape.circle),
                      child: Icon(Icons.add, color: Colors.grey, size: 20.r),
                    ),
                    SizedBox(width: 16.w),
                    Text('Adicionar novo endereço',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15.sp,
                            color: Colors.grey)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
