import 'dart:math' as math;
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class AvatarCropPage extends StatefulWidget {
  final File arquivo;
  const AvatarCropPage({super.key, required this.arquivo});
  @override
  State<AvatarCropPage> createState() => _AvatarCropPageState();
}

class _AvatarCropPageState extends State<AvatarCropPage> {
  final _boundary = GlobalKey();
  ui.Image? _image;
  String? _error;
  double _zoom = 1, _initialZoom = 1;
  Offset _offset = Offset.zero,
      _initialOffset = Offset.zero,
      _focal = Offset.zero;
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final codec = await ui.instantiateImageCodec(
        await widget.arquivo.readAsBytes(),
      );
      final frame = await codec.getNextFrame();
      codec.dispose();
      if (!mounted) {
        frame.image.dispose();
        return;
      }
      setState(() => _image = frame.image);
    } catch (_) {
      if (mounted)
        setState(
          () => _error =
              'Não foi possível abrir esta foto. Escolha outra imagem.',
        );
    }
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final image =
          await (_boundary.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (bytes == null) throw StateError('Falha ao recortar');
      final dir = await Directory.systemTemp.createTemp('nhac-avatar-');
      final file = await File('${dir.path}/avatar.png')
          .writeAsBytes(bytes.buffer.asUint8List(), flush: true);
      if (mounted) Navigator.pop(context, file);
    } catch (_) {
      if (mounted)
        setState(
          () => _error =
              'Não foi possível salvar o enquadramento. Tente novamente.',
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFFFF6F5),
    appBar: AppBar(
      title: const Text('Enquadrar foto'),
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF5D201C),
    ),
    body: SafeArea(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Arraste para posicionar e use dois dedos para ampliar.',
            ),
          ),
          if (_image == null)
            Expanded(
              child: Center(
                child: _error == null
                    ? const CircularProgressIndicator()
                    : Text(_error!),
              ),
            )
          else
            Expanded(
              child: Center(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final side = math
                        .min(
                          constraints.maxWidth - 48,
                          constraints.maxHeight - 16,
                        )
                        .clamp(64.0, 320.0)
                        .toDouble();
                    return GestureDetector(
                      onScaleStart: (d) {
                        _initialZoom = _zoom;
                        _initialOffset = _offset;
                        _focal = d.focalPoint;
                      },
                      onScaleUpdate: (d) => setState(() {
                        _zoom = (_initialZoom * d.scale)
                            .clamp(1.0, 5.0)
                            .toDouble();
                        final scale =
                            (side / _image!.width > side / _image!.height
                                ? side / _image!.width
                                : side / _image!.height) *
                            _zoom;
                        final x = (_image!.width * scale - side) / 2,
                            y = (_image!.height * scale - side) / 2;
                        final candidate =
                            _initialOffset + d.focalPoint - _focal;
                        _offset = Offset(
                          candidate.dx.clamp(-x, x).toDouble(),
                          candidate.dy.clamp(-y, y).toDouble(),
                        );
                      }),
                      child: ClipOval(
                        child: RepaintBoundary(
                          key: _boundary,
                          child: CustomPaint(
                            size: Size.square(side),
                            painter: _AvatarPainter(_image!, _zoom, _offset),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          if (_error != null && _image != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),
          Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6961),
                ),
                onPressed: _image == null || _saving ? null : _save,
                child: Text(
                  _saving ? 'Salvando...' : 'Usar este enquadramento',
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _AvatarPainter extends CustomPainter {
  final ui.Image image;
  final double zoom;
  final Offset offset;
  _AvatarPainter(this.image, this.zoom, this.offset);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    final scale =
        (size.width / image.width > size.height / image.height
            ? size.width / image.width
            : size.height / image.height) *
        zoom;
    final width = image.width * scale, height = image.height * scale;
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(
        (size.width - width) / 2 + offset.dx,
        (size.height - height) / 2 + offset.dy,
        width,
        height,
      ),
      Paint()..filterQuality = FilterQuality.high,
    );
  }

  @override
  bool shouldRepaint(covariant _AvatarPainter old) =>
      old.image != image || old.zoom != zoom || old.offset != offset;
}
