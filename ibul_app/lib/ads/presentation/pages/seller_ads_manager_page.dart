import 'package:flutter/material.dart';

import 'seller_ads_manager_content.dart';

class SellerAdsManagerPage extends StatefulWidget {
  const SellerAdsManagerPage({required this.sellerId, super.key});

  final String sellerId;

  @override
  State<SellerAdsManagerPage> createState() => _SellerAdsManagerPageState();
}

class _SellerAdsManagerPageState extends State<SellerAdsManagerPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Seller Ads Manager')),
      body: SellerAdsManagerContent(sellerId: widget.sellerId),
    );
  }
}
