import 'package:flutter/material.dart';

import 'admin_ads_manager_content.dart';

class AdminAdsManagerPage extends StatefulWidget {
  const AdminAdsManagerPage({super.key});

  @override
  State<AdminAdsManagerPage> createState() => _AdminAdsManagerPageState();
}

class _AdminAdsManagerPageState extends State<AdminAdsManagerPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ads Manager')),
      body: const AdminAdsManagerContent(),
    );
  }
}
