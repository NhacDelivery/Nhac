import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

class FeedShareService {
  static Uri link(String id) =>
      Uri(scheme: 'nhac', host: 'app', pathSegments: ['publicacao', id]);
  static Future<void> compartilhar(BuildContext context, String id) async {
    final box = context.findRenderObject();
    await Share.share(
      'Veja esta publicação no Nhac: ${link(id)}',
      sharePositionOrigin: box is RenderBox
          ? box.localToGlobal(Offset.zero) & box.size
          : null,
    );
  }
}
