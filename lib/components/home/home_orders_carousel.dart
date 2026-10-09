import 'package:flutter/material.dart';

/// Mantém os cartões vivos e usa a altura natural do conteúdo, sem recortes.
class HomeOrdersCarousel extends StatefulWidget {
  const HomeOrdersCarousel({
    super.key,
    required this.orderIds,
    required this.children,
  }) : assert(orderIds.length == children.length);

  final List<String> orderIds;
  final List<Widget> children;

  @override
  State<HomeOrdersCarousel> createState() => _HomeOrdersCarouselState();
}

class _HomeOrdersCarouselState extends State<HomeOrdersCarousel> {
  final _controller = ScrollController();
  int _index = 0;
  double _width = 0;
  bool _realigning = false;

  @override
  void didUpdateWidget(HomeOrdersCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selected = oldWidget.orderIds.isEmpty
        ? null
        : oldWidget.orderIds[_index.clamp(0, oldWidget.orderIds.length - 1).toInt()];
    final next = selected == null ? -1 : widget.orderIds.indexOf(selected);
    final index = next >= 0
        ? next
        : widget.orderIds.isEmpty
            ? 0
            : _index.clamp(0, widget.orderIds.length - 1).toInt();
    if (index != _index || oldWidget.orderIds.length != widget.orderIds.length) {
      _index = index;
      _alignAfterLayout();
    }
  }

  void _alignAfterLayout() {
    _realigning = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_controller.hasClients) {
        _controller.jumpTo((_index * _width)
            .clamp(0.0, _controller.position.maxScrollExtent).toDouble());
      }
      _realigning = false;
    });
  }

  void _goTo(int index) {
    if (!_controller.hasClients) return;
    _controller.animateTo(
      index * _width,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      if (_width != constraints.maxWidth) {
        _width = constraints.maxWidth;
        _alignAfterLayout();
      }
      return Column(mainAxisSize: MainAxisSize.min, children: [
        NotificationListener<ScrollUpdateNotification>(
          onNotification: (notification) {
            if (!_realigning && _width > 0 && widget.orderIds.isNotEmpty &&
                notification.metrics.axis == Axis.horizontal) {
              final index = (notification.metrics.pixels / _width)
                  .round()
                  .clamp(0, widget.orderIds.length - 1).toInt();
              if (_index != index) setState(() => _index = index);
            }
            return false;
          },
          child: SingleChildScrollView(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            physics: const PageScrollPhysics(),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < widget.children.length; i++)
                  SizedBox(
                    key: ValueKey('carousel-${widget.orderIds[i]}'),
                    width: _width,
                    child: widget.children[i],
                  ),
              ],
            ),
          ),
        ),
        if (widget.orderIds.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton(
                tooltip: 'Pedido anterior',
                color: const Color(0xFF5D201C),
                onPressed: _index > 0 ? () => _goTo(_index - 1) : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Semantics(
                liveRegion: true,
                child: Text(
                  'Pedido ${_index + 1} de ${widget.orderIds.length}',
                  style: const TextStyle(
                    color: Color(0xFF5D201C),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Próximo pedido',
                color: const Color(0xFF5D201C),
                onPressed: _index < widget.orderIds.length - 1
                    ? () => _goTo(_index + 1)
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ]),
          ),
      ]);
    });
  }
}
