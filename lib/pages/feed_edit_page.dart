import 'package:flutter/material.dart';
import 'package:nhac/models/feed/feed_post_model.dart';
import 'package:nhac/pages/feed_publish_page.dart';

class FeedEditPage extends StatelessWidget {
  final FeedPostModel post;
  const FeedEditPage({super.key, required this.post});
  @override
  Widget build(BuildContext context) => FeedPublishPage(post: post);
}
