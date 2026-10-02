import 'package:flutter/material.dart';

import '../../screens/ibul_not_found_page.dart';
import 'blog_paths.dart';
import 'screens/blog_home_page.dart';
import 'screens/blog_post_page.dart';
import 'screens/blog_preview_page.dart';
import 'screens/blog_studio_page.dart';

/// Entry point of the deferred blog library (see `app_route_table.dart`).
Widget blogPageForPath(String path, Object? arguments) {
  if (path == BlogPaths.root) return BlogHomePage.fromArguments(arguments);
  if (path == BlogPaths.studio) return const BlogStudioPage();
  final previewId = BlogPaths.previewIdFrom(path);
  if (previewId != null) return BlogPreviewPage(postId: previewId);
  final slug = BlogPaths.slugFrom(path);
  if (slug != null) return BlogPostPage(slug: slug);
  return IbulNotFoundPage(path: path);
}
