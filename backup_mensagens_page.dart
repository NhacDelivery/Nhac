import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:nhac/models/chat/conversa_resumo.dart';
import 'package:nhac/models/chat/conversa_pessoa_resumo.dart';
import 'package:nhac/repositories/chat_repository.dart';
import 'package:nhac/components/loading_nhac.dart';

class MensagensPage extends StatefulWidget {
  const MensagensPage({super.key});

  @override
  State<MensagensPage> createState() => _MensagensPageState();
}

class _MensagensPageState extends State<MensagensPage> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top actions (Back button + Search + More)
            Padding(
              padding: EdgeInsets.only(top: 8.h, right: 8.w, left: 8.w),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back,
                      color: const Color(0xFF5D201C),
                      size: 24.r,
                    ),
                    onPressed: () => context.pop(),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      Icons.search,
                      color: const Color(0xFF5D201C),
                      size: 28.r,
                    ),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.more_vert,
                      color: const Color(0xFF5D201C),
                      size: 28.r,
                    ),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
            // Large Title
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 8.h),
              child: Text(
                'Mensagens',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 34.sp,
                  color: const Color(0xFF5D201C),
                  letterSpacing: -0.5,
                ),
              ),
            ),
            // List
            Expanded(
              child: _currentIndex == 0 ? _buildPessoasTab() : _buildLojasTab(),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: const Color(0xFFFF6961), // Vermelho do app
        shape: const CircleBorder(),
        elevation: 4,
        child: Icon(Icons.add, color: Colors.white, size: 36.r),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF5D201C),
        unselectedItemColor: Colors.grey.shade500,
        selectedLabelStyle: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12.sp,
        ),
        unselectedLabelStyle: TextStyle(
          fontWeight: FontWeight.normal,
          fontSize: 12.sp,
        ),
        items: const [
          BottomNavigationBarItem(
            icon: Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Icon(Icons.chat),
            ),
            label: 'Pessoas',
          ),
          BottomNavigationBarItem(
            icon: Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Badge(
                smallSize: 10,
                backgroundColor: Color(0xFFFE645C), // Red badge
                child: Icon(Icons.inventory_2_outlined),
              ),
            ),
            label: 'Lojas',
          ),
        ],
      ),
    );
  }

  Widget _buildPessoasTab() {
    return FutureBuilder<List<ConversaPessoaResumo>>(
      future: ChatRepository().listarConversasPessoas(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: LoadingNhac(telaCheia: false, tamanho: 40),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Ainda não há conversas com pessoas.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16.sp),
            ),
          );
        }

        final conversas = snapshot.data ?? [];

        if (conversas.isEmpty) {
          return Center(
            child: Text(
              'Ainda não há conversas com pessoas.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16.sp),
            ),
          );
        }

        return ListView.builder(
          itemCount: conversas.length,
          itemBuilder: (context, index) {
            final item = conversas[index];
            final dateFormat = DateFormat('dd/MM', 'pt_BR');
            final dataStr = dateFormat.format(item.ultimaMensagemData);

            return ListTile(
              contentPadding: EdgeInsets.symmetric(
                horizontal: 24.w,
                vertical: 6.h,
              ),
              leading: CircleAvatar(
                radius: 25.r,
                backgroundColor: Colors.grey.shade300,
                child: Icon(Icons.person, color: Colors.white, size: 34.r),
              ),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      item.pessoaNome,
                      style: TextStyle(
                        fontWeight: item.mensagensNaoLidas > 0
                            ? FontWeight.bold
                            : FontWeight.w500,
                        fontSize: 17.sp,
                        color: const Color(0xFF5D201C),
                      ),
                    ),
                  ),
                  Text(
                    dataStr,
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: item.mensagensNaoLidas > 0
                          ? const Color(0xFFFF6961)
                          : Colors.grey.shade500,
                      fontWeight: item.mensagensNaoLidas > 0
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
              subtitle: Padding(
                padding: EdgeInsets.only(top: 4.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.ultimaMensagem,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: item.mensagensNaoLidas > 0
                            ? const Color(0xFF5D201C)
                            : Colors.grey.shade500,
                        fontWeight: item.mensagensNaoLidas > 0
                            ? FontWeight.w500
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              onTap: () {
                // Future route for chat-pessoa
              },
            );
          },
        );
      },
    );
  }

  Widget _buildLojasTab() {
    return FutureBuilder<List<ConversaResumo>>(
      future: ChatRepository().listarConversas(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: LoadingNhac(telaCheia: false, tamanho: 40),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Ainda não há conversas com lojas.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16.sp),
            ),
          );
        }

        final conversas = snapshot.data ?? [];

        if (conversas.isEmpty) {
          return Center(
            child: Text(
              'Ainda não há conversas com lojas.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16.sp),
            ),
          );
        }

        return ListView.builder(
          itemCount: conversas.length,
          itemBuilder: (context, index) {
            final item = conversas[index];
            final dateFormat = DateFormat('dd/MM', 'pt_BR');
            final dataStr = dateFormat.format(item.ultimaMensagemData);

            return ListTile(
              contentPadding: EdgeInsets.symmetric(
                horizontal: 24.w,
                vertical: 6.h,
              ),
              leading: CircleAvatar(
                radius: 25.r,
                backgroundColor: Colors.grey.shade300,
                child: Icon(Icons.store, color: Colors.white, size: 30.r),
              ),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      item.lojaNome,
                      style: TextStyle(
                        fontWeight: item.mensagensNaoLidas > 0
                            ? FontWeight.bold
                            : FontWeight.w500,
                        fontSize: 17.sp,
                        color: const Color(0xFF5D201C),
                      ),
                    ),
                  ),
                  Text(
                    dataStr,
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: item.mensagensNaoLidas > 0
                          ? const Color(0xFFFF6961)
                          : Colors.grey.shade500,
                      fontWeight: item.mensagensNaoLidas > 0
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
              subtitle: Padding(
                padding: EdgeInsets.only(top: 4.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '[Loja Oficial]', // Placeholder for store context tag
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: const Color(0xFFE67E22), // Orange
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      item.ultimaMensagem,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: item.mensagensNaoLidas > 0
                            ? const Color(0xFF5D201C)
                            : Colors.grey.shade500,
                        fontWeight: item.mensagensNaoLidas > 0
                            ? FontWeight.w500
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              onTap: () {
                context.push(
                  '/chat-loja',
                  extra: {'lojaId': item.lojaId, 'lojaNome': item.lojaNome},
                );
              },
            );
          },
        );
      },
    );
  }
}
