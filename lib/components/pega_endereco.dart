import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lottie/lottie.dart';
import 'package:dio/dio.dart';
import 'package:nhac/globals/app_constants.dart';
import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart';
import 'package:nhac/utils/endereco_utils.dart';

class AddressPickerSheet extends StatefulWidget {
  const AddressPickerSheet({super.key});

  @override
  State<AddressPickerSheet> createState() => _AddressPickerSheetState();
}

class _AddressPickerSheetState extends State<AddressPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  final FocusNode _focusNode = FocusNode();
  List<Map<String, dynamic>> _sugestoes = [];
  bool _estaDigitando = false;
  bool _isLoadingSearch = false;
  Timer? _debounce;
  final Dio _dio = Dio();
  final String _googleApiKey = AppConstants.googlePlacesApiKey;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        _sheetController.animateTo(
          0.95,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _filtrarEnderecos(String query) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();

    if (query.isEmpty) {
      setState(() {
        _sugestoes = [];
        _estaDigitando = false;
        _isLoadingSearch = false;
      });
      return;
    }

    setState(() {
      _estaDigitando = true;
      _isLoadingSearch = true;
    });

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted) return;
      if (_googleApiKey.isEmpty) {
        debugPrint('🚨 ERRO CRÍTICO: A chave do Google (API Key) está vazia!');
        debugPrint(
            'Verifique se o arquivo .env existe e se está declarado no pubspec.yaml.');
        setState(() => _isLoadingSearch = false);
        return;
      }

      try {
        final places = FlutterGooglePlacesSdk(_googleApiKey);
        final response = await places.findAutocompletePredictions(
          query,
          countries: ['br'],
          // Sem isso o Google devolve cidade, estado e país junto.
          placeTypesFilter: [PlaceTypeFilter.ADDRESS],
        );

        setState(() {
          _sugestoes = response.predictions
              .map((p) => {
                    'description': p.fullText,
                    'place_id': p.placeId,
                    'main_text': p.primaryText,
                    'secondary_text': p.secondaryText,
                  })
              .toList();
          _isLoadingSearch = false;
        });
      } catch (e) {
        debugPrint('⚠️ ERRO DE REQUISIÇÃO (Places SDK): $e');
        setState(() {
          _sugestoes = [];
          _isLoadingSearch = false;
        });
      }
    });
  }

  Future<void> _obterDetalhes(String placeId) async {
    setState(() {
      _isLoadingSearch = true;
    });

    try {
      final response = await _dio.get(
        'https://maps.googleapis.com/maps/api/place/details/json',
        queryParameters: {
          'place_id': placeId,
          'key': _googleApiKey,
          'language': 'pt-BR',
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['status'] == 'OK') {
          final result = data['result'];
          final components = result['address_components'] as List;

          String rua = '';
          String numero = '';
          String bairro = '';
          String cidade = '';
          String estado = '';

          for (var c in components) {
            final types = c['types'] as List;
            if (types.contains('route')) {
              rua = c['long_name'];
            }
            if (types.contains('street_number')) {
              numero = c['long_name'];
            }
            if (types.contains('sublocality') ||
                types.contains('sublocality_level_1') ||
                types.contains('neighborhood')) {
              bairro = c['long_name'];
            }
            if (types.contains('administrative_area_level_2')) {
              cidade = c['long_name'];
            }
            if (types.contains('administrative_area_level_1')) {
              estado = c['short_name'];
            }
          }

          if (mounted) {
            Navigator.pop(context, {
              'rua': rua,
              'numero': EnderecoUtils.normalizarNumero(numero),
              'bairro': bairro,
              'cidade': cidade,
              'estado': EnderecoUtils.normalizarEstado(estado),
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Erro ao obter detalhes do local: \$e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingSearch = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: 0.60,
      minChildSize: 0.60,
      maxChildSize: 0.95,
      snap: true,
      snapSizes: const [0.60, 0.95],
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
          ),
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(vertical: 16.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                        width: 8.w,
                        height: 8.h,
                        decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            shape: BoxShape.circle)),
                    SizedBox(width: 8.w),
                    Container(
                        width: 8.w,
                        height: 8.h,
                        decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            shape: BoxShape.circle)),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.symmetric(horizontal: 24.w),
                  children: [
                    Text(
                      'Onde você quer receber o seu pedido?',
                      style: TextStyle(
                          fontSize: 22.sp,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF5D201C)),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                        'Busque pelo nome da rua e pelo número do seu endereço.',
                        style: TextStyle(fontSize: 14.sp, color: Colors.grey)),
                    SizedBox(height: 24.h),
                    TextField(
                      controller: _searchController,
                      focusNode: _focusNode,
                      onChanged: _filtrarEnderecos,
                      style: TextStyle(
                          color: const Color(0xFF5D201C),
                          fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: 'Nome da rua e número',
                        hintStyle: const TextStyle(color: Color(0xFFC9BCBC)),
                        enabledBorder: const UnderlineInputBorder(
                            borderSide:
                                BorderSide(color: Colors.grey, width: 1.0)),
                        focusedBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(
                                color: Color(0xFFC9BCBC), width: 2.0)),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear, size: 20.r),
                                onPressed: () {
                                  _searchController.clear();
                                  _filtrarEnderecos('');
                                },
                              )
                            : null,
                      ),
                    ),
                    SizedBox(height: 20.h),
                    if (_isLoadingSearch)
                      Center(
                          child: Lottie.asset(
                              'assets/animations/loading_nhac.json',
                              width: 150.w,
                              height: 150.h))
                    else if (_sugestoes.isEmpty && _estaDigitando)
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 40.h),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.search_off_outlined,
                                  size: 48.r, color: Colors.grey.shade200),
                              SizedBox(height: 16.h),
                              const Text('Nenhum endereço encontrado',
                                  style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ),
                      )
                    else
                      ..._sugestoes.map((item) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  shape: BoxShape.circle),
                              child: Icon(Icons.location_on_outlined,
                                  size: 20.r, color: Colors.grey),
                            ),
                            title: Text(item['main_text'].toString(),
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15.sp)),
                            subtitle: Text(item['secondary_text'].toString()),
                            onTap: () {
                              _obterDetalhes(item['place_id']);
                            },
                          )),
                    SizedBox(height: 20.h),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
