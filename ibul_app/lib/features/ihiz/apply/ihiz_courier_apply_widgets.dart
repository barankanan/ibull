import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/ihiz_brand.dart';
import '../widgets/ihiz_landing_widgets.dart';
import '../../../services/ihiz_courier_application_service.dart';

class IhizApplyTextField extends StatelessWidget {
  const IhizApplyTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.keyboardType,
    this.obscureText = false,
    this.readOnly = false,
    this.onTap,
    this.onChanged,
    this.inputFormatters,
    this.maxLength,
    this.maxLines = 1,
    this.hasError = false,
    this.errorText,
    this.suffixIcon,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;
  final bool obscureText;
  final bool readOnly;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final int maxLines;
  final bool hasError;
  final String? errorText;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: IhizBrand.ink,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          readOnly: readOnly,
          onTap: onTap,
          onChanged: onChanged,
          inputFormatters: inputFormatters,
          maxLength: maxLength,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            counterText: '',
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: Colors.white,
            errorText: hasError ? errorText : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: IhizBrand.line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: hasError ? Colors.red.shade300 : IhizBrand.line,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: hasError ? Colors.red : IhizBrand.blue,
                width: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class IhizApplySelectField extends StatelessWidget {
  const IhizApplySelectField({
    super.key,
    required this.label,
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hasError = false,
    this.errorText,
  });

  final String label;
  final String hint;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final bool hasError;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: IhizBrand.ink,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          // Controlled select: `value` still required for live updates.
          // ignore: deprecated_member_use
          value: value,
          isExpanded: true,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.white,
            errorText: hasError ? errorText : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: IhizBrand.line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: hasError ? Colors.red.shade300 : IhizBrand.line,
              ),
            ),
          ),
          items: items
              .map(
                (item) => DropdownMenuItem<String>(
                  value: item,
                  child: Text(item, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class IhizApplyDocumentCard extends StatelessWidget {
  const IhizApplyDocumentCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.document,
    required this.isPicking,
    required this.onPick,
    required this.onRemove,
    this.hasError = false,
  });

  final String title;
  final String subtitle;
  final IhizPickedDocument? document;
  final bool isPicking;
  final VoidCallback onPick;
  final VoidCallback onRemove;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final selected = document != null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasError
              ? Colors.red.shade300
              : (selected ? IhizBrand.blue.withValues(alpha: 0.45) : IhizBrand.line),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: IhizBrand.ink,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            selected ? document!.name : subtitle,
            style: TextStyle(
              color: selected ? IhizBrand.inkSoft : IhizBrand.inkSoft,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              IhizPrimaryButton(
                label: isPicking ? 'Seçiliyor…' : (selected ? 'Değiştir' : 'Dosya Seç'),
                icon: Icons.upload_file_rounded,
                onPressed: isPicking ? () {} : onPick,
              ),
              if (selected)
                IhizSecondaryButton(
                  label: 'Kaldır',
                  icon: Icons.delete_outline_rounded,
                  onPressed: onRemove,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class IhizApplyStepIndicator extends StatelessWidget {
  const IhizApplyStepIndicator({
    super.key,
    required this.currentStep,
    required this.labels,
    required this.invalidSteps,
  });

  final int currentStep;
  final List<String> labels;
  final Set<int> invalidSteps;

  @override
  Widget build(BuildContext context) {
    final mobile = IhizBrand.isMobile(MediaQuery.sizeOf(context).width);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < labels.length; i++)
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: mobile ? 10 : 12,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: i == currentStep
                  ? IhizBrand.blue
                  : (invalidSteps.contains(i)
                      ? Colors.red.shade50
                      : Colors.white),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: i == currentStep
                    ? IhizBrand.blue
                    : (invalidSteps.contains(i)
                        ? Colors.red.shade300
                        : IhizBrand.line),
              ),
            ),
            child: Text(
              '${i + 1}. ${labels[i]}',
              style: TextStyle(
                color: i == currentStep
                    ? Colors.white
                    : (invalidSteps.contains(i)
                        ? Colors.red.shade700
                        : IhizBrand.inkSoft),
                fontWeight: FontWeight.w700,
                fontSize: mobile ? 11.5 : 12.5,
              ),
            ),
          ),
      ],
    );
  }
}

/// İki kolon / tek kolon form satırı.
class IhizApplyFieldGrid extends StatelessWidget {
  const IhizApplyFieldGrid({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoCol = constraints.maxWidth >= 720;
        final gap = 12.0;
        final width = twoCol
            ? (constraints.maxWidth - gap) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final child in children)
              SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

class IhizApplyNavBar extends StatelessWidget {
  const IhizApplyNavBar({
    super.key,
    required this.mobile,
    required this.currentStep,
    required this.isSubmitting,
    required this.onBack,
    required this.onNext,
    required this.onSubmit,
  });

  final bool mobile;
  final int currentStep;
  final bool isSubmitting;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final primary = currentStep < 4
        ? IhizPrimaryButton(
            label: 'Devam',
            icon: Icons.arrow_forward_rounded,
            onPressed: onNext,
            expanded: mobile,
          )
        : IhizPrimaryButton(
            label: isSubmitting ? 'Gönderiliyor…' : 'Başvuruyu Gönder',
            icon: Icons.send_rounded,
            onPressed: isSubmitting ? () {} : onSubmit,
            expanded: mobile,
          );
    final back = IhizSecondaryButton(
      label: currentStep == 0 ? 'Vazgeç' : 'Geri',
      onPressed: isSubmitting ? () {} : onBack,
      expanded: mobile,
    );

    return Container(
      padding: EdgeInsets.fromLTRB(mobile ? 16 : 28, 12, mobile ? 16 : 28, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: IhizBrand.line)),
      ),
      child: SafeArea(
        top: false,
        child: mobile
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  primary,
                  const SizedBox(height: 8),
                  back,
                ],
              )
            : Row(
                children: [
                  back,
                  const Spacer(),
                  primary,
                ],
              ),
      ),
    );
  }
}

class IhizApplySuccessView extends StatelessWidget {
  const IhizApplySuccessView({
    super.key,
    required this.onLogin,
    required this.onDone,
  });

  final VoidCallback onLogin;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final mobile = IhizBrand.isMobile(MediaQuery.sizeOf(context).width);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(mobile ? 20 : 28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: IhizBrand.line),
            boxShadow: IhizBrand.cardShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: IhizBrand.mint.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: IhizBrand.mint,
                  size: 36,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Başvurunuz başarıyla alındı.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: IhizBrand.ink,
                  fontWeight: FontWeight.w900,
                  fontSize: mobile ? 22 : 26,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Başvurunuz incelendikten sonra sonuç tarafınıza bildirilecektir.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: IhizBrand.inkSoft,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 22),
              if (mobile)
                Column(
                  children: [
                    IhizPrimaryButton(
                      label: 'Giriş Yap',
                      icon: Icons.login_rounded,
                      onPressed: onLogin,
                      expanded: true,
                    ),
                    const SizedBox(height: 10),
                    IhizSecondaryButton(
                      label: 'Tamam',
                      onPressed: onDone,
                      expanded: true,
                    ),
                  ],
                )
              else
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    IhizPrimaryButton(
                      label: 'Giriş Yap',
                      icon: Icons.login_rounded,
                      onPressed: onLogin,
                    ),
                    IhizSecondaryButton(
                      label: 'Tamam',
                      onPressed: onDone,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}


