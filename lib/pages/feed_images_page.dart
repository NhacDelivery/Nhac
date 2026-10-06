import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class FeedImagesPage extends StatefulWidget {
  final List<String> imagens;
  final int inicial;
  const FeedImagesPage({super.key, required this.imagens, this.inicial = 0});
  @override
  State<FeedImagesPage> createState() => _FeedImagesPageState();
}

class _FeedImagesPageState extends State<FeedImagesPage> {
  late final PageController _controller = PageController(
    initialPage: widget.inicial,
  );
  late int _index = widget.inicial;
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      title: Text('${_index + 1} de ${widget.imagens.length}'),
    ),
    body: PageView.builder(
      controller: _controller,
      itemCount: widget.imagens.length,
      onPageChanged: (i) => setState(() => _index = i),
      itemBuilder: (_, i) => InteractiveViewer(
        minScale: 1,
        maxScale: 5,
        child: Center(
          child: CachedNetworkImage(
            imageUrl: widget.imagens[i],
            fit: BoxFit.contain,
            placeholder: (_, __) => const CircularProgressIndicator(),
            errorWidget: (_, __, ___) => const Text(
              'Não foi possível carregar a foto.',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
      ),
    ),
  );
}
