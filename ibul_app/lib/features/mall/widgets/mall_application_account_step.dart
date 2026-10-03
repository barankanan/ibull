import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Logs only the field name and length; values may be secrets or tax ids.
void logMallFormInput(String field, String value) {
  if (!kDebugMode) return;
  debugPrint('[MALL][FORM_INPUT] field=$field len=${value.length}');
}

class MallApplicationAccountStep extends StatelessWidget {
  const MallApplicationAccountStep({
    super.key,
    required this.signedIn,
    required this.existingAccount,
    required this.givenName,
    required this.surname,
    required this.email,
    required this.phone,
    required this.title,
    required this.password,
    required this.confirm,
  });

  final bool signedIn;
  final bool existingAccount;
  final TextEditingController givenName;
  final TextEditingController surname;
  final TextEditingController email;
  final TextEditingController phone;
  final TextEditingController title;
  final TextEditingController password;
  final TextEditingController confirm;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Hesap ve Yetkili',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          signedIn
              ? 'İBUL hesabınız kullanılacak. Ayrı bir AVM şifresi yoktur.'
              : 'Başvuru mevcut İBUL hesabınızla açılır. Şifre başvuruya yazılmaz.',
        ),
        const SizedBox(height: 16),
        if (existingAccount && !signedIn) ...[
          const Text(
            'Bu e-posta ile bir İBUL hesabı zaten bulunuyor.',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
        ],
        _grid([
          _box(givenName, 'Ad *', field: 'given_name'),
          _box(surname, 'Soyad *', field: 'surname'),
          _box(
            email,
            'E-posta *',
            field: 'email',
            readOnly: existingAccount ||
                (signedIn && email.text.trim().isNotEmpty),
          ),
          _box(
            phone,
            'Telefon *',
            field: 'phone',
            keyboard: TextInputType.phone,
          ),
          if (!signedIn && !existingAccount) ...[
            _box(password, 'Şifre *', field: 'password', obscure: true),
            _box(confirm, 'Şifre tekrar *', field: 'confirm', obscure: true),
          ],
          if (existingAccount && !signedIn)
            _box(password, 'Şifre *', field: 'password', obscure: true),
          _box(title, 'Yetkili görevi / ünvanı *', field: 'title'),
        ]),
      ],
    );
  }

  Widget _grid(List<Widget> children) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 640;
        if (!wide) {
          return Column(
            children: [
              for (final child in children) ...[
                child,
                const SizedBox(height: 12),
              ],
            ],
          );
        }
        final rows = <Widget>[];
        for (var i = 0; i < children.length; i += 2) {
          rows.add(
            Row(
              children: [
                Expanded(child: children[i]),
                const SizedBox(width: 12),
                Expanded(
                  child: i + 1 < children.length
                      ? children[i + 1]
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          );
          rows.add(const SizedBox(height: 12));
        }
        return Column(children: rows);
      },
    );
  }

  Widget _box(
    TextEditingController controller,
    String label, {
    required String field,
    bool obscure = false,
    bool readOnly = false,
    TextInputType? keyboard,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      readOnly: readOnly,
      keyboardType: keyboard,
      onChanged: (value) => logMallFormInput(field, value),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
