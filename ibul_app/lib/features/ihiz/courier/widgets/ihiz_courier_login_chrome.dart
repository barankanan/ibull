import 'package:flutter/material.dart';

class IhizCourierSectionShell extends StatelessWidget {
  const IhizCourierSectionShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE6EEF9)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0E2A47).withValues(alpha: 0.06),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class IhizCourierHeroChip extends StatelessWidget {
  const IhizCourierHeroChip(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class IhizCourierLoginPoint extends StatelessWidget {
  const IhizCourierLoginPoint(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_circle, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class IhizCourierLoginMarketingSection extends StatelessWidget {
  const IhizCourierLoginMarketingSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF163B73), Color(0xFF2C6BC0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IhizCourierHeroChip('Sadece onaylı kuryeler'),
          SizedBox(height: 18),
          Text(
            'İhız kurye paneline giriş',
            style: TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),
          SizedBox(height: 12),
          Text(
            'Giriş sonrası sipariş havuzu, canlı rota, mağaza adresi ve müşteri teslim ekranları açılır.',
            style: TextStyle(color: Colors.white70, height: 1.6, fontSize: 15),
          ),
          SizedBox(height: 20),
          IhizCourierLoginPoint('Sipariş havuzundan görev seç'),
          SizedBox(height: 10),
          IhizCourierLoginPoint('Mağazadan teslim al'),
          SizedBox(height: 10),
          IhizCourierLoginPoint('Müşteriye bırak ve görevi kapat'),
        ],
      ),
    );
  }
}

class IhizCourierFieldLabel extends StatelessWidget {
  const IhizCourierFieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF163B73),
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class IhizCourierInput extends StatelessWidget {
  const IhizCourierInput({
    super.key,
    required this.hint,
    this.obscure = false,
    this.controller,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
  });

  final String hint;
  final bool obscure;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      obscureText: obscure,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF6F9FF),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
