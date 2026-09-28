import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:nhac/components/loading_nhac.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:nhac/controllers/user_provider.dart';
import 'package:nhac/services/auth_service.dart';
import 'package:nhac/repositories/user_repository.dart';
import 'package:provider/provider.dart';
import 'package:nhac/globals/ui_utils.dart';

import 'package:nhac/components/botoes/botao_largo_nhac.dart';

class EditarFotoPage extends StatefulWidget {
  const EditarFotoPage({super.key});

  @override
  State<EditarFotoPage> createState() => _EditarFotoPageState();
}

class _EditarFotoPageState extends State<EditarFotoPage> {
  File? _image;
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1000,
        maxHeight: 1000,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _image = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (!mounted) return;
      context.showError('Erro ao selecionar imagem: $e');
    }
  }

  void _showPickerOptions() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Galeria'),
                onTap: () {
                  _pickImage(ImageSource.gallery);
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Câmera'),
                onTap: () {
                  _pickImage(ImageSource.camera);
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _savePhoto() async {
    if (_image == null) return;

    setState(() => _isLoading = true);
    try {
      final authService = context.read<AuthService>();
      final uid = authService.usuarioId;
      debugPrint("UID obtido para upload: $uid");

      if (uid == null) {
        throw Exception("Usuário não autenticado.");
      }

      final url = await UserRepository().enviarFotoPerfil(_image!);

      if (!mounted) return;
      final userProvider = context.read<UserProvider>();
      
      await UserRepository().atualizarDadosUsuario(uid, {
        'imagemUrl': url,
      });

      await userProvider.carregarDadosUsuario();

      if (!mounted) return;
      
      context.showSuccess('Foto de perfil atualizada com sucesso!');

      context.pop();
    } catch (e) {
      if (!mounted) return;
      
      context.showError('Erro ao atualizar foto: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final usuario = context.watch<UserProvider>().usuario;

    return Scaffold(
      backgroundColor: const Color(0xFFFFE7E5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFE7E5),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF5D201C), size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16.0),
                      const Text(
                        'Foto de Perfil',
                        style: TextStyle(
                          fontSize: 28.0,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF5D201C),
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12.0),
                      Text(
                        'Escolha uma foto bem bonita para que todos possam te reconhecer.',
                        style: TextStyle(
                          fontSize: 16.0,
                          color: Colors.grey.shade800,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 40.0),
                      Center(
                        child: GestureDetector(
                          onTap: _showPickerOptions,
                          child: Stack(
                            children: [
                              Container(
                                width: 160,
                                height: 160,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 4),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Color(0xFF5D201C).withValues(alpha: 0.1),
                                      blurRadius: 10,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: _image != null 
    ? Image.file(_image!, fit: BoxFit.cover)
    : (usuario?.imagemUrl != null && usuario!.imagemUrl!.isNotEmpty 
        ? CachedNetworkImage(
            imageUrl: usuario.imagemUrl!,
                                              fit: BoxFit.cover,
                                              placeholder: (ctx, url) => Container(
                                                color: Colors.grey.shade200,
                                                child: const LoadingNhac(telaCheia: false, tamanho: 40),
                                              ),
                                              errorWidget: (ctx, url, err) => Container(
                                                color: Colors.grey.shade300,
                                                child: Icon(Icons.person, size: 80, color: Colors.grey.shade600),
                                              ),
                                            )
                                          : Container(
                                              color: Colors.grey.shade300,
                                              child: Icon(Icons.person, size: 80, color: Colors.grey.shade600),
                                            )),
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFE645C),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.camera_alt, color: Colors.white, size: 24),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20.0),
                      const Center(
                        child: Text(
                          'Toque para mudar a foto',
                          style: TextStyle(
                            fontSize: 14.0,
                            color: Color(0xFF5D201C),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 32.0, top: 16.0),
              child: BotaoLargoNhac(
                texto: 'Salvar alterações',
                carregando: _isLoading,
                onPressed: (_image != null && !_isLoading) ? _savePhoto : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
