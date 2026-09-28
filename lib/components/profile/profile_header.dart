import 'dart:io';
import 'dart:ui';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import '../../models/usuario/usuario_model.dart';
import '../../controllers/user_provider.dart';
import 'package:nhac/globals/ui_utils.dart';

class ProfileHeader extends StatefulWidget {
  final UsuarioModel usuario;
  final String textoEndereco;

  const ProfileHeader({
    super.key,
    required this.usuario,
    required this.textoEndereco,
  });

  @override
  State<ProfileHeader> createState() => _ProfileHeaderState();
}

class _ProfileHeaderState extends State<ProfileHeader> {
  bool _isUploading = false;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Stack(
          children: [
            GestureDetector(
              onLongPress: () => _mostrarPreviewFoto(context, widget.usuario.imagemUrl),
              onLongPressUp: () => Navigator.of(context).pop(),
              child: Container(
                width: 80.w,
                height: 80.h,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  image: (widget.usuario.imagemUrl?.isNotEmpty ?? false)
                      ? DecorationImage(image: CachedNetworkImageProvider(widget.usuario.imagemUrl!), fit: BoxFit.cover)
                      : null,
                  boxShadow: [BoxShadow(color: const Color(0xFF5D201C).withValues(alpha: 0.1), blurRadius: 10.r, offset: Offset(0, 4.h))],
                ),
                child: _isUploading
                    ? Center(child: Lottie.asset('assets/animations/loading_nhac.json', width: 40.w, height: 40.h))
                    : (widget.usuario.imagemUrl?.isNotEmpty ?? false)
                        ? null
                        : Icon(Icons.person, size: 48.r, color: Colors.grey.shade400),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: GestureDetector(
                onTap: _isUploading
                    ? null
                    : () async {
                        final picker = ImagePicker();
                        final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
                        if (pickedFile != null && mounted) {
                          setState(() => _isUploading = true);
                          try {
                            if (context.mounted) await context.read<UserProvider>().atualizarFotoPerfil(File(pickedFile.path));
                          } catch (e) {
                            if (context.mounted) context.showError('Erro ao carregar imagem: $e');
                          } finally {
                            if (mounted) setState(() => _isUploading = false);
                          }
                        }
                      },
                child: Container(
                  padding: EdgeInsets.all(4.w),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: Container(
                    padding: EdgeInsets.all(4.w),
                    decoration: const BoxDecoration(color: Color(0xFF5D201C), shape: BoxShape.circle),
                    child: _isUploading
                        ? SizedBox(width: 12.w, height: 12.h, child: Lottie.asset('assets/animations/loading_nhac.json'))
                        : const Icon(Icons.edit, size: 12, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(width: 16.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.usuario.nome, style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.bold, color: const Color(0xFF5D201C))),
              SizedBox(height: 4.h),
              Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 14.r, color: Colors.grey.shade600),
                  SizedBox(width: 4.w),
                  Expanded(
                    child: Text(widget.textoEndereco, style: TextStyle(color: Colors.grey.shade700, fontSize: 12.sp), overflow: TextOverflow.ellipsis, maxLines: 1),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _mostrarPreviewFoto(BuildContext context, String? fotoUrl) {
    showGeneralPage(
      context,
      BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
        child: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            color: const Color(0xFF5D201C).withValues(alpha: 0.4),
            child: Center(
              child: Container(
                width: 260.w,
                height: 260.h,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: Colors.white, width: 4.w),
                  image: (fotoUrl != null && fotoUrl.isNotEmpty) ? DecorationImage(image: CachedNetworkImageProvider(fotoUrl), fit: BoxFit.cover) : null,
                  boxShadow: [BoxShadow(color: const Color(0xFF5D201C).withValues(alpha: 0.3), blurRadius: 30.r, offset: Offset(0, 10.h))],
                ),
                child: (fotoUrl == null || fotoUrl.isEmpty) ? Icon(Icons.person, size: 160.r, color: Colors.grey.shade300) : null,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void showGeneralPage(BuildContext context, Widget child) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 110),
        reverseTransitionDuration: const Duration(milliseconds: 110),
        pageBuilder: (context, _, __) => child,
        transitionsBuilder: (context, animation, __, child) => FadeTransition(opacity: animation, child: child),
      ),
    );
  }
}
