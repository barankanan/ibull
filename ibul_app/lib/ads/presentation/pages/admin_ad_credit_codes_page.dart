import 'package:flutter/material.dart';

import '../widgets/admin_ad_credit_codes_panel.dart';

class AdminAdCreditCodesPage extends StatelessWidget {
  const AdminAdCreditCodesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Reklam Kredisi'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: const [AdminAdCreditCodesPanel()],
      ),
    );
  }
}
