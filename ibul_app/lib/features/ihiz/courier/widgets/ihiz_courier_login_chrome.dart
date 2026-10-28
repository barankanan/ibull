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
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F8FF),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFDCE8F8)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'İHIZ KURYE',
            style: TextStyle(
              color: Color(0xFF1F64D6),
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
              fontSize: 12,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Teslimatı tek ekrandan yönet.',
            style: TextStyle(
              color: Color(0xFF102941),
              fontSize: 32,
              fontWeight: FontWeight.w900,
              height: 1.15,
            ),
          ),
          SizedBox(height: 12),
          Text(
            'Onaylı kurye hesabınla sipariş havuzu, rota ve teslimat adımları açılır.',
            style: TextStyle(
              color: Color(0xFF51677F),
              height: 1.5,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 18),
          _LightPoint('Yakındaki görevleri gör'),
          SizedBox(height: 8),
          _LightPoint('Mağazadan teslim al'),
          SizedBox(height: 8),
          _LightPoint('Müşteriye bırak ve görevi kapat'),
        ],
      ),
    );
  }
}

class _LightPoint extends StatelessWidget {
  const _LightPoint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.check_circle, color: Color(0xFF1F64D6), size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFF102941),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
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
