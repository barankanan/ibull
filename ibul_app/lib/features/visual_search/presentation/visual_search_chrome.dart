import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../../../core/home_navigation.dart';

AppBar visualSearchAppBar(BuildContext context, String title) {
  return AppBar(
    backgroundColor: AppColors.surface,
    surfaceTintColor: AppColors.surface,
    elevation: 0,
    centerTitle: true,
    leading: IconButton(
      icon: const Icon(Icons.arrow_back, color: AppColors.primary),
      onPressed: () {
        if (Navigator.of(context).canPop()) {
          Navigator.pop(context);
          return;
        }
        HomeNavigation.openHome(context, replaceStack: true);
      },
    ),
    title: Text(
      title,
      style: const TextStyle(
        color: AppColors.primary,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class VisualSearchPageBody extends StatelessWidget {
  const VisualSearchPageBody({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 800;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1120),
        child: ListView(
          padding: padding ??
              EdgeInsets.symmetric(horizontal: wide ? 28 : 16, vertical: 20),
          children: [child],
        ),
      ),
    );
  }
}
